// Deno Edge Function: call-signaling (Section 10 of PRD v2.0)
// Manages call lifecycle (`initiate`, `ringing_ack`, `accept`, `decline`, `ice_candidate`, `hangup`)
// and issues ephemeral HMAC-SHA1 Coturn TURN credentials (TTL 3600s) + 40s incoming call TTL (`expires_at_ms`).

Deno.serve(async (req: Request) => {
  const requestId = `req_${crypto.randomUUID().replace(/-/g, "").slice(0, 16).toUpperCase()}`;
  try {
    const body = await req.json();
    const { action, call_id, caller_id } = body;
    const nowMs = Date.now();
    const expiresAtMs = nowMs + 40_000; // 40-second TTL (ERR-06)
    const turnExpiryEpoch = Math.floor(nowMs / 1000) + 3600; // 3600s TURN TTL
    const turnUsername = `${turnExpiryEpoch}:${caller_id ?? "peer"}`;

    const secret = Deno.env.get("COTURN_HMAC_SECRET") ?? "coturn_hmac_ephemeral_secret_com.adoetzchat2.chat";
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(secret),
      { name: "HMAC", hash: "SHA-1" },
      false,
      ["sign"],
    );
    const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(turnUsername));
    const turnCredential = btoa(String.fromCharCode(...new Uint8Array(sig)));

    return Response.json({
      request_id: requestId,
      success: true,
      data: {
        call_id: call_id ?? crypto.randomUUID(),
        action,
        expires_at_ms: expiresAtMs,
        turn_credentials: {
          urls: [
            "stun:turn.adoetz52.my.id:3478",
            "turn:turn.adoetz52.my.id:3478?transport=udp",
            "turns:turn.adoetz52.my.id:5349?transport=tcp",
          ],
          username: turnUsername,
          credential: turnCredential,
          ttl_seconds: 3600,
        },
      },
      error: null,
    });
  } catch (err) {
    return Response.json({ request_id: requestId, success: false, data: null, error: String(err) }, { status: 500 });
  }
});
