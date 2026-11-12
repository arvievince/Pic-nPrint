import { createClient } from "npm:@supabase/supabase-js@2";

// Table queries go to the photobooth schema. Storage calls are not affected by this setting.
export const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { db: { schema: "photobooth" } },
);

export const BUCKET = "photobooth-photos";

async function sha256Hex(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function verifyKiosk(
  locationId: string,
  key: string,
): Promise<boolean> {
  if (!/^[A-Z0-9]{2,8}$/.test(locationId ?? "") || !key) {
    console.warn(
      `verifyKiosk: invalid input (location_id=${JSON.stringify(locationId)}, key=${key ? "set" : "missing"})`,
    );
    return false;
  }

  const { data, error } = await admin
    .from("kiosks")
    .select("key_hash, enabled")
    .eq("location_id", locationId)
    .maybeSingle();

  if (error) {
    console.error(
      `verifyKiosk: query failed for ${locationId}: ${error.message}`,
    );
    return false;
  }
  if (!data) {
    console.warn(`verifyKiosk: no kiosk row for ${locationId}`);
    return false;
  }
  if (!data.enabled) {
    console.warn(`verifyKiosk: kiosk ${locationId} is disabled`);
    return false;
  }

  const matches = data.key_hash === (await sha256Hex(key));
  if (!matches) {
    console.warn(`verifyKiosk: key mismatch for ${locationId}`);
  }
  return matches;
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

