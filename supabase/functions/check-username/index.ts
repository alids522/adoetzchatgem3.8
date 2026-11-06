// Deno Edge Function: check-username (Section 10 of PRD v2.0)
// Rate-limited endpoint checking regex format, reserved words, and uniqueness in `profiles`.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESERVED = new Set(["admin", "system", "support", "root", "adoetz"]);
const USERNAME_REGEX = /^[a-z0-9_]{3,24}$/;

Deno.serve(async (req: Request) => {
  const requestId = `req_${crypto.randomUUID().replace(/-/g, "").slice(0, 16).toUpperCase()}`;
  try {
    const { username } = await req.json();
    const normalized = String(username ?? "").trim().toLowerCase().replace(/^@/, "");

    if (!USERNAME_REGEX.test(normalized)) {
      return Response.json({
        request_id: requestId,
        success: true,
        data: { available: false, reason: "INVALID_USERNAME_FORMAT" },
        error: null,
      });
    }

    if (RESERVED.has(normalized)) {
      return Response.json({
        request_id: requestId,
        success: true,
        data: { available: false, reason: "RESERVED_USERNAME" },
        error: null,
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: existing } = await adminClient
      .from("profiles")
      .select("user_id")
      .eq("username_normalized", normalized)
      .maybeSingle();

    return Response.json({
      request_id: requestId,
      success: true,
      data: {
        available: !existing,
        reason: existing ? "USERNAME_TAKEN" : "AVAILABLE",
      },
      error: null,
    });
  } catch (err) {
    return Response.json({ request_id: requestId, success: false, data: null, error: String(err) }, { status: 500 });
  }
});
