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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: _logoPath != null && File(_logoPath!).existsSync()
            ? Image.file(
                File(_logoPath!),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.camera_alt_outlined,
                  size: 50,
                  color: AppColors.onBackground,
                ),
              )
            : Text(
                'Pic’n’Slip',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            _timer?.cancel();
            context.goNamed(AppRoute.attract);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: AppColors.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_remainingSeconds}s',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    return Column(
      children: [
        const SizedBox(height: 20),
        // ── Fixed Top Title Block ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose your tier',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontSize: 48,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'How many shots do you want to take?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontSize: 14,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Centered 2-Column Cards Area ────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final availableHeight = constraints.maxHeight;

              // Strictly 2 columns
              const int crossAxisCount = 2;
              const double targetCardHeight = 110.0;
              const double spacing = 18.0;

              final double maxContentWidth = availableWidth < 550
                  ? (availableWidth - 24)
                  : (availableWidth - 48).clamp(500.0, 980.0);

              final double cardWidth =
                  (maxContentWidth - (crossAxisCount - 1) * spacing) /
                      crossAxisCount;
              final double childAspectRatio = cardWidth / targetCardHeight;

              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxContentWidth,
                      maxHeight:
                          (availableHeight - 16).clamp(200.0, double.infinity),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          childAspectRatio: childAspectRatio,
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tiers.length,
                        itemBuilder: (context, i) => _TierCard(
                          tier: tiers[i],
                          showPrice: showPrice,
                          onTap: () => onSelect(tiers[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Tier Card ────────────────────────────────────────────────────────────────

class _TierCard extends StatefulWidget {
  final _TierOption tier;
  final bool showPrice;
  final VoidCallback onTap;

  const _TierCard({
    required this.tier,
    required this.showPrice,
    required this.onTap,
  });

  @override
  State<_TierCard> createState() => _TierCardState();
}

class _TierCardState extends State<_TierCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

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
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.cardBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 16,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // ── Icon cluster ────────────────────────────────────────────
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _ShotCountIcon(count: count),
                ),
              ),
              const SizedBox(width: 18),

              // ── Labels ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      mode.label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onBackground,
                        letterSpacing: 0.2,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$count photo${count == 1 ? '' : 's'} per session',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurface,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.showPrice && widget.tier.price != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₱ ${widget.tier.price!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Arrow ───────────────────────────────────────────────────
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shot Count Icon ──────────────────────────────────────────────────────────

class _ShotCountIcon extends StatelessWidget {
  final int count;
  const _ShotCountIcon({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Icon(
          Icons.camera_alt_rounded,
          color: AppColors.primary,
          size: 26,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 1.5),
            ),
            child: Center(
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
