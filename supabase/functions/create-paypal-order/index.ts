const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

async function paypalToken(base: string, clientId: string, secret: string) {
  const auth = btoa(clientId + ":" + secret);
  const response = await fetch(base + "/v1/oauth2/token", {
    method: "POST",
    headers: { Authorization: "Basic " + auth, "Content-Type": "application/x-www-form-urlencoded" },
    body: "grant_type=client_credentials",
  });
  const data = await response.json();
  if (!response.ok || !data.access_token) throw new Error("Autenticazione PayPal non riuscita.");
  return data.access_token as string;
}

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

    const body = await req.json();
    const cart = body?.cart;
    if (!Array.isArray(cart) || cart.length < 1 || cart.length > 30) return json({ error: "Carrello non valido." }, 400);

    const normalized = cart.map((item: any) => ({
      id: String(item?.id || ""),
      size: String(item?.size || ""),
      qty: Number(item?.qty),
    }));
    if (normalized.some((x: any) => !x.id || !x.size || !Number.isInteger(x.qty) || x.qty < 1 || x.qty > 10)) {
      return json({ error: "Controlla taglie e quantità del carrello." }, 400);
    }

    const ids = [...new Set(normalized.map((x: any) => x.id))];
    const query = new URLSearchParams({
      select: "id,name,price,sizes,color_name,active",
      id: "in.(" + ids.join(",") + ")",
      active: "eq.true",
    });
    const productsResponse = await fetch(supabaseUrl + "/rest/v1/products?" + query.toString(), {
      headers: { apikey: serviceKey, Authorization: "Bearer " + serviceKey },
    });
    const products = await productsResponse.json();
    if (!productsResponse.ok || !Array.isArray(products)) throw new Error("Impossibile verificare il catalogo.");

    const byId = new Map(products.map((p: any) => [String(p.id), p]));
    let total = 0;
    const snapshot = normalized.map((item: any) => {
      const p: any = byId.get(item.id);
      if (!p || !Array.isArray(p.sizes) || !p.sizes.includes(item.size)) throw new Error("Un prodotto o una taglia non è più disponibile. Aggiorna il carrello.");
      const price = Number(p.price);
      if (!Number.isFinite(price) || price <= 0) throw new Error("Un prodotto non ha un prezzo valido. Contatta JHAVÈ.");
      total += price * item.qty;
      return { product_id: p.id, name: p.name, color: p.color_name || "", size: item.size, quantity: item.qty, unit_price: price };
    });
    total = Math.round((total + Number.EPSILON) * 100) / 100;
    if (total <= 0) throw new Error("Totale ordine non valido.");

    const base = mode === "live" ? "https://api-m.paypal.com" : "https://api-m.sandbox.paypal.com";
    const token = await paypalToken(base, clientId, secret);
    const orderResponse = await fetch(base + "/v2/checkout/orders", {
      method: "POST",
      headers: { Authorization: "Bearer " + token, "Content-Type": "application/json", "PayPal-Request-Id": crypto.randomUUID() },
      body: JSON.stringify({
        intent: "CAPTURE",
        purchase_units: [{
          reference_id: "JHAVE-" + crypto.randomUUID(),
          description: "Ordine JHAVÈ Official",
          custom_id: "JHAVE_OFFICIAL",
          amount: { currency_code: "EUR", value: total.toFixed(2) },
        }],
      }),
    });
    const order = await orderResponse.json();
    if (!orderResponse.ok || !order.id) throw new Error(order?.message || "PayPal non ha creato l'ordine.");

    const save = await fetch(supabaseUrl + "/rest/v1/store_orders", {
      method: "POST",
      headers: { apikey: serviceKey, Authorization: "Bearer " + serviceKey, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({ paypal_order_id: order.id, amount: total, currency: "EUR", items: snapshot, status: "pending" }),
    });
    if (!save.ok) {
      await fetch(base + "/v2/checkout/orders/" + order.id, { headers: { Authorization: "Bearer " + token } }).catch(() => null);
      throw new Error("Non è stato possibile registrare l'ordine. Riprova.");
    }
    return json({ id: order.id });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Errore durante la creazione del pagamento." }, 400);
  }
});
