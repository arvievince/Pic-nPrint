import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/capture_bloc.dart';
import '../bloc/capture_event.dart';
import '../bloc/capture_state.dart';
import '../../../core/models/models.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Camera capture + image upload screen.
///
/// Sections:
///   1. Method selection (camera vs upload) — shown first.
///   2. Camera preview with countdown overlay — when camera is chosen.
///   3. Progress indicator showing captured thumbnails.
///   4. On [CaptureComplete] → navigates to /editor.
///
class CaptureScreen extends StatefulWidget {
  final SessionModel session;
  const CaptureScreen({super.key, required this.session});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _currentCameraIndex = 0;
  bool _cameraReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Default to front camera if available
        final frontIndex = _cameras!.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _currentCameraIndex = frontIndex != -1 ? frontIndex : 0;
        await _startCamera(_cameras![_currentCameraIndex]);
      } else {
        debugPrint('[CaptureScreen] No cameras reported by availableCameras().');
      }
    } catch (e, stack) {
      debugPrint('[CaptureScreen] Error initializing cameras: $e\n$stack');
      // Camera unavailable — upload mode still works
    }
  }

  Future<void> _startCamera(CameraDescription description) async {
    setState(() => _cameraReady = false);
    final oldController = _cameraController;
    _cameraController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await oldController?.dispose();

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e, stack) {
      debugPrint('[CaptureScreen] Error starting camera controller: $e\n$stack');
      if (mounted) setState(() => _cameraReady = false);
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;
    await _startCamera(_cameras![_currentCameraIndex]);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CaptureBloc(
        db: context.read(),
        shotMode: widget.session.shotMode,
      ),
      child: BlocConsumer<CaptureBloc, CaptureState>(
        listener: (context, state) async {
          if (state is CaptureTaking) {
            // Trigger the actual camera shutter
            await _takePhoto(context);
          }
          if (state is CaptureComplete) {
            // Update session with image paths, navigate to editor
            final updated = widget.session.copyWith(
              imagePaths: state.imagePaths,
            );
            if (context.mounted) {
              context.goNamed(AppRoute.editor, extra: updated);
            }
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Camera Preview ─────────────────────────────────────────
                  if (_cameraReady && _cameraController != null)
                    CameraPreview(_cameraController!)
                  else
                    const Center(
                      child: Icon(Icons.camera_alt_rounded,
                          size: 80, color: Colors.white24),
                    ),

                  // ── Method Selection Overlay ────────────────────────────────
                  if (state is CaptureMethodSelection)
                    _MethodSelectionOverlay(
                      session: widget.session,
                      cameraAvailable: _cameraReady,
                      onCamera: () => context
                          .read<CaptureBloc>()
                          .add(const CaptureMethodChosen(CaptureMethod.camera)),
                      onUpload: () => _pickImages(context),
                    ),

                  // ── Countdown Overlay ───────────────────────────────────────
                  if (state is CaptureCountingDown)
                    _CountdownOverlay(state: state),

                  // ── Flash Effect ────────────────────────────────────────────
                  if (state is CaptureTaking)
                    Container(color: Colors.white.withOpacity(0.8)),

                  // ── Progress Bar ────────────────────────────────────────────
                  if (state is CaptureInProgress)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _ProgressBar(state: state),
                    ),

                  // ── Error ───────────────────────────────────────────────────
                  if (state is CaptureError)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.error, size: 48),
                            const SizedBox(height: 12),
                            Text(state.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => context
                                  .read<CaptureBloc>()
                                  .add(const CaptureMethodChosen(CaptureMethod.camera)),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Back Button ─────────────────────────────────────────────
                  Positioned(
                    top: 12,
                    left: 12,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),

                  // ── Camera Flip / Switch Button ─────────────────────────────
                  if (_cameras != null && _cameras!.length > 1)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.flip_camera_ios_rounded,
                              color: Colors.white, size: 28),
                          tooltip: 'Switch Camera',
                          onPressed: _toggleCamera,
                        ),
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

  Future<void> _takePhoto(BuildContext context) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      context.read<CaptureBloc>().add(
            const CaptureFailed('Camera is not ready or available.'),
          );
      return;
    }

    try {
      final file = await _cameraController!.takePicture();
      if (context.mounted) {
        context.read<CaptureBloc>().add(PhotoCaptured(file.path));
      }
    } catch (e) {
      if (context.mounted) {
        context.read<CaptureBloc>().add(
              CaptureFailed('Failed to take photo: $e'),
            );
      }
    }
  }

  Future<void> _pickImages(BuildContext context) async {
    final picker = ImagePicker();
    final count = context.read<CaptureBloc>().shotMode.photoCount;

    List<String> paths = [];
    if (count == 1) {
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        paths = [file.path];
      }
    } else {
      final files = await picker.pickMultiImage(limit: count);
      paths = files.map((f) => f.path).toList();
    }

    if (paths.isEmpty) return;

    if (context.mounted) {
      context.read<CaptureBloc>().add(
            ImagesUploaded(paths),
          );
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _MethodSelectionOverlay extends StatelessWidget {
  final SessionModel session;
  final bool cameraAvailable;
  final VoidCallback onCamera;
  final VoidCallback onUpload;

  const _MethodSelectionOverlay({
    required this.session,
    required this.cameraAvailable,
    required this.onCamera,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${session.shotMode.label} — ${session.shotMode.photoCount} photo(s)',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to add your photos',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MethodButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Take Photo',
                    enabled: cameraAvailable,
                    onTap: onCamera,
                  ),
                  const SizedBox(width: 24),
                  _MethodButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Upload',
                    enabled: true,
                    onTap: onUpload,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _MethodButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  final CaptureCountingDown state;
  const _CountdownOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${state.shotNumber} / ${state.totalShots}',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 22,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              '${state.secondsLeft}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 120,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              'Get ready!',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                  letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final CaptureInProgress state;
  const _ProgressBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photo ${state.capturedPaths.length} of ${state.totalRequired} captured',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: state.capturedPaths.length / state.totalRequired,
            backgroundColor: Colors.white24,
            color: AppColors.primary,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
