# PhotoReceipt: Final Development Plan (v1)

**Platforms:** Windows and Android (Flutter)
**Model:** Standalone kiosks per location, no backend, no subscriptions

---

## 1. Customer Flow

**Attract screen (tap to begin)** → **Enter voucher code** → **Take Photo or Upload** → **Choose layout** (mode is set by the voucher) → **Countdown capture** (or pick images) → **Edit** (emoji/stickers, borders, text) → **Save, upload, print** → **QR screen (on-screen only)** → back to attract screen

---

## 2. Shot Modes and Layouts

| Mode | Layout options |
|---|---|
| Single | One photo, no layout choice |
| 3 shots | Horizontal row only |
| 4 shots | Side by side (2×2 grid) or horizontal row |
| 6 shots | Side by side (3×2 grid) or horizontal row |

- **Take photo:** a countdown runs before each shot. The admin sets the countdown seconds and the gap between shots.
- **Upload image:** the user picks 1, 3, 4, or 6 images to fill the same layout.
- **GIF:** created for 4 and 6 shots, with a configurable frame delay.
- **Print rotation:** a wide horizontal row can look small on 80mm paper, so the print renderer can rotate the strip 90° to use the paper length. The admin can turn this off.

---

## 3. Editor

- Add emojis/stickers (drag, scale, rotate, delete).
- Choose a border.
- Add text: edit, move, resize, and set font, size, and color.
- The preview uses the same widget that is exported, so what the user sees is what prints.

---

## 4. Footer of the Image and Print

Every saved image and print ends with a footer containing:

- Store/event logo (or the default PhotoReceipt logo)
- Session-ID barcode (Code128), for example `MNL1-241009-0042`

**Notes:**

- The QR code is **not** printed or embedded in the image. It is shown on screen only.
- The barcode is for your own tracking (finding a session in the log). Scanning it does **not** open the image. Making the barcode open the image needs the short-link feature (see Later Options).
- The barcode ID is short (about 16 characters), so it scans reliably on both 80mm and 58mm paper.

---

## 5. Storage, Drive, and QR Screen

### Saving and upload

1. The final image (and GIF, when applicable) is saved locally.
2. If a Drive folder is configured, the kiosk uploads the file, sets "anyone with the link can view," and builds the QR from the share link.
3. If no Drive folder is set, files stay local only and the QR screen is skipped.
4. If an upload fails, it is queued and retried. The admin chooses whether to print without waiting for the upload.

### QR screen (on-screen only)

- Large QR code that opens the image on Drive.
- Text: "Scan to get your photo. Link valid for 7 days."
- Auto-return timer (admin setting, default 60 seconds), then back to the attract screen. A "Done" button lets the customer leave sooner.
- Printing starts right after capture and editing, so the customer can scan the QR while the receipt prints.
- The customer cannot return to the QR afterward.

### Rolling 7-day cleanup

- Each session stores its `created_at`.
- The app checks on startup and every few hours, and deletes any local file and Drive file older than 7 days.
- The cleanup uses Drive file IDs from the database, so only files created by the app are touched.
- After deletion, an old QR shows Drive's "file not found" page.

### Drive setup

- Use a **service account**. The admin shares the Drive folder with the service account's email, so no interactive login is needed.
- Each location uses its own subfolder (for example `PhotoReceipt/MNL1/`).

---

## 6. Printing

- The final strip is rendered as an image and printed as a raster bitmap, which is more reliable than separate text commands.
- **Paper width** is configurable per printer: **80mm default** (576 dots) or 58mm (384 dots).
- **Transports:**
  - Network: raw TCP to port 9100 (Android and Windows)
  - USB: Windows spooler raw printing, or USB host on Android
  - Bluetooth: well supported on Android, limited on Windows (use USB or network there)
- **Multiple printers:** add, edit, remove, test print, and set a default.
- Photos are dithered (Floyd–Steinberg) for good black-and-white output.

---

## 7. Payment: Tier-Locked Vouchers

**Code format:** `LOC-T-SERIAL-CHK`, for example `MNL1-F-00042-A7K9`

| Part | Meaning |
|---|---|
| `MNL1` | Location ID |
| `S / T / F / X` | Single / 3 shots / 4 shots / 6 shots |
| `00042` | Serial number |
| `A7K9` | HMAC checksum, verified offline with the location's secret |

**Rules:**

- The voucher stores the **tier**, not the price, so later price changes do not break old codes. The sales log records the price at redemption.
- Each code works once and expires at a configurable time (for example, end of day).
- Validation checks the location, signature, expiry, and used status. Repeated wrong entries trigger a lockout.
- When a code is entered, the app skips mode selection and goes to the paid tier. The customer still chooses the layout, stickers, and borders.
- Vouchers are bound to the kiosk that issued them, so there is no cross-location double-use problem.

**How the cashier issues vouchers (v1):**

- **Cashier mode on the kiosk:** unlocked with the admin password, the cashier taps a tier and gets a code.
- **Printable voucher batches:** the admin generates a batch (for example 50 Single and 50 4-shot) and prints them as slips on the thermal printer. The cashier hands one out after payment.
- **Reconciliation:** the sales report compares slips issued against slips redeemed by serial number.
- **Void and reissue:** a voucher can be voided, or reissued with a logged reason if a session failed.

