import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../bloc/capture_bloc.dart';
import '../bloc/capture_event.dart';
import '../bloc/capture_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/models.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

// ─── Capture Screen ──────────────────────────────────────────────────────────

/// Camera capture screen featuring a centered rounded live camera viewport,
/// photo framing guide, live filter preview, and bottom circular shutter.
class CaptureScreen extends StatefulWidget {
  final SessionModel session;
  final int? retakeIndex;
  const CaptureScreen({super.key, required this.session, this.retakeIndex});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _currentCameraIndex = 0;
  bool _cameraReady = false;
  bool _isCameraInitializing = false;

  CameraFilter _selectedFilter = CameraFilter.natural;
  String? _logoPath;
  String? _title;

  @override
  void initState() {
    super.initState();
    _loadBranding();
    _initCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    try {
      final db = context.read<AppDatabase>();
      final logoPath = await db.getSetting('kiosk_logo_path');
      final title = await db.getSetting('kiosk_title');
      if (mounted) {
        setState(() {
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
        });
      }
    } catch (e) {
      debugPrint('[CaptureScreen] Error loading branding: $e');
    }
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
        debugPrint(
            '[CaptureScreen] No cameras reported by availableCameras().');
      }
    } catch (e, stack) {
      debugPrint('[CaptureScreen] Error initializing cameras: $e\n$stack');
    }
  }

  Future<void> _startCamera(CameraDescription description) async {
    if (_isCameraInitializing) return;
    _isCameraInitializing = true;
    setState(() => _cameraReady = false);

    // Dispose old controller completely BEFORE creating new one
    final oldController = _cameraController;
    _cameraController = null;
    if (oldController != null) {
      try {
        await oldController.dispose();
      } catch (e) {
        debugPrint('[CaptureScreen] Error disposing previous camera: $e');
      }
    }

    if (Platform.isWindows) {
      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (!mounted) {
      _isCameraInitializing = false;
      return;
    }

    final newController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await newController.initialize();
      if (mounted) {
        _cameraController = newController;
        setState(() => _cameraReady = true);
      } else {
        await newController.dispose();
      }
    } catch (e, stack) {
      debugPrint(
          '[CaptureScreen] Error starting camera controller: $e\n$stack');
      try {
        await newController.dispose();
      } catch (_) {}

      if (e.toString().contains('already exists') && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          final retryController = CameraController(
            description,
            ResolutionPreset.high,
            enableAudio: false,
          );
          try {
            await retryController.initialize();
            if (mounted) {
              _cameraController = retryController;
              setState(() => _cameraReady = true);
            } else {
              await retryController.dispose();
            }
          } catch (_) {
            if (mounted) setState(() => _cameraReady = false);
          }
        }
      } else {
        if (mounted) setState(() => _cameraReady = false);
      }
    } finally {
      _isCameraInitializing = false;
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
    _cameraController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        return CaptureBloc(
          db: context.read(),
          shotMode: widget.session.shotMode,
          initialPaths: widget.session.imagePaths,
          retakeIndex: widget.retakeIndex,
          retakesUsed: widget.session.retakesUsed,
        );
      },
      child: BlocConsumer<CaptureBloc, CaptureState>(
        listener: (context, state) async {
          if (state is CaptureTaking) {
            await _takePhoto(context);
          }
          if (state is CaptureComplete) {
            _cameraController?.dispose();
            _cameraController = null;
            final updated = widget.session.copyWith(
              imagePaths: state.imagePaths,
              filter: _selectedFilter.name,
            );
            if (context.mounted) {
              context.goNamed(AppRoute.editor, extra: updated);
            }
          }
        },
        builder: (context, state) {
          final totalShots = widget.session.shotMode.photoCount;
          int shotsTaken = 0;
          if (state is CaptureCountingDown) {
            shotsTaken = state.shotNumber - 1;
          } else if (state is CaptureTaking) {
            shotsTaken = state.shotNumber - 1;
          } else if (state is CaptureInProgress) {
            shotsTaken = state.capturedPaths.length;
          } else if (state is CaptureReview) {
            shotsTaken = state.capturedPaths.length;
          } else if (state is CaptureReadyForRetake) {
            shotsTaken = state.retakeIndex;
          }

          final mode = widget.session.shotMode;

          return Scaffold(
            backgroundColor: const Color(0xFFF8F6F0),
            appBar: AppBar(
              backgroundColor: const Color(0xFFF8F6F0),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Color(0xFF1E1E1E),
                ),
                onPressed: () {
                  if (state is CaptureReadyForRetake) {
                    context
                        .read<CaptureBloc>()
                        .add(const CaptureRetakeCancelled());
                  } else {
                    context.goNamed(AppRoute.tierSelect);
                  }
                },
              ),
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
                                errorBuilder: (_, __, ___) =>
                                    _buildFallbackTitle(),
                              )
                            : _buildFallbackTitle()))
                    : _buildFallbackTitle(),
              ),
              centerTitle: false,
              actions: [
                // Tier Badge (e.g. "Single · 1 shot")
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${mode.label} · ${mode.photoCount} shot${mode.photoCount > 1 ? 's' : ''}',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
                ),

                // Camera Switch Button (Flip)
                if (_cameras != null && _cameras!.length > 1)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: GestureDetector(
                        onTap: _toggleCamera,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E1E1E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.flip_camera_ios_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Main UI Layout ─────────────────────────────────────────
                  Column(
                    children: [
                      const SizedBox(height: 6),

                      // ── Centered Rounded Camera Viewport (Live Feed) ───────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: _buildCameraViewport(
                                context: context,
                                state: state,
                                shotsTaken: shotsTaken,
                                totalShots: totalShots,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Filter Selector Bar ────────────────────────────────
                      _buildFilterSelector(),

                      const SizedBox(height: 12),

                      // ── Bottom Controls (Circular Shutter Button) ──────────
                      _buildBottomControls(context, state),

                      const SizedBox(height: 14),
                    ],
                  ),

                  // ── Error Dialog Overlay ───────────────────────────────────
                  if (state is CaptureError) _buildErrorOverlay(context, state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Sub-Layout Builders ───────────────────────────────────────────────────

  Widget _buildFallbackTitle() {
    return Text(
      _title ?? 'snapbox',
      style: GoogleFonts.bricolageGrotesque(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF111827),
      ),
    );
  }

  /// The Center Rounded Camera Viewport.
  /// Displays the live camera feed when available, or an orange fallback when unavailable.
  Widget _buildCameraViewport({
    required BuildContext context,
    required CaptureState state,
    required int shotsTaken,
    required int totalShots,
  }) {
    final bool hasLiveCamera = _cameraReady &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 1: Live Camera Feed with Active Color Filter ─────
            ColorFiltered(
              colorFilter: _selectedFilter.colorFilter,
              child: hasLiveCamera
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ??
                              720,
                          height: _cameraController!.value.previewSize?.width ??
                              1280,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    )
                  : _buildCameraFallback(),
            ),

            // ── Layer 2: Dashed Inner Framing Guideline ────────────────
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: Colors.white.withValues(alpha: 0.40),
                    strokeWidth: 1.5,
                    dashLength: 7.0,
                    dashGap: 5.0,
                    radius: 16.0,
                  ),
                ),
              ),
            ),

            // ── Layer 3: Top-Left Progress Badge ("0/1 shots" or "Retaking Photo 1")
            Positioned(
              top: 18,
              left: 18,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: (state is CaptureReadyForRetake)
                      ? const Color(0xFFFF5238)
                      : Colors.black.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.retakeIndex != null
                      ? 'Retaking Photo ${widget.retakeIndex! + 1}'
                      : (state is CaptureReadyForRetake
                          ? (totalShots > 1
                              ? 'Retaking Photo ${state.shotNumber}'
                              : 'Retaking Photo')
                          : '$shotsTaken/$totalShots shots'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),

            // ── Prompt for Retake Ready State ─────────────────────────
            if (state is CaptureReadyForRetake)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt_rounded,
                          color: Color(0xFFFF7253),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Press shutter when ready to retake',
                          style: GoogleFonts.bricolageGrotesque(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Layer 4: Countdown Numbers Overlay (3, 2, 1, Get ready!)
            if (state is CaptureCountingDown)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.secondsLeft}',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 110,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get ready!',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.95),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Layer 5: Flash Effect on Shutter Snap ──────────────────
            if (state is CaptureTaking)
              Container(
                color: Colors.white.withValues(alpha: 0.85),
              ),
          ],
        ),
      ),
    );
  }

  /// Displayed inside the viewport when the camera is initializing or missing.
  Widget _buildCameraFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFF7253),
            Color(0xFFC73052),
            Color(0xFF6B2252),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Say cheese!',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Camera unavailable — demo shots will be used.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSelector() {
    return SizedBox(
      height: 38,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: CameraFilter.values.map((filter) {
              final isSelected = filter == _selectedFilter;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? Colors.black : const Color(0xFFEBE7DD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      filter.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color:
                            isSelected ? Colors.white : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, CaptureState state) {
    final isBusy = state is CaptureCountingDown || state is CaptureTaking;
    final isRetakeMode = state is CaptureReadyForRetake;

    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cancel retake pill button
          // if (isRetakeMode || widget.retakeIndex != null)
          //   Positioned(
          //     left: 20,
          //     child: TextButton.icon(
          //       onPressed: () {
          //         if (widget.retakeIndex != null) {
          //           context.goNamed(AppRoute.editor, extra: widget.session);
          //         } else {
          //           context
          //               .read<CaptureBloc>()
          //               .add(const CaptureRetakeCancelled());
          //         }
          //       },
          //       icon: const Icon(
          //         Icons.arrow_back_rounded,
          //         size: 18,
          //         color: Color(0xFF1E1E1E),
          //       ),
          //       label: const Text(
          //         'Cancel',
          //         style: TextStyle(
          //           color: Color(0xFF1E1E1E),
          //           fontWeight: FontWeight.w700,
          //           fontSize: 13.5,
          //         ),
          //       ),
          //       style: TextButton.styleFrom(
          //         backgroundColor: const Color(0xFFEBE7DD),
          //         shape: RoundedRectangleBorder(
          //           borderRadius: BorderRadius.circular(20),
          //         ),
          //         padding:
          //             const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          //       ),
          //     ),
          //   ),

          // // Gallery Upload Button
          // Positioned(
          //   right: 20,
          //   child: IconButton(
          //     onPressed: isBusy ? null : () => _pickImages(context),
          //     tooltip: 'Upload from gallery',
          //     icon: Container(
          //       width: 44,
          //       height: 44,
          //       decoration: BoxDecoration(
          //         color: const Color(0xFFEBE7DD),
          //         shape: BoxShape.circle,
          //         border:
          //             Border.all(color: const Color(0xFF1E1E1E), width: 1.5),
          //       ),
          //       child: const Icon(
          //         Icons.photo_library_outlined,
          //         size: 22,
          //         color: Color(0xFF1E1E1E),
          //       ),
          //     ),
          //   ),
          // ),

          // Centered Shutter Button
          GestureDetector(
            onTap: isBusy
                ? null
                : () {
                    context.read<CaptureBloc>().add(
                          const CaptureMethodChosen(CaptureMethod.camera),
                        );
                  },
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: isBusy ? 0.94 : 1.0,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF8F6F0),
                  border: Border.all(
                    color: const Color(0xFF1E1E1E),
                    width: 3.5,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: isBusy ? 28 : 56,
                    height: isBusy ? 28 : 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isBusy ? 6 : 28),
                      color: isBusy
                          ? const Color(0xFFFF5238).withValues(alpha: 0.85)
                          : const Color(0xFFFF5238),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay(BuildContext context, CaptureError state) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1E1E1E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5238),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => context.read<CaptureBloc>().add(
                    const CaptureMethodChosen(CaptureMethod.camera),
                  ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Photo Capture Handlers ────────────────────────────────────────────────

  Future<void> _takePhoto(BuildContext context) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      // Demo shot generation when no physical camera is attached
      try {
        final bloc = context.read<CaptureBloc>();
        final shotNum = (bloc.state is CaptureTaking)
            ? (bloc.state as CaptureTaking).shotNumber
            : 1;
        final demoPath = await _generateDemoPhoto(shotNum);
        if (context.mounted) {
          bloc.add(PhotoCaptured(demoPath));
        }
      } catch (e) {
        if (context.mounted) {
          context
              .read<CaptureBloc>()
              .add(CaptureFailed('Demo capture error: $e'));
        }
      }
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

  Future<String> _generateDemoPhoto(int shotNumber) async {
    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/demo_photo_${DateTime.now().millisecondsSinceEpoch}_$shotNumber.jpg';
    final image = img.Image(width: 900, height: 1200);

    // Aesthetic sunset gradient image for demo testing
    for (int y = 0; y < 1200; y++) {
      final t = y / 1200.0;
      final r = (255 * (1 - t) + 107 * t).toInt().clamp(0, 255);
      final g = (114 * (1 - t) + 34 * t).toInt().clamp(0, 255);
      final b = (83 * (1 - t) + 82 * t).toInt().clamp(0, 255);
      for (int x = 0; x < 900; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }
    final bytes = img.encodeJpg(image, quality: 90);
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  Future<void> _pickImages(BuildContext context) async {
    final picker = ImagePicker();
    final isRetake = widget.retakeIndex != null;

    if (isRetake) {
      // Retake mode: select exactly 1 photo to replace the chosen slot
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file != null && context.mounted) {
        context.read<CaptureBloc>().add(ImagesUploaded([file.path]));
      }
      return;
    }

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
      context.read<CaptureBloc>().add(ImagesUploaded(paths));
    }
  }
}

// ─── Dashed Border Painter ───────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;
  final double radius;

  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.dashGap,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + dashLength < metric.length)
            ? dashLength
            : metric.length - distance;
        dashedPath.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += dashLength + dashGap;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashLength != oldDelegate.dashLength ||
      dashGap != oldDelegate.dashGap ||
      radius != oldDelegate.radius;
}
