// Deno Edge Function: auth-login-identifier (Section 10 of PRD v2.0)
// Maps @username -> email internally on the server without leaking email to the client,
// verifies Turnstile, executes login, and checks for existing active E2EE device conflict (UI-05).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  const requestId = `req_${crypto.randomUUID().replace(/-/g, "").slice(0, 16).toUpperCase()}`;
  try {
    if (req.method !== "POST") {
      return Response.json({ request_id: requestId, success: false, data: null, error: "METHOD_NOT_ALLOWED" }, { status: 405 });
    }

    const { identifier, password, turnstile_token } = await req.json();
    if (!identifier || !password) {
      return Response.json({ request_id: requestId, success: false, data: null, error: "MISSING_CREDENTIALS" }, { status: 400 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    let resolvedEmail = String(identifier).trim().toLowerCase();
    if (!resolvedEmail.includes("@") || resolvedEmail.startsWith("@")) {
      const normalizedUsername = resolvedEmail.replace(/^@/, "");
      const { data: profileRow, error: profileErr } = await adminClient
        .from("profiles")
        .select("user_id")
        .eq("username_normalized", normalizedUsername)
        .maybeSingle();

      if (profileErr || !profileRow) {
        return Response.json({ request_id: requestId, success: false, data: null, error: "INVALID_CREDENTIALS" }, { status: 401 });
      }

      const { data: userAuth } = await adminClient.auth.admin.getUserById(profileRow.user_id);
      if (!userAuth?.user?.email) {
        return Response.json({ request_id: requestId, success: false, data: null, error: "INVALID_CREDENTIALS" }, { status: 401 });
      }
      resolvedEmail = userAuth.user.email;
    }

    const { data: authData, error: signInErr } = await adminClient.auth.signInWithPassword({
      email: resolvedEmail,
      password: String(password),
      options: turnstile_token ? { captchaToken: String(turnstile_token) } : undefined,
    });

    if (signInErr || !authData.user) {
      return Response.json({ request_id: requestId, success: false, data: null, error: "INVALID_CREDENTIALS" }, { status: 401 });
    }

    const { data: activeDevice } = await adminClient
      .from("devices")
      .select("id, device_name, last_seen_at")
      .eq("user_id", authData.user.id)
      .eq("status", "active")
      .maybeSingle();

    return Response.json({
      request_id: requestId,
      success: true,
      data: {
        session: authData.session,
        has_active_device_conflict: Boolean(activeDevice),
        active_device_name: activeDevice?.device_name ?? null,
      },
      error: null,
    });
  } catch (err) {
    return Response.json({ request_id: requestId, success: false, data: null, error: String(err) }, { status: 500 });
  }
});
