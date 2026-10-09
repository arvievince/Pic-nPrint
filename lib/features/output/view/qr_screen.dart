import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// QR screen — shown after Drive upload.
///
/// Shows a large QR code so the customer can scan to get their photo.
/// Auto-returns to attract screen after [data.displaySeconds] seconds.
/// The customer can tap "Done" to leave sooner.
///
/// IMPORTANT: The QR code is on-screen ONLY — it is NOT printed or
/// embedded in the image (per the plan).
///
class QrScreen extends StatefulWidget {
  final QrScreenData data;
  const QrScreen({super.key, required this.data});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.data.displaySeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _done();
      }
    });
  }

  void _done() {
    _timer?.cancel();
    if (mounted) {
      context.goNamed(AppRoute.thankYou, extra: widget.data.sessionId);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your Photo is Ready!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Scan the QR code to save your photo.\nLink valid for 7 days.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),

              // QR Code
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: widget.data.driveUrl,
                    size: 260,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Session ID
              Text(
                'Session: ${widget.data.sessionId}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
              ),

              const SizedBox(height: 48),

              // Countdown
              Text(
                'Returning in $_remaining seconds',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Done button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _done,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  child: const Text('Done — I scanned it!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
