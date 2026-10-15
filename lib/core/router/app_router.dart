import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/attract/view/attract_screen.dart';
import '../../features/voucher/view/voucher_screen.dart';
import '../../features/capture/view/capture_screen.dart';
import '../../features/layout/view/layout_screen.dart';
import '../../features/editor/view/editor_screen.dart';
import '../../features/output/view/output_screen.dart';
import '../../features/output/view/qr_screen.dart';
import '../../features/output/view/thank_you_screen.dart';
import '../../features/admin/view/admin_screen.dart';
import '../../features/admin/view/first_run_screen.dart';
import '../../core/models/models.dart';

/// Fallback session used in debug mode if route extra is lost during hot reload/restart.
SessionModel _getFallbackSession() {
  final now = DateTime.now();
  return SessionModel(
    sessionId: 'DEV-${now.millisecondsSinceEpoch}',
    voucher: VoucherModel(
      code: 'DEV-DEMO',
      locationId: 'MNL1',
      shotMode: ShotMode.triple,
      serial: '0001',
      expiresAt: now.add(const Duration(hours: 24)),
      priceSnapshot: 80.0,
    ),
    shotMode: ShotMode.triple,
    createdAt: now,
  );
}

/// ─── Route Name Constants ───────────────────────────────────────────────────
/// Always use these constants when navigating — never hardcode path strings.
///
/// Navigation examples:
///   context.goNamed(AppRoute.attract);
///   context.goNamed(AppRoute.capture, extra: session);
///
class AppRoute {
  AppRoute._();

  static const String attract = 'attract'; // /
  static const String voucher = 'voucher'; // /voucher
  static const String capture = 'capture'; // /capture
  static const String layout = 'layout'; // /layout
  static const String editor = 'editor'; // /editor
  static const String output = 'output'; // /output
  static const String qr = 'qr'; // /qr
  static const String thankYou = 'thank-you'; // /thank-you
  static const String admin = 'admin'; // /admin
  static const String firstRun = 'first-run'; // /first-run
}

/// ─── Router Factory ─────────────────────────────────────────────────────────
///
/// Customer flow:
///   / → /voucher → /capture → /layout (skip if single) → /editor → /output → /qr → /
///
/// Admin flow:
///   Long-press logo → /admin (password gate) → admin sections
///
/// First-run:
///   / → /first-run (if no password set) → /admin → /
///
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // ── 1. Attract / Idle Screen ──────────────────────────────────────────
      GoRoute(
        path: '/',
        name: AppRoute.attract,
        builder: (context, state) => const AttractScreen(),
      ),

      // ── 2. Voucher Entry ──────────────────────────────────────────────────
      GoRoute(
        path: '/voucher',
        name: AppRoute.voucher,
        builder: (context, state) => const VoucherScreen(),
      ),

      // ── 3. Capture (camera / upload) ─────────────────────────────────────
      // Receives SessionModel via GoRouterState.extra
      GoRoute(
        path: '/capture',
        name: AppRoute.capture,
        redirect: (context, state) {
          if (kReleaseMode && state.extra is! SessionModel) return '/';
          return null;
        },
        builder: (context, state) {
          final session = state.extra is SessionModel ? state.extra as SessionModel : _getFallbackSession();
          return CaptureScreen(session: session);
        },
      ),

      // ── 4. Layout Selection ───────────────────────────────────────────────
      // Only shown for multi-shot modes (triple/quad/hex)
      GoRoute(
        path: '/layout',
        name: AppRoute.layout,
        redirect: (context, state) {
          if (kReleaseMode && state.extra is! SessionModel) return '/';
          return null;
        },
        builder: (context, state) {
          final session = state.extra is SessionModel ? state.extra as SessionModel : _getFallbackSession();
          return LayoutScreen(session: session);
        },
      ),

      // ── 5. Editor ────────────────────────────────────────────────────────
      GoRoute(
        path: '/editor',
        name: AppRoute.editor,
        redirect: (context, state) {
          if (kReleaseMode && state.extra is! SessionModel) return '/';
          return null;
        },
        builder: (context, state) {
          final session = state.extra is SessionModel ? state.extra as SessionModel : _getFallbackSession();
          return EditorScreen(session: session);
        },
      ),

      // ── 6. Output (save + print) ─────────────────────────────────────────
      GoRoute(
        path: '/output',
        name: AppRoute.output,
        redirect: (context, state) {
          if (kReleaseMode && state.extra is! SessionModel) return '/';
          return null;
        },
        builder: (context, state) {
          final session = state.extra is SessionModel ? state.extra as SessionModel : _getFallbackSession();
          return OutputScreen(session: session);
        },
      ),

      // ── 7. QR Screen (on-screen only, shown if Drive URL is available) ───
      GoRoute(
        path: '/qr',
        name: AppRoute.qr,
        redirect: (context, state) {
          if (kReleaseMode && state.extra is! QrScreenData) return '/';
          return null;
        },
        builder: (context, state) {
          final data = state.extra is QrScreenData
              ? state.extra as QrScreenData
              : const QrScreenData(
                  driveUrl: 'https://picnprint.app',
                  sessionId: 'DEV-DEMO',
                  displaySeconds: 60,
                );
          return QrScreen(data: data);
        },
      ),

      // ── 8. Thank You Screen (shown after printing/output) ────────────────
      GoRoute(
        path: '/thank-you',
        name: AppRoute.thankYou,
        builder: (context, state) {
          final sessionId = state.extra as String?;
          return ThankYouScreen(sessionId: sessionId);
        },
      ),

      // ── 9. First-Run Wizard ───────────────────────────────────────────────
      GoRoute(
        path: '/first-run',
        name: AppRoute.firstRun,
        builder: (context, state) => const FirstRunScreen(),
      ),

      // ── 10. Admin Panel ────────────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        name: AppRoute.admin,
        builder: (context, state) => const AdminScreen(),
      ),
    ],

    // ── Error fallback ────────────────────────────────────────────────────────
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.uri}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
}

/// Data passed to QrScreen via GoRouter extra.
class QrScreenData {
  final String driveUrl;
  final String sessionId;
  final int displaySeconds; // admin-configured display time

  const QrScreenData({
    required this.driveUrl,
    required this.sessionId,
    required this.displaySeconds,
  });
}
