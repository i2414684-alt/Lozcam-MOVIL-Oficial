// @ts-nocheck — Archivo Deno (Edge Function). VS Code lo valida con el checker
// de Node y marca en rojo los imports por URL; eso es una falsa alarma. Deno y
// Supabase lo ejecutan sin problema. Esta línea silencia esas marcas del editor.
// ============================================================================
//  Edge Function: chat-gerente  (proxy seguro hacia Ollama Cloud)
//
//  La app NO lleva la API key: vive aquí como secreto (OLLAMA_API_KEY).
//  La función recibe { pregunta, contexto } (datos que la app ya leyó en
//  SOLO LECTURA) y los reenvía a Ollama. NO toca el esquema ni escribe en la BD.
//
//  Desplegar:
//    supabase functions deploy chat-gerente
//    supabase secrets set OLLAMA_API_KEY=tu_clave_de_ollama
//    supabase secrets set OLLAMA_MODEL=gpt-oss:120b   (o el modelo que tengas)
// ============================================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OLLAMA_API_KEY = Deno.env.get("OLLAMA_API_KEY") ?? "";
const OLLAMA_MODEL = Deno.env.get("OLLAMA_MODEL") ?? "gpt-oss:120b";
const OLLAMA_URL = "https://ollama.com/api/chat";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// Solo estos roles (gerencia) pueden usar el asistente de monitoreo.
const ROLES_GERENCIA = ["gerente_general", "subgerente", "administrador"];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    if (!OLLAMA_API_KEY) {
      return json({ error: "Falta configurar OLLAMA_API_KEY en el servidor." }, 500);
    }

    // ---- Autorización: el que llama debe ser gerencia ----
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "No autorizado." }, 401);
    }
    const supa = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await supa.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "Tu sesión expiró. Vuelve a iniciar sesión." }, 401);
    }
    const { data: perfil } = await supa
      .from("profiles")
      .select("rol")
      .eq("id", userData.user.id)
      .maybeSingle();
    if (!perfil || !ROLES_GERENCIA.includes(`${perfil.rol}`)) {
      return json({ error: "Solo gerencia puede usar el asistente." }, 403);
    }

    const { pregunta, contexto } = await req.json();
    if (!pregunta || `${pregunta}`.trim().length === 0) {
      return json({ error: "Falta la pregunta." }, 400);
    }

    const messages = [
      {
        role: "system",
        content:
          "Eres el asistente de monitoreo del gerente de la constructora LOZCAM. " +
          "Responde breve, claro y profesional, SOLO con base en el CONTEXTO de datos provisto. " +
          "Si el dato no está en el contexto, dilo claramente; NO inventes números. Responde en español.",
      },
      {
        role: "user",
        content:
          `CONTEXTO (datos actuales de la empresa):\n${contexto ?? "(sin datos)"}\n\n` +
          `PREGUNTA DEL GERENTE: ${pregunta}`,
      },
    ];

    const r = await fetch(OLLAMA_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OLLAMA_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ model: OLLAMA_MODEL, messages, stream: false }),
    });

    if (!r.ok) {
      const t = await r.text();
      return json(
        { error: `La IA no está disponible (${r.status}).`, detalle: t.slice(0, 300) },
        502,
      );
    }

    const data = await r.json();
    const respuesta = data?.message?.content ?? "Sin respuesta.";
    return json({ respuesta });
  } catch (_e) {
    return json({ error: "Error procesando la solicitud." }, 500);
  }
});
