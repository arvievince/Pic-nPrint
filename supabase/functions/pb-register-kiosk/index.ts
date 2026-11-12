import { admin, json } from "../_shared/photobooth.ts";

async function sha256Hex(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const body = await req.json().catch(() => ({}));
  const { location_id, kiosk_key, setup_token } = body;

  // 1. Validate inputs
  if (!/^[A-Z0-9]{2,8}$/.test(location_id ?? "")) {
    return json(
      { error: "Invalid Location ID. Use 2–8 uppercase letters and numbers only." },
      400,
    );
  }

  if (!kiosk_key || typeof kiosk_key !== "string" || kiosk_key.trim().length < 8) {
    return json(
      { error: "Invalid Kiosk Key. Must be at least 8 characters long." },
      400,
    );
  }

  // 2. Validate setup authorization (if PB_SETUP_PASSWORD is set in secrets)
  const requiredSecret = Deno.env.get("PB_SETUP_PASSWORD");
  const allowAutoEnroll = Deno.env.get("PB_AUTO_ENROLL") === "true";

  if (requiredSecret && !allowAutoEnroll) {
    if (setup_token !== requiredSecret) {
      return json(
        { error: "Unauthorized: Invalid Master Setup Password." },
        401,
      );
    }
  }

  // 3. Compute SHA-256 hash of the kiosk key
  const cleanKey = kiosk_key.trim();
  const keyHash = await sha256Hex(cleanKey);
  const cleanLocationId = location_id.trim().toUpperCase();

  // 4. Upsert into photobooth.kiosks table
  const { error } = await admin.from("kiosks").upsert(
    {
      location_id: cleanLocationId,
      key_hash: keyHash,
      enabled: true,
      created_at: new Date().toISOString(),
    },
    { onConflict: "location_id" },
  );

  if (error) {
    console.error(`Failed to register kiosk ${cleanLocationId}:`, error);
    return json({ error: `Database error: ${error.message}` }, 500);
  }

  return json({
    ok: true,
    message: `Kiosk ${cleanLocationId} successfully registered in Supabase.`,
  });
});

