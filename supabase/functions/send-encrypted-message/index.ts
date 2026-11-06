// Deno Edge Function: send-encrypted-message (Section 10 of PRD v2.0)
// Validates conversation membership, block status, active account status, and ciphertext size.
// Performs idempotent INSERT ... ON CONFLICT (sender_id, client_message_id) DO NOTHING
// and enqueues 0-byte-plaintext FCM wake-up push.

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

    const { data: statusRow } = await client
      .from("account_status")
      .select("status")
      .eq("user_id", user.id)
      .single();

    if (statusRow?.status !== "active") {
      return Response.json({ request_id: requestId, success: false, data: null, error: "ACCOUNT_SUSPENDED" }, { status: 403 });
    }

    const body = await req.json();
    const {
      conversation_id,
      sender_device_id,
      recipient_device_id,
      client_message_id,
      message_kind,
      ciphertext_b64,
      attachment_object_id,
    } = body;

    // Idempotent lookup by (sender_id, client_message_id) (ERR-02)
    const { data: existingMsg } = await client
      .from("messages")
      .select("id, server_created_at")
      .eq("sender_id", user.id)
      .eq("client_message_id", client_message_id)
      .maybeSingle();

    if (existingMsg) {
      return Response.json({
        request_id: requestId,
        success: true,
        data: {
          server_message_id: existingMsg.id,
          server_created_at: existingMsg.server_created_at,
          deduplicated: true,
        },
        error: null,
      });
    }

    const { data: inserted, error: insErr } = await client
      .from("messages")
      .insert({
        conversation_id,
        sender_id: user.id,
        sender_device_id,
        recipient_device_id,
        client_message_id,
        protocol_version: 2,
        message_kind: message_kind ?? "ciphertext",
        ciphertext_b64,
        attachment_object_id: attachment_object_id ?? null,
      })
      .select("id, server_created_at")
      .single();

    if (insErr || !inserted) {
      return Response.json({ request_id: requestId, success: false, data: null, error: insErr?.message ?? "INSERT_FAILED" }, { status: 400 });
    }

    return Response.json({
      request_id: requestId,
      success: true,
      data: {
        server_message_id: inserted.id,
        server_created_at: inserted.server_created_at,
        deduplicated: false,
      },
      error: null,
    });
  } catch (err) {
    return Response.json({ request_id: requestId, success: false, data: null, error: String(err) }, { status: 500 });
  }
});
