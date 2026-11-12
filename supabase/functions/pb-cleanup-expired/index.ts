import { admin, BUCKET, json, verifyKiosk } from "../_shared/photobooth.ts";

const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

Deno.serve(async (req) => {
  // Allowed callers: the scheduled job (secret header) or a registered kiosk
  const secret = req.headers.get("x-cleanup-secret");
  const body = await req.json().catch(() => ({}));
  const okSecret =
    !!secret && secret === Deno.env.get("PB_CLEANUP_SECRET");
  const okKiosk = await verifyKiosk(body.location_id, body.kiosk_key);

  if (!okSecret && !okKiosk) return json({ error: "unauthorized" }, 401);

  const cutoff = new Date(Date.now() - MAX_AGE_MS).toISOString();
  const { data: rows } = await admin
    .from("shares")
    .select("session_token, photo_path, gif_path")
    .lt("created_at", cutoff)
    .is("deleted_at", null)
    .limit(200);

  if (!rows || rows.length === 0) return json({ deleted: 0 });

  const paths = rows
    .flatMap((r) => [r.photo_path, r.gif_path])
    .filter(Boolean) as string[];

  // Always delete through the Storage API — SQL deletes leave physical files
  // behind and they keep counting against your quota.
  const { error } = await admin.storage.from(BUCKET).remove(paths);
  if (error) {
    console.error("storage remove failed:", error);
    return json({ error: "remove failed" }, 500);
  }

  await admin
    .from("shares")
    .update({ deleted_at: new Date().toISOString() })
    .in(
      "session_token",
      rows.map((r) => r.session_token),
    );

  return json({ deleted: rows.length });
});

