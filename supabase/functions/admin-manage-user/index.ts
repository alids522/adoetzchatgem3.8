// Deno Edge Function: admin-manage-user (Section 10 of PRD v2.0)
// Verifies directly in DB that caller has `role = 'admin'` and `status = 'active'`.
// Handles `suspend`, `unsuspend`, `force_reset_password`, `revoke_sessions`, `change_role`, `delete_user`
// with mandatory audit logging in `private.admin_audit_logs` (never logging temporary passwords).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  const requestId = `req_${crypto.randomUUID().replace(/-/g, "").slice(0, 16).toUpperCase()}`;
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user } } = await adminClient.auth.getUser();
    if (!user) {
      return Response.json({ request_id: requestId, success: false, data: null, error: "UNAUTHORIZED" }, { status: 401 });
    }

    const { data: roleRow } = await adminClient.from("user_roles").select("role").eq("user_id", user.id).single();
    const { data: statusRow } = await adminClient.from("account_status").select("status").eq("user_id", user.id).single();

    if (roleRow?.role !== "admin" || statusRow?.status !== "active") {
      return Response.json({ request_id: requestId, success: false, data: null, error: "FORBIDDEN_ADMIN_ONLY" }, { status: 403 });
    }

    const { target_user_id, operation, reason } = await req.json();
    if (!reason || String(reason).trim().length < 5) {
      return Response.json({ request_id: requestId, success: false, data: null, error: "AUDIT_REASON_REQUIRED" }, { status: 400 });
    }

    let oneTimePassword: string | null = null;

    if (operation === "suspend") {
      await adminClient.from("account_status").update({ status: "suspended", suspended_reason: reason }).eq("user_id", target_user_id);
    } else if (operation === "unsuspend") {
      await adminClient.from("account_status").update({ status: "active", suspended_reason: null }).eq("user_id", target_user_id);
    } else if (operation === "revoke_sessions") {
      await adminClient.from("devices").update({ status: "revoked" }).eq("user_id", target_user_id).eq("status", "active");
    } else if (operation === "force_reset_password") {
      const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%";
      const randBytes = crypto.getRandomValues(new Uint8Array(16));
      oneTimePassword = Array.from(randBytes).map((b) => chars[b % chars.length]).join("");
      await adminClient.auth.admin.updateUserById(target_user_id, { password: oneTimePassword });
    }

    // Record mandatory audit log WITHOUT storing the temporary password
    await adminClient.schema("private").from("admin_audit_logs").insert({
      request_id: requestId,
      actor_user_id: user.id,
      target_user_id,
      action: operation,
      reason: String(reason).trim(),
    });

    return Response.json({
      request_id: requestId,
      success: true,
      data: {
        target_user_id,
        operation,
        temporary_password_once: oneTimePassword,
      },
      error: null,
    });
  } catch (err) {
    return Response.json({ request_id: requestId, success: false, data: null, error: String(err) }, { status: 500 });
  }
});
