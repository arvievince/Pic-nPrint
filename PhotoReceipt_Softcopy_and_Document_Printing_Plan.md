# PhotoReceipt: Soft Copy (Supabase) and Document Printing Plan

**Applies to:** PhotoReceipt v1 (Flutter, Windows + Android)
**Replaces / consolidates:** `PhotoReceipt_Supabase_Plan.md` and `PhotoReceipt_Document_Printer_Plan.md`
**Related file:** `PhotoReceipt_Final_Plan.md` (voucher, capture, editor, thermal printing, and admin sections still apply)

> **How to read the facts in this file:** free-tier limits, dashboard menu names, and package behavior were checked against web sources in 2026 and may have changed. The sources disagree on a few figures, which are noted where they appear. Code is a **starter sketch** that must be tested. Anything marked **Verify** should be confirmed before you depend on it.

---

## Part 1: Overview

### 1.1 Goals

1. After the customer finishes editing, the app saves a **soft copy** (photo, plus a GIF for 4 and 6 shots) to **Supabase Storage**.
2. The app shows a **QR code on screen only** (nothing is printed for it) so the customer can open the soft copy on their phone.
3. Files are **deleted automatically after 7 days**.
4. The app can also print the image on a **document/photo printer** (full color, photo paper or standard paper), in addition to the thermal receipt printer already planned.
5. Everything runs on **Windows and Android**, and keeps working (locally) when the internet or Supabase is unavailable.

### 1.2 Decisions already made

| Topic | Decision |
|---|---|
| Soft copy storage | Supabase Storage (replaces Google Drive) |
| QR | On screen only. Not printed or embedded in the image |
| Footer on image and print | Store/event logo and a session-ID barcode (for your own tracking) |
| Retention | 7 days per file |
| Thermal printing | Stays on `esc_pos_utils_plus` |
| Document printing | New printer type using `printing` + `pdf` |
| Vouchers | Tier-locked, offline-verified, kiosk-bound (unchanged) |
| Supabase project | **Shared with your existing project**, using a separate `photobooth` schema (see section 2.3) |

### 1.3 End-to-end flow

```
Edit finished
  ├─ Create session (session ID for barcode, random token for the storage path)
  ├─ Print step ──► print jobs queued (thermal and/or document)   [does not wait for upload]
  └─ Upload (parallel, in background)
        ├─ compress photo (and GIF)
        ├─ ask Edge Function for signed upload tokens
        └─ upload files
  QR screen: "Preparing…" → QR(s) → timer → attract screen
```

Printing never waits for the upload, and the upload never waits for printing.

---

## Part 2: Soft Copy Architecture

### 2.1 Components

| Component | Where | Role |
|---|---|---|
| Bucket `photobooth-photos` | Supabase Storage | Public read, 10 MB limit, images only |
| Schema `photobooth` | Postgres | Holds the tables below, separate from your existing schema |
| Table `photobooth.kiosks` | Postgres | One row per location: hashed key, enabled flag |
| Table `photobooth.shares` | Postgres | One row per session upload: paths, created, expires, deleted |
| `pb-create-upload` | Edge Function | Verifies the kiosk key, returns signed upload tokens and public URLs |
| `pb-cleanup-expired` | Edge Function | Deletes expired files through the Storage API |
| `pb-healthcheck` | Edge Function | Lets the admin test the connection |
| `SupabaseStorageProvider` | Flutter | Implements the `StorageProvider` interface |

### 2.2 Why uploads go through an Edge Function

If the app wrote straight to the bucket with only the public key, anyone who pulled that key out of the app could upload files to your bucket. With the function approach:

- The bucket has **no upload policy** for the public roles, so direct uploads are refused.
- Only a kiosk with a valid **location key** gets a signed upload token.
- A lost or stolen kiosk can be switched off by setting `enabled = false`.
- The service-role (secret) key stays inside the functions and **never** goes on a device.

### 2.3 Sharing your existing project (separate schema)

Your existing schema stays untouched. A few Supabase things are **project-wide**, so they need prefixes to avoid clashing with your first app:

| Item | Separate or shared | What to do |
|---|---|---|
| Tables | Separate (own schema) | Use schema `photobooth` |
| Storage buckets | Project-wide | Bucket name `photobooth-photos` |
| Storage policies | Shared (`storage.objects`) | Check the existing policies first (step C3) |
| Edge Function names | Project-wide | Prefix `pb-` |
| Secrets | Project-wide | Prefix `PB_` |
| `pg_cron` job names | Shared | Name `photobooth-cleanup` |
| Service-role / secret key | Shared | Keep photobooth functions limited to the `photobooth` schema and the one bucket |
| Free-tier quotas (storage, bandwidth, database) | Shared | Both apps count toward the same limits |
| Pausing | Whole project | Both apps pause together |

**Moving out later:** because everything is prefixed and in its own schema, you can later dump the `photobooth` schema, recreate the bucket, redeploy the `pb-` functions, and change the project URL and key in each kiosk's admin screen. No app code changes.

### 2.4 Free tier reality check

Figures found in 2026 sources for the **Free** plan (confirm on the Supabase pricing page):

| Limit | Value |
|---|---|
| File storage | 500 MB to 1 GB (sources disagree) |
| Egress (bandwidth) | 5 GB per month |
| Database | 500 MB |
| Inactivity | Projects pause after 7 days without activity and need a manual restore |

The Pro plan (about $25 per month per organization) was listed with 100 GB storage, 250 GB egress, and no pausing.

