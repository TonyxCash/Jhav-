const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

Deno.serve((req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET") return Response.json({ error: "Method not allowed" }, { status: 405, headers: corsHeaders });

  const clientId = Deno.env.get("PAYPAL_CLIENT_ID");
  const mode = (Deno.env.get("PAYPAL_MODE") || "sandbox").toLowerCase();
  if (!clientId || !["sandbox", "live"].includes(mode)) {
    return Response.json({ error: "Configurazione PayPal incompleta." }, { status: 503, headers: corsHeaders });
  }
  return Response.json({ clientId, mode }, { headers: corsHeaders });
});