---

## 8. Multi-Location Setup (Standalone Kiosks)

Each kiosk has its own:

- Location ID and voucher secret (set in a first-run wizard)
- Prices (locations can charge differently)
- Drive subfolder, logo, printers, and attract screen
- Admin password (bcrypt hash)
- Sales log

Sales logs can be exported and merged in a spreadsheet. Central reporting is a later option.

---

## 9. Admin Configuration

Opened by a hidden gesture (for example, long-press on the logo) and protected by a bcrypt-hashed admin password, with a lockout after repeated failures. The first-run wizard creates the password.

1. **Pricing:** price per mode (Single, 3, 4, 6)
2. **Counter:** countdown seconds and gap between shots
3. **Stickers/Emojis:** add and remove
4. **Borders:** add and remove
5. **Printers:** add multiple (Bluetooth, USB, network), edit, remove, test print, set default, paper width
6. **Drive:** folder, service-account credentials, connection test (local-only if not set)
7. **Branding:** app logo (top of screen) and print logo, with the default PhotoReceipt fallback
8. **Attract screen:** background images, adjustments, prompt text
9. **QR screen:** show or skip, display time in seconds
10. **Vouchers and sales:** cashier mode, batch generation and printing, void, sales log export
11. **Data:** manual cleanup, secret rotation

---

## 10. Tech Stack

| Area | Package |
|---|---|
| State / navigation | `flutter_riverpod`, `go_router` |
| Camera | `camera` + `camera_windows` |
| Permissions | `permission_handler` (Windows uses OS privacy settings) |
| Upload from device | `image_picker` / `file_picker` |
| Compositing and GIF | `image` + `RepaintBoundary`, run in `compute()` isolates |
| QR and barcode | `qr_flutter`, `barcode` |
| Drive | `googleapis` + `googleapis_auth` (service account) |
| Printing | `esc_pos_utils_plus` + network / USB / Bluetooth transports |
| Admin password | `bcrypt` + `flutter_secure_storage` |
| Local data | `drift` (SQLite) |
| Cleanup | `workmanager` (Android), Timer + startup check (Windows) |

All of these are free. The only possible cost is extra Drive storage beyond the free 15 GB, which the 7-day cleanup should prevent.

---

## 11. Architecture

Feature-first folders: `attract/`, `voucher/`, `capture/`, `editor/`, `output/` (save, QR, print), `admin/`, `core/` (db, drive, printing, security).

Key services:

- **PricingService:** price per mode from settings
- **VoucherService:** generate, validate, redeem
- **CompositionService:** builds the final image and GIF
- **StorageService:** local save, Drive upload, cleanup
- **PrinterService:** abstraction over Bluetooth, USB, and network

---

## 12. Data Model

`settings` · `prices` · `assets` (sticker/border) · `printers` · `vouchers` (serial, tier, status, price_snapshot, timestamps) · `sessions` (session_id, voucher, mode, layout, local paths, drive_file_id, created_at) · `admin_auth`

---

## 13. Development Phases

| Phase | Scope |
|---|---|
| 1 | Project setup, navigation, DB, first-run wizard (location ID, admin password), attract screen |
| 2 | Camera, permissions, countdown, modes, layouts, upload option |
| 3 | Editor (stickers, borders, text), composition, GIF, footer with logo and barcode |
| 4 | Local save, Drive upload, on-screen QR screen with timer, rolling 7-day cleanup |
| 5 | Printing (network, then USB, then Bluetooth), multiple printers, paper width |
| 6 | Tier-locked vouchers, cashier mode, voucher batches, sales log |
| 7 | Admin polish, branding, real-device testing, packaging (MSIX for Windows, APK/AAB for Android) |

### Later options (not in v1)

- Short link (Supabase or Firebase plus a short domain) so the barcode opens the image
- Central vouchers and combined reports across locations
- Separate cashier device
- Cashless payment (GCash/Maya)
- Reprint or lookup by barcode scan

---

## 14. Risks to Test Early

- **Windows camera:** test `camera_windows` with your actual webcam.
- **Bluetooth printing on Windows:** may not work with your printer, so plan on USB or network there.
- **Thermal print quality:** test dithering on your actual printer.
- **Rotated strip printing:** check the 90° rotation on 80mm and 58mm paper.
- **Barcode scanning:** test-scan the printed barcode from the receipt.
- **QR scan time:** confirm the on-screen QR is large and bright enough to scan from a phone, and that the timer gives enough time.
- **GIF size:** limit resolution and frame count to keep uploads fast.
- **Kiosk lockdown:** on Windows, use kiosk or assigned-access mode so customers cannot leave the app.
- **Voucher slips:** reconcile slips issued against the sales log regularly.
- **Missing digital copy:** the printed receipt has no link to the digital copy, so a customer who skips the on-screen QR cannot get it. You can find the file through the session log using the barcode ID until the short-link feature exists.
