import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/attract_bloc.dart';
import '../bloc/attract_event.dart';
import '../bloc/attract_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// The idle / attract screen — shown when no customer is using the kiosk.
///
/// Features:
///   - Full-screen animated background with slideshow.
///   - Configurable Polaroid photo cards scattered around the perimeter (shown when uploaded).
///   - "Tap anywhere to begin" prompt.
///   - Long-press on logo or top-right button → navigates to /admin.
///   - Tap anywhere → directly resets and navigates to /voucher or /tierSelect.
///
class AttractScreen extends StatefulWidget {
  const AttractScreen({super.key});

  @override
  State<AttractScreen> createState() => _AttractScreenState();
}

class _AttractScreenState extends State<AttractScreen> {
  String _title = 'Pic & Print';
  String _subtitle = 'Your memories, printed instantly.';
  String? _logoPath;
  String? _polaroid1Path;
  String? _polaroid2Path;
  String? _polaroid3Path;
  String? _polaroid4Path;
  bool _eventModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBranding();
    // Always reset the attract bloc to idle state when screen mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AttractBloc>().add(const AttractReset());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    try {
      final db = context.read<AppDatabase>();
      final title = await db.getSetting('kiosk_title');
      final subtitle = await db.getSetting('kiosk_subtitle');
      final logoPath = await db.getSetting('kiosk_logo_path');
      final eventMode = await db.getSetting('event_mode_enabled');
      final p1 = await db.getSetting('attract_polaroid_1_path');
      final p2 = await db.getSetting('attract_polaroid_2_path');
      final p3 = await db.getSetting('attract_polaroid_3_path');
      final p4 = await db.getSetting('attract_polaroid_4_path');

