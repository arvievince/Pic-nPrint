import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Screen shown between the Attract screen and Tier Selection when
/// [color_printing_enabled] is ON.
///
/// The customer chooses one of two modes:
///   • Full Color Photo Print  → isColorPrint = true
///   • Classic B&W Thermal     → isColorPrint = false
///
/// The choice is forwarded via [GoRouter] `extra` as a [ColorModeArgs] to
/// [TierSelectionScreen] → [VoucherScreen] → [OutputBloc] for final routing.
class ColorModeSelectionScreen extends StatefulWidget {
  const ColorModeSelectionScreen({super.key});

  @override
  State<ColorModeSelectionScreen> createState() =>
      _ColorModeSelectionScreenState();
}

class _ColorModeSelectionScreenState extends State<ColorModeSelectionScreen>
    with SingleTickerProviderStateMixin {
  static const _timeoutSeconds = 30;
  int _remaining = _timeoutSeconds;
  Timer? _countdownTimer;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining--;
      });
      if (_remaining <= 0) {
        t.cancel();
        if (mounted) context.goNamed(AppRoute.attract);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _selectMode(bool isColorPrint) {
    _countdownTimer?.cancel();
    context.goNamed(
      AppRoute.tierSelect,
      extra: ColorModeArgs(isColorPrint: isColorPrint),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Column(
                children: [
                  // ── Header ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
                    child: Column(
                      children: [
                        Text(
                          'Choose Your Print Style',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: isWide ? 42 : 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onBackground,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Select how you want your photo printed.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.onSurface,
                                fontSize: 16,
                              ),
                        ),
                        const SizedBox(height: 8),
                        // Countdown chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined,
                                  size: 14, color: AppColors.onSurface),
                              const SizedBox(width: 6),
                              Text(
                                'Returns to start in $_remaining s',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Mode Cards ────────────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: isWide
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                    child: _ModeCard(
                                  isColor: true,
                                  onTap: () => _selectMode(true),
                                )),
                                const SizedBox(width: 24),
                                Expanded(
                                    child: _ModeCard(
                                  isColor: false,
                                  onTap: () => _selectMode(false),
                                )),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                    child: _ModeCard(
                                  isColor: true,
                                  onTap: () => _selectMode(true),
                                )),
                                const SizedBox(height: 20),
                                Expanded(
                                    child: _ModeCard(
                                  isColor: false,
                                  onTap: () => _selectMode(false),
                                )),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Mode Selection Card ──────────────────────────────────────────────────────

class _ModeCard extends StatefulWidget {
  final bool isColor;
  final VoidCallback onTap;

  const _ModeCard({required this.isColor, required this.onTap});

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isColor = widget.isColor;

    final Color cardBg = isColor
        ? const Color(0xFF2A1A0A) // deep warm espresso for color
        : AppColors.surface;

    final Color borderColor = isColor
        ? AppColors.primary
        : Colors.white24;

    final Color accentColor = isColor ? AppColors.primary : Colors.grey[400]!;

    final IconData icon = isColor
        ? Icons.palette_rounded
        : Icons.receipt_long_rounded;

    final String title =
        isColor ? 'Full Color Photo Print' : 'Black & White Receipt';

    final String subtitle = isColor
        ? 'High-resolution color print on photo or document paper.'
        : 'Classic thermal receipt print in black & white.';

    final String badge =
        isColor ? 'Document / Color Printer' : 'Thermal Receipt Printer';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.diagonal3Values(
            _hovered ? 1.025 : 1.0,
            _hovered ? 1.025 : 1.0,
            1.0,
          ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hovered ? accentColor : borderColor,
              width: _hovered ? 2.5 : 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon circle
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: accentColor.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Icon(icon, color: accentColor, size: 36),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: accentColor.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isColor ? Icons.print_rounded : Icons.receipt_rounded,
                        size: 14,
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        badge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Select button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: isColor
                          ? AppColors.onPrimary
                          : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: widget.onTap,
                    child: Text(
                      'Select',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Arguments passed from [ColorModeSelectionScreen] to [TierSelectionScreen].
class ColorModeArgs {
  final bool isColorPrint;
  const ColorModeArgs({required this.isColorPrint});
}

