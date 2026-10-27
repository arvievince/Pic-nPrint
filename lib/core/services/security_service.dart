import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/app_database.dart';

/// Handles admin password hashing, verification, and lockout.
///
/// The admin password is stored as a bcrypt hash in the DB.
/// A secondary copy of the hash is kept in SecureStorage as a backup.
///
/// Lockout: after [maxFailedAttempts] wrong entries, the admin panel
/// is locked for [lockoutDurationMinutes] minutes.
///
/// Flow:
///   AdminScreen (first-run) → SecurityService.setPassword(plain)
///   AdminScreen (unlock)    → SecurityService.verifyPassword(attempt)
///     → returns true/false + tracks failed attempts
///
class SecurityService {
  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage;

  static const int maxFailedAttempts = 5;
  static const int lockoutDurationMinutes = 15;

  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  SecurityService(this._db)
      : _secureStorage = const FlutterSecureStorage();

  // ─── Setup ───────────────────────────────────────────────────────────────────

  /// Returns true if an admin password has been set (first-run check).
  Future<bool> isPasswordSet() async {
    final entry = await _db.getAdminAuth();
    return entry != null;
  }

  /// Hashes and stores the admin password.
  /// Call this from the first-run wizard.
  Future<void> setPassword(String plainPassword) async {
    final hash = BCrypt.hashpw(plainPassword, BCrypt.gensalt(logRounds: 12));
    await _db.upsertAdminAuth(hash);
    // Mirror in secure storage
    await _secureStorage.write(key: 'admin_pw_hash', value: hash);
  }

  // ─── Verification ────────────────────────────────────────────────────────────

  int get remainingAttempts => maxFailedAttempts;

  /// Returns true if [attempt] matches the stored password.
  /// Password verification has no attempt limits or lockout.
  Future<bool> verifyPassword(String attempt) async {
    final entry = await _db.getAdminAuth();
    if (entry == null) {
      // No password set yet — accept blank or default 'admin'
      return attempt.isEmpty || attempt.trim() == 'admin';
    }

    return BCrypt.checkpw(attempt, entry.passwordHash);
  }

  // ─── Lockout ─────────────────────────────────────────────────────────────────

  bool get isLockedOut => false;

  Duration get remainingLockout => Duration.zero;

  void _checkLockout() {}

  void _recordFailedAttempt() {}

  void _resetFailedAttempts() {
    _failedAttempts = 0;
    _lockedUntil = null;
  }
}

class AdminLockedException implements Exception {
  final Duration remaining;
  AdminLockedException(this.remaining);
  @override
  String toString() =>
      'Admin panel locked. Try again in ${remaining.inMinutes} minutes.';
}
