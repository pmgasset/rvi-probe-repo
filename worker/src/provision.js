export default {
  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);
      // Lightweight config health check (no secrets exposed)
      if (request.method === 'GET' && url.pathname === '/health') {
        const missing = missingConfig(env);
        return json({ ok: missing.length === 0, missing });
      }
      if (request.method !== 'POST' || url.pathname !== '/provision') {
        return json({ error: 'Not found' }, 404);
      }

      const body = await safeJSON(request);
      if (!body || typeof body.mac !== 'string') {
        return json({ error: 'Missing mac' }, 400);
      }

      const mac = (body.mac || '').trim().toLowerCase();
      if (!/^[0-9a-f]{12}$/.test(mac)) {
        return json({ error: 'Invalid mac format' }, 400);
      }

      const { ACCOUNT_ID, ZONE_ID, ZONE_NAME, API_TOKEN, TUNNELS_KV } = env;
      const missing = missingConfig(env);
      if (missing.length) {
        return json({ error: 'Worker misconfigured', missing }, 500);
      }

      const hostname = `${mac}.${ZONE_NAME}`;

      // Idempotent: check KV for existing mapping
      let tunnelId = await TUNNELS_KV.get(mac);
      if (!tunnelId) {
        // Create tunnel with name=mac
        const tRes = await cfFetch(env, `/accounts/${ACCOUNT_ID}/cfd_tunnel`, {
          method: 'POST',
          body: { name: mac },
        });
        tunnelId = tRes?.result?.id;
        if (!tunnelId) {
          console.error('Tunnel create failed', tRes);
          return json({ error: 'Failed to create tunnel' }, 502);
        }
        await TUNNELS_KV.put(mac, tunnelId);
      }

      // Upsert DNS CNAME: <mac>.ZONE_NAME -> <tunnel_id>.cfargotunnel.com
      const target = `${tunnelId}.cfargotunnel.com`;
      const dns = await upsertDns(env, ZONE_ID, hostname, target);
      if (!dns) {
        return json({ error: 'DNS upsert failed' }, 502);
      }

      // Retrieve connector token
      const tokenRes = await cfFetch(env, `/accounts/${ACCOUNT_ID}/cfd_tunnel/${tunnelId}/token`, { method: 'GET' });
      const token = tokenRes?.result;
      if (typeof token !== 'string' || token.length < 32 || token === 'TOKEN_PLACEHOLDER') {
        console.error('Token fetch failed', tokenRes);
        return json({ error: 'Failed to retrieve token' }, 502);
      }

      return json({ token, hostname });
    } catch (err) {
      console.error('Unhandled error', err);
      return json({ error: 'Internal error' }, 500);
    }
  },
};

async function safeJSON(request) {
  try {
    return await request.json();
  } catch (_) {
    return null;
  }
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

async function cfFetch(env, path, opts = {}) {
  const { API_TOKEN } = env;
  const method = opts.method || 'POST';
  const init = {
    method,
    headers: {
      'content-type': 'application/json',
      'authorization': `Bearer ${API_TOKEN}`,
    },
  };
  if (opts.body) init.body = JSON.stringify(opts.body);
  const res = await fetch(`https://api.cloudflare.com/client/v4${path}`, init);
  const json = await res.json().catch(() => ({}));
  if (!res.ok || !json.success) {
    return json;
  }
  return json;
}

function missingConfig(env) {
  const required = ['ACCOUNT_ID', 'ZONE_ID', 'ZONE_NAME', 'API_TOKEN'];
  const missing = required.filter((k) => !env[k]);
  if (!env.TUNNELS_KV || typeof env.TUNNELS_KV.get !== 'function') missing.push('TUNNELS_KV');
  return missing;
}

async function upsertDns(env, zoneId, name, target) {
  // Try to create
  const create = await cfFetch(env, `/zones/${zoneId}/dns_records`, {
    method: 'POST',
    body: { type: 'CNAME', name, content: target, proxied: true },
  });
  if (create?.success) return true;
  // If exists, fetch and patch
  const list = await cfFetch(env, `/zones/${zoneId}/dns_records?type=CNAME&name=${encodeURIComponent(name)}`, { method: 'GET' });
  const rec = list?.result?.[0];
  if (!rec?.id) return false;
  const patch = await cfFetch(env, `/zones/${zoneId}/dns_records/${rec.id}`, {
    method: 'PATCH',
    body: { content: target, proxied: true },
  });
  return !!patch?.success;
}

