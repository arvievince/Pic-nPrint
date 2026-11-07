import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;

import '../../../core/database/app_database.dart';
import '../../../core/models/models.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/responsive.dart';

/// Shown in Event Mode instead of VoucherScreen.
///
/// The customer picks a shot tier (Single / 3 / 4 / 6 shots).
/// A voucherless [SessionModel] is created and passed forward.
///
/// Admin configures which tiers are visible via `event_mode_tiers` (CSV, e.g. "S,D,T,F,X,O")
/// and whether prices are shown via `event_mode_price_display`.
class TierSelectionScreen extends StatefulWidget {
  const TierSelectionScreen({super.key});

  @override
  State<TierSelectionScreen> createState() => _TierSelectionScreenState();
}

class _TierSelectionScreenState extends State<TierSelectionScreen> {
  static const int _timeoutSeconds = 60;
  int _remainingSeconds = _timeoutSeconds;
  Timer? _timer;
  String? _logoPath;
  String? _title;

  List<_TierOption> _tiers = [];
  bool _loading = true;
  bool _showPrice = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadTiers();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        _onTimeout();
      }
    });
  }

  void _resetTimer() {
    if (_remainingSeconds != _timeoutSeconds) {
      setState(() => _remainingSeconds = _timeoutSeconds);
    }
    _startTimer();
  }

  void _onTimeout() {
    _timer?.cancel();
    if (mounted) {
      context.goNamed(AppRoute.attract);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTiers() async {
    try {
      final db = context.read<AppDatabase>();

      // Load admin settings
      final tiersRaw = await db.getSetting('event_mode_tiers') ?? 'S,D,T,F,X,O';
      final showPriceRaw =
          await db.getSetting('event_mode_price_display') ?? 'true';
      final logoPath = await db.getSetting('kiosk_logo_path');
      final title = await db.getSetting('kiosk_title');
      final allPrices = await db.getAllPrices();

      final priceMap = {for (final p in allPrices) p.tierChar: p.price};
      final enabledChars = tiersRaw
          .split(',')
          .map((c) => c.trim().toUpperCase())
          .where((c) => c.isNotEmpty)
          .toList();

      final tierOptions = <_TierOption>[];
      for (final char in enabledChars) {
        try {
          final mode = ShotModeExtension.fromTierChar(char);
          // Fallback to settings-based prices if PricesTable row missing
          double? price = priceMap[char];
          tierOptions.add(_TierOption(mode: mode, price: price));
        } catch (_) {
          // Unknown char — skip
        }
      }

      if (!mounted) return;

      // If exactly 1 tier is enabled, skip selection and navigate directly.
      if (tierOptions.length == 1) {
        _navigateWithTier(tierOptions.first);
        return;
      }

      setState(() {
        _tiers = tierOptions;
        _showPrice = showPriceRaw.toLowerCase() == 'true';
        if (logoPath != null && logoPath.trim().isNotEmpty) {
          final trimmed = logoPath.trim();
          if (trimmed.startsWith('assets/') || File(trimmed).existsSync()) {
            _logoPath = trimmed;
          } else {
            _logoPath = null;
          }
        } else {
          _logoPath = null;
        }
        if (title != null && title.trim().isNotEmpty) {
          _title = title.trim();
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _tiers = ShotMode.values
              .map((m) => _TierOption(mode: m, price: null))
              .toList();
          _loading = false;
        });
      }
    }
  }

  void _navigateWithTier(_TierOption tier) {
    _timer?.cancel();
    final session = _buildEventSession(tier);
    if (session.shotMode.photoCount == 1) {
      context.goNamed(AppRoute.capture, extra: session);
    } else {
      context.goNamed(AppRoute.layout, extra: session);
    }
  }

  /// Builds a voucherless [SessionModel] for Event Mode.
  /// Session ID format: EVT-YYMMDD-HHMMSS
  SessionModel _buildEventSession(_TierOption tier) {
    final now = DateTime.now();
    final date = '${now.year.toString().substring(2)}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final time = '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final sessionId = 'EVT-$date-$time';

    final voucher = VoucherModel(
      code: 'EVT-MODE',
      locationId: 'EVT',
      shotMode: tier.mode,
      serial: '0000',
      expiresAt: now.add(const Duration(days: 3650)), // ~10 years — no expiry
      priceSnapshot: tier.price ?? 0.0,
    );

    return SessionModel(
      sessionId: sessionId,
      voucher: voucher,
      shotMode: tier.mode,
      createdAt: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6F0),
        elevation: 0,
        title: SizedBox(
          height: 38,
          child: _logoPath != null
              ? (_logoPath!.startsWith('assets/')
                  ? Image.asset(
                      _logoPath!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildFallbackTitle(),
                    )
                  : (File(_logoPath!).existsSync()
                      ? Image.file(
                          File(_logoPath!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _buildFallbackTitle(),
                        )
                      : _buildFallbackTitle()))
              : _buildFallbackTitle(),
        ),
        centerTitle: true,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back_ios_new_rounded),
        //   onPressed: () {
        //     _timer?.cancel();
        //     context.goNamed(AppRoute.attract);
        //   },
        // ),
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 16),
        //     child: Center(
        //       child: Container(
        //         padding:
        //             const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        //         decoration: BoxDecoration(
        //           color: AppColors.surfaceVariant,
        //           borderRadius: BorderRadius.circular(16),
        //         ),
        //         child: Row(
        //           mainAxisSize: MainAxisSize.min,
        //           children: [
        //             const Icon(
        //               Icons.timer_outlined,
        //               size: 16,
        //               color: AppColors.onSurface,
        //             ),
        //             const SizedBox(width: 4),
        //             Text(
        //               '${_remainingSeconds}s',
        //               style: GoogleFonts.bricolageGrotesque(
        //                 fontSize: 13,
        //                 fontWeight: FontWeight.w600,
        //                 color: AppColors.onSurface,
        //               ),
        //             ),
        //           ],
        //         ),
        //       ),
        //     ),
        //   ),
        // ],
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _resetTimer(),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _tiers.isEmpty
                ? _EmptyTiersView(
                    onBack: () {
                      _timer?.cancel();
                      context.goNamed(AppRoute.attract);
                    },
                  )
                : _TierGrid(
                    tiers: _tiers,
                    showPrice: _showPrice,
                    onSelect: _navigateWithTier,
                  ),
      ),
    );
  }

  Widget _buildFallbackTitle() {
    return Text(
      _title ?? 'Pic’n’Slip',
      style: GoogleFonts.bricolageGrotesque(
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

// ─── Tier Grid ────────────────────────────────────────────────────────────────

class _TierGrid extends StatelessWidget {
  final List<_TierOption> tiers;
  final bool showPrice;
  final ValueChanged<_TierOption> onSelect;

  const _TierGrid({
    required this.tiers,
    required this.showPrice,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        final screenType = Responsive.fromWidth(availableWidth);

        // ── Responsive Header Typography & Spacing ──
        final double titleFontSize = switch (screenType) {
          ScreenType.compact => (availableWidth * 0.08).clamp(24.0, 32.0),
          ScreenType.medium => 38.0,
          ScreenType.expanded => 48.0,
          ScreenType.large => 56.0,
        };

        final double subtitleFontSize = switch (screenType) {
          ScreenType.compact => 13.0,
          ScreenType.medium => 15.0,
          ScreenType.expanded => 17.0,
          ScreenType.large => 19.0,
        };

        final double headerTopGap = switch (screenType) {
          ScreenType.compact => 8.0,
          ScreenType.medium => 14.0,
          _ => 20.0,
        };

        final double headerBottomGap = switch (screenType) {
          ScreenType.compact => 10.0,
          ScreenType.medium => 14.0,
          _ => 18.0,
        };

        // ── Responsive Grid Settings ──
        final int count = tiers.length;
        final int crossAxisCount = _calculateCrossAxisCount(
          width: availableWidth,
          tierCount: count,
          screenType: screenType,
        );

        final double spacing = switch (screenType) {
          ScreenType.compact => 12.0,
          ScreenType.medium => 16.0,
          _ => 20.0,
        };

        final double childAspectRatio = switch (screenType) {
          ScreenType.compact => 0.68,
          ScreenType.medium => 0.70,
          _ => 0.72,
        };

        final double targetCardWidth = switch (screenType) {
          ScreenType.compact =>
            (availableWidth / crossAxisCount - spacing).clamp(130.0, 240.0),
          ScreenType.medium => 260.0,
          ScreenType.expanded => 300.0,
          ScreenType.large => 340.0,
        };

        final double maxContentWidth = (crossAxisCount * targetCardWidth +
                (crossAxisCount - 1) * spacing)
            .clamp(
                280.0, availableWidth - (screenType.isCompact ? 24.0 : 40.0));

        final int rows = (count / crossAxisCount).ceil();
        final double cardHeight = targetCardWidth / childAspectRatio;
        final double requiredGridHeight =
            (rows * cardHeight) + ((rows - 1) * spacing) + 48;
        // On compact/small screens or when height is constrained, make cards scrollable
        final bool shouldScroll = screenType.isCompact ||
            availableHeight < requiredGridHeight ||
            rows > 2 ||
            availableHeight < 720;

        return Column(
          children: [
            SizedBox(height: headerTopGap),
            // ── Top Title Block ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose your tier',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          fontSize: titleFontSize,
                          color: const Color(0xFF111827),
                          height: 1.1,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How many shots do you want to take?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                          fontSize: subtitleFontSize,
                          height: 1.2,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(height: headerBottomGap),

            // ── Responsive Cards Area ──────────────────────────────────────────
            Expanded(
              child: shouldScroll
                  ? Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            screenType.isCompact ? 16 : 20,
                            8,
                            screenType.isCompact ? 16 : 20,
                            40,
                          ),
                          // physics: const BouncingScrollPhysics(
                          //   parent: AlwaysScrollableScrollPhysics(),
                          // ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: spacing,
                            crossAxisSpacing: spacing,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: tiers.length,
                          itemBuilder: (context, i) => _TierPolaroidCard(
                            tier: tiers[i],
                            showPrice: showPrice,
                            screenType: screenType,
                            onTap: () => onSelect(tiers[i]),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                            maxHeight: (availableHeight - 16)
                                .clamp(180.0, double.infinity),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenType.isCompact ? 16 : 20,
                              vertical: 8,
                            ),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: spacing,
                                crossAxisSpacing: spacing,
                                childAspectRatio: childAspectRatio,
                              ),
                              itemCount: tiers.length,
                              itemBuilder: (context, i) => _TierPolaroidCard(
                                tier: tiers[i],
                                showPrice: showPrice,
                                screenType: screenType,
                                onTap: () => onSelect(tiers[i]),
                              ),
                            ),
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

  static int _calculateCrossAxisCount({
    required double width,
    required int tierCount,
    required ScreenType screenType,
  }) {
    if (tierCount <= 1) return 1;
    return 2;
  }
}

// ─── Tier Polaroid Card ───────────────────────────────────────────────────────

class _TierPolaroidCard extends StatefulWidget {
  final _TierOption tier;
  final bool showPrice;
  final VoidCallback onTap;
  final ScreenType screenType;

  const _TierPolaroidCard({
    required this.tier,
    required this.showPrice,
    required this.onTap,
    this.screenType = ScreenType.expanded,
  });

  @override
  State<_TierPolaroidCard> createState() => _TierPolaroidCardState();
}

class _TierPolaroidCardState extends State<_TierPolaroidCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.reverse();
  void _onTapUp(TapUpDetails _) {
    _ctrl.forward();
    widget.onTap();
  }

  void _onTapCancel() => _ctrl.forward();

  @override
  Widget build(BuildContext context) {
    final mode = widget.tier.mode;
    final count = mode.photoCount;
    final pastelBg = _getPastelColor(mode);

    // ── Responsive Dimensions & Typography per Card ──
    final double cardPadding = switch (widget.screenType) {
      ScreenType.compact => 10.0,
      ScreenType.medium => 12.0,
      ScreenType.expanded => 14.0,
      ScreenType.large => 16.0,
    };

    final double cardRadius = switch (widget.screenType) {
      ScreenType.compact => 18.0,
      ScreenType.medium => 20.0,
      ScreenType.expanded => 24.0,
      ScreenType.large => 28.0,
    };

    final double previewRadius = switch (widget.screenType) {
      ScreenType.compact => 14.0,
      _ => 18.0,
    };

    final double numberSize = switch (widget.screenType) {
      ScreenType.compact => 22.0,
      ScreenType.medium => 24.0,
      ScreenType.expanded => 26.0,
      ScreenType.large => 30.0,
    };

    final double unitSize = switch (widget.screenType) {
      ScreenType.compact => 12.0,
      ScreenType.medium => 13.0,
      ScreenType.expanded => 14.0,
      ScreenType.large => 16.0,
    };

    final double labelSize = switch (widget.screenType) {
      ScreenType.compact => 15.0,
      ScreenType.medium => 16.0,
      ScreenType.expanded => 18.0,
      ScreenType.large => 20.0,
    };

    final double descSize = switch (widget.screenType) {
      ScreenType.compact => 11.0,
      ScreenType.medium => 11.5,
      ScreenType.expanded => 12.5,
      ScreenType.large => 14.0,
    };

    final double priceSize = switch (widget.screenType) {
      ScreenType.compact => 11.0,
      ScreenType.medium => 11.5,
      ScreenType.expanded => 12.5,
      ScreenType.large => 14.0,
    };

    final double stripScale = switch (widget.screenType) {
      ScreenType.compact => 1.05,
      ScreenType.medium => 1.15,
      ScreenType.expanded => 1.25,
      ScreenType.large => 1.35,
    };

    final double gapBetweenPreviewAndText = switch (widget.screenType) {
      ScreenType.compact => 8.0,
      ScreenType.medium => 10.0,
      _ => 12.0,
    };

    return ScaleTransition(
      scale: _scale,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(
                color: _isHovered
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFE5E5E5),
                width: _isHovered ? 2.0 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? Colors.black.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: _isHovered ? 20 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Pastel Preview Box with Floating Strip ───────
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: pastelBg,
                      borderRadius: BorderRadius.circular(previewRadius),
                    ),
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: stripScale,
                      child: _TierStripVisual(mode: mode),
                    ),
                  ),
                ),
                SizedBox(height: gapBetweenPreviewAndText),

                // ── Lower Info Block ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Number + 'shot'/'shots'
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$count',
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: numberSize,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF111827),
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            count == 1 ? 'shot' : 'shots',
                            style: TextStyle(
                              fontSize: unitSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Mode Label
                      Text(
                        mode.label,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: labelSize,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Subtitle
                      Text(
                        _getTierSubtitle(mode),
                        style: TextStyle(
                          fontSize: descSize,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Price (if enabled)
                      if (widget.showPrice && widget.tier.price != null) ...[
                        SizedBox(
                            height: widget.screenType.isCompact ? 5.0 : 7.0),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.screenType.isCompact ? 6 : 8,
                            vertical: widget.screenType.isCompact ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '₱ ${widget.tier.price!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: priceSize,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
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

// ─── Tier Strip Visual ────────────────────────────────────────────────────────

class _TierStripVisual extends StatelessWidget {
  final ShotMode mode;

  const _TierStripVisual({required this.mode});

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case ShotMode.single:
        return _buildSingle();
      case ShotMode.double:
        return _buildDouble();
      case ShotMode.triple:
        return _buildTriple();
      case ShotMode.quad:
        return _buildQuad();
      case ShotMode.hex:
        return _buildHex();
      case ShotMode.octa:
        return _buildOcta();
    }
  }

  // 1 Shot: Single Square Box
  Widget _buildSingle() {
    const double size = 68.0;
    return _StripContainer(
      angle: 0.04,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: const _MiniSquareBox(
        size: size,
        color: Color(0xFFE5E5E5),
      ),
    );
  }

  // 2 Shots: 2 Vertical Square Boxes (1x2 strip)
  Widget _buildDouble() {
    const double size = 46.0;
    return _StripContainer(
      angle: 0.04,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 10),
      chinTextColor: Colors.white70,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
          SizedBox(height: 5),
          _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
        ],
      ),
    );
  }

  // 3 Shots: 3 Vertical Square Boxes (1x3 strip)
  Widget _buildTriple() {
    const double size = 34.0;
    return _StripContainer(
      angle: -0.04,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
      chinTextColor: Colors.black45,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
          SizedBox(height: 4),
          _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
          SizedBox(height: 4),
          _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
        ],
      ),
    );
  }

  // 4 Shots: 2x2 Grid of Square Boxes
  Widget _buildQuad() {
    const double size = 38.0;
    return _StripContainer(
      angle: 0.03,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 10),
      chinTextColor: Colors.white60,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
              SizedBox(width: 5),
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
            ],
          ),
          SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
              SizedBox(width: 5),
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
            ],
          ),
        ],
      ),
    );
  }

  // 6 Shots: 2x3 Grid of Square Boxes (2 columns of 3)
  Widget _buildHex() {
    const double size = 28.0;
    return _StripContainer(
      angle: -0.03,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 9),
      chinTextColor: Colors.black45,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
              SizedBox(width: 4),
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
              SizedBox(width: 4),
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
              SizedBox(width: 4),
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
            ],
          ),
        ],
      ),
    );
  }

  // 8 Shots: 2x4 Grid of Square Boxes (2 columns of 4)
  Widget _buildOcta() {
    const double size = 23.0;
    return _StripContainer(
      angle: 0.03,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 8),
      chinTextColor: Colors.black45,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
              SizedBox(width: 4),
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
              SizedBox(width: 4),
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
              SizedBox(width: 4),
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
              SizedBox(width: 4),
              _MiniSquareBox(size: size, color: Color(0xFFE5E5E5)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Square Box Widget (Guaranteed Square with White Center Circle) ───────────

class _MiniSquareBox extends StatelessWidget {
  final double size;
  final Color color;

  const _MiniSquareBox({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.10),
      ),
      // child: Center(
      //   child: Container(
      //     width: size * 0.44,
      //     height: size * 0.44,
      //     decoration: const BoxDecoration(
      //       color: Colors.white,
      //       shape: BoxShape.circle,
      //     ),
      //   ),
      // ),
    );
  }
}

