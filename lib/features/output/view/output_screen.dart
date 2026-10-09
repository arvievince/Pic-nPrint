import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:picnprint/features/output/bloc/output_event.dart';

import '../bloc/output_bloc.dart';
import '../bloc/output_state.dart';
import '../../../core/models/models.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Output screen — shown while the app saves, uploads, and prints.
///
/// This screen auto-starts the pipeline (OutputBloc triggers on creation).
/// The user sees a progress indicator for each step.
/// On [OutputComplete] → if driveUrl is available, navigate to /qr.
///                      → otherwise navigate back to /attract.
///
class OutputScreen extends StatelessWidget {
  final SessionModel session;
  const OutputScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OutputBloc(
        storageService: context.read(),
        printerService: context.read(),
        db: context.read(),
        session: session,
      ),
      child: BlocConsumer<OutputBloc, OutputState>(
        listener: (context, state) {
          if (state is OutputComplete) {
            if (state.driveUrl != null) {
              context.goNamed(
                AppRoute.qr,
                extra: QrScreenData(
                  driveUrl: state.driveUrl!,
                  sessionId: session.sessionId,
                  displaySeconds: 60,
                ),
              );
            } else {
              // No Drive URL — show thank you screen before returning to attract
              context.goNamed(AppRoute.thankYou, extra: session.sessionId);
            }
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Status icon
                    _StatusIcon(state: state),
                    const SizedBox(height: 32),

                    // Status text
                    Text(
                      _titleFor(state),
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _subtitleFor(state),
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),

                    // Error actions
                    if (state is OutputUploadFailed) ...[
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => context.read<OutputBloc>().add(
                          const UploadRetried(),
                        ),
                        child: const Text('Retry Upload'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.goNamed(AppRoute.attract),
                        child: const Text('Skip & Go Home'),
                      ),
                    ],

                    if (state is OutputPrintFailed) ...[
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => context.read<OutputBloc>().add(
                          const PrintRequested(),
                        ),
                        child: const Text('Retry Print'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.goNamed(AppRoute.attract),
                        child: const Text('Skip Printing'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _titleFor(OutputState s) {
    if (s is OutputSaving) return 'Saving your photo…';
    if (s is OutputUploading) return 'Uploading to Drive…';
    if (s is OutputPrinting) return 'Printing your receipt…';
    if (s is OutputComplete) return 'All done!';
    if (s is OutputUploadFailed) return 'Upload Failed';
    if (s is OutputPrintFailed) return 'Print Failed';
    return '';
  }

  String _subtitleFor(OutputState s) {
    if (s is OutputSaving) return 'Keeping your photo safe on this device.';
    if (s is OutputUploading) {
      return 'So you can scan the QR code to get your photo.';
    }
    if (s is OutputPrinting) return 'Your receipt is printing. Please wait…';
    if (s is OutputComplete) {
      return s.driveUrl != null
          ? 'Get ready to scan your QR code!'
          : 'Your photo has been printed!';
    }
    if (s is OutputUploadFailed) return (s).error;
    if (s is OutputPrintFailed) return (s).error;
    return '';
  }
}

class _StatusIcon extends StatelessWidget {
  final OutputState state;
  const _StatusIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is OutputComplete) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 60,
        ),
      );
    }

    if (state is OutputUploadFailed || state is OutputPrintFailed) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: 60,
        ),
      );
    }

    return SizedBox(
      width: 80,
      height: 80,
      child: CircularProgressIndicator(
        strokeWidth: 5,
        color: AppColors.primary,
        backgroundColor: AppColors.primary.withOpacity(0.2),
      ),
    );
  }
}
