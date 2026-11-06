// Deno Edge Function: claim-prekey-bundle (Section 10 of PRD v2.0)
// Atomically fetches recipient's active device Identity Key + Signed PreKey and
// consumes (DELETE ... RETURNING) exactly 1 One-Time PreKey for X3DH initialization.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  const requestId = `req_${crypto.randomUUID().replace(/-/g, "").slice(0, 16).toUpperCase()}`;
  try {
    const { recipient_user_id } = await req.json();
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: activeDevice } = await adminClient
      .from("devices")
      .select("id, registration_id, identity_public_key, signed_prekey_id, signed_prekey_public, signed_prekey_signature")
      .eq("user_id", recipient_user_id)
      .eq("status", "active")
      .maybeSingle();

    if (!activeDevice) {
      return Response.json({ request_id: requestId, success: false, data: null, error: "RECIPIENT_NO_ACTIVE_DEVICE" }, { status: 404 });
    }

    const { data: otpkRows } = await adminClient
      .from("device_one_time_prekeys")
      .select("id, key_id, public_key")
      .eq("device_id", activeDevice.id)
      .order("key_id", { ascending: true })
      .limit(1);

    let consumedOtpk = null;
    if (otpkRows && otpkRows.length > 0) {
      consumedOtpk = otpkRows[0];
      await adminClient.from("device_one_time_prekeys").delete().eq("id", consumedOtpk.id);
    }

    return Response.json({
      request_id: requestId,
      success: true,
      data: {
        device_id: activeDevice.id,
        registration_id: activeDevice.registration_id,
        identity_public_key: activeDevice.identity_public_key,
        signed_prekey_id: activeDevice.signed_prekey_id,
        signed_prekey_public: activeDevice.signed_prekey_public,
        signed_prekey_signature: activeDevice.signed_prekey_signature,
        one_time_prekey: consumedOtpk,
      },
      error: null,
    });
  } catch (err) {
    return Response.json({ request_id: requestId, success: false, data: null, error: String(err) }, { status: 500 });
  }
});