**Capacity estimate (my own arithmetic, not an official figure).** Assuming a compressed photo of about 0.5 MB and a GIF of about 1.5 MB, the average is about 1.5 MB per session.

| Free storage | Sessions held at once (7-day window) | About per day, all kiosks and your other app's files included |
|---|---|---|
| 500 MB | about 330 | about 47 |
| 1 GB | about 660 | about 95 |

Bandwidth: 5 GB per month at about 1.5 MB per view is roughly 3,300 views per month (about 110 per day). Your existing app's files and traffic use the **same** allowances, so check how much it already uses.

**What this means:**

- The free plan is realistic for a pilot or a small location.
- Several busy locations or events will probably need the Pro plan. Decide before launch.
- A quiet week can pause the project. Uploads then fail, and the kiosk falls back to local-only and retries.

**Ways to stay within limits:** compress files, upload GIFs only for 4 and 6 shots, run cleanup hourly, and show usage in the admin screen.

---

## Part 3: Supabase Dashboard Setup (Step by Step)

Menu names in the dashboard change over time. Where I give a path, treat it as a guide, and use the dashboard search if something has moved.

### C1. Back up your existing schema first

Your existing app's data matters more than anything here. Free projects may not include automatic backups (one source listed daily backups under Pro), so take your own:

- Dashboard: **Database → Backups** (see what your plan offers), or
- CLI: `supabase db dump -f backup.sql` (after `supabase login` and `supabase link`)

Keep the file somewhere safe.

### C2. Collect the project values

In **Project Settings → API Keys** (older projects: **Project Settings → API**):

| Value | Goes where |
|---|---|
| Project URL | Kiosk app (safe to ship) |
| Public key (**anon** or the newer **publishable** key) | Kiosk app (safe to ship, because it has no write access to our tables or bucket) |
| **Service-role / secret** key | **Never in the app.** Only inside Supabase |

**Verify:** newer projects show both "publishable/secret" keys and the legacy "anon/service_role" keys. Edge Functions check for a valid JWT by default, and a publishable key may not pass that check. If calls return 401 before reaching your code, either use the legacy anon key, or deploy with JWT verification off (`--no-verify-jwt`). Turning it off is acceptable here because every function does its own kiosk-key check, but then the **kiosk key check is your only gate**, so keep the keys strong.

### C3. Check the existing storage policies

My security design assumes the public roles cannot upload to the new bucket. If your first app has a policy on `storage.objects` that is **not limited to a specific bucket**, it also applies to the new bucket. In **SQL Editor**, run:

```sql
select policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'storage' and tablename = 'objects';
```

Every policy should mention its own `bucket_id`. If one does not, fix it before creating the new bucket.

### C4. Check what is already exposed

**Project Settings → Data API → Exposed schemas.** Note the current list (usually `public` and `graphql_public`). Do not remove anything your first app uses.

### C5. Create the schema, tables, and permissions

In **SQL Editor**:

```sql
create schema if not exists photobooth;

-- One row per location
create table photobooth.kiosks (
  location_id text primary key,
  key_hash    text not null,
  enabled     boolean not null default true,
  created_at  timestamptz not null default now()
);

-- One row per uploaded session
create table photobooth.shares (
  session_token text primary key,
  location_id   text not null references photobooth.kiosks (location_id),
  photo_path    text,
  gif_path      text,
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null default (now() + interval '7 days'),
  deleted_at    timestamptz
);

create index shares_cleanup_idx on photobooth.shares (created_at)
  where deleted_at is null;

alter table photobooth.kiosks enable row level security;
alter table photobooth.shares enable row level security;

-- Only the service role (the Edge Functions) may touch this schema.
-- This deliberately differs from the generic Supabase example, which also
-- grants access to anon and authenticated.
revoke all on schema photobooth from anon, authenticated;
grant usage on schema photobooth to service_role;
grant all on all tables in schema photobooth to service_role;
alter default privileges in schema photobooth
  grant all on tables to service_role;
```

### C6. Expose the schema to the Data API

The Edge Functions reach the tables through the Data API, which only serves schemas on the exposed list.

1. Go to **Project Settings → Data API → Exposed schemas**.
2. **Add** `photobooth` to the existing list (keep the others).
3. Save.

Exposing it is safe here because the `anon` and `authenticated` roles have no access to the schema.

### C7. Create the storage bucket

**Storage → New bucket** (or use SQL below):

| Setting | Value |
|---|---|
| Name | `photobooth-photos` |
| Public bucket | **On** (so the QR link opens without signing in) |
| Restrict file size | On, 10 MB |
| Allowed MIME types | `image/jpeg, image/png, image/gif` |

SQL alternative:

```sql
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photobooth-photos', 'photobooth-photos', true, 10485760,
        array['image/jpeg', 'image/png', 'image/gif'])
on conflict (id) do nothing;
```

**Do not** add insert, update, or delete policies on this bucket. Signed upload tokens work without them, and the lack of policies is what blocks anyone else from uploading. A public bucket lets people open a file if they know its exact URL, but does not let them list the files.

### C8. Enable the extensions

**Database → Extensions:** enable `pg_cron` and `pg_net`. Also confirm `pgcrypto` is enabled (used to hash the kiosk key). **Verify:** one source suggested scheduled jobs may need the Pro plan. If you cannot enable `pg_cron`, use the kiosk-triggered cleanup fallback described in step C13.

### C9. Install the CLI and link the project

Follow the current Supabase CLI install instructions for Windows, then:

