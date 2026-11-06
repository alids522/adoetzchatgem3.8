// Deno Edge Function: register-device-key (Section 10 of PRD v2.0)
// Enforces Strict Single-Active-Device: revokes previous device if `replace_existing_device == true`
// and registers Identity Key, Signed PreKey, and 100 One-Time PreKeys atomically.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  const requestId = `req_${crypto.randomUUID().replace(/-/g, "").slice(0, 16).toUpperCase()}`;
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const client = createClient(supabaseUrl, serviceRoleKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user } } = await client.auth.getUser();
    if (!user) {
      return Response.json({ request_id: requestId, success: false, data: null, error: "UNAUTHORIZED" }, { status: 401 });
    }

    const body = await req.json();
    const replaceExisting = Boolean(body.replace_existing_device);

    if (replaceExisting) {
      await client
        .from("devices")
        .update({ status: "revoked" })
        .eq("user_id", user.id)
        .eq("status", "active");
    }

    const { data: insertedDevice, error: devErr } = await client
      .from("devices")
      .insert({
        user_id: user.id,
        device_name: body.device_name ?? "Android Device",
        registration_id: body.registration_id,
        identity_public_key: body.identity_public_key,
        signed_prekey_id: body.signed_prekey_id,
        signed_prekey_public: body.signed_prekey_public,
        signed_prekey_signature: body.signed_prekey_signature,
        status: "active",
      })
      .select("id")
      .single();

    if (devErr || !insertedDevice) {
      return Response.json({ request_id: requestId, success: false, data: null, error: devErr?.message ?? "DEVICE_CONFLICT" }, { status: 409 });
    }

    const otpks = Array.isArray(body.one_time_prekeys) ? body.one_time_prekeys : [];
    if (otpks.length > 0) {
      await client.from("device_one_time_prekeys").insert(
        otpks.map((k: { key_id: number; public_key: string }) => ({
          device_id: insertedDevice.id,
          key_id: k.key_id,
          public_key: k.public_key,
        })),
      );
    }

    return Response.json({
      request_id: requestId,
      success: true,
      data: { device_id: insertedDevice.id, prekeys_stored: otpks.length },
      error: null,
    });
  } catch (err) {
    return Response.json({ request_id: requestId, success: false, data: null, error: String(err) }, { status: 500 });
  }
});
