// Reemplaza la llamada directa a la API de Gemini desde el navegador
// (audit_screen.dart) por una llamada de servidor, para que GEMINI_API_KEY
// nunca viaje al cliente ni quede expuesta en el build web.
//
// El cliente sigue armando el prompt (no es secreto) y sigue parseando la
// respuesta JSON como antes; lo único que cambia es el transporte.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Sin esto, el navegador bloquea la llamada en el preflight (OPTIONS) antes
// de que siquiera llegue a la función -- Deno.serve no las agrega por defecto.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// gemini-2.5-flash dejó de estar disponible para API keys nuevas (Google
// pide migrar a gemini-3.6-flash); confirmado probando la key real.
const GEMINI_MODEL = "gemini-3.6-flash";

const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "application/pdf"]);
const MAX_PROMPT_CHARS = 20_000;
// 8 MB de archivo ≈ 10,7 M caracteres en base64.
const MAX_BASE64_CHARS = 11_000_000;

// Límite por usuario: máx. 10 llamadas por minuto. Es en memoria, así que
// se reinicia con cada instancia de la función; frena el abuso casual sin
// necesitar una tabla extra.
const RATE_LIMIT_MAX = 10;
const RATE_LIMIT_WINDOW_MS = 60_000;
const callsByUser = new Map<string, number[]>();

function isRateLimited(userId: string): boolean {
  const now = Date.now();
  const recent = (callsByUser.get(userId) ?? []).filter((t) => now - t < RATE_LIMIT_WINDOW_MS);
  if (recent.length >= RATE_LIMIT_MAX) {
    callsByUser.set(userId, recent);
    return true;
  }
  recent.push(now);
  callsByUser.set(userId, recent);
  return false;
}