```bash
supabase login
supabase init
supabase link --project-ref <your-project-ref>
```

If your first app already uses this folder and migrations, **keep the photobooth functions in a separate folder or repository**, to avoid migration-history mismatches. Deploying functions does not touch your existing ones. Run the photobooth SQL in the dashboard SQL Editor rather than through `supabase db push`.

### C10. Register each kiosk

Generate one random key per location (PowerShell):

```powershell
$b = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
($b | ForEach-Object { $_.ToString('x2') }) -join ''
```

Save the plain key in a password manager. Store only its **hash** in the database (SQL Editor):

```sql
insert into photobooth.kiosks (location_id, key_hash)
values ('MNL1', encode(extensions.digest('PASTE-THE-KEY-HERE', 'sha256'), 'hex'));
```

Repeat per location with a **different** key. If `extensions.digest` is not found, enable `pgcrypto` first.

### C11. Create and deploy the Edge Functions

```bash
supabase functions new pb-create-upload
supabase functions new pb-cleanup-expired
supabase functions new pb-healthcheck
```

**`supabase/functions/_shared/photobooth.ts`**

```ts
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

export async function verifyKiosk(locationId: string, key: string): Promise<boolean> {
  if (!/^[A-Z0-9]{2,8}$/.test(locationId ?? "") || !key) return false;
  const { data } = await admin
    .from("kiosks")
    .select("key_hash, enabled")
    .eq("location_id", locationId)
    .maybeSingle();
  if (!data || !data.enabled) return false;
  return data.key_hash === (await sha256Hex(key));
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
```

**`supabase/functions/pb-create-upload/index.ts`**

```ts
import { admin, BUCKET, json, verifyKiosk } from "../_shared/photobooth.ts";

const DAILY_CAP = Number(Deno.env.get("PB_DAILY_CAP") ?? "500");

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);

  const { location_id, kiosk_key, session_token, files } = await req.json();

  if (!(await verifyKiosk(location_id, kiosk_key))) {
    return json({ error: "unauthorized" }, 401);
  }
  // Random, unguessable token generated on the kiosk (not the barcode ID)
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

  const uploads: Record<string, { path: string; token: string; url: string }> = {};
  let photoPath: string | null = null;
  let gifPath: string | null = null;

  for (const kind of wanted) {
    if (kind !== "photo" && kind !== "gif") continue;
    const path = `${base}/${kind === "photo" ? "photo.jpg" : "animation.gif"}`;
    const { data, error } = await admin.storage.from(BUCKET).createSignedUploadUrl(path);
    if (error || !data) return json({ error: "sign failed" }, 500);
    const url = admin.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;
    uploads[kind] = { path, token: data.token, url };
    if (kind === "photo") photoPath = path; else gifPath = path;
  }

  const { error: dbError } = await admin.from("shares").insert({
    session_token, location_id, photo_path: photoPath, gif_path: gifPath,
  });
  if (dbError) return json({ error: "db" }, 500);

  return json({ uploads });
});
```

**`supabase/functions/pb-cleanup-expired/index.ts`**

```ts
import { admin, BUCKET, json, verifyKiosk } from "../_shared/photobooth.ts";

const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

Deno.serve(async (req) => {
  // Allowed callers: the scheduled job (secret header) or a registered kiosk
  const secret = req.headers.get("x-cleanup-secret");
  const body = await req.json().catch(() => ({}));
  const okSecret = !!secret && secret === Deno.env.get("PB_CLEANUP_SECRET");
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

  const paths = rows.flatMap((r) => [r.photo_path, r.gif_path]).filter(Boolean) as string[];
  // Always delete through the Storage API. Deleting rows from storage.objects with SQL
  // leaves the physical files behind and they keep using your quota.
  const { error } = await admin.storage.from(BUCKET).remove(paths);
  if (error) return json({ error: "remove failed" }, 500);

  await admin
    .from("shares")
    .update({ deleted_at: new Date().toISOString() })
    .in("session_token", rows.map((r) => r.session_token));

  return json({ deleted: rows.length });
});
```

**`supabase/functions/pb-healthcheck/index.ts`**

```ts
import { json, verifyKiosk } from "../_shared/photobooth.ts";

Deno.serve(async (req) => {
  const { location_id, kiosk_key } = await req.json().catch(() => ({}));
  const ok = await verifyKiosk(location_id, kiosk_key);
  return json({ ok }, ok ? 200 : 401);
});
```

Set the secrets and deploy (**Edge Functions → Secrets** in the dashboard works too):

```bash
supabase secrets set PB_CLEANUP_SECRET=<a-long-random-value> PB_DAILY_CAP=500
supabase functions deploy pb-create-upload
supabase functions deploy pb-cleanup-expired
supabase functions deploy pb-healthcheck
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are normally available inside functions automatically (**Verify** this on your project, especially if you moved to the newer secret keys).

### C12. Test the backend before writing any Flutter code

Use PowerShell (replace the placeholders):

```powershell
$url  = "https://<project-ref>.supabase.co/functions/v1"
$hdr  = @{ Authorization = "Bearer <anon-or-publishable-key>"; "Content-Type" = "application/json" }

# 1. Health check: expect ok = true
Invoke-RestMethod -Method Post -Uri "$url/pb-healthcheck" -Headers $hdr `
  -Body '{"location_id":"MNL1","kiosk_key":"<plain-key>"}'

# 2. Wrong key: expect 401
Invoke-RestMethod -Method Post -Uri "$url/pb-healthcheck" -Headers $hdr `
  -Body '{"location_id":"MNL1","kiosk_key":"wrong"}'

