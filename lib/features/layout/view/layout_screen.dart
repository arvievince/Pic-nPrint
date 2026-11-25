import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/layout_bloc.dart';
import '../bloc/layout_event.dart';
import '../bloc/layout_state.dart';
import '../../../core/models/models.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Layout selection screen — shown for triple/quad/hex shot modes.
///
/// The user picks between horizontal strip and grid layouts.
/// After confirming, the session is updated with the chosen layout
/// and navigation proceeds to /capture.
///
class LayoutScreen extends StatelessWidget {
  final SessionModel session;
  const LayoutScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LayoutBloc(shotMode: session.shotMode),
      child: BlocListener<LayoutBloc, LayoutState>(
        listener: (context, state) {
          if (state is LayoutChosen) {
            // Update session with the chosen layout, then go to capture
            final updated = session.copyWith(layout: state.layout);
            context.goNamed(AppRoute.capture, extra: updated);
          }
        },
        child: _LayoutView(session: session),
      ),
    );
  }
}

class _LayoutView extends StatelessWidget {
  final SessionModel session;
  const _LayoutView({required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Choose Layout — ${session.shotMode.label}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                fontSize: 24,
                color: const Color(0xFF111827),
                height: 1.1,
              ),
        ),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              context.goNamed(AppRoute.tierSelect);
            }),
      ),
      body: BlocBuilder<LayoutBloc, LayoutState>(
        builder: (context, state) {
          if (state is! LayoutInitial) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How do you want your photos arranged?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 40),

                // Layout option cards
                ...state.availableLayouts.map((layout) {
                  final isSelected = state.highlighted == layout;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _LayoutCard(
                      layout: layout,
                      isSelected: isSelected,
                      onTap: () => context
                          .read<LayoutBloc>()
                          .add(LayoutSelected(layout)),
                    ),
                  );
                }),

                const Spacer(),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () =>
                        context.read<LayoutBloc>().add(const LayoutConfirmed()),
                    child: Text(
                      'Continue',
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
          );
        },
      ),
    );
  }
}

class _LayoutCard extends StatelessWidget {
  final LayoutType layout;
  final bool isSelected;
  final VoidCallback onTap;

  const _LayoutCard({
    required this.layout,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.cardBorder,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                _iconFor(layout),
                size: 40,
                color: isSelected ? AppColors.primary : AppColors.onSurface,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layout.label,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.onBackground,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _descFor(layout),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(LayoutType l) {
    switch (l) {
      case LayoutType.classicStrip:
        return Icons.view_day_rounded;
      case LayoutType.receipt:
        return Icons.receipt_long_rounded;
      case LayoutType.spotify:
        return Icons.graphic_eq_rounded;
      case LayoutType.filmStrip:
        return Icons.movie_filter_rounded;
      case LayoutType.boardingPass:
        return Icons.flight_takeoff_rounded;
      case LayoutType.polaroid:
        return Icons.crop_portrait_rounded;
      case LayoutType.instagram:
        return Icons.favorite_border_rounded;
      case LayoutType.bento:
        return Icons.dashboard_customize_rounded;
      case LayoutType.onePieceWanted:
        return Icons.workspace_premium_rounded;
      case LayoutType.theaterTicket:
        return Icons.confirmation_number_rounded;
    }
  }

  String _descFor(LayoutType l) {
    switch (l) {
      case LayoutType.classicStrip:
        return 'Classic photo booth strip';
      case LayoutType.receipt:
        return 'Receipt order slip theme';
      case LayoutType.spotify:
        return 'Music player theme';
      case LayoutType.filmStrip:
        return '35mm cinema film strip';
      case LayoutType.boardingPass:
        return 'Airline boarding pass';
      case LayoutType.polaroid:
        return 'Instant film Polaroid';
      case LayoutType.instagram:
        return 'Social post frame';
      case LayoutType.bento:
        return 'Creative staggered bento-box collage';
      case LayoutType.onePieceWanted:
        return 'Wanted bounty poster';
      case LayoutType.theaterTicket:
        return 'Vintage theater admit-one ticket';
    }
  }
}