// Anota cada llamada en la tabla uso_ia para el panel de administración. Es solo
// un registro: si falla, la solicitud del usuario no debe fallar con él. Escribe
// con la llave de servicio (ningún usuario puede insertar filas por su cuenta).
// No guarda el contenido de lo enviado, solo datos de la llamada.
async function registrarUso(fila: {
  usuarioId: string;
  resultado: "ok" | "error" | "limitado";
  httpStatus?: number;
  conArchivo: boolean;
  tipoArchivo?: string;
  promptChars: number;
  duracionMs?: number;
}): Promise<void> {
  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) {
      console.error("No se registró el uso de la IA: falta SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en la función.");
      return;
    }
    const admin = createClient(url, serviceKey);
    const { error } = await admin.from("uso_ia").insert({
      usuario_id: fila.usuarioId,
      resultado: fila.resultado,
      http_status: fila.httpStatus ?? null,
      con_archivo: fila.conArchivo,
      tipo_archivo: fila.tipoArchivo ?? null,
      prompt_chars: fila.promptChars,
      duracion_ms: fila.duracionMs ?? null,
    });
    if (error) console.error("No se pudo registrar el uso de la IA:", error.message);
  } catch (e) {
    console.error("No se pudo registrar el uso de la IA:", e);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
  // Proveedor alternativo: si existe OPENAI_API_KEY se usa OpenAI en vez de
  // Gemini (el contrato con la app no cambia: sigue devolviendo { text }).
  const openaiApiKey = Deno.env.get("OPENAI_API_KEY");

  if (!supabaseUrl || !anonKey || (!geminiApiKey && !openaiApiKey)) {
    // Devolver un error con headers CORS en vez de dejar que Deno.env.get(...)!
    // lance una excepción no capturada (esa respuesta de error no lleva
    // corsHeaders y el navegador vuelve a ver un "Failed to fetch" genérico).
    return new Response("Faltan variables de entorno en el servidor", {
      status: 500,
      headers: corsHeaders,
    });
  }

  // Cualquier usuario autenticado de la app puede usar su propia auditoría
  // con IA; no requiere rol de administrador.
  const supabaseCaller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: callerData, error: callerErr } = await supabaseCaller.auth.getUser();
  if (callerErr || !callerData.user) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  let body: { prompt?: string; imageBase64?: string; imageMimeType?: string };
  try {
    body = await req.json();
  } catch {
    return new Response("Body invalido", { status: 400, headers: corsHeaders });
  }

  if (!body.prompt) {
    return new Response("prompt es requerido", { status: 400, headers: corsHeaders });
  }

  // Límites para que una cuenta cualquiera no pueda usar este proxy como
  // acceso gratuito a la cuota de Gemini (el registro es abierto).
  if (body.prompt.length > MAX_PROMPT_CHARS) {
    return new Response("prompt demasiado largo", { status: 413, headers: corsHeaders });
  }
  if (body.imageBase64 || body.imageMimeType) {
    if (!body.imageBase64 || !body.imageMimeType) {
      return new Response("imageBase64 e imageMimeType van juntos", { status: 400, headers: corsHeaders });
    }
    if (!ALLOWED_MIME_TYPES.has(body.imageMimeType)) {
      return new Response("Tipo de archivo no permitido", { status: 415, headers: corsHeaders });
    }
    if (body.imageBase64.length > MAX_BASE64_CHARS) {
      return new Response("Archivo demasiado grande (máx. 8 MB)", { status: 413, headers: corsHeaders });
    }
  }
  const usuarioId = callerData.user.id;
  const conArchivo = Boolean(body.imageBase64);
  const base = {
    usuarioId,
    conArchivo,
    tipoArchivo: body.imageMimeType,
    promptChars: body.prompt.length,
  };
  if (isRateLimited(usuarioId)) {
    await registrarUso({ ...base, resultado: "limitado", httpStatus: 429 });
    return new Response("Demasiadas solicitudes, intenta en un minuto", {
      status: 429,
      headers: { ...corsHeaders, "Retry-After": "60" },
    });
  }

  // ---- Proveedor OpenAI (se activa con el secreto OPENAI_API_KEY) ----------
  if (openaiApiKey) {
    const modeloOpenAI = Deno.env.get("OPENAI_MODEL");
    if (!modeloOpenAI) {
      return new Response("Falta el secreto OPENAI_MODEL (nombre del modelo de OpenAI)", {
        status: 500,
        headers: corsHeaders,
      });
    }
    const contenido: Record<string, unknown>[] = [{ type: "text", text: body.prompt }];
    if (body.imageBase64 && body.imageMimeType) {
      const dataUrl = `data:${body.imageMimeType};base64,${body.imageBase64}`;
      contenido.push(
        body.imageMimeType === "application/pdf"
          ? { type: "file", file: { filename: "documento.pdf", file_data: dataUrl } }
          : { type: "image_url", image_url: { url: dataUrl } },
      );
    }
    // Con "extras" se piden respuesta JSON y razonamiento mínimo: la extracción de
    // datos de una boleta no necesita "pensar" (el modelo razona en nivel medio por
    // defecto, lo que la haría lenta y más cara). Si el modelo rechazara alguno de
    // esos parámetros (error 400), se repite una vez sin ellos.
    const armarCuerpo = (conExtras: boolean) =>
      JSON.stringify({
        model: modeloOpenAI,
        messages: [{ role: "user", content: contenido }],
        ...(conExtras
          ? {
              response_format: { type: "json_object" },
              reasoning_effort: Deno.env.get("OPENAI_REASONING_EFFORT") ?? "none",
            }
          : {}),
      });
    const llamarOpenAI = (conExtras = true) =>
      fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${openaiApiKey}` },
        body: armarCuerpo(conExtras),
      });

    const inicioOpenAI = Date.now();
    // 500/502/503/504 son fallas pasajeras del proveedor: se reintenta hasta 3 veces.
    const REINTENTABLES_OPENAI = new Set([500, 502, 503, 504]);
    const ESPERAS_OPENAI_MS = [1500, 3000];
    let respuesta = await llamarOpenAI();
    if (respuesta.status === 400) {
      const detalle400 = await respuesta.text();
      console.error(`gemini-proxy: OpenAI rechazó (400) con parámetros extra; se reintenta sin ellos: ${detalle400.slice(0, 300)}`);
      respuesta = await llamarOpenAI(false);
    }
    for (let i = 0; i < ESPERAS_OPENAI_MS.length && REINTENTABLES_OPENAI.has(respuesta.status); i++) {
      await respuesta.body?.cancel();
      await new Promise((r) => setTimeout(r, ESPERAS_OPENAI_MS[i]));
      respuesta = await llamarOpenAI();
    }

    if (!respuesta.ok) {
      const errorText = await respuesta.text();
      console.error(`gemini-proxy: OpenAI respondió ${respuesta.status} (modelo ${modeloOpenAI}): ${errorText.slice(0, 500)}`);
      await registrarUso({ ...base, resultado: "error", httpStatus: respuesta.status, duracionMs: Date.now() - inicioOpenAI });
      return new Response(`Error de OpenAI: ${errorText}`, { status: 502, headers: corsHeaders });
    }

    const resultado = await respuesta.json();
    const textoOpenAI = resultado?.choices?.[0]?.message?.content ?? "";
    if (!textoOpenAI) {
      const motivo = resultado?.choices?.[0]?.finish_reason ?? "sin contenido";
      console.error(`gemini-proxy: OpenAI devolvió una respuesta vacía (${motivo})`);
      await registrarUso({ ...base, resultado: "error", httpStatus: 502, duracionMs: Date.now() - inicioOpenAI });
      return new Response(`La IA no devolvió una respuesta utilizable (${motivo})`, { status: 502, headers: corsHeaders });
    }

    await registrarUso({ ...base, resultado: "ok", duracionMs: Date.now() - inicioOpenAI });
    return new Response(JSON.stringify({ text: textoOpenAI }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Si viene una imagen (foto de boleta), se manda como inline_data junto
  // al prompt de texto -- Gemini es multimodal y puede "leer" la imagen.
  const parts: Record<string, unknown>[] = [{ text: body.prompt }];
  if (body.imageBase64 && body.imageMimeType) {
    parts.push({
      inline_data: { mime_type: body.imageMimeType, data: body.imageBase64 },
    });
  }

  const inicio = Date.now();
  const cuerpo = JSON.stringify({
    contents: [{ parts }],
    generationConfig: {
      responseMimeType: "application/json",
      // gemini-3.6-flash activa "thinking" por defecto, lo que hace
      // la respuesta tardar 40+ segundos para esta tarea de extracción
      // estructurada -- no lo necesitamos, así que lo desactivamos.
      thinkingConfig: { thinkingBudget: 0 },
    },
  });
  const llamarGemini = (modelo: string) =>
    fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent?key=${geminiApiKey}`,
      { method: "POST", headers: { "Content-Type": "application/json" }, body: cuerpo },
    );

  // 503/500/504 de Gemini son "alta demanda" pasajera: se reintenta con espera
  // creciente (hasta 3 intentos). Un 429 (cuota diaria) no se reintenta con el
  // mismo modelo porque seguiría fallando; solo se prueba el modelo de respaldo
  // si se configuró GEMINI_FALLBACK_MODEL (opcional, no hay uno por defecto).
  const REINTENTABLES = new Set([500, 503, 504]);
  const ESPERAS_MS = [1500, 3000];
  let geminiResponse = await llamarGemini(GEMINI_MODEL);
  for (let i = 0; i < ESPERAS_MS.length && REINTENTABLES.has(geminiResponse.status); i++) {
    await geminiResponse.body?.cancel();
    await new Promise((r) => setTimeout(r, ESPERAS_MS[i]));
    geminiResponse = await llamarGemini(GEMINI_MODEL);
  }
  const modeloRespaldo = Deno.env.get("GEMINI_FALLBACK_MODEL");
  if (!geminiResponse.ok && modeloRespaldo && (geminiResponse.status === 429 || REINTENTABLES.has(geminiResponse.status))) {
    await geminiResponse.body?.cancel();
    geminiResponse = await llamarGemini(modeloRespaldo);
  }

  if (!geminiResponse.ok) {
    const errorText = await geminiResponse.text();
    // Queda en Supabase > Edge Functions > gemini-proxy > Logs, para ver el
    // motivo exacto que dio Google (cuota, sobrecarga, clave, etc.).
    console.error(`gemini-proxy: Gemini respondió ${geminiResponse.status} (modelo ${GEMINI_MODEL}): ${errorText.slice(0, 500)}`);
    await registrarUso({
      ...base,
      resultado: "error",
      httpStatus: geminiResponse.status,
      duracionMs: Date.now() - inicio,
    });
    return new Response(`Error de Gemini: ${errorText}`, { status: 502, headers: corsHeaders });
  }

  const geminiResult = await geminiResponse.json();
  const text = geminiResult?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

  if (!text) {
    // Gemini respondió 200 pero sin contenido (p. ej. bloqueado por el
    // filtro de seguridad) -- devolver un error explícito en vez de un
    // 200 con texto vacío, que el cliente intentaría parsear como JSON
    // y fallaría con un mensaje confuso de "Unexpected end of input".
    const blockReason = geminiResult?.promptFeedback?.blockReason ?? "sin contenido";
    await registrarUso({ ...base, resultado: "error", httpStatus: 502, duracionMs: Date.now() - inicio });
    return new Response(`Gemini no devolvió una respuesta utilizable (${blockReason})`, {
      status: 502,
      headers: corsHeaders,
    });
  }

  await registrarUso({ ...base, resultado: "ok", duracionMs: Date.now() - inicio });
  return new Response(JSON.stringify({ text }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
