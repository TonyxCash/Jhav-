import { corsHeaders } from "../_shared/cors.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const clientId = Deno.env.get("PAYPAL_CLIENT_ID")!;
    const secret = Deno.env.get("PAYPAL_CLIENT_SECRET")!;
    const mode = (Deno.env.get("PAYPAL_MODE") || "sandbox").toLowerCase();
    if (!supabaseUrl || !serviceKey || !clientId || !secret || !["sandbox", "live"].includes(mode)) {
      return json({ error: "Configurazione pagamenti incompleta." }, 503);
    }

    const { orderID } = await req.json();
    if (typeof orderID !== "string" || !/^[A-Z0-9-]{8,64}$/i.test(orderID)) return json({ error: "Ordine non valido." }, 400);

    const dbHeaders = { apikey: serviceKey, Authorization: "Bearer " + serviceKey };
    const lookup = await fetch(supabaseUrl + "/rest/v1/store_orders?select=paypal_order_id,amount,currency,status&id=not.is.null&paypal_order_id=eq." + encodeURIComponent(orderID), { headers: dbHeaders });
    const rows = await lookup.json();
    if (!lookup.ok || !Array.isArray(rows) || !rows.length) return json({ error: "Ordine JHAVÈ non trovato." }, 404);
    const saved = rows[0];
    if (saved.status === "paid") return json({ status: "COMPLETED", alreadyCaptured: true });
    if (saved.status !== "pending") return json({ error: "Questo ordine non è più pagabile." }, 409);

    const base = mode === "live" ? "https://api-m.paypal.com" : "https://api-m.sandbox.paypal.com";
    const auth = btoa(clientId + ":" + secret);
    const tokenResponse = await fetch(base + "/v1/oauth2/token", {
      method: "POST",
      headers: { Authorization: "Basic " + auth, "Content-Type": "application/x-www-form-urlencoded" },
      body: "grant_type=client_credentials",
    });
    const tokenData = await tokenResponse.json();
    if (!tokenResponse.ok || !tokenData.access_token) throw new Error("Autenticazione PayPal non riuscita.");

    const captureResponse = await fetch(base + "/v2/checkout/orders/" + orderID + "/capture", {
      method: "POST",
      headers: { Authorization: "Bearer " + tokenData.access_token, "Content-Type": "application/json" },
      body: "{}",
    });
    const capture = await captureResponse.json();
    const payment = capture?.purchase_units?.[0]?.payments?.captures?.[0];
    const paidAmount = Number(payment?.amount?.value);
    if (!captureResponse.ok || capture.status !== "COMPLETED" || payment?.status !== "COMPLETED" ||
        capture?.purchase_units?.[0]?.payments?.captures?.[0]?.amount?.currency_code !== saved.currency ||
        !Number.isFinite(paidAmount) || Math.abs(paidAmount - Number(saved.amount)) > 0.001) {
      throw new Error("PayPal non ha confermato il pagamento dell'importo previsto.");
    }

    const update = await fetch(supabaseUrl + "/rest/v1/store_orders?paypal_order_id=eq." + encodeURIComponent(orderID), {
      method: "PATCH",
      headers: { ...dbHeaders, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({ status: "paid", paid_at: new Date().toISOString(), payment_capture_id: payment.id }),
    });
    if (!update.ok) throw new Error("Pagamento ricevuto, ma aggiornamento ordine non riuscito. Contatta l'assistenza.");
    return json({ status: "COMPLETED", captureId: payment.id });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Errore durante la conferma del pagamento." }, 400);
  }
});