      if (mounted) {
        setState(() {
          if (title != null && title.trim().isNotEmpty) {
            _title = title.trim();
          }
          if (subtitle != null && subtitle.trim().isNotEmpty) {
            _subtitle = subtitle.trim();
          }
          if (logoPath != null &&
              logoPath.trim().isNotEmpty &&
              File(logoPath.trim()).existsSync()) {
            _logoPath = logoPath.trim();
          } else {
            _logoPath = null;
          }
          _polaroid1Path = (p1 != null &&
                  p1.trim().isNotEmpty &&
                  File(p1.trim()).existsSync())
              ? p1.trim()
              : null;
          _polaroid2Path = (p2 != null &&
                  p2.trim().isNotEmpty &&
                  File(p2.trim()).existsSync())
              ? p2.trim()
              : null;
          _polaroid3Path = (p3 != null &&
                  p3.trim().isNotEmpty &&
                  File(p3.trim()).existsSync())
              ? p3.trim()
              : null;
          _polaroid4Path = (p4 != null &&
                  p4.trim().isNotEmpty &&
                  File(p4.trim()).existsSync())
              ? p4.trim()
              : null;
          _eventModeEnabled = eventMode?.toLowerCase() == 'true';
        });
      }
    } catch (_) {}
  }

  void _onStartTap() {
    context.read<AttractBloc>().add(const AttractTapped());
    if (_eventModeEnabled) {
      context.goNamed(AppRoute.tierSelect);
    } else {
      context.goNamed(AppRoute.voucher);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AttractBloc, AttractState>(
      listener: (context, state) {
        if (state is AttractNavigating) {
          if (_eventModeEnabled) {
            context.goNamed(AppRoute.tierSelect);
          } else {
            context.goNamed(AppRoute.voucher);
          }
        }
      },
      child: BlocBuilder<AttractBloc, AttractState>(
        builder: (context, state) {
          final slideIndex = state is AttractIdle ? state.slideIndex : 0;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onStartTap,
            child: Scaffold(
              backgroundColor: AppColors.background,
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  final shortestSide = math.min(width, height);

                  // Responsive card dimension (standard 3:4 Polaroid aspect ratio)
                  final cardWidth = (shortestSide * 0.22).clamp(120.0, 220.0);
                  final cardHeight = cardWidth * 1.28;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // ── Background gradient (slideshow) ───────────────────────
                      // AnimatedContainer(
                      //   duration: const Duration(milliseconds: 800),
                      //   decoration: BoxDecoration(
                      //     gradient: LinearGradient(
                      //       begin: Alignment.topLeft,
                      //       end: Alignment.bottomRight,
                      //       colors: _slideColors(slideIndex),
                      //     ),
                      //   ),
                      // ),

                      // ── Overlay subtle vignette ────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.2,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.04),
                            ],
                          ),
                        ),
                      ),

                      // ── Floating Polaroid Photo Cards (shown only when uploaded) ──
                      // 1. Top-Left Polaroid (tilted -12°)
                      if (_polaroid1Path != null)
                        Positioned(
                          top: height * 0.08,
                          left: width * 0.08,
                          child: _PolaroidCard(
                            width: cardWidth,
                            height: cardHeight,
                            angleDegrees: -12.0,
                            imagePath: _polaroid1Path!,
                          ),
                        ),

                      // 2. Top-Right Polaroid (tilted +9°)
                      if (_polaroid2Path != null)
                        Positioned(
                          top: height * 0.12,
                          right: width * 0.09,
                          child: _PolaroidCard(
                            width: cardWidth,
                            height: cardHeight,
                            angleDegrees: 9.0,
                            imagePath: _polaroid2Path!,
                          ),
                        ),

                      // 3. Bottom-Left Polaroid (tilted -8°)
                      if (_polaroid3Path != null)
                        Positioned(
                          bottom: height * 0.14,
                          left: width * 0.09,
                          child: _PolaroidCard(
                            width: cardWidth,
                            height: cardHeight,
                            angleDegrees: -8.0,
                            imagePath: _polaroid3Path!,
                          ),
                        ),

                      // 4. Bottom-Right Polaroid (tilted +7°)
                      if (_polaroid4Path != null)
                        Positioned(
                          bottom: height * 0.10,
                          right: width * 0.08,
                          child: _PolaroidCard(
                            width: cardWidth,
                            height: cardHeight,
                            angleDegrees: 7.0,
                            imagePath: _polaroid4Path!,
                          ),
                        ),

                      // ── Center Branding & Logo ─────────────────────────────────
                      SafeArea(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo card — long-press opens admin
                              GestureDetector(
                                onLongPress: () =>
                                    context.goNamed(AppRoute.admin),
                                child: Container(
                                  width: 108,
                                  height: 108,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.08),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: _logoPath != null &&
                                          File(_logoPath!).existsSync()
                                      ? Image.file(
                                          File(_logoPath!),
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.camera_alt_outlined,
                                            size: 50,
                                            color: AppColors.onBackground,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt_outlined,
                                          size: 50,
                                          color: AppColors.onBackground,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _title != '' ? _title : 'Pic & Print',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onBackground,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _subtitle != ''
                                    ? _subtitle
                                    : 'Strike a pose. Take home a print.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: AppColors.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Bottom "Tap to start" Action ───────────────────────────
                      Positioned(
                        bottom: height * 0.08,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _TapToBeginPulse(onTap: _onStartTap),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  List<Color> _slideColors(int index) {
    const palettes = [
      [Color(0xFFEFF2FE), Color(0xFFE0E7FF)],
      [Color(0xFFE0F2FE), Color(0xFFF0FDF4)],
      [Color(0xFFFEF3C7), Color(0xFFFCE7F3)],
      [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
      [Color(0xFFFDF4FF), Color(0xFFEFF6FF)],
    ];
    return palettes[index % palettes.length];
  }
}

/// A realistic, rotated Polaroid card widget.
class _PolaroidCard extends StatelessWidget {
  final double width;
  final double height;
  final double angleDegrees;
  final String imagePath;

  const _PolaroidCard({
    required this.width,
    required this.height,
    required this.angleDegrees,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final double rad = angleDegrees * (math.pi / 180.0);
    final double innerPadding = width * 0.065;
    final double bottomPadding =
        width * 0.22; // Classic thick Polaroid bottom chin

    return Transform.rotate(
      angle: rad,
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.fromLTRB(
          innerPadding,
          innerPadding,
          innerPadding,
          bottomPadding,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(width * 0.04),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(width * 0.02),
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Pulsing "Tap anywhere to begin" widget.
class _TapToBeginPulse extends StatefulWidget {
  final VoidCallback? onTap;
  const _TapToBeginPulse({this.onTap});

  @override
  State<_TapToBeginPulse> createState() => _TapToBeginPulseState();
}

class _TapToBeginPulseState extends State<_TapToBeginPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: AppColors.onBackground,
            boxShadow: [
              BoxShadow(
                color: AppColors.onBackground.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tap to start',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
