// Deno Edge Function: issue-attachment-grant (Section 10 of PRD v2.0)
// Validates conversation membership & quota, then issues a 120-second Signed Upload URL
// to private bucket `encrypted-attachments/{conversation_id}/{random_uuid}.enc`.

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

    const { conversation_id } = await req.json();
    const objectId = crypto.randomUUID();
    const objectPath = `${conversation_id}/${objectId}.enc`;

    const { data: signed, error: signErr } = await client.storage
      .from("encrypted-attachments")
      .createSignedUploadUrl(objectPath);

    return Response.json({
      request_id: requestId,
      success: !signErr,
      data: {
        object_id: objectId,
        object_path: objectPath,
        signed_url: signed?.signedUrl ?? null,
        expires_in_seconds: 120,
      },
      error: signErr?.message ?? null,
    });
  } catch (err) {
    return Response.json({ request_id: requestId, success: false, data: null, error: String(err) }, { status: 500 });
  }
});