# 3. Ask for upload tokens
Invoke-RestMethod -Method Post -Uri "$url/pb-create-upload" -Headers $hdr `
  -Body '{"location_id":"MNL1","kiosk_key":"<plain-key>","session_token":"abcdefghij0123456789","files":["photo"]}'
```

Then:

4. Upload a small JPEG using the returned token (easiest from the Flutter spike in phase 4.0), and open the returned public URL in a browser.
5. Try uploading to the bucket with only the public key and **confirm it is refused**.
6. In **Table Editor**, change a test row's `created_at` to 8 days ago, call `pb-cleanup-expired` with the header `x-cleanup-secret`, and confirm the file disappears and `deleted_at` is set.
7. Confirm your **existing app still works** and that the `public` schema is unchanged.

### C13. Schedule the hourly cleanup

In **SQL Editor**:

```sql
select cron.schedule(
  'photobooth-cleanup',
  '0 * * * *',
  $$
  select net.http_post(
    url     := 'https://<project-ref>.supabase.co/functions/v1/pb-cleanup-expired',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <anon-or-publishable-key>',
      'x-cleanup-secret', '<PB_CLEANUP_SECRET>'
    ),
    body    := '{}'::jsonb
  );
  $$
);
```

If you would rather not keep the secret in plain SQL, store it in **Vault** and read it from there. To remove the job later: `select cron.unschedule('photobooth-cleanup');`

**Fallback if `pg_cron` is not available:** each kiosk calls `pb-cleanup-expired` with its own location key on app start and every few hours. The function already accepts that.

### C14. Monitoring

| Where | What to watch |
|---|---|
| **Settings → Usage** (or Reports) | Storage size and bandwidth against the free limits, shared with your first app |
| **Storage → photobooth-photos** | Files appear and disappear as expected |
| **Edge Functions → Logs** | Errors from the three functions |
| **Table Editor → photobooth.shares** | Rows with `deleted_at` null and `created_at` older than 7 days (cleanup is failing) |
| **Database → Cron jobs** | The `photobooth-cleanup` job runs hourly |

Check usage weekly during the pilot.

---

## Part 4: Soft Copy in the Flutter App

### 4.1 Storage abstraction

```dart
abstract class StorageProvider {
  Future<UploadResult> upload({
    required String sessionToken,
    required File photo,
    File? gif,
  });
  Future<bool> testConnection();
}

class UploadResult {
  final String photoUrl;
  final String? gifUrl;
  final String photoPath;
  final String? gifPath;
}
```

`SupabaseStorageProvider` replaces the Drive provider. The interface stays, so another provider can be added later without touching capture, editing, or printing.

### 4.2 Upload flow

1. Generate a **random session token** (20 to 40 lowercase letters and digits, from a secure random source). It is used in the storage path and is **not** the barcode ID, so reading the barcode cannot reveal the link.
2. Compress the photo (JPEG) and the GIF (4 and 6 shots only) in an isolate.
3. Call `pb-create-upload` with the key, location ID, kiosk key, session token, and file list.
4. Upload each file with its signed token.
5. Save paths, URLs, and `upload_status = done` in the local `sessions` row.
6. Show the QR screen.

Sketch (check exact method names in the current `supabase_flutter` docs):

```dart
final res = await http.post(
  Uri.parse('$projectUrl/functions/v1/pb-create-upload'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $publicKey',
  },
  body: jsonEncode({
    'location_id': locationId,
    'kiosk_key': kioskKey,
    'session_token': sessionToken,
    'files': gif == null ? ['photo'] : ['photo', 'gif'],
  }),
);
final uploads = jsonDecode(res.body)['uploads'];

await supabase.storage.from('photobooth-photos').uploadToSignedUrl(
  uploads['photo']['path'],
  uploads['photo']['token'],
  photoFile,
  fileOptions: const FileOptions(contentType: 'image/jpeg'),
);
```

The app does **not** need to read the `photobooth` tables directly, so the Flutter client does not need the schema setting. Only the Edge Functions use it.

### 4.3 Where each value is stored on the kiosk

| Value | Storage |
|---|---|
| Project URL, public key, bucket name | `settings` (not secret) |
| Location ID | `settings` |
| Kiosk key | `flutter_secure_storage` |

### 4.4 Compression targets

| File | Target |
|---|---|
| Photo (all modes) | JPEG, long edge about 1080 px, quality about 80, aim for 0.3 to 0.8 MB |
| GIF (4 and 6 shots) | Max width about 480 px, limited colors and frames, aim for 1.5 MB or less |

Printing uses the **full-resolution composed image**. Only the uploaded soft copy is compressed.

### 4.5 QR screen

| Item | Behavior |
|---|---|
| Single, 3 shots | One QR for the photo |
| 4 and 6 shots | **Two tabs: Photo and GIF**, each with its own QR |
| Loading | "Preparing your photo…" with a progress indicator while uploading |
| Slow or failed upload | "Still uploading, please wait," keep retrying in the background, and let the customer keep waiting or leave |
| Thumbnail | Small preview of the customer's photo next to the QR |
| Timer | Configurable, default 60 seconds, with "Need more time" and "Done" buttons |
| Privacy line | "Anyone with this link can view the photo for 7 days." |
| QR size | As large as the screen allows, high contrast, white border (quiet zone) |
| Supabase not configured, or local-only mode | Skip the QR screen and return to the attract screen |