// ─── Floating Strip Container with Drop Shadow ────────────────────────────────

class _StripContainer extends StatelessWidget {
  final double angle;
  final Color backgroundColor;
  final EdgeInsets padding;
  final Widget child;
  final Color? chinTextColor;

  const _StripContainer({
    required this.angle,
    required this.backgroundColor,
    required this.padding,
    required this.child,
    this.chinTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: 7),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _getPastelColor(ShotMode mode) {
  switch (mode) {
    case ShotMode.single:
      return const Color(0xFFF5F5F7);
    case ShotMode.double:
      return const Color(0xFFF5F5F7);
    case ShotMode.triple:
      return const Color(0xFFF5F5F7);
    case ShotMode.quad:
      return const Color(0xFFF5F5F7);
    case ShotMode.hex:
      return const Color(0xFFF5F5F7);
    case ShotMode.octa:
      return const Color(0xFFF5F5F7);
  }
}

String _getTierSubtitle(ShotMode mode) {
  switch (mode) {
    case ShotMode.single:
      return 'One perfect shot';
    case ShotMode.double:
      return 'Quick duo';
    case ShotMode.triple:
      return 'Classic mini strip';
    case ShotMode.quad:
      return 'Classic 2×2 grid';
    case ShotMode.hex:
      return 'Group favourite';
    case ShotMode.octa:
      return 'The ultimate set';
  }
}

// ─── Empty Tiers View ─────────────────────────────────────────────────────────

class _EmptyTiersView extends StatelessWidget {
  final VoidCallback onBack;
  const _EmptyTiersView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 72,
              color: AppColors.warning,
            ),
            const SizedBox(height: 24),
            Text(
              'No Packages Available',
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'No shot tiers are enabled for Event Mode.\nPlease contact your administrator.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.onSurface),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Go Back'),
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _TierOption {
  final ShotMode mode;
  final double? price;
  const _TierOption({required this.mode, this.price});
}
