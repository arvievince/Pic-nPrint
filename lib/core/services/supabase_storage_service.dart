import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../database/app_database.dart';
import '../models/models.dart';

// ─── Upload result ──────────────────────────────────────────────────────────

class SupabaseUploadResult {
  final String photoUrl;
  final String? gifUrl;

  const SupabaseUploadResult({
    required this.photoUrl,
    this.gifUrl,
  });
}

// ─── Service ────────────────────────────────────────────────────────────────

/// Uploads photos (and optional GIFs) to Supabase Storage via signed URLs
/// obtained from the `pb-create-upload` Edge Function.
///
/// Design constraints:
///   - The service role key **never** leaves the server.
///   - The app only holds the anon (public) key and the kiosk's location key.
///   - Signed upload tokens are short-lived and issued per session.
///   - All uploads happen through these signed tokens — direct uploads are blocked.
///
class SupabaseStorageService {
  final AppDatabase _db;

  SupabaseStorageService(this._db);

  /// Bucket used by the Edge Functions when no `supabase_bucket` setting exists.
  static const String defaultBucket = 'photobooth-photos';

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Generates a random, secure 32-character hex key suitable for kiosk credentials.
  static String generateRandomKioskKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Register or update a kiosk in Supabase automatically from the admin screen.
  /// Eliminates the need to manually write SQL queries in the Supabase Dashboard.
  /// Returns null on success, or an error message string on failure.
  Future<String?> registerKiosk({
    required String projectUrl,
    required String anonKey,
    required String locationId,
    required String kioskKey,
    String? setupToken,
  }) async {
    final cleanUrl = _normalizeProjectUrl(projectUrl);
    if (cleanUrl.isEmpty) return 'Project URL is required';
    if (anonKey.trim().isEmpty) return 'Anon / publishable key is required';
    final cleanLoc = locationId.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{2,8}$').hasMatch(cleanLoc)) {
      return 'Location ID must be 2–8 uppercase letters/numbers (e.g. QC, MNL1)';
    }
    final cleanKey = kioskKey.trim();
    if (cleanKey.length < 8) {
      return 'Kiosk key must be at least 8 characters long';
    }

