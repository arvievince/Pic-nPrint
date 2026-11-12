import { admin, BUCKET, json, verifyKiosk } from "../_shared/photobooth.ts";

const DAILY_CAP = Number(Deno.env.get("PB_DAILY_CAP") ?? "500");

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);

  const { location_id, kiosk_key, session_token, files } = await req
    .json()
    .catch(() => ({}));

  if (!(await verifyKiosk(location_id, kiosk_key))) {
    return json({ error: "unauthorized" }, 401);
  }

  // Random, unguessable token generated on the kiosk (not the barcode ID).
  // Must be 20–40 lowercase hex chars (matches Flutter's _generateToken()).
  if (!/^[a-z0-9]{20,40}$/.test(session_token ?? "")) {
    return json({ error: "bad session" }, 400);
  }

  // Optional abuse limit: uploads per location per day
  const startOfDay = new Date();
  startOfDay.setUTCHours(0, 0, 0, 0);
  const { count } = await admin
    .from("shares")
    .select("session_token", { count: "exact", head: true })
    .eq("location_id", location_id)
    .gte("created_at", startOfDay.toISOString());
  if ((count ?? 0) >= DAILY_CAP) return json({ error: "daily cap" }, 429);

  const day = new Date().toISOString().slice(0, 10);
  const base = `${location_id}/${day}/${session_token}`;
  const wanted: string[] = Array.isArray(files) ? files : ["photo"];

  const uploads: Record<string, { path: string; token: string; url: string }> =
    {};
  let photoPath: string | null = null;
  let gifPath: string | null = null;

  for (const kind of wanted) {
    if (kind !== "photo" && kind !== "gif") continue;
    const path = `${base}/${kind === "photo" ? "photo.jpg" : "animation.gif"}`;
    const { data, error } = await admin.storage
      .from(BUCKET)
      .createSignedUploadUrl(path);
    if (error || !data) {
      console.error(`sign failed for ${kind}:`, error);
      return json({ error: "sign failed" }, 500);
    }
    const url = admin.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;
    uploads[kind] = { path, token: data.token, url };
    if (kind === "photo") photoPath = path;
    else gifPath = path;
  }

  const { error: dbError } = await admin.from("shares").insert({
    session_token,
    location_id,
    photo_path: photoPath,
    gif_path: gifPath,
  });
  if (dbError) {
    console.error("db insert failed:", dbError);
    return json({ error: "db" }, 500);
  }

  return json({ uploads });
});

