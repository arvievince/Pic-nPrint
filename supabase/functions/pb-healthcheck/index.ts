import { json, verifyKiosk } from "../_shared/photobooth.ts";

Deno.serve(async (req) => {
  const { location_id, kiosk_key } = await req.json().catch(() => ({}));
  const ok = await verifyKiosk(location_id, kiosk_key);
  return json({ ok }, ok ? 200 : 401);
});

