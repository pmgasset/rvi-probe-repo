export interface Env {
  CF_API_TOKEN: string;   // Tunnel:Edit + DNS:Edit
  CF_ACCOUNT_ID: string;
  CF_ZONE_ID: string;     // zone for nomadconnect.app
  BASE_HOST?: string;     // default nomadconnect.app
}

const CF_API = "https://api.cloudflare.com/client/v4";

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === "/health") return j({ ok: true });

    if (url.pathname === "/provision") {
      const mac = await readMac(req, url);
      if (!mac) return j({ error: "bad_mac" }, 400);

      const baseHost = (env.BASE_HOST || "nomadconnect.app").toLowerCase();
      const hostname = `${mac}.${baseHost}`;

      // (1) get or create tunnel
      const t = await getOrCreateTunnel(env, mac); // name == mac

      // (2) get token (create returns token; otherwise fetch)
      const token = t.token || await getTunnelToken(env, t.id);

      // (3) ensure hostname route on this tunnel: hostname -> http://127.0.0.1:8081
      await ensureTunnelHostnameRoute(env, t.id, hostname, "http://127.0.0.1:8081");

      // (4) ensure DNS CNAME host -> <tunnel_id>.cfargotunnel.com (proxied)
      await upsertCname(env, hostname, `${t.id}.cfargotunnel.com`);

      return j({ token, tunnel_id: t.id, hostname });
    }

    return new Response("Not Found", { status: 404 });
  }
};

function j(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" }});
}

async function readMac(req: Request, url: URL): Promise<string|null> {
  let mac = "";
  if (req.method === "POST") {
    try { const b:any = await req.json(); mac = (b?.mac||"").toLowerCase().replace(/[^0-9a-f]/g, ""); } catch {}
  } else if (req.method === "GET") {
    mac = (url.searchParams.get("mac")||"").toLowerCase().replace(/[^0-9a-f]/g, "");
  } else return null;
  return mac.length === 12 ? mac : null;
}

async function getOrCreateTunnel(env: Env, name: string): Promise<{id:string; token?:string}> {
  const h = { Authorization: `Bearer ${env.CF_API_TOKEN}`, "content-type":"application/json" };
  // find by name
  const L = await fetch(`${CF_API}/accounts/${env.CF_ACCOUNT_ID}/cfd_tunnel?name=${encodeURIComponent(name)}`, { headers: h });
  const Lj = await L.json();
  if (L.ok && Lj?.result?.length) return { id: Lj.result[0].id };

  // create
  const C = await fetch(`${CF_API}/accounts/${env.CF_ACCOUNT_ID}/cfd_tunnel`, {
    method: "POST", headers: h, body: JSON.stringify({ name, config_src: "cloudflare" })
  });
  const Cj = await C.json();
  if (!C.ok || !Cj?.success) throw new Error(`create tunnel failed: ${C.status} ${JSON.stringify(Cj)}`);
  return { id: Cj.result.id, token: Cj.result.token };
}

async function getTunnelToken(env: Env, id: string): Promise<string> {
  const h = { Authorization: `Bearer ${env.CF_API_TOKEN}` };
  const R = await fetch(`${CF_API}/accounts/${env.CF_ACCOUNT_ID}/cfd_tunnel/${id}/token`, { headers: h });
  const J = await R.json();
  if (!R.ok || !J?.result) throw new Error(`token fetch failed: ${R.status} ${JSON.stringify(J)}`);
  return J.result as string;
}

/**
 * Ensure the tunnel has a public hostname route:
 *   hostname -> http://127.0.0.1:8081
 * This uses the "tunnel configuration (ingress rules)" API for Zero Trust.
 * Idempotent: if hostname exists with same service, no change.
 */
async function ensureTunnelHostnameRoute(env: Env, tunnelId: string, hostname: string, service: string) {
  const h = { Authorization: `Bearer ${env.CF_API_TOKEN}`, "content-type": "application/json" };

  // GET current config
  let cfg: any = { ingress: [] };
  {
    const R = await fetch(`${CF_API}/accounts/${env.CF_ACCOUNT_ID}/cfd_tunnel/${tunnelId}/configurations`, { headers: h });
    const J = await R.json();
    if (R.ok && J?.result) cfg = J.result;
  }

  const ingress = Array.isArray(cfg.ingress) ? cfg.ingress : [];
  const found = ingress.find((r: any) => r?.hostname === hostname);

  if (found) {
    // update if service differs
    if (found.service !== service) found.service = service;
  } else {
    ingress.unshift({ hostname, service });
  }

  // Ensure last rule is a 404 catcher
  if (!ingress.find((r: any) => r?.service?.startsWith("http_status:"))) {
    ingress.push({ service: "http_status:404" });
  }

  // PUT back config (idempotent)
  const P = await fetch(`${CF_API}/accounts/${env.CF_ACCOUNT_ID}/cfd_tunnel/${tunnelId}/configurations`, {
    method: "PUT", headers: h, body: JSON.stringify({ ingress })
  });
  if (!P.ok) {
    const J = await P.json().catch(() => ({}));
    throw new Error(`update ingress failed: ${P.status} ${JSON.stringify(J)}`);
  }
}

async function upsertCname(env: Env, name: string, target: string) {
  const h = { Authorization: `Bearer ${env.CF_API_TOKEN}`, "content-type": "application/json" };
  const L = await fetch(`${CF_API}/zones/${env.CF_ZONE_ID}/dns_records?type=CNAME&name=${encodeURIComponent(name)}`, { headers: h });
  const Lj = await L.json();

  if (L.ok && Lj?.result?.length) {
    const rec = Lj.result[0];
    if (rec.content !== target || rec.proxied !== true) {
      const U = await fetch(`${CF_API}/zones/${env.CF_ZONE_ID}/dns_records/${rec.id}`, {
        method: "PUT", headers: h, body: JSON.stringify({ type:"CNAME", name, content: target, proxied: true })
      });
      if (!U.ok) throw new Error(`dns update failed: ${U.status} ${JSON.stringify(await U.json().catch(()=>({})))}`);
    }
    return;
  }

  const C = await fetch(`${CF_API}/zones/${env.CF_ZONE_ID}/dns_records`, {
    method: "POST", headers: h, body: JSON.stringify({ type:"CNAME", name, content: target, proxied: true })
  });
  if (!C.ok) throw new Error(`dns create failed: ${C.status} ${JSON.stringify(await C.json().catch(()=>({})))}`);
}
