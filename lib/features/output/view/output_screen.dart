import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../bloc/output_bloc.dart';
import '../bloc/output_event.dart';
import '../bloc/output_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/models.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Animated kiosk printing screen — shows the photo sliding down from a printer slot,
/// displays live printing status, and transitions to softcopy QR download upon completion.
class OutputScreen extends StatefulWidget {
  final SessionModel session;
  const OutputScreen({super.key, required this.session});

  @override
  State<OutputScreen> createState() => _OutputScreenState();
}

class _OutputScreenState extends State<OutputScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ejectController;
  late final Animation<double> _ejectAnimation;

  String? _logoPath;
  String _brandTitle = 'PicnPrint';
  int _qrTimeoutSeconds = 60;
  int _countdownRemaining = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    // 3.5s smooth easing curve for the photo ejection animation
    _ejectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _ejectAnimation = CurvedAnimation(
      parent: _ejectController,
      curve: Curves.easeOutCubic,
    );

    _ejectController.forward();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = context.read<AppDatabase>();
    final logo = await db.getSetting('kiosk_logo_path');
    final title = await db.getSetting('kiosk_title');
    final timeoutStr = await db.getSetting('drive_qr_timeout_seconds');

    if (mounted) {
      setState(() {
        if (logo != null &&
            logo.trim().isNotEmpty &&
            File(logo.trim()).existsSync()) {
          _logoPath = logo.trim();
        }
        if (title != null && title.trim().isNotEmpty) {
          _brandTitle = title.trim();
        }
        if (timeoutStr != null) {
          _qrTimeoutSeconds = int.tryParse(timeoutStr.trim()) ?? 60;
          _countdownRemaining = _qrTimeoutSeconds;
        }
      });
    }
  }

  void _startReadyCountdown() {
    _countdownTimer?.cancel();
    _countdownRemaining = _qrTimeoutSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownRemaining <= 1) {
        timer.cancel();
        _finishSession();
      } else {
        setState(() => _countdownRemaining--);
      }
    });
  }

  void _finishSession() {
    _countdownTimer?.cancel();
    if (mounted) {
      context.goNamed(AppRoute.attract);
    }
  }

  @override
  void dispose() {
    _ejectController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OutputBloc(
        storageService: context.read(),
        printerService: context.read(),
        db: context.read(),
        session: widget.session,
      ),
      child: BlocConsumer<OutputBloc, OutputState>(
        listener: (context, state) {
          if (state is OutputComplete) {
            _startReadyCountdown();
          }
        },
        builder: (context, state) {
          final isReady = state is OutputComplete;

          return Scaffold(
            backgroundColor:
                const Color(0xFFF8F6F0), // Warm Lightmode Background
            body: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),

                        // ── 1. Top Status Pill ───────────────────────────────
                        _StatusPill(
                          isReady: isReady,
                          logoPath: _logoPath,
                          brandTitle: _brandTitle,
                        ),

                        // const SizedBox(height: 14),

                        // ── 2. Printer Dispenser & Animated Photo Ejection ───
                        Expanded(
                          flex: 10,
                          child: _PrinterDispenserArea(
                            session: widget.session,
                            ejectAnimation: _ejectAnimation,
                            logoPath: _logoPath,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── 3. Bottom Animated Section (Printing vs QR Code) ─
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: state is OutputComplete
                              ? _ReadyBottomSection(
                                  key: const ValueKey('ready_section'),
                                  driveUrl: state.driveUrl,
                                  countdown: _countdownRemaining,
                                  onFinish: _finishSession,
                                )
                              : _PrintingBottomSection(
                                  key: const ValueKey('printing_section'),
                                  state: state,
                                  onRetryUpload: () => context
                                      .read<OutputBloc>()
                                      .add(const UploadRetried()),
                                  onRetryPrint: () => context
                                      .read<OutputBloc>()
                                      .add(const PrintRequested()),
                                  onSkipHome: _finishSession,
                                ),
                        ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Top Status Pill ─────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final bool isReady;
  final String? logoPath;
  final String brandTitle;

  const _StatusPill({
    required this.isReady,
    this.logoPath,
    required this.brandTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF212120), // Charcoal pill container
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Glowing status dot + Label
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: isReady
                      ? const Color(0xFF52C41A) // Ready green
                      : const Color(0xFFF5A623), // Printing amber
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isReady
                              ? const Color(0xFF52C41A)
                              : const Color(0xFFF5A623))
                          .withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isReady ? 'READY' : 'PRINTING',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),

          // Right: Brand Logo or Text
          if (logoPath != null && File(logoPath!).existsSync())
            Image.file(
              File(logoPath!),
              height: 24,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            )
          else
            Text(
              brandTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.6,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Printer Dispenser & Ejection Area ───────────────────────────────────────

class _PrinterDispenserArea extends StatelessWidget {
  final SessionModel session;
  final Animation<double> ejectAnimation;
  final String? logoPath;

  const _PrinterDispenserArea({
    required this.session,
    required this.ejectAnimation,
    this.logoPath,
  });

  double _getCardAspectRatio(SessionModel session) {
    final paths = session.imagePaths;
    if (paths.length <= 1) return 3 / 4;
    final layout = session.layout ??
        (paths.length == 4
            ? LayoutType.grid2x2
            : paths.length == 6
                ? LayoutType.grid2x3
                : paths.length >= 8
                    ? LayoutType.grid2x4
                    : LayoutType.verticalStrip);

    switch (layout) {
      case LayoutType.single:
        return 3 / 4;
      case LayoutType.verticalStrip:
        return paths.length == 2
            ? 2 / 3
            : (paths.length >= 3 ? 1 / 2.2 : 9 / 16);
      case LayoutType.horizontalRow:
        return paths.length >= 3 ? 16 / 10 : 4 / 3;
      case LayoutType.grid2x2:
        return 1.0;
      case LayoutType.grid2x3:
        return 2 / 3;
      case LayoutType.grid2x4:
        return 1 / 2;
      case LayoutType.bento:
        return paths.length >= 7 ? 1 / 2 : 2 / 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = session.composedImagePath ??
        (session.imagePaths.isNotEmpty ? session.imagePaths.first : null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        final targetRatio = _getCardAspectRatio(session);

        // Bounded card height responsive to viewport
        final cardHeight = (availableHeight * 0.60).clamp(260.0, 380.0);
        // Width derived directly from the layout's aspect ratio without arbitrary wide clamp
        final cardWidth =
            (cardHeight * targetRatio).clamp(110.0, availableWidth * 0.85);
        final slotWidth = cardWidth + 24.0;
        const restingOffset = 20.0;
        final areaHeight = cardHeight + restingOffset + 36.0;
        final areaWidth = cardWidth + 48.0;

        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // ── Photo Card Emerging from Slot ──
            Positioned(
              top: 6,
              width: areaWidth,
              height: areaHeight,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: ejectAnimation,
                  builder: (context, child) {
                    final startOffset = -cardHeight;
                    final currentOffset = startOffset +
                        (restingOffset - startOffset) * ejectAnimation.value;

                    return Transform.translate(
                      offset: Offset(0, currentOffset),
                      child: child,
                    );
                  },
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: cardWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 22,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildPhotoImage(imagePath),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Physical Printer Slot / Slit (Renders in front of emerging photo) ──
            Positioned(
              top: 1,
              child: Container(
                width: slotWidth,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF141312),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: cardWidth + 8,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhotoImage(String? path) {
    if (path == null) {
      return Container(
        color: const Color(0xFFF3F1EC),
        child: const Center(
          child: Icon(Icons.photo_rounded, size: 48, color: Colors.black26),
        ),
      );
    }

    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFF3F1EC),
          child: const Center(
            child: Icon(Icons.broken_image_rounded,
                size: 40, color: Colors.black26),
          ),
        ),
      );
    }

    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFF3F1EC),
        child: const Center(
          child: Icon(Icons.photo_rounded, size: 40, color: Colors.black26),
        ),
      ),
    );
  }
}

// ─── State 1: Printing Bottom Section ────────────────────────────────────────

class _PrintingBottomSection extends StatelessWidget {
  final OutputState state;
  final VoidCallback onRetryUpload;
  final VoidCallback onRetryPrint;
  final VoidCallback onSkipHome;

  const _PrintingBottomSection({
    super.key,
    required this.state,
    required this.onRetryUpload,
    required this.onRetryPrint,
    required this.onSkipHome,
  });

  @override
  Widget build(BuildContext context) {
    final isUploadFailed = state is OutputUploadFailed;
    final isPrintFailed = state is OutputPrintFailed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isUploadFailed || isPrintFailed) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isUploadFailed
                        ? 'Cloud upload failed: ${(state as OutputUploadFailed).error}'
                        : 'Printing error: ${(state as OutputPrintFailed).error}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isUploadFailed ? onRetryUpload : onRetryPrint,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Retry'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onSkipHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ] else ...[
          // Animated Orange Progress Indicator Bar
          Container(
            width: double.infinity,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE6E2D8),
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: const LinearProgressIndicator(
                backgroundColor: Color(0xFFE6E2D8),
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.black), // Vibrant coral
                minHeight: 5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          const Text(
            'Printing your photos...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1E1E),
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 6),

          // Subtitle
          const Text(
            'Grab your print from the slot',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF757575),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── State 2: Ready & Softcopy QR Bottom Section ─────────────────────────────

class _ReadyBottomSection extends StatelessWidget {
  final String? driveUrl;
  final int countdown;
  final VoidCallback onFinish;

  const _ReadyBottomSection({
    super.key,
    this.driveUrl,
    required this.countdown,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    if (driveUrl != null && driveUrl!.trim().isNotEmpty) {
      // ── Drive Configured: QR Softcopy Card + Instructions + Finish Button ──
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE8E5DD), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Clean QR Code in rounded sub-card
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF9F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4E0D6)),
              ),
              child: QrImageView(
                data: driveUrl!,
                size: 96,
                backgroundColor: Colors.transparent,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1A1A1A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Right: Softcopy instructions + Finish button
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan for your softcopy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Open your phone camera and point it at the code.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: onFinish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black, // Vibrant coral
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Finish', //$countdown
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                  fontSize: 20,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Drive NOT Configured: Clean Ready Confirmation + Finish Button ──
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 250,
          height: 60,
          child: ElevatedButton(
            onPressed: onFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            child: Text(
              'Finish', //($countdown s)
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.50,
                    fontSize: 16,
                    color: Colors.white,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
