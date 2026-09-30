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

  if (!supabaseUrl || !anonKey || !geminiApiKey) {
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
  if (isRateLimited(callerData.user.id)) {
    return new Response("Demasiadas solicitudes, intenta en un minuto", {
      status: 429,
      headers: { ...corsHeaders, "Retry-After": "60" },
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

  const geminiResponse = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${geminiApiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          responseMimeType: "application/json",
          // gemini-3.6-flash activa "thinking" por defecto, lo que hace
          // la respuesta tardar 40+ segundos para esta tarea de extracción
          // estructurada -- no lo necesitamos, así que lo desactivamos.
          thinkingConfig: { thinkingBudget: 0 },
        },
      }),
    },
  );

  if (!geminiResponse.ok) {
    const errorText = await geminiResponse.text();
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
    return new Response(`Gemini no devolvió una respuesta utilizable (${blockReason})`, {
      status: 502,
      headers: corsHeaders,
    });
  }

  return new Response(JSON.stringify({ text }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
