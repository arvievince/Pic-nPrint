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

// ─── Camera Filter Presets ───────────────────────────────────────────────────

enum CameraFilter {
  natural('Natural', [
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]),
  noir('Noir', [
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]),
  retro('Retro', [
    0.393,
    0.769,
    0.189,
    0,
    0,
    0.349,
    0.686,
    0.168,
    0,
    0,
    0.272,
    0.534,
    0.131,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]),
  pop('Pop', [
    1.25,
    0,
    0,
    0,
    -10,
    0,
    1.25,
    0,
    0,
    -10,
    0,
    0,
    1.25,
    0,
    -10,
    0,
    0,
    0,
    1,
    0,
  ]),
  fade('Fade', [
    0.88,
    0.06,
    0.06,
    0,
    18,
    0.06,
    0.88,
    0.06,
    0,
    18,
    0.06,
    0.06,
    0.88,
    0,
    18,
    0,
    0,
    0,
    1,
    0,
  ]);

  final String label;
  final List<double> matrix;
  const CameraFilter(this.label, this.matrix);

  ColorFilter get colorFilter => ColorFilter.matrix(matrix);
}

// ─── Capture Screen ──────────────────────────────────────────────────────────

/// Camera capture screen featuring a centered rounded live camera viewport,
/// photo framing guide, live filter preview, and bottom circular shutter.
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
      create: (context) => CaptureBloc(
        db: context.read(),
        shotMode: widget.session.shotMode,
      ),
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
                onPressed: () => context.goNamed(AppRoute.tierSelect),
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

                  // ── Review & Retake Overlay (When All Shots Captured) ──────
                  if (state is CaptureReview)
                    _ReviewOverlay(
                      state: state,
                      shotMode: widget.session.shotMode,
                      onSelectPhoto: (index) => context
                          .read<CaptureBloc>()
                          .add(CapturePhotoSelectedForRetake(index)),
                      onRetake: () => context
                          .read<CaptureBloc>()
                          .add(const CaptureRetakeConfirmed()),
                      onConfirm: () => context
                          .read<CaptureBloc>()
                          .add(const CaptureReviewConfirmed()),
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

            // ── Layer 3: Top-Left Progress Badge ("0/1 shots") ─────────
            Positioned(
              top: 18,
              left: 18,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$shotsTaken/$totalShots shots',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
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
                      color: isSelected
                          ? const Color(0xFFFF5C38)
                          : const Color(0xFFEBE7DD),
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
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
                padding: const EdgeInsets.all(4.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isBusy
                        ? const Color(0xFFFF5238).withValues(alpha: 0.6)
                        : const Color(0xFFFF5238),
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

// ─── Review & Retake Overlay ─────────────────────────────────────────────────

class _ReviewOverlay extends StatelessWidget {
  final CaptureReview state;
  final ShotMode shotMode;
  final ValueChanged<int> onSelectPhoto;
  final VoidCallback onRetake;
  final VoidCallback onConfirm;

  const _ReviewOverlay({
    required this.state,
    required this.shotMode,
    required this.onSelectPhoto,
    required this.onRetake,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isSingle = state.capturedPaths.length <= 1;
    final canRetake = state.retakesRemaining > 0;
    final targetNum = state.selectedIndex + 1;

    return Container(
      color: Colors.black87,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // ── Header Bar ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSingle ? 'Review Photo' : 'Review Your Photos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isSingle) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'Tap a photo to choose which one to retake',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: canRetake
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: canRetake ? AppColors.primary : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.replay_rounded,
                          size: 16,
                          color: canRetake ? AppColors.primary : Colors.white60,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${state.retakesRemaining}/${state.maxRetakes} retakes left',
                          style: TextStyle(
                            color: canRetake ? Colors.white : Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Photo Grid / Single View ─────────────────────────────
              Expanded(
                child: isSingle
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 380,
                            maxHeight: 460,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(state.capturedPaths.first),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final count = state.capturedPaths.length;
                          final crossAxisCount = count <= 2
                              ? 2
                              : count <= 4
                                  ? 2
                                  : 3;
                          return GridView.builder(
                            itemCount: count,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 3 / 4,
                            ),
                            itemBuilder: (context, index) {
                              final isSelected = state.selectedIndex == index;
                              final path = state.capturedPaths[index];

                              return GestureDetector(
                                onTap: () => onSelectPhoto(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.white24,
                                      width: isSelected ? 3.5 : 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          File(path),
                                          fit: BoxFit.cover,
                                        ),
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Photo ${index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // ── Bottom Action Buttons ────────────────────────────────
              Row(
                children: [
                  // Retake Button
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: canRetake ? onRetake : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            canRetake ? Colors.white : Colors.white38,
                        side: BorderSide(
                          color: canRetake ? AppColors.primary : Colors.white24,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Icons.replay_rounded,
                        color: canRetake ? AppColors.primary : Colors.white38,
                      ),
                      label: Text(
                        canRetake
                            ? (isSingle
                                ? 'Retake Photo'
                                : 'Retake Photo #$targetNum')
                            : 'No Retakes Left',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Confirm / Continue Button
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: const Text(
                        'Keep & Continue',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
