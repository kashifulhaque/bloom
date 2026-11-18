// Stores, serves, and revokes end-to-end encrypted doctor-report share links.
//
// The app encrypts the report on the device and uploads only the ciphertext.
// The decryption key lives in the link's URL fragment, which never reaches a
// server, so this function can't read a report.
//
// This function is reachable only through the nginx proxy on bloom.ifkash.dev
// (/api/share/...), which applies per-address rate limits and sends two
// headers: X-Bloom-Proxy-Secret (must equal BLOOM_SHARE_PROXY_SECRET) and
// X-Bloom-Client-Ip. Requests without the secret are refused, so the nginx
// limits can't be bypassed by calling Supabase directly.
//
//   POST   /report-share?days=7         body: the encrypted report
//          201 {"id", "revokeToken", "expiresAt"}
//   GET    /report-share/<id>           200 the encrypted report, or 404
//   DELETE /report-share/<id>           header X-Bloom-Revoke-Token; 204
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

/** Box format byte, shared with the app's SyncCrypto. */
const FORMAT = 1;
const MIN_BYTES = 1024;
/** 2 MiB of PDF plus the box overhead (format byte, nonce, tag). */
const MAX_BYTES = 2 * 1024 * 1024 + 41;
const DAYS = new Set([1, 7, 30]);
const ID_RE = /^[A-Za-z0-9_-]{22}$/;
const TOKEN_RE = /^[A-Za-z0-9_-]{43}$/;

const proxySecret = Deno.env.get("BLOOM_SHARE_PROXY_SECRET") ?? "";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";

function serviceKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  // The hosted platform also provides the new secret keys as JSON.
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    return (Object.values(keys)[0] as string | undefined) ?? "";
  } catch {
    return "";
  }
}

const db = createClient(supabaseUrl, serviceKey(), {
  auth: { persistSession: false, autoRefreshToken: false },
});

function error(status: number, code: string, message: string): Response {
  return Response.json(
    { error: { code, message } },
    { status, headers: { "Cache-Control": "no-store" } },
  );
}

function base64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function randomId(n: number): string {
  return base64url(crypto.getRandomValues(new Uint8Array(n)));
}

/** PostgREST reads and writes bytea as "\x" followed by hex. */
function toHex(bytes: Uint8Array): string {
  let s = "\\x";
  for (const b of bytes) s += b.toString(16).padStart(2, "0");
  return s;
}

function fromHex(s: string): Uint8Array {
  const hex = s.startsWith("\\x") ? s.slice(2) : s;
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(hex.substr(i * 2, 2), 16);
  return out;
}

async function sha256(data: Uint8Array | string): Promise<Uint8Array> {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  return new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
}

async function hmac(key: string, message: string): Promise<Uint8Array> {
  const k = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(message)));
}

/** Compares two strings in time that doesn't depend on where they differ. */
function sameSecret(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

async function create(req: Request, url: URL): Promise<Response> {
  const days = Number(url.searchParams.get("days") ?? "7");
  if (!DAYS.has(days)) return error(400, "bad_days", "A link can last 1, 7, or 30 days.");

  const declared = Number(req.headers.get("Content-Length") ?? "0");
  if (declared > MAX_BYTES) return error(413, "too_large", "The report is larger than 2 MB.");
  const body = new Uint8Array(await req.arrayBuffer());
  if (body.length > MAX_BYTES) return error(413, "too_large", "The report is larger than 2 MB.");
  if (body.length < MIN_BYTES || body[0] !== FORMAT) {
    return error(400, "bad_body", "That isn't an encrypted Bloom report.");
  }

  const clientIp = req.headers.get("X-Bloom-Client-Ip") ?? "unknown";
  const id = randomId(16);
  const revokeToken = randomId(32);
  const { data, error: e } = await db.rpc("report_share_create", {
    p_id: id,
    p_revoke_hash: toHex(await sha256(revokeToken)),
    p_ciphertext: toHex(body),
    p_days: days,
    p_client_hash: toHex(await hmac(proxySecret, `bloom/report-share/client\n${clientIp}`)),
  });
  if (e) {
    if (e.message === "rate_limited") {
      return error(429, "rate_limited", "You've made a lot of links today. Try again tomorrow.");
    }
    if (e.message === "busy") {
      return error(503, "busy", "Sharing is busy right now. Try again later.");
    }
    console.error("report-share: create failed", e.code);
    return error(500, "create_failed", "Couldn't create the link. Try again.");
  }
  return Response.json(
    { id, revokeToken, expiresAt: new Date(data as string).toISOString() },
    { status: 201, headers: { "Cache-Control": "no-store" } },
  );
}

async function fetchShare(id: string): Promise<Response> {
  const { data, error: e } = await db.rpc("report_share_get", { p_id: id });
  if (e) {
    console.error("report-share: get failed", e.code);
    return error(500, "get_failed", "Couldn't load the report. Try again.");
  }
  const row = (data as { ciphertext: string; expires_at: string }[] | null)?.[0];
  if (!row) return error(404, "not_found", "This link has expired or was turned off.");
  return new Response(fromHex(row.ciphertext), {
    status: 200,
    headers: {
      "Content-Type": "application/octet-stream",
      "Cache-Control": "no-store",
      "X-Bloom-Expires-At": new Date(row.expires_at).toISOString(),
    },
  });
}

async function revoke(req: Request, id: string): Promise<Response> {
  const token = req.headers.get("X-Bloom-Revoke-Token") ?? "";
  if (!TOKEN_RE.test(token)) return error(400, "bad_token", "The revoke token is missing.");
  const { error: e } = await db.rpc("report_share_revoke", {
    p_id: id,
    p_revoke_hash: toHex(await sha256(token)),
  });
  if (e) {
    console.error("report-share: revoke failed", e.code);
    return error(500, "revoke_failed", "Couldn't turn off the link. Try again.");
  }
  // 204 whether or not a row matched, so this can't be used to probe ids.
  return new Response(null, { status: 204, headers: { "Cache-Control": "no-store" } });
}

Deno.serve(async (req) => {
  if (!proxySecret || !sameSecret(req.headers.get("X-Bloom-Proxy-Secret") ?? "", proxySecret)) {
    return error(401, "unauthorized", "Use bloom.ifkash.dev/api/share.");
  }
  const url = new URL(req.url);
  const parts = url.pathname.split("/").filter(Boolean);
  const at = parts.lastIndexOf("report-share");
  const rest = at >= 0 ? parts.slice(at + 1) : parts;

  if (rest.length === 0) {
    if (req.method !== "POST") return error(405, "method_not_allowed", "Use POST.");
    return await create(req, url);
  }
  if (rest.length !== 1 || !ID_RE.test(rest[0])) {
    return error(404, "not_found", "This link has expired or was turned off.");
  }
  if (req.method === "GET") return await fetchShare(rest[0]);
  if (req.method === "DELETE") return await revoke(req, rest[0]);
  return error(405, "method_not_allowed", "Use GET or DELETE.");
});