**What the QR contains:** the public file URL, for example
`https://<project-ref>.supabase.co/storage/v1/object/public/photobooth-photos/MNL1/2026-11-10/<random-token>/photo.jpg`.
It is long, so the on-screen QR must be large. This is fine because it is not printed.

**What the customer sees after scanning:** the phone's browser opens the image directly, and a GIF plays in the browser. Saving is by long-press or the browser menu, which varies by phone, so test several devices.

**Optional later: viewer page.** A page with a **Download** button showing both photo and GIF would be nicer. I have **not verified** whether Supabase can serve an HTML page from an Edge Function on its default domain (it may serve it as plain text). A static page on a free static host (for example GitHub Pages or Cloudflare Pages) that takes the file path in the URL is the safer route. It is not part of v1.

### 4.6 Offline, failure, and pause handling

| Situation | Behavior |
|---|---|
| No internet at upload time | Save locally, queue the upload, retry with backoff. Customer sees "still uploading," and printing continues |
| Project paused (free plan idle) | Uploads fail, so the same queue and retry applies. Admin sees a "Supabase unreachable" alert and restores the project from the dashboard |
| Signed token expired | Request a new token and retry |
| Photo uploaded, GIF failed | Retry only the missing file |
| Upload completes after the customer left | The QR is no longer shown. Staff can find the file using the session ID in the admin session log |
| Cleanup did not run | Files linger past 7 days. The kiosk's startup call to `pb-cleanup-expired` is the backup |

### 4.7 Security and privacy

| Topic | Approach |
|---|---|
| Secret/service-role key | Only inside Supabase. Never in the app or in Git. Rotate immediately if exposed |
| Public key in the app | Acceptable, because public roles have no write access to our schema or bucket |
| Uploads | Only through signed tokens issued after a valid kiosk key |
| Kiosk keys | One per location, hashed in the database, stored securely on the device |
| Lost or stolen kiosk | Set `enabled = false` on its row, issue a new key to the replacement |
| Key rotation | Update `key_hash`, then enter the new key in the kiosk admin screen |
| Public links | Unguessable token in the path, bucket listing not possible. Anyone holding the link can view the file until deletion |
| Barcode vs link | The printed barcode ID is different from the storage token, so it cannot be used to guess the link |
| Link expiry | Files are deleted after 7 days, and the link then shows an error |
| Abuse control | Daily cap per location in `pb-create-upload` |
| Minors | Tell customers links are viewable by anyone who has them. Consider a visible notice at events with children |
| Data retention | `shares` rows can be purged after about 30 days. Files are already gone after 7 |

---

## Part 5: Document Printer Plan

### 5.1 Why a separate path

`esc_pos_utils_plus` sends ESC/POS commands, which only thermal receipt printers understand. A photo or document printer needs a full-color page sent through the operating system's print system.

| | Thermal (receipt) | Document (photo) |
|---|---|---|
| Package | `esc_pos_utils_plus` + transport | `printing` + `pdf` |
| What is sent | ESC/POS bytes (raster bitmap) | A PDF page |
| Color | Black and white (dithered) | Full color or grayscale |
| Paper | Roll, 80mm (default) or 58mm | Sheets: 4×6, 5×7, A4, Letter, custom |
| Connection | Bluetooth, USB, network (port 9100) | OS-installed printers (Windows), or system print dialog (Android) |
| Speed | Fast | Slower |

### 5.2 Dependencies

| Package | Role |
|---|---|
| `printing` | Lists installed printers, sends the PDF to a printer, supports silent printing on Windows, opens the system print dialog on Android |
| `pdf` | Builds the print page at the exact paper size |
| `image` | Already used. Resizes or crops to the target resolution |
| `path_provider` | Temp storage for generated PDFs |
| `esc_pos_utils_plus` | Unchanged, for thermal printing |
| `win32` (optional) | Only if you need Windows driver settings that `printing` does not expose |

```yaml
dependencies:
  printing: any   # pin to the latest version when you add it
  pdf: any
```

**Verify:** I have not checked the latest versions or changelogs. Confirm current Windows and Android support for `printing` on pub.dev before starting phase 5b.

### 5.3 Platform behavior (the key constraint)

