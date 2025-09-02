export interface Env {
  // Secrets (set via `wrangler secret put`)
  CF_API_TOKEN: string;      // Needs Account: Cloudflare Tunnel Edit + Zone: DNS Edit
  CF_ACCOUNT_ID: string;
  CF_ZONE_ID: string;

  // Non-secret config (can live in wrangler.toml vars)
  BASE_HOST?: string;        // defaults to "nomadconnect.app"
}

const CF_API = "https://api.cloudflare.com/client/v4";

type ProvisionResult = { token: string; tunnel_id: string; hostname: string };

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);

    if (url.pathname === "/health") {
      return json({ ok: true });
    }

    if (url.pathname === "/provision") {
      const mac = await readMac(req, url);
      if (!mac) return json({ error: "bad_mac" }, 400);

      const baseHost = (env.BASE_HOST || "nomadconnect.app").toLowerCase();
      const hostname = `${mac}.${baseHost}`;

      // 1) get or create tunnel
      const tunnel = await getOrCreateTunnel(env, mac); // name == mac

      // 2) get token (create returns token; else fetch)
      const token = tunnel.token || await getTunnelToken(env, tunnel.id);

      // 3) ensure tunnel config ingress: hostname -> http://127.0.0.1:8081 (plus 404 catch-all)
      await ensureTunnelHostnameRoute(env, tunnel.id, hostname, "http://127.0.0.1:8081");

      // 4) ensure DNS CNAME: host -> <tunnel_id>.cfargotunnel.com (proxied)
      await upsertCname(env, hostname, `${tunnel.id}.cfargotunnel.com`);

      const result: ProvisionResult = { token, tunnel_id: tunnel.id, hostname };
      return json(result);
    }

    return new Response("Not Found", { status: 404 });
  }
};

/* ---------------- helpers ---------------- */

function json(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json" }
  });
}

async function readMac(req: Request, url: URL): Promise<string | null> {
  let mac = "";
  if (req.method === "POST") {
    try {
      const body = await req.json();
      mac = (body?.mac || "").toString().toLowerCase().replace(/[^0-9a-f]/g, "");
    } catch { /* ignore */ }
  } else if (req.method === "GET") {
    mac = (url.searchParams.get("mac") || "").toLowerCase().replace(/[^0-9a-f]/g, "");
  } else {
    return null;
  }
  return mac.length === 12 ? mac : null;
}

async function getOrCreateTunnel(env: Env, name: string): Promise<{ id: string; token?: string }> {
  const headers = { Authorization: `Bearer ${env.CF_API_TOKEN}`, "content-type": "application/json" };

  // find by name
  {
    const r = await fetch(`${CF_API}/accounts/${env.CF_ACCOUNT_ID}/cfd_tunnel?name=${encodeURIComponent(name)}`, { headers });
    const j = await r.json().catch(() => ({}));
    if (r.ok && j?.result?.length) {
      return { id: j.result[0].id };
    }
  }

  // create (returns token + id)
  const c = await fetch(`${CF_API}/accounts/${env.CF_ACCOUNT_ID}/cfd_tunnel`, {
    method: "POST",
    headers,
    body: JSON.stringify({ name, config_src: "cloudflare" })
  });
  const cj = await c.json().catch(() => ({}));
  if (!c.ok || !cj?.success) {
    throw new Error(`create tunnel failed: ${c.status} ${JSON.stringify(cj)}`);
  }
  return { id: cj.result.id, token: cj.result.token };
}

async function getTunnelToken(env: Env, id: string): Promise<string> {
  const r = await fetch(`${CF_API}/accounts/${env.CF_ACCOUNT_ID}/cfd_tunnel/${id}/token`, {
    headers: { Authorization: `Bearer ${env.CF_API_TOKEN}` }
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j?.result) throw new Error(`token fetch failed: ${r.status} ${JSON.stringify(j)}`);
  return j.result as string;
}

/**
 * Ensure the tunnel has a public hostname route:
 *   hostname -> service (e.g., http://127.0.0.1:8081)
 * Uses the "configurations" API: PUT body must be { "config": { "ingress": [...] } }.
 */
async function ensureTunnelHostnameRoute(env: Env, tunnelId: string, hostname: string, service: string) {
  const headers = { Authorization: `Bearer ${env.CF_API_TOKEN}`, "content-type": "application/json" };

  // read current config (optional but lets us idempotently upsert)
  let ingress: any[] = [];
  {
    const r = await fetch(`${CF_API}/accounts/${env.CF_ACCOUNT_ID}/cfd_tunnel/${tunnelId}/configurations`, { headers });
    const j = await r.json().catch(() => ({}));
    if (r.ok && j?.result?.config?.ingress) {
      ingress = Array.isArray(j.result.config.ingress) ? j.result.config.ingress : [];
    }
  }

  const idx = ingress.findIndex((rule: any) => rule?.hostname === hostname);
  if (idx >= 0) ingress[idx].service = service;
  else ingress.unshift({ hostname, service });

  // ensure catch-all 404
  if (!ingress.some((rule) => (rule.service || "").startsWith("http_status:"))) {
    ingress.push({ service: "http_status:404" });
  }

  // PUT with required wrapper
  const body = JSON.stringify({ config: { ingress } });
  const p = await fetch(`${CF_API}/accounts/${env.CF_ACCOUNT_ID}/cfd_tunnel/${tunnelId}/configurations`, {
    method: "PUT", headers, body
  });
  if (!p.ok) {
    const err = await p.text().catch(() => "");
    throw new Error(`update ingress failed: ${p.status} ${err}`);
  }
}

async function upsertCname(env: Env, name: string, target: string) {
  const headers = { Authorization: `Bearer ${env.CF_API_TOKEN}`, "content-type": "application/json" };

  // find
  const l = await fetch(`${CF_API}/zones/${env.CF_ZONE_ID}/dns_records?type=CNAME&name=${encodeURIComponent(name)}`, { headers });
  const lj = await l.json().catch(() => ({}));
  if (l.ok && lj?.result?.length) {
    const rec = lj.result[0];
    if (rec.content !== target || rec.proxied !== true) {
      const u = await fetch(`${CF_API}/zones/${env.CF_ZONE_ID}/dns_records/${rec.id}`, {
        method: "PUT", headers, body: JSON.stringify({ type: "CNAME", name, content: target, proxied: true })
      });
      if (!u.ok) throw new Error(`dns update failed: ${u.status} ${await u.text().catch(()=> "")}`);
    }
    return;
  }

  // create
  const c = await fetch(`${CF_API}/zones/${env.CF_ZONE_ID}/dns_records`, {
    method: "POST", headers, body: JSON.stringify({ type: "CNAME", name, content: target, proxied: true })
  });
  if (!c.ok) throw new Error(`dns create failed: ${c.status} ${await c.text().catch(()=> "")}`);
}
