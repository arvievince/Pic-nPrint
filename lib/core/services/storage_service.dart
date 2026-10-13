import 'dart:io';
import 'package:drift/drift.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../models/models.dart';

/// Handles local file saving, Google Drive upload, and 7-day rolling cleanup.
///
/// Flow (OutputBloc calls in sequence):
///   1. saveLocalFiles(session)   — copies composed image to permanent location
///   2. uploadToDrive(session)    — uploads to Drive, returns share URL
///   3. scheduleCleanup()         — cleans up files older than 7 days
///
/// Drive setup:
///   The admin provides a service account JSON key.
///   The Drive folder is shared with the service account email.
///   No interactive login is required.
///
class StorageService {
  final AppDatabase _db;

  StorageService(this._db);

  // ─── Local Save ───────────────────────────────────────────────────────────────

  /// Copies the composed image to a permanent location and updates the session DB entry.
  /// Also saves a copy to the device's public Pictures folder (Pictures/Pic-nPrint) so it is visible in Gallery/Photos.
  Future<String> saveLocalFiles(SessionModel session) async {
    final appDir = await getApplicationDocumentsDirectory();
    final destDir = Directory(p.join(appDir.path, 'output'));
    if (!destDir.existsSync()) destDir.createSync(recursive: true);

    final ext = (session.composedImagePath != null && p.extension(session.composedImagePath!).isNotEmpty)
        ? p.extension(session.composedImagePath!)
        : '.png';
    final destPath = p.join(destDir.path, '${session.sessionId}$ext');

    if (session.composedImagePath != null) {
      final src = File(session.composedImagePath!);
      if (src.existsSync()) {
        await src.copy(destPath);
        // Also save to public Pictures folder
        await _saveToPublicGallery(src, '${session.sessionId}$ext');
      }
    }

    // Persist in DB
    await _db.updateSession(
        session.sessionId,
        SessionsTableCompanion(
          composedImagePath: Value(destPath),
        ));

    return destPath;
  }

  /// Copies a finished photo to the device's public Pictures directory.
  Future<void> _saveToPublicGallery(File srcFile, String filename) async {
    try {
      Directory? targetDir;
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          targetDir = Directory(p.join(userProfile, 'Pictures', 'Pic-nPrint'));
        }
      } else if (Platform.isAndroid) {
        final publicPictures = Directory('/storage/emulated/0/Pictures/Pic-nPrint');
        if (publicPictures.parent.existsSync()) {
          targetDir = publicPictures;
        } else {
          final extDirs = await getExternalStorageDirectories(type: StorageDirectory.pictures);
          if (extDirs != null && extDirs.isNotEmpty) {
            targetDir = Directory(p.join(extDirs.first.path, 'Pic-nPrint'));
          }
        }
      }

      if (targetDir != null) {
        if (!targetDir.existsSync()) {
          await targetDir.create(recursive: true);
        }
        final publicFile = File(p.join(targetDir.path, filename));
        await srcFile.copy(publicFile.path);
      }
    } catch (_) {
      // Best-effort copy to public gallery: do not interrupt main kiosk workflow if denied
    }
  }

  // ─── Drive Upload ─────────────────────────────────────────────────────────────

  /// Uploads the composed image to Google Drive. Returns the public share URL.
  /// Throws [StorageException] if Drive is not configured or upload fails.
  Future<String> uploadToDrive(SessionModel session) async {
    if (session.composedImagePath == null) {
      throw StorageException('No composed image to upload.');
    }

    // Load Drive config from settings
    final folderName = await _db.getSetting('drive_folder_id');
    final serviceAccJson = await _db.getSetting('drive_service_account_json');

    if (folderName == null || serviceAccJson == null) {
      throw StorageException('Drive is not configured. Files saved locally only.');
    }

    final credentials = ServiceAccountCredentials.fromJson(serviceAccJson);
    final scopes = [drive.DriveApi.driveFileScope];

    final authClient = await clientViaServiceAccount(credentials, scopes);
    final driveApi = drive.DriveApi(authClient);

    try {
      final file = File(session.composedImagePath!);
      final ext = p.extension(session.composedImagePath!).isNotEmpty ? p.extension(session.composedImagePath!) : '.png';
      final media = drive.Media(file.openRead(), file.lengthSync());
      final driveFile = drive.File()
        ..name = '${session.sessionId}$ext'
        ..parents = [folderName];

      final uploaded = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );

      // Set permission: anyone with the link can view
      await driveApi.permissions.create(
        drive.Permission()
          ..role = 'reader'
          ..type = 'anyone',
        uploaded.id!,
      );

      final shareUrl = 'https://drive.google.com/file/d/${uploaded.id}/view';

      // Persist drive info in DB
      await _db.updateSession(
          session.sessionId,
          SessionsTableCompanion(
            driveFileId: Value(uploaded.id!),
            driveShareUrl: Value(shareUrl),
            isUploaded: const Value(true),
          ));

      return shareUrl;
    } finally {
      authClient.close();
    }
  }

  // ─── 7-Day Rolling Cleanup ────────────────────────────────────────────────────

  /// Deletes local files and Drive files older than 7 days.
  /// Called on app startup and every few hours (via timer in main.dart).
  Future<void> runCleanup() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final expiredSessions = await _db.getExpiredSessions(cutoff);

    if (expiredSessions.isEmpty) return;

    // Load Drive config for Drive deletions
    final serviceAccJson = await _db.getSetting('drive_service_account_json');
    drive.DriveApi? driveApi;
    http.Client? authClient;

    if (serviceAccJson != null) {
      final credentials = ServiceAccountCredentials.fromJson(serviceAccJson);
      authClient = await clientViaServiceAccount(credentials, [drive.DriveApi.driveFileScope]);
      driveApi = drive.DriveApi(authClient);
    }

    try {
      for (final session in expiredSessions) {
        // Delete local files
        _deleteFileIfExists(session.composedImagePath);
        _deleteFileIfExists(session.gifPath);
        for (final path in (session.localImagePaths).split(',')) {
          _deleteFileIfExists(path.trim());
        }

        // Delete Drive file (using stored file ID — only deletes what we created)
        if (driveApi != null && session.driveFileId != null) {
          try {
            await driveApi.files.delete(session.driveFileId!);
          } catch (_) {
            // Ignore — file may already be gone
          }
        }

        // Remove from DB
        await _db.deleteSession(session.sessionId);
      }
    } finally {
      authClient?.close();
    }
  }

  void _deleteFileIfExists(String? path) {
    if (path == null) return;
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  }
}

class StorageException implements Exception {
  final String message;
  StorageException(this.message);
  @override
  String toString() => message;
}