| | Windows | Android |
|---|---|---|
| List installed printers | Yes | No |
| Admin picks a specific printer in the app | Yes | No |
| Silent print (no dialog) | Yes | No, uses the system print dialog |
| Needs a print service on the device | No (uses the Windows spooler and driver) | Yes (for example Mopria or the manufacturer's plugin) |

**Consequences:**

- **Windows kiosks** can print photos fully automatically after the admin picks the printer once.
- **Android devices** show the system print dialog for every job, so someone must tap Print (and may need to choose the printer). The printer profile on Android is "System print dialog."
- If you need fully automatic photo printing, **use Windows** for those kiosks. Android remains a good fit for thermal printing, which does not use the OS print system.

### 5.4 Printer profiles

**Common fields:** name, kind (`thermal` or `document`), enabled, default for its kind.

**Thermal fields (unchanged):** connection (Bluetooth, USB, network), address, paper width (80mm default, 58mm), rotate-strip option.

**Document fields (new):**

| Field | Options |
|---|---|
| Printer reference | Windows: chosen from the installed printer list. Android: "System print dialog" |
| Paper size | 4×6, 5×7, A4, Letter, custom (width × height) |
| Orientation | Auto, portrait, landscape |
| Margins | None (borderless attempt), small, normal, custom |
| Color mode | Color or grayscale |
| Fit mode | Fit (whole image visible) or fill (crop to cover) |
| Layout template | See 5.6 |
| Copies | Default number of copies |
| Resolution | Target DPI (default 300) |
| Silent print | On or off (Windows only) |

**Admin actions:** add, edit, delete, enable or disable, set default for its kind, preview the page, and **test print** (sample image with footer and a ruler border to check margins).

### 5.5 Customer flow: the Print step

After editing, a **Print step** appears, using the printers the admin has enabled:

| Option | Result |
|---|---|
| Receipt (thermal) | Default thermal printer |
| Photo / Document | Default document printer |
| Both | Both printers |
| No print | Digital copy only |

**Destination modes (admin setting):**

1. **Customer chooses** the destination on the Print step.
2. **Fixed per tier:** the admin assigns a destination to each mode (for example Single and 3 shots on thermal, 4 and 6 shots on the photo printer).
3. **Fixed globally:** one destination for everyone.

If only one printer kind is enabled, the Print step is skipped and printing starts automatically.

**Pricing note:** photo paper and ink cost more than thermal paper. "Fixed per tier" lets you tie photo prints to the higher-priced tiers. **Decision needed:** which mode should be the default? (See open questions.)

### 5.6 Document print layouts

**Page generation:**

1. Read the printer profile (paper size, margins, orientation, fit mode).
2. Create a page format for the paper size.
3. Place the **full-resolution composed image** according to the layout template.
4. Add the footer (store/event logo and session-ID barcode).
5. Save the PDF to a temp folder and send it to the printer.

**Layout templates:**

| Template | Description | Best for |
|---|---|---|
| Single on page | One strip centered | 4×6, 5×7 |
| Rotated fill | Strip rotated 90° to use the page length | Horizontal rows on 4×6 |
| Two-up | Two copies side by side so the sheet can be cut in half | A4, Letter |
| Full bleed | Image fills the page edge to edge | Borderless photo printers |

**Rules:** full color with **no dithering** (dithering is only for thermal), images resized to the target DPI before being placed, barcode rendered as vector or high resolution so it stays sharp, grayscale mode converts the image first, and the admin can preview the page including margins before saving.

### 5.7 Print pipeline and queue

```
PrintService.enqueue(session, destination)
   ├─ thermal job  → ThermalRenderer (esc_pos_utils_plus) → network / USB / Bluetooth
   └─ document job → DocumentRenderer (pdf) → printing package
```

| Component | Responsibility |
|---|---|
| `PrintService` | Creates jobs for the chosen destination(s) |
| `PrintQueue` | One queue per printer, jobs run in order |
| `ThermalRenderer` | Builds ESC/POS bytes |
| `DocumentRenderer` | Builds the PDF page |
| `PrinterDriver` (interface) | `print(job)`, with implementations for thermal network, thermal USB, thermal Bluetooth, document Windows, document Android dialog |

**Job status:** `queued → rendering → sending → done`, or `failed` (with an error) or `cancelled`.

**Behavior:**

- Printing runs in the background and **does not wait for the upload**.
- Failed jobs retry automatically a configurable number of times with a delay.
- After the retries are used up, the job stays `failed` and the admin screen shows an alert.
- The admin can **reprint** a failed job, or reprint a past session by session ID.
- If one printer is offline, its jobs wait, and other printers keep working.
- A job is `done` when the driver confirms the job was **sent**. That does not guarantee paper came out (no ink or paper cannot always be detected).

---

## Part 6: Admin Configuration Changes

### 6.1 Cloud storage (Supabase) section (replaces "Drive")

| Setting | Notes |
|---|---|
| Project URL | From Supabase settings |
| Public key | The anon or publishable key |
| Bucket name | Default `photobooth-photos` |
| Location ID | Must match the `photobooth.kiosks` row, for example `MNL1` |
| Kiosk key | Hidden field, stored securely |
| Test connection | Calls `pb-healthcheck`, shows OK or the error |
| Retention | Fixed at 7 days (cleanup runs on the server) |
| Upload queue | Pending count, retry now, clear |
| Usage view | Uploads today and total bytes uploaded from this kiosk |
| Import kiosk config | Load a small JSON file containing the values above, so setting up many kiosks is fast |
| Local-only mode | Toggle. When on, nothing is uploaded and the QR screen is skipped |
| QR screen time | Seconds, default 60 |

**First-run wizard:** add a Supabase step (or "skip, local only").

### 6.2 Printers section

- Two sections: **Receipt printers** and **Document printers**
- Each row shows name, kind, connection, status, and the default marker
- Actions: add, edit, test, enable or disable, delete
- **Print destination settings:** mode, per-tier destination table, retry count and delay, failed-job alert behavior
- **Print queue view:** recent jobs with session ID, printer, status, attempts, time, and actions (retry, cancel, reprint)

---

## Part 7: Data Model Changes

### Local database (Drift)

**`sessions`**

| Column | Change |
|---|---|
| `drive_file_id` | **Remove** |
| `session_id` | Kept (the barcode ID, for example `MNL1-241009-0042`) |
| `session_token` | Add (random token for the storage path) |
| `photo_path`, `gif_path`, `photo_url`, `gif_url` | Add |
| `upload_status` | Add: `pending`, `uploading`, `done`, `failed`, `local_only` |
| `upload_attempts` | Add |
| `expires_at` | Add (created + 7 days) |
| `print_destination` | Add |

**`printers`:** add `kind`, `enabled`, `is_default`, `printer_ref`, `paper_size`, `orientation`, `margins`, `color_mode`, `fit_mode`, `layout_template`, `copies`, `dpi`, `silent_print`. Existing thermal columns stay.

**`print_jobs` (new):** `id`, `session_id`, `printer_id`, `status`, `attempts`, `error`, `created_at`, `updated_at`.

**`settings`:** remove Drive keys. Add Supabase URL, public key, bucket name, QR display time, local-only toggle, destination mode, per-tier destinations, retry count, and retry delay.

### Supabase (`photobooth` schema)

`kiosks` and `shares`, as created in step C5.

---

## Part 8: Implementation Phases

Phase 4 (storage) and phase 5 (printing) from the main plan are replaced by the phases below.

### Phase 4: Soft copy with Supabase

| Step | Task | Output |
|---|---|---|
| 4.0 | **Spike:** upload a test file from a Flutter app on Windows and Android with a signed token | Confirms `supabase_flutter` works on both |
| 4.1 | Back up the existing schema, check storage policies, and check exposed schemas (C1 to C4) | Safe starting point |
| 4.2 | Create the schema, tables, permissions, exposed schema, and bucket (C5 to C7) | Backend skeleton |
| 4.3 | Enable extensions, register a test kiosk, deploy the three functions (C8 to C11) | Working functions |
| 4.4 | Test the backend from PowerShell, including a refused public-key upload and the existing app check (C12) | Verified security |
| 4.5 | Build `SupabaseStorageProvider` and the compression step | App can upload |
| 4.6 | Upload queue, retries, and failure states | Reliable uploads |
| 4.7 | QR screen: loading, two tabs, thumbnail, timer, privacy line | Customer-facing flow |
| 4.8 | Schedule hourly cleanup and the kiosk startup fallback (C13) | Auto-deletion |
| 4.9 | Admin Supabase screen: config, test connection, usage view, config import | Setup tools |
| 4.10 | Remove Drive code, packages, settings, and docs | Clean codebase |

### Phase 5a: Thermal printing (unchanged)

Network, then USB, then Bluetooth. Paper width (80mm default), dithering, rotation, test print.

### Phase 5b: Document printing

| Step | Task |
|---|---|
| 5b.1 | Add `printing` and `pdf`, and confirm they build and run on Windows and Android |
| 5b.2 | Database changes: `printers` with `kind`, `print_jobs`, and the new settings |
| 5b.3 | Windows: list installed printers and let the admin pick one |
| 5b.4 | `DocumentRenderer`: PDF at the paper size with the image and footer |
| 5b.5 | Layout templates (single, rotated fill, two-up, full bleed) |
| 5b.6 | Windows silent printing to the saved printer |
| 5b.7 | Android system print dialog flow |
| 5b.8 | Admin screens: add, edit, preview, and test print for document printers |
| 5b.9 | `PrintService`, `PrintQueue`, retry logic |
| 5b.10 | Customer Print step and destination modes |
| 5b.11 | Print queue view, failed-job alerts, reprint |
| 5b.12 | Real-printer testing and tuning |

### Phase 5c: Integration

| Step | Task |
|---|---|
| 5c.1 | Run print and upload in parallel after editing, and confirm neither blocks the other |
| 5c.2 | Confirm the barcode ID printed on both printers matches the session ID in the log |
| 5c.3 | End-to-end tests for every mode, layout, and destination |
| 5c.4 | Packaging and kiosk setup (MSIX for Windows, APK or AAB for Android) |

---

## Part 9: Testing Plan

### Soft copy backend

- Valid and invalid kiosk keys (success and 401)
- A disabled kiosk is refused
- Direct upload with only the public key is refused
- Oversized files and wrong file types are refused by the bucket
- The daily cap returns an error after the limit
- Cleanup deletes files older than 7 days and does not touch newer files
- After cleanup, the old public URL no longer works
- Bucket listing is not possible with the public key
- **Your existing app still works** and its schema, policies, and buckets are unchanged

### Soft copy app

- Single, 3, 4, and 6 shot uploads (photo only, and photo plus GIF)
- QR opens the photo, and the GIF tab opens the GIF
- Wi-Fi off during upload, then back on (queue and retry)
- Upload interrupted halfway (photo done, GIF missing)
- Wrong kiosk key shows a clear error
- Local-only mode skips the QR screen
- Compressed files stay within the size targets

### Phones

- iPhone and several Android models scanning the on-screen QR with the default camera
- Photo saves correctly, and the GIF plays and saves
- Slow mobile data

### Document printing

- Test page on each target printer (paper size, orientation, margins, ruler border)
- Full-color strip on real photo paper (color, sharpness, crop)
- Each layout template on each paper size
- Single, 3, 4, and 6 shots in grid and row layouts
- Footer logo and barcode sharp and positioned correctly, and the printed barcode scans
- Copies greater than 1
- Windows: printer list loads, silent print works
- Android: system dialog opens and prints
- Printer unplugged mid-job, printer off then on (retry), several jobs sent quickly (order), kiosk idle for hours then print (printer wake-up), out of paper (visible to the admin)

### Combined flow

- Print and upload both running, with the QR screen showing while the print job is still going
- Each destination mode, and only one printer kind enabled
- No printers configured (digital-only output still works)
- No Supabase configured (print-only still works)
- Voucher tier matches the fixed destination for that tier

### Load and limits

- Upload a day's worth of test sessions and compare real storage and bandwidth use in the dashboard against the 1.5 MB average assumption

---

## Part 10: Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Free-tier storage or bandwidth exceeded (shared with your other app) | Uploads or links fail | Compress files, check usage weekly, upgrade to Pro if volume grows |
| Free project pauses after 7 idle days | Both apps unreachable until restored | Queue and retry, quiet-period check, a health ping (effect unverified) |
| A broad storage policy from your first app | Public roles might upload to the new bucket | Check policies in C3 before creating the bucket |
| Mistake while sharing the project | Damage to your first app's data | Backup first, separate schema, test the first app after each step |
| CLI migration history clashes | Failed deploys or schema drift | Run photobooth SQL in the dashboard, keep functions in a separate folder |
| `supabase_flutter` issues on Windows | No uploads from Windows kiosks | Phase 4.0 spike, with plain HTTP as a fallback |
| JWT check rejects the publishable key | Function calls return 401 | Use the legacy anon key, or deploy with JWT verification off and rely on the kiosk key |
| `pg_cron` unavailable on the plan | No scheduled cleanup | Kiosk startup call to `pb-cleanup-expired` |
| Orphaned files from SQL deletes | Storage fills up | Delete only through the Storage API |
| Public links shared further | Photos seen by others for 7 days | Unguessable paths, privacy line, short retention |
| Kiosk key extracted from a device | Someone can request upload tokens | Per-location keys, disable and rotate, daily cap |
| Android shows the print dialog | No fully automatic photo printing on Android | Use Windows for photo-printing kiosks |
| Android needs a print service | Printer not found | Add the manufacturer plugin or Mopria to the setup checklist |
| Borderless printing depends on the driver | White margins on photos | Test on the real printer, tune margins, `win32` only if needed |
| Printer status is unreliable | App thinks a job printed when it did not | Mark done on send, alert on failures, staff check paper and ink |
| Slow photo printing | Long wait, backed-up queue | Background printing, pre-render the PDF |
| Large PDFs | Memory use, slow generation | Resize to target DPI, render in an isolate |
| Ink and photo paper costs | Lower margin | Fixed-per-tier destinations, price tiers accordingly |
| Raw image view on phones | Saving a GIF is awkward | Test, and consider the optional viewer page on a static host |
| Pricing and limits change | Cost surprise | Re-check the pricing page before launch and every quarter |

---

## Part 11: Setup Checklists

### Supabase (once per project)

1. Back up the existing schema.
2. Check storage policies and exposed schemas.
3. Create the `photobooth` schema, tables, permissions, bucket, and extensions.
4. Add `photobooth` to the exposed schemas.
5. Deploy the three `pb-` functions and set the secrets.
6. Schedule the cleanup job (or plan the kiosk fallback).
7. Run the PowerShell tests and check that your existing app still works.

### Each location

1. Generate a kiosk key, store its hash in `photobooth.kiosks`, and keep the plain key safe.
2. In the kiosk admin screen, enter (or import) the Supabase URL, public key, bucket, location ID, and kiosk key.
3. Press **Test connection**.
4. Set the QR screen time and local-only toggle.

### Windows kiosk with a photo printer

1. Install the printer driver and confirm a test page prints from Windows.
2. Set the default paper size and quality in the printer preferences, and disable status pop-ups where possible.
3. In PhotoReceipt admin, add a document printer, pick it from the list, and set paper size and layout.
4. Run a test print, check margins and color, and set it as the default document printer.
5. Set the destination rules.

### Android device with a photo printer

1. Install the printer's print service (Mopria or the manufacturer plugin) and confirm it prints from another app.
2. In PhotoReceipt admin, add a document printer with "System print dialog."
3. Run a test print, choose the printer in the dialog, and check the result.
4. Train staff on the one-tap flow, or use a Windows kiosk if automatic printing is required.

### Thermal printer

Follow the thermal setup in `PhotoReceipt_Final_Plan.md`.

---

## Part 12: Open Questions

1. **Volume:** roughly how many sessions per day across all locations? This decides whether the free plan is enough, and your first app's current usage matters too.
2. **Region:** your existing project's region is already fixed. Is its latency acceptable for all locations?
3. **Quiet periods:** will any location sit unused for a week or longer? That can pause the project and affect your first app too.
4. **Print destination default:** customer chooses, fixed per tier, or fixed globally?
5. **Paper sizes:** which will you actually use (4×6, 5×7, A4)? This decides which layout templates to build first.
6. **Android photo printing:** does any location need fully automatic photo printing on Android? If yes, the design needs another approach (for example a network printer with direct IPP, or a small Windows PC as a print server).
7. **A4 two-up sheets:** will staff cut them, or should the app only print single-up pages?
8. **Viewer page:** do you want the optional download page on a free static host, or is opening the raw image fine for v1?
9. **QR screen items** (two tabs, thumbnail, loading state, extended timer, privacy line): do you approve them?
10. **Existing app:** what does your first app store in Supabase (size and traffic)? It shares quota and the pause risk with this one.

---

## Part 13: Summary of Changes to Other Plan Files

| File | Change |
|---|---|
| `PhotoReceipt_Final_Plan.md` | Replace section 5 (Drive) with Parts 2 to 4 of this file. Update tech stack, admin config, data model, risks, and phases. Replace the printing section with Part 5 |
| `PhotoReceipt_Supabase_Plan.md` | Superseded by this file (adds the shared-project setup, `photobooth` schema, `pb-` names, and full dashboard steps) |
| `PhotoReceipt_Document_Printer_Plan.md` | Superseded by Part 5 of this file |