    try {
      final response = await http
          .post(
            Uri.parse('$cleanUrl/functions/v1/pb-register-kiosk'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${anonKey.trim()}',
            },
            body: jsonEncode({
              'location_id': cleanLoc,
              'kiosk_key': cleanKey,
              if (setupToken != null && setupToken.trim().isNotEmpty)
                'setup_token': setupToken.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['ok'] == true) {
        return null; // Success
      }
      return body['error']?.toString() ??
          'Registration failed (HTTP ${response.statusCode})';
    } on SocketException {
      return 'No internet connection';
    } catch (e) {
      return 'Registration error: $e';
    }
  }

  /// Test whether the Supabase backend is reachable and the kiosk key is valid.
  /// Returns the error message, or null if the connection is healthy.
  Future<String?> testConnection() async {
    final config = await _loadConfig();
    if (config == null) return 'Supabase not configured';
    return _testConnection(config);
  }

  /// Test values straight from the admin form, before they are saved.
  Future<String?> testConnectionWith({
    required String projectUrl,
    required String anonKey,
    required String locationId,
    required String kioskKey,
  }) {
    return _testConnection(_SupabaseConfig(
      projectUrl: _normalizeProjectUrl(projectUrl),
      anonKey: anonKey.trim(),
      locationId:
          locationId.trim().toUpperCase(), // regex requires ^[A-Z0-9]{2,8}$
      kioskKey: kioskKey.trim(),
      bucket: defaultBucket,
    ));
  }

  Future<String?> _testConnection(_SupabaseConfig config) async {
    if (config.projectUrl.isEmpty) return 'Project URL is required';
    if (!config.projectUrl.startsWith('http://') &&
        !config.projectUrl.startsWith('https://')) {
      return 'Project URL must start with https://';
    }
    if (config.anonKey.isEmpty) return 'Anon / publishable key is required';
    if (config.locationId.isEmpty) return 'Location ID is required';
    if (config.kioskKey.isEmpty) return 'Kiosk key is required';

    try {
      final response = await http
          .post(
            Uri.parse('${config.projectUrl}/functions/v1/pb-healthcheck'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.anonKey}',
            },
            body: jsonEncode({
              'location_id': config.locationId,
              'kiosk_key': config.kioskKey,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) return null; // healthy
        return 'Server returned ok=false';
      }
      if (response.statusCode == 401) {
        final bodyText = response.body.trim();
        if (bodyText.contains('Invalid JWT') || bodyText.contains('jwt')) {
          return 'Unauthorized (Invalid Anon/Publishable Key): $bodyText';
        }
        return 'Unauthorized (HTTP 401): $bodyText — check kiosk key, location ID, or kiosk row in DB';
      }
      return 'Server error (HTTP ${response.statusCode})';
    } on SocketException {
      return 'No internet connection';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  /// Compress and upload the composed photo (and optional GIF) for [session].
  ///
  /// Returns [SupabaseUploadResult] with public URLs on success.
  /// Throws [SupabaseStorageException] on failure.
  Future<SupabaseUploadResult> uploadSession(SessionModel session) async {
    final config = await _loadConfig();
    if (config == null) {
      throw SupabaseStorageException('Supabase is not configured');
    }

    // 1. Generate a random, unguessable session token for the storage path.
    //    This is intentionally separate from the barcode session ID.
    final token = _generateToken();

    // 2. Determine which files to upload
    final hasGif = session.gifPath != null &&
        File(session.gifPath!).existsSync() &&
        _shouldUploadGif(session.shotMode);
    final files = hasGif ? ['photo', 'gif'] : ['photo'];

    // 3. Ask the Edge Function for signed upload URLs
    final uploads = await _requestSignedUrls(
      config: config,
      sessionToken: token,
      files: files,
    );

    // 4. Compress and upload photo
    final compressedPhoto = await _compressPhoto(session.composedImagePath!);
    await _uploadFile(
      uploadUrl: _signedUploadUrl(config, uploads['photo']!['path'] as String),
      token: uploads['photo']!['token'] as String,
      bytes: compressedPhoto,
      contentType: 'image/jpeg',
    );
    final photoUrl = uploads['photo']!['url'] as String;

    // 5. Upload GIF if applicable
    String? gifUrl;
    if (hasGif && uploads.containsKey('gif')) {
      final gifBytes = await File(session.gifPath!).readAsBytes();
      await _uploadFile(
        uploadUrl: _signedUploadUrl(config, uploads['gif']!['path'] as String),
        token: uploads['gif']!['token'] as String,
        bytes: gifBytes,
        contentType: 'image/gif',
      );
      gifUrl = uploads['gif']!['url'] as String;
    }

    // 6. Persist to local DB
    await _db.updateSession(
      session.sessionId,
      SessionsTableCompanion(
        sessionToken: Value(token),
        photoUrl: Value(photoUrl),
        gifUrl: Value(gifUrl),
        uploadStatus: const Value('done'),
        isUploaded: const Value(true),
        expiresAt: Value(DateTime.now().add(const Duration(days: 7))),
      ),
    );

    return SupabaseUploadResult(photoUrl: photoUrl, gifUrl: gifUrl);
  }

  /// Trigger the server-side cleanup function (deletes files older than 7 days).
  /// Called on app start and optionally on a periodic timer.
  Future<void> runCleanup() async {
    try {
      final config = await _loadConfig();
      if (config == null) return;

      await http
          .post(
            Uri.parse('${config.projectUrl}/functions/v1/pb-cleanup-expired'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.anonKey}',
            },
            body: jsonEncode({
              'location_id': config.locationId,
              'kiosk_key': config.kioskKey,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Best-effort — cleanup failures are non-critical
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  Future<_SupabaseConfig?> _loadConfig() async {
    final projectUrl = await _db.getSetting('supabase_url');
    final anonKey = await _db.getSetting('supabase_anon_key');
    final locationId = await _db.getSetting('supabase_location_id');
    final kioskKey = await _db.getSetting('supabase_kiosk_key');
    final bucket = await _db.getSetting('supabase_bucket');

    if (projectUrl == null ||
        projectUrl.isEmpty ||
        anonKey == null ||
        anonKey.isEmpty ||
        locationId == null ||
        locationId.isEmpty ||
        kioskKey == null ||
        kioskKey.isEmpty) {
      return null;
    }

    return _SupabaseConfig(
      projectUrl: _normalizeProjectUrl(projectUrl),
      anonKey: anonKey.trim(),
      locationId:
          locationId.trim().toUpperCase(), // regex requires ^[A-Z0-9]{2,8}$
      kioskKey: kioskKey.trim(),
      bucket: (bucket == null || bucket.trim().isEmpty)
          ? defaultBucket
          : bucket.trim(),
    );
  }

  String _normalizeProjectUrl(String url) =>
      url.trim().replaceAll(RegExp(r'/+$'), '');

  /// Builds the signed-upload endpoint. Supabase expects the bucket to be part
  /// of the path: `/storage/v1/object/upload/sign/{bucket}/{objectPath}`.
  String _signedUploadUrl(_SupabaseConfig config, String objectPath) {
    final cleanPath =
        objectPath.startsWith('/') ? objectPath.substring(1) : objectPath;
    return '${config.projectUrl}/storage/v1/object/upload/sign/'
        '${config.bucket}/$cleanPath';
  }

  Future<Map<String, Map<String, dynamic>>> _requestSignedUrls({
    required _SupabaseConfig config,
    required String sessionToken,
    required List<String> files,
  }) async {
    final response = await http
        .post(
          Uri.parse('${config.projectUrl}/functions/v1/pb-create-upload'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config.anonKey}',
          },
          body: jsonEncode({
            'location_id': config.locationId,
            'kiosk_key': config.kioskKey,
            'session_token': sessionToken,
            'files': files,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 401) {
      throw SupabaseStorageException('Kiosk key rejected (HTTP 401)');
    }
    if (response.statusCode != 200) {
      throw SupabaseStorageException(
          'Sign URL failed (HTTP ${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final uploadsRaw = body['uploads'] as Map<String, dynamic>;
    return uploadsRaw.map(
      (key, val) => MapEntry(key, Map<String, dynamic>.from(val as Map)),
    );
  }

  Future<void> _uploadFile({
    required String uploadUrl,
    required String token,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uri = Uri.parse(uploadUrl).replace(
      queryParameters: {'token': token},
    );

    final response = await http
        .put(
          uri,
          headers: {
            'Content-Type': contentType,
            'x-upsert': 'true',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw SupabaseStorageException(
          'Upload failed (HTTP ${response.statusCode}): ${response.body}');
    }
  }

  /// Compress the composed photo for web viewing.
  /// Target: JPEG, max 1080px on the long edge, quality ~82, aiming for <600 KB.
  Future<Uint8List> _compressPhoto(String imagePath) async {
    return compute(_compressPhotoIsolate, imagePath);
  }

  static Uint8List _compressPhotoIsolate(String imagePath) {
    final bytes = File(imagePath).readAsBytesSync();
    final src = img.decodeImage(bytes);
    if (src == null) return Uint8List.fromList(bytes);

    // Resize so the long edge is at most 1080 px
    const maxEdge = 1080;
    img.Image resized;
    if (src.width >= src.height && src.width > maxEdge) {
      resized = img.copyResize(src, width: maxEdge, maintainAspect: true);
    } else if (src.height > src.width && src.height > maxEdge) {
      resized = img.copyResize(src, height: maxEdge, maintainAspect: true);
    } else {
      resized = src;
    }

    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  /// Generates a URL-safe random token (32 lowercase hex chars).
  String _generateToken() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// GIF uploads are for Quad, Hex, and Octa modes (matching CompositionService).
  bool _shouldUploadGif(ShotMode mode) =>
      mode == ShotMode.quad || mode == ShotMode.hex || mode == ShotMode.octa;
}

// ─── Internal config model ───────────────────────────────────────────────────

class _SupabaseConfig {
  final String projectUrl;
  final String anonKey;
  final String locationId;
  final String kioskKey;
  final String bucket;

  const _SupabaseConfig({
    required this.projectUrl,
    required this.anonKey,
    required this.locationId,
    required this.kioskKey,
    required this.bucket,
  });
}

// ─── Exception ───────────────────────────────────────────────────────────────

class SupabaseStorageException implements Exception {
  final String message;
  SupabaseStorageException(this.message);

  @override
  String toString() => 'SupabaseStorageException: $message';
}
