import 'dart:io';
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
///   - "Tap anywhere to begin" prompt.
///   - Long-press on logo or top-right button → navigates to /admin.
///   - Tap anywhere → directly resets and navigates to /voucher.
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
              body: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Background gradient (slideshow) ─────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _slideColors(slideIndex),
                      ),
                    ),
                  ),

                  // ── Overlay dark vignette ───────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),

                  // ── Content ─────────────────────────────────────────────────
                  SafeArea(
                    child: Stack(
                      children: [
                        // // Top-right Admin button
                        // Align(
                        //   alignment: Alignment.topRight,
                        //   child: Padding(
                        //     padding: const EdgeInsets.all(16.0),
                        //     child: IconButton(
                        //       icon: const Icon(
                        //         Icons.admin_panel_settings_rounded,
                        //         color: Colors.white60,
                        //         size: 30,
                        //       ),
                        //       tooltip: 'Admin Panel',
                        //       onPressed: () => context.goNamed(AppRoute.admin),
                        //     ),
                        //   ),
                        // ),

                        // Center content
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo — long-press opens admin
                              Column(
                                children: [
                                  GestureDetector(
                                    onLongPress: () =>
                                        context.goNamed(AppRoute.admin),
                                    child: Container(
                                      width: 200,
                                      height: 200,
                                      // decoration: BoxDecoration(
                                      //   color: AppColors.surface.withValues(
                                      //     alpha: 0.8,
                                      //   ),
                                      //   borderRadius: BorderRadius.circular(24),
                                      //   boxShadow: [
                                      //     BoxShadow(
                                      //       color: AppColors.primary.withValues(
                                      //         alpha: 0.4,
                                      //       ),
                                      //       blurRadius: 30,
                                      //       spreadRadius: 5,
                                      //     ),
                                      //   ],
                                      // ),
                                      child: _logoPath != null &&
                                              File(_logoPath!).existsSync()
                                          ? Image.file(
                                              File(_logoPath!),
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                Icons.camera_alt_rounded,
                                                size: 60,
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.camera_alt_rounded,
                                              size: 60,
                                              color: AppColors.primary,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _title != '' ? _title : '',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _subtitle != ''
                                        ? _subtitle
                                        : 'Strike a pose. Take home a print.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 100),

                              // Tap-to-start pulse animation
                              _TapToBeginPulse(onTap: _onStartTap),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Color> _slideColors(int index) {
    const palettes = [
      [Color(0xFF6C63FF), Color(0xFF0F0F1A)],
      [Color(0xFF1A1A3E), Color(0xFF6C63FF)],
      [Color(0xFF0F1A2E), Color(0xFF4A44CC)],
      [Color(0xFF1E0F2E), Color(0xFF9C27B0)],
      [Color(0xFF0F2E1E), Color(0xFF4CAF7D)],
    ];
    return palettes[index % palettes.length];
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
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(40),
            color: Colors.black,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tap to start',
                // style: TextStyle(
                //   color: Colors.white,
                //   fontSize: 24,
                //   fontWeight: FontWeight.w800,
                //   letterSpacing: 1.2,
                // ),
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
