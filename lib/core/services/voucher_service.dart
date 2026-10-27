import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/models.dart';

/// Handles voucher generation, validation, and redemption.
///
/// Voucher format: LOC-T-SERIAL-CHK
///   LOC    = location ID (e.g. MNL1)
///   T      = tier char  (S/T/F/X)
///   SERIAL = zero-padded 5-digit serial
///   CHK    = 4-char HMAC-SHA256 derived checksum (uppercase hex)
///
/// Flow:
///   VoucherScreen → VoucherBloc.VoucherSubmitted
///     → VoucherService.validate(code)
///       → checks format, location, HMAC sig, expiry, used status
///     → returns VoucherModel on success
///
///   AdminScreen (cashier mode) → AdminBloc.GenerateVoucher
///     → VoucherService.generateVoucher(locationId, mode)
///
class VoucherService {
  final AppDatabase _db;

  VoucherService(this._db);

  // ─── Validate a customer-entered code ────────────────────────────────────────

  /// Validates and (if valid) marks the voucher as [VoucherStatus.used].
  /// Returns [VoucherModel] on success, throws [VoucherException] on failure.
  Future<VoucherModel> redeemVoucher(String rawCode) async {
    final code = rawCode.trim().toUpperCase();

    // 1. Format check
    final parts = code.split('-');
    if (parts.length != 4) throw VoucherException('Invalid format.');

    final locationId = parts[0];
    final tierChar   = parts[1];
    final serial     = parts[2];
    final checksum   = parts[3];

    // 2. Location match
    final configuredLocation = await _db.getSetting('location_id') ?? '';
    if (locationId != configuredLocation) {
      throw VoucherException('This code is not for this location.');
    }

    // 3. HMAC signature check
    final secret = await _db.getSetting('voucher_secret') ?? '';
    final expectedCheck = _computeChecksum(locationId, tierChar, serial, secret);
    if (checksum != expectedCheck) {
      throw VoucherException('Invalid code. Please check and try again.');
    }

    // 4. Database lookup
    final entry = await _db.getVoucher(code);
    if (entry == null) throw VoucherException('Code not found. It may not have been issued yet.');

    // 5. Status checks
    if (entry.status == 1) throw VoucherException('This code has already been used.');
    if (entry.status == 2) throw VoucherException('This code has been voided.');
    if (entry.expiresAt.isBefore(DateTime.now())) {
      throw VoucherException('This code has expired.');
    }

    // 6. Redeem (mark as used = 1) and record sale
    final now = DateTime.now();
    await _db.updateVoucherStatus(code, 1, redeemedAt: now);
    await _db.insertSale(SalesTableCompanion(
      code: Value(code),
      locationId: Value(locationId),
      tierChar: Value(tierChar),
      serial: Value(serial),
      priceSnapshot: Value(entry.priceSnapshot),
      status: const Value(1),
      expiresAt: Value(entry.expiresAt),
      createdAt: Value(entry.createdAt),
      redeemedAt: Value(now),
    ));

    return VoucherModel(
      code: code,
      locationId: locationId,
      shotMode: ShotModeExtension.fromTierChar(tierChar),
      serial: serial,
      expiresAt: entry.expiresAt,
      priceSnapshot: entry.priceSnapshot,
    );
  }

  /// Generates and persists a voucher for [mode].
  /// Returns the complete [VoucherModel].
  Future<VoucherModel> generateVoucher({
    required ShotMode mode,
    double? priceSnapshot,
    DateTime? expiresAt,
  }) async {
    final locationId = await _db.getSetting('location_id') ?? 'MNL1';
    final secret     = await _db.getSetting('voucher_secret') ?? '';
    final defaultPrice = double.tryParse(await _db.getSetting('price_${mode.tierChar}') ?? '') ??
        (mode == ShotMode.single
            ? 50.0
            : mode == ShotMode.triple
                ? 80.0
                : mode == ShotMode.quad
                    ? 100.0
                    : 120.0);
    final finalPrice = priceSnapshot ?? defaultPrice;
    final finalExpiry = expiresAt ?? DateTime.now().add(const Duration(days: 1));

    // Get next serial by counting existing vouchers for this location
    final all = await _db.getAllVouchers();
    final nextSerial = (all.length + 1).toString().padLeft(5, '0');

    final tierChar = mode.tierChar;
    final checksum = _computeChecksum(locationId, tierChar, nextSerial, secret);
    final code = '$locationId-$tierChar-$nextSerial-$checksum';

    await _db.insertVoucher(VouchersTableCompanion(
      code: Value(code),
      locationId: Value(locationId),
      tierChar: Value(tierChar),
      serial: Value(nextSerial),
      priceSnapshot: Value(finalPrice),
      status: const Value(0),
      expiresAt: Value(finalExpiry),
      createdAt: Value(DateTime.now()),
    ));

    return VoucherModel(
      code: code,
      locationId: locationId,
      shotMode: mode,
      serial: nextSerial,
      expiresAt: finalExpiry,
      priceSnapshot: finalPrice,
    );
  }

  /// Generate a batch of vouchers. Returns the list of created [VoucherModel]s.
  Future<List<VoucherModel>> generateBatch({
    required ShotMode mode,
    required int count,
    double? priceSnapshot,
    DateTime? expiresAt,
  }) async {
    final vouchers = <VoucherModel>[];
    for (int i = 0; i < count; i++) {
      final v = await generateVoucher(
        mode: mode,
        priceSnapshot: priceSnapshot,
        expiresAt: expiresAt,
      );
      vouchers.add(v);
    }
    return vouchers;
  }

  // ─── Void / reissue ───────────────────────────────────────────────────────────

  Future<void> voidVoucher(String code, String reason) =>
      _db.updateVoucherStatus(code, 2, voidReason: reason);

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  /// Computes a 4-char uppercase HMAC-SHA256 checksum.
  /// Input = "LOC-T-SERIAL" signed with [secret].
  String _computeChecksum(String loc, String tier, String serial, String secret) {
    final payload = '$loc-$tier-$serial';
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(payload));
    // Take the first 4 hex chars (16-bit) — short but sufficient for offline check
    return digest.toString().substring(0, 4).toUpperCase();
  }
}

/// Thrown by [VoucherService] when a code is invalid or cannot be redeemed.
class VoucherException implements Exception {
  final String message;
  VoucherException(this.message);
  @override
  String toString() => message;
}
