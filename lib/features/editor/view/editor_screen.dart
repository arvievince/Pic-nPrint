import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../bloc/editor_bloc.dart';
import '../bloc/editor_event.dart';
import '../bloc/editor_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/models.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Photo editor screen — stickers, text, and decorative borders.
class EditorScreen extends StatefulWidget {
  final SessionModel session;
  const EditorScreen({super.key, required this.session});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  bool _isCapturing = false;
  String? _logoPath;
  String? _brandText;
  late CameraFilter _activeFilter;
  int? _selectedPhotoIndex;

  void _handleRetake() {
    final photoCount = widget.session.imagePaths.length;
    if (_selectedPhotoIndex == null && photoCount > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Tap a photo on the canvas to choose which one to retake.'),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() => _selectedPhotoIndex = 0);
      return;
    }
    final targetIndex = _selectedPhotoIndex ?? 0;
    context.goNamed(
      AppRoute.capture,
      extra: {
        'session': widget.session,
        'retakeIndex': targetIndex,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _activeFilter = CameraFilter.fromName(widget.session.filter);
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    final db = context.read<AppDatabase>();
    final path = await db.getSetting('kiosk_logo_path');
    final title = await db.getSetting('kiosk_title');
    if (mounted) {
      setState(() {
        if (path != null &&
            path.trim().isNotEmpty &&
            File(path.trim()).existsSync()) {
          _logoPath = path.trim();
        }
        if (title != null && title.trim().isNotEmpty) {
          _brandText = title.trim();
        }
      });
    }
  }

  Future<void> _handleDone(BuildContext context) async {
    setState(() => _isCapturing = true);

    // Wait for the UI to rebuild without editing chrome / delete buttons
    await Future.delayed(const Duration(milliseconds: 60));

    Uint8List? pngBytes;
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        // High resolution snapshot (3.5x pixel ratio)
        final uiImage = await boundary.toImage(pixelRatio: 3.5);
        final byteData =
            await uiImage.toByteData(format: ui.ImageByteFormat.png);
        pngBytes = byteData?.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('[EditorScreen] Error capturing canvas snapshot: $e');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }

    if (context.mounted) {
      context.read<EditorBloc>().add(EditorConfirmed(renderedBytes: pngBytes));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditorBloc(
        compositionService: context.read(),
        session: widget.session,
        logoPath: _logoPath,
        brandText: _brandText,
      ),
      child: BlocConsumer<EditorBloc, EditorState>(
        listener: (context, state) {
          if (state.composedPath != null && !state.isComposing) {
            final updated = widget.session.copyWith(
              composedImagePath: state.composedPath,
              filter: _activeFilter.name,
            );
            context.goNamed(AppRoute.output, extra: updated);
          }
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isProcessing = state.isComposing || _isCapturing;
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              title: Text(
                'Your Prints',
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
                onPressed: isProcessing ? null : () => context.pop(),
              ),
            ),
            body: Column(
              children: [
                // ────── Canvas ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
                Expanded(
                  child: _EditorCanvas(
                    session: widget.session,
                    editorState: state,
                    canvasKey: _canvasKey,
                    isCapturing: _isCapturing,
                    logoPath: _logoPath,
                    brandText: _brandText,
                    activeFilter: _activeFilter,
                    selectedPhotoIndex: _selectedPhotoIndex,
                    onSelectPhoto: (index) {
                      setState(() {
                        _selectedPhotoIndex =
                            (_selectedPhotoIndex == index) ? null : index;
                      });
                    },
                  ),
                ),

                // ────── Tool Tabs ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
                _ToolBar(
                  session: widget.session,
                  activeFilter: _activeFilter,
                  onFilterChanged: (filter) {
                    setState(() => _activeFilter = filter);
                  },
                  selectedPhotoIndex: _selectedPhotoIndex,
                  onRetake: _handleRetake,
                  onDone: () => _handleDone(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ───────── Canvas ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

class _EditorCanvas extends StatelessWidget {
  final SessionModel session;
  final EditorState editorState;
  final GlobalKey canvasKey;
  final bool isCapturing;
  final String? logoPath;
  final String? brandText;
  final CameraFilter activeFilter;
  final int? selectedPhotoIndex;
  final ValueChanged<int>? onSelectPhoto;

  const _EditorCanvas({
    required this.session,
    required this.editorState,
    required this.canvasKey,
    required this.isCapturing,
    this.logoPath,
    this.brandText,
    required this.activeFilter,
    this.selectedPhotoIndex,
    this.onSelectPhoto,
  });

  double _getAspectRatio() {
    final paths = session.imagePaths;
    if (paths.length <= 1) return 3 / 4;

    final layout = session.layout ??
        (paths.length == 4
            ? LayoutType.grid2x2
            : paths.length == 6
                ? LayoutType.grid2x3
                : paths.length >= 8
                    ? LayoutType.grid2x4
                    : LayoutType.verticalStrip);

    switch (layout) {
      case LayoutType.single:
        return 3 / 4;
      case LayoutType.verticalStrip:
        return paths.length == 2
            ? 2 / 3
            : (paths.length >= 3 ? 1 / 2.2 : 9 / 16);
      case LayoutType.horizontalRow:
        return paths.length >= 3 ? 16 / 10 : 4 / 3;
      case LayoutType.grid2x2:
        return 1.0;
      case LayoutType.grid2x3:
        return 2 / 3;
      case LayoutType.grid2x4:
        return 2 / 3;
      case LayoutType.bendo:
        return 2 / 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoPath != null && File(logoPath!).existsSync();
    final double headerHeight = 48.0;
    final double footerHeight = 80.0;

    final double radius = isCapturing ? 0.0 : 16.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE6DC), // Darker warm stage background
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Container(
          margin: isCapturing
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: isCapturing
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 28,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 40,
                      spreadRadius: 0,
                      offset: const Offset(0, 14),
                    ),
                  ],
          ),
          child: AspectRatio(
            aspectRatio: _getAspectRatio(),
            child: RepaintBoundary(
              key: canvasKey,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ────── 1. Base Layout: Top Logo Bar + Middle Photos (with Border) + Bottom Footer ──────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Header with Logo (Always visible and displayed)
                          SizedBox(
                            height: headerHeight,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: hasLogo
                                    ? Image.file(
                                        File(logoPath!),
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.camera_alt_rounded,
                                            color: AppColors.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            (brandText != null &&
                                                    brandText!
                                                        .trim()
                                                        .isNotEmpty)
                                                ? brandText!.trim()
                                                : 'Pic & Print',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          // Middle: Photo Layout edge-to-edge (no left/right space)
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildPhotoLayout(),
                                if (editorState.borderAssetPath != null)
                                  _BorderOverlay(
                                    borderId: editorState.borderAssetPath!,
                                  ),
                              ],
                            ),
                          ),

                          // const SizedBox(
                          //   height: 16,
                          // ),

                          // Bottom Footer: Universal Session Barcode
                          SizedBox(
                            height: footerHeight,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 8,
                                ),
                                // child: ConstrainedBox(
                                //   constraints: const BoxConstraints(
                                //     maxWidth: 450,
                                //     maxHeight: 60,
                                //   ),
                                //   child: BarcodeWidget(
                                //     barcode: Barcode.code128(),
                                //     data: session.sessionId,
                                //     drawText: true,
                                //     style: const TextStyle(
                                //       color: Colors.white,
                                //       fontSize: 9,
                                //       fontWeight: FontWeight.w600,
                                //       letterSpacing: 0.5,
                                //     ),
                                //     color: Colors.black,
                                //   ),
                                // ),
                              ),
                            ),
                          ),

                          // const SizedBox(
                          //   height: 4,
                          // )
                        ],
                      ),

                      // ────── 4. Sticker Overlays Layer ───────────────────────────────────────────────────────────────────────────────────────────────────
                      ...editorState.stickers.map(
                        (s) => _StickerWidget(
                            sticker: s, isCapturing: isCapturing),
                      ),

                      // ────── 5. Text Overlays Layer ────────────────────────────────────────────────────────────────────────────────────────────────────────────
                      ...editorState.texts.map(
                        (t) =>
                            _TextWidget(textItem: t, isCapturing: isCapturing),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableImage(String path, int index) {
    final isSelected = !isCapturing && selectedPhotoIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isCapturing ? null : () => onSelectPhoto?.call(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBaseImage(path),
          if (isSelected) ...[
            // Highlight selection border
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary,
                      width: 3.5,
                    ),
                  ),
                ),
              ),
            ),
            // Selection Badge Tag
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Photo #${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoLayout() {
    final paths = session.imagePaths;

    if (paths.isEmpty) return _errorPlaceholder();
    if (paths.length == 1) return _buildSelectableImage(paths.first, 0);
    final layout = session.layout ??
        (paths.length == 4
            ? LayoutType.grid2x2
            : paths.length == 6
                ? LayoutType.grid2x3
                : paths.length >= 8
                    ? LayoutType.grid2x4
                    : LayoutType.verticalStrip);

    switch (layout) {
      case LayoutType.single:
        return _buildBaseImage(paths.first);

      case LayoutType.verticalStrip:
        return Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < paths.length; i++) ...[
                if (i > 0) Container(height: 4, color: Colors.white),
                Expanded(child: _buildSelectableImage(paths[i], i)),
              ],
            ],
          ),
        );

      case LayoutType.horizontalRow:
        return Container(
          color: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < paths.length; i++) ...[
                if (i > 0) Container(width: 4, color: Colors.white),
                Expanded(child: _buildSelectableImage(paths[i], i)),
              ],
            ],
          ),
        );

      case LayoutType.grid2x2:
        return Container(
          color: Colors.white,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildSelectableImage(paths[0], 0)),
                    Container(width: 4, color: Colors.white),
                    Expanded(
                      child: _buildSelectableImage(
                        paths.length > 1 ? paths[1] : paths[0],
                        1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 4, color: Colors.white),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildSelectableImage(
                        paths.length > 2 ? paths[2] : paths[0],
                        2,
                      ),
                    ),
                    Container(width: 4, color: Colors.white),
                    Expanded(
                      child: _buildSelectableImage(
                        paths.length > 3 ? paths[3] : paths[0],
                        3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case LayoutType.grid2x3:
        return Container(
          color: Colors.white,
          child: Column(
            children: [
              for (int row = 0; row < 3; row++) ...[
                if (row > 0) Container(height: 4, color: Colors.white),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int col = 0; col < 2; col++) ...[
                        if (col > 0) Container(width: 4, color: Colors.white),
                        Expanded(
                          child: _buildSelectableImage(
                            paths.length > (row * 2 + col)
                                ? paths[row * 2 + col]
                                : paths[0],
                            row * 2 + col,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

      case LayoutType.grid2x4:
        return Container(
          color: Colors.white,
          child: Column(
            children: [
              for (int row = 0; row < 4; row++) ...[
                if (row > 0) Container(height: 4, color: Colors.white),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int col = 0; col < 2; col++) ...[
                        if (col > 0) Container(width: 4, color: Colors.white),
                        Expanded(
                          child: _buildSelectableImage(
                            paths.length > (row * 2 + col)
                                ? paths[row * 2 + col]
                                : paths[0],
                            row * 2 + col,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

      case LayoutType.bendo:
        return _buildBendoLayout(paths);
    }
  }

  Widget _buildBendoCard(String path, int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _buildSelectableImage(path, index),
    );
  }

  Widget _buildBendoBrandTag() {
    final text = (brandText != null && brandText!.trim().isNotEmpty)
        ? brandText!.trim()
        : 'Snapbox.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Icon(
                  Icons.camera_enhance_rounded,
                  size: 20,
                  color: Colors.black87,
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBendoLayout(List<String> paths) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: () {
        if (paths.length <= 3) {
          // ────── 3-Shot Bendo: Left hero photo + Right 2 stacked photos with brand tag ──────
          final p0 = paths[0];
          final p1 = paths.length > 1 ? paths[1] : p0;
          final p2 = paths.length > 2 ? paths[2] : p0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildBendoCard(p0, 0),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildBendoCard(p1, 1)),
                    _buildBendoBrandTag(),
                    Expanded(child: _buildBendoCard(p2, 2)),
                  ],
                ),
              ),
            ],
          );
        } else if (paths.length <= 4) {
          // ────── 4-Shot Bendo: Staggered 2x2 masonry with brand tag ──────
          final p0 = paths[0];
          final p1 = paths.length > 1 ? paths[1] : p0;
          final p2 = paths.length > 2 ? paths[2] : p0;
          final p3 = paths.length > 3 ? paths[3] : p0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: _buildBendoCard(p0, 0)),
                    const SizedBox(height: 16),
                    Expanded(flex: 3, child: _buildBendoCard(p1, 1)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _buildBendoCard(p2, 2)),
                    _buildBendoBrandTag(),
                    Expanded(flex: 2, child: _buildBendoCard(p3, 3)),
                  ],
                ),
              ),
            ],
          );
        } else if (paths.length <= 6) {
          // ────── 6-Shot Bendo: 3 Left + 3 Right with brand tag ──────
          final p0 = paths[0];
          final p1 = paths.length > 1 ? paths[1] : p0;
          final p2 = paths.length > 2 ? paths[2] : p0;
          final p3 = paths.length > 3 ? paths[3] : p0;
          final p4 = paths.length > 4 ? paths[4] : p0;
          final p5 =
              paths.length > 5 ? paths[5] : (paths.length > 4 ? paths[4] : p0);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column: 3 photos (short, tall, short)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: _buildBendoCard(p0, 0)),
                    const SizedBox(height: 6),
                    Expanded(flex: 3, child: _buildBendoCard(p1, 1)),
                    const SizedBox(height: 6),
                    Expanded(flex: 2, child: _buildBendoCard(p2, 2)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right Column: 3 photos (tall, medium, medium) + brand tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _buildBendoCard(p3, 3)),
                    _buildBendoBrandTag(),
                    Expanded(flex: 2, child: _buildBendoCard(p4, 4)),
                    if (paths.length >= 6) ...[
                      const SizedBox(height: 6),
                      Expanded(flex: 2, child: _buildBendoCard(p5, 5)),
                    ],
                  ],
                ),
              ),
            ],
          );
        } else {
          // ────── 8-Shot Bendo: 4 Left + 4 Right with brand tag ──────
          final p0 = paths[0];
          final p1 = paths.length > 1 ? paths[1] : p0;
          final p2 = paths.length > 2 ? paths[2] : p0;
          final p3 = paths.length > 3 ? paths[3] : p0;
          final p4 = paths.length > 4 ? paths[4] : p0;
          final p5 = paths.length > 5 ? paths[5] : p0;
          final p6 = paths.length > 6 ? paths[6] : p0;
          final p7 = paths.length > 7 ? paths[7] : p0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column: 4 photos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _buildBendoCard(p0, 0)),
                    const SizedBox(height: 6),
                    Expanded(flex: 2, child: _buildBendoCard(p1, 1)),
                    const SizedBox(height: 6),
                    Expanded(flex: 3, child: _buildBendoCard(p2, 2)),
                    const SizedBox(height: 6),
                    Expanded(flex: 2, child: _buildBendoCard(p3, 3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right Column: 4 photos + brand tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: _buildBendoCard(p4, 4)),
                    const SizedBox(height: 6),
                    Expanded(flex: 3, child: _buildBendoCard(p5, 5)),
                    _buildBendoBrandTag(),
                    Expanded(flex: 2, child: _buildBendoCard(p6, 6)),
                    const SizedBox(height: 6),
                    Expanded(flex: 3, child: _buildBendoCard(p7, 7)),
                  ],
                ),
              ),
            ],
          );
        }
      }(),
    );
  }

  Widget _buildBaseImage(String path) {
    return _AdjustablePhotoSlot(
      key: ValueKey(path),
      path: path,
      isCapturing: isCapturing,
      activeFilter: activeFilter,
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_rounded,
              size: 60,
              color: AppColors.onSurface,
            ),
            SizedBox(height: 8),
            Text(
              'Photo not loaded',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── Interactive Adjustable Photo Slot ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

class _AdjustablePhotoSlot extends StatefulWidget {
  final String path;
  final bool isCapturing;
  final CameraFilter activeFilter;

  const _AdjustablePhotoSlot({
    super.key,
    required this.path,
    this.isCapturing = false,
    required this.activeFilter,
  });

  @override
  State<_AdjustablePhotoSlot> createState() => _AdjustablePhotoSlotState();
}

class _AdjustablePhotoSlotState extends State<_AdjustablePhotoSlot> {
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _baseOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;

  Size? _imageSize;
  ImageStream? _imageStream;
  ImageStreamListener? _streamListener;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant _AdjustablePhotoSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _scale = 1.0;
      _offset = Offset.zero;
      _resolveImageSize();
    }
  }

  void _resolveImageSize() {
    final file = File(widget.path);
    final ImageProvider provider = file.existsSync()
        ? FileImage(file)
        : AssetImage(widget.path) as ImageProvider;

    final config = const ImageConfiguration();
    _streamListener = ImageStreamListener((info, synchronousCall) {
      if (mounted) {
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      }
    });

    _imageStream = provider.resolve(config);
    _imageStream?.addListener(_streamListener!);
  }

  @override
  void dispose() {
    if (_streamListener != null) {
      _imageStream?.removeListener(_streamListener!);
    }
    super.dispose();
  }

  void _reset() {
    setState(() {
      _scale = 1.0;
      _baseScale = 1.0;
      _offset = Offset.zero;
      _baseOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.path);
    final rawImage = file.existsSync()
        ? Image.file(
            file,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) => _slotErrorPlaceholder(),
          )
        : Image.asset(
            widget.path,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) => _slotErrorPlaceholder(),
          );

    final imageWidget = ColorFiltered(
      colorFilter: widget.activeFilter.colorFilter,
      child: rawImage,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;

        if (cw <= 0 || ch <= 0 || _imageSize == null) {
          return ClipRect(
            child: file.existsSync()
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                    width: cw > 0 ? cw : null,
                    height: ch > 0 ? ch : null,
                    errorBuilder: (_, __, ___) => _slotErrorPlaceholder(),
                  )
                : Image.asset(
                    widget.path,
                    fit: BoxFit.cover,
                    width: cw > 0 ? cw : null,
                    height: ch > 0 ? ch : null,
                    errorBuilder: (_, __, ___) => _slotErrorPlaceholder(),
                  ),
          );
        }

        final iw = _imageSize!.width;
        final ih = _imageSize!.height;

        final coverScale = math.max(cw / iw, ch / ih);
        final sw = iw * coverScale * _scale;
        final sh = ih * coverScale * _scale;

        final maxPanX = math.max(0.0, (sw - cw) / 2);
        final maxPanY = math.max(0.0, (sh - ch) / 2);

        final clampedX = _offset.dx.clamp(-maxPanX, maxPanX);
        final clampedY = _offset.dy.clamp(-maxPanY, maxPanY);

        final left = (cw - sw) / 2 + clampedX;
        final top = (ch - sh) / 2 + clampedY;

        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: widget.isCapturing
                ? null
                : (details) {
                    _startFocalPoint = details.localFocalPoint;
                    _baseScale = _scale;
                    _baseOffset = _offset;
                  },
            onScaleUpdate: widget.isCapturing
                ? null
                : (details) {
                    setState(() {
                      if (details.scale != 1.0) {
                        _scale = (_baseScale * details.scale).clamp(1.0, 3.0);
                      }
                      final dragDelta =
                          details.localFocalPoint - _startFocalPoint;
                      final targetOffset = _baseOffset + dragDelta;

                      final updatedSw = iw * coverScale * _scale;
                      final updatedSh = ih * coverScale * _scale;
                      final currentMaxX = math.max(0.0, (updatedSw - cw) / 2);
                      final currentMaxY = math.max(0.0, (updatedSh - ch) / 2);

                      _offset = Offset(
                        targetOffset.dx.clamp(-currentMaxX, currentMaxX),
                        targetOffset.dy.clamp(-currentMaxY, currentMaxY),
                      );
                    });
                  },
            onDoubleTap: widget.isCapturing ? null : _reset,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: sw,
                  height: sh,
                  child: imageWidget,
                ),
                // Subtle reposition guide (only visible in edit mode when the image has room to move)
                if (!widget.isCapturing &&
                    (maxPanX > 2 || maxPanY > 2 || _scale > 1.0))
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.open_with_rounded,
                          size: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _slotErrorPlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded,
                size: 36, color: AppColors.onSurface),
            SizedBox(height: 4),
            Text('Photo not loaded',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ───────── Border Frame Overlay ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

class _BorderOverlay extends StatelessWidget {
  final String borderId;
  const _BorderOverlay({required this.borderId});

  @override
  Widget build(BuildContext context) {
    switch (borderId) {
      case 'polaroid':
        return const SizedBox.shrink();

      case 'gold':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFFFD700), width: 6),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFFE082), width: 2),
            ),
          ),
        );

      case 'film':
        return Column(
          children: [_buildFilmStrip(), const Spacer(), _buildFilmStrip()],
        );

      case 'pastel':
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF80AB), width: 6),
          ),
        );

      case 'midnight':
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF212121), width: 14),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFilmStrip() {
    return Container(
      height: 28,
      color: Colors.black87,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          8,
          (index) => Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────── Sticker Widget ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

class _StickerWidget extends StatefulWidget {
  final StickerItem sticker;
  final bool isCapturing;
  const _StickerWidget({required this.sticker, this.isCapturing = false});

  @override
  State<_StickerWidget> createState() => _StickerWidgetState();
}

class _StickerWidgetState extends State<_StickerWidget> {
  // Global drag & pinch tracking
  Offset _lastFocalPoint = Offset.zero;
  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  // Handle interaction tracking
  Offset _center = Offset.zero;
  double _startAngle = 0.0;
  double _startDistance = 1.0;
  double _initialRotation = 0.0;
  double _initialScale = 1.0;

  Offset _getGlobalCenter() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(box.size.center(Offset.zero));
    }
    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    final sticker = widget.sticker;
    final isEmoji = sticker.assetPath.startsWith('emoji:');
    final emojiChar =
        isEmoji ? sticker.assetPath.replaceFirst('emoji:', '') : '';
    final handleCounterScale = 1.0 / sticker.scale.clamp(0.4, 4.0);

    return Positioned(
      left: sticker.x,
      top: sticker.y,
      child: Transform.rotate(
        angle: sticker.rotation,
        child: Transform.scale(
          scale: sticker.scale,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Main content & gesture area
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: widget.isCapturing
                    ? null
                    : (details) {
                        _lastFocalPoint = details.focalPoint;
                        _baseScale = sticker.scale;
                        _baseRotation = sticker.rotation;
                      },
                onScaleUpdate: widget.isCapturing
                    ? null
                    : (details) {
                        final dx = details.focalPoint.dx - _lastFocalPoint.dx;
                        final dy = details.focalPoint.dy - _lastFocalPoint.dy;
                        _lastFocalPoint = details.focalPoint;

                        if (details.pointerCount > 1) {
                          // Two-finger pinch & rotate
                          final newScale =
                              (_baseScale * details.scale).clamp(0.4, 4.0);
                          final newRotation = _baseRotation + details.rotation;
                          context.read<EditorBloc>().add(
                                StickerUpdated(
                                  sticker.copyWith(
                                    x: sticker.x + dx,
                                    y: sticker.y + dy,
                                    scale: newScale,
                                    rotation: newRotation,
                                  ),
                                ),
                              );
                        } else {
                          // Single-finger or mouse drag: always moves 1:1 on screen
                          context.read<EditorBloc>().add(
                                StickerUpdated(
                                  sticker.copyWith(
                                    x: sticker.x + dx,
                                    y: sticker.y + dy,
                                  ),
                                ),
                              );
                        }
                      },
                onLongPress: widget.isCapturing
                    ? null
                    : () => context
                        .read<EditorBloc>()
                        .add(StickerDeleted(sticker.id)),
                child: Container(
                  decoration: widget.isCapturing
                      ? null
                      : BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                  padding: widget.isCapturing
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(8.0),
                  child: isEmoji
                      ? Text(
                          emojiChar,
                          style: const TextStyle(
                            fontSize: 46,
                            shadows: [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black45,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                        )
                      : Image.asset(
                          sticker.assetPath,
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.emoji_emotions_rounded,
                            size: 50,
                            color: Colors.amber,
                          ),
                        ),
                ),
              ),

              // Control Handles (hidden during final image capture)
              if (!widget.isCapturing) ...[
                // Top-Right: Delete Handle
                Positioned(
                  top: -14,
                  right: -14,
                  child: Transform.scale(
                    scale: handleCounterScale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        context
                            .read<EditorBloc>()
                            .add(StickerDeleted(sticker.id));
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom-Right: Radial Resize Handle
                Positioned(
                  bottom: -14,
                  right: -14,
                  child: Transform.scale(
                    scale: handleCounterScale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        double nextScale = 1.0;
                        if (sticker.scale < 1.2) {
                          nextScale = 1.5;
                        } else if (sticker.scale < 1.7) {
                          nextScale = 2.0;
                        } else if (sticker.scale < 2.2) {
                          nextScale = 0.75;
                        } else {
                          nextScale = 1.0;
                        }
                        context.read<EditorBloc>().add(
                              StickerUpdated(
                                  sticker.copyWith(scale: nextScale)),
                            );
                      },
                      onPanStart: (details) {
                        _center = _getGlobalCenter();
                        _startDistance =
                            (details.globalPosition - _center).distance;
                        if (_startDistance < 10) _startDistance = 10;
                        _initialScale = sticker.scale;
                      },
                      onPanUpdate: (details) {
                        final currentDistance =
                            (details.globalPosition - _center).distance;
                        final factor = currentDistance / _startDistance;
                        final newScale =
                            (_initialScale * factor).clamp(0.4, 4.0);
                        context.read<EditorBloc>().add(
                              StickerUpdated(
                                sticker.copyWith(scale: newScale),
                              ),
                            );
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom-Left: Arc Rotate Handle
                Positioned(
                  bottom: -14,
                  left: -14,
                  child: Transform.scale(
                    scale: handleCounterScale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final newRotation =
                            (sticker.rotation + (math.pi / 4)) % (2 * math.pi);
                        context.read<EditorBloc>().add(
                              StickerUpdated(
                                sticker.copyWith(rotation: newRotation),
                              ),
                            );
                      },
                      onPanStart: (details) {
                        _center = _getGlobalCenter();
                        _startAngle = math.atan2(
                          details.globalPosition.dy - _center.dy,
                          details.globalPosition.dx - _center.dx,
                        );
                        _initialRotation = sticker.rotation;
                      },
                      onPanUpdate: (details) {
                        final currentAngle = math.atan2(
                          details.globalPosition.dy - _center.dy,
                          details.globalPosition.dx - _center.dx,
                        );
                        final deltaAngle = currentAngle - _startAngle;
                        final newRotation = _initialRotation + deltaAngle;
                        context.read<EditorBloc>().add(
                              StickerUpdated(
                                sticker.copyWith(rotation: newRotation),
                              ),
                            );
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.rotate_right_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Top-Left: Reset Scale & Rotation
                Positioned(
                  top: -14,
                  left: -14,
                  child: Transform.scale(
                    scale: handleCounterScale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        context.read<EditorBloc>().add(
                              StickerUpdated(
                                sticker.copyWith(scale: 1.0, rotation: 0.0),
                              ),
                            );
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.cardBorder, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restart_alt_rounded,
                          size: 16,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Text Widget ─────────────────────────────────────────────────────────────

class _TextWidget extends StatefulWidget {
  final TextItem textItem;
  final bool isCapturing;
  const _TextWidget({required this.textItem, this.isCapturing = false});

  @override
  State<_TextWidget> createState() => _TextWidgetState();
}

class _TextWidgetState extends State<_TextWidget> {
  // Global drag & pinch tracking
  Offset _lastFocalPoint = Offset.zero;
  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  // Handle interaction tracking
  Offset _center = Offset.zero;
  double _startAngle = 0.0;
  double _startDistance = 1.0;
  double _initialRotation = 0.0;
  double _initialScale = 1.0;

  Offset _getGlobalCenter() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(box.size.center(Offset.zero));
    }
    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    final textItem = widget.textItem;
    final handleCounterScale = 1.0 / textItem.scale.clamp(0.4, 4.0);

    return Positioned(
      left: textItem.x,
      top: textItem.y,
      child: Transform.rotate(
        angle: textItem.rotation,
        child: Transform.scale(
          scale: textItem.scale,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Main content & gesture area
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: widget.isCapturing
                    ? null
                    : (details) {
                        _lastFocalPoint = details.focalPoint;
                        _baseScale = textItem.scale;
                        _baseRotation = textItem.rotation;
                      },
                onScaleUpdate: widget.isCapturing
                    ? null
                    : (details) {
                        final dx = details.focalPoint.dx - _lastFocalPoint.dx;
                        final dy = details.focalPoint.dy - _lastFocalPoint.dy;
                        _lastFocalPoint = details.focalPoint;

                        if (details.pointerCount > 1) {
                          // Two-finger pinch & rotate
                          final newScale =
                              (_baseScale * details.scale).clamp(0.4, 4.0);
                          final newRotation = _baseRotation + details.rotation;
                          context.read<EditorBloc>().add(
                                TextUpdated(
                                  textItem.copyWith(
                                    x: textItem.x + dx,
                                    y: textItem.y + dy,
                                    scale: newScale,
                                    rotation: newRotation,
                                  ),
                                ),
                              );
                        } else {
                          // Single-finger or mouse drag: always moves 1:1 on screen
                          context.read<EditorBloc>().add(
                                TextUpdated(
                                  textItem.copyWith(
                                    x: textItem.x + dx,
                                    y: textItem.y + dy,
                                  ),
                                ),
                              );
                        }
                      },
                onLongPress: widget.isCapturing
                    ? null
                    : () => context
                        .read<EditorBloc>()
                        .add(TextDeleted(textItem.id)),
                child: Container(
                  decoration: widget.isCapturing
                      ? null
                      : BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                  padding: widget.isCapturing
                      ? const EdgeInsets.all(4.0)
                      : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    textItem.text,
                    style: TextStyle(
                      fontSize: textItem.fontSize,
                      fontWeight: FontWeight.bold,
                      color: Color(textItem.colorValue),
                      fontFamily: textItem.fontFamily,
                      shadows: const [
                        // Shadow(
                        //   blurRadius: 6,
                        //   color: Colors.black,
                        //   offset: Offset(1.5, 1.5),
                        // ),
                        // Shadow(
                        //   blurRadius: 6,
                        //   color: Colors.black87,
                        //   offset: Offset(-1, -1),
                        // ),
                      ],
                    ),
                  ),
                ),
              ),

              // Control Handles (hidden during final image capture)
              if (!widget.isCapturing) ...[
                // Top-Right: Delete Handle
                Positioned(
                  top: -14,
                  right: -14,
                  child: Transform.scale(
                    scale: handleCounterScale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        context
                            .read<EditorBloc>()
                            .add(TextDeleted(textItem.id));
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom-Right: Radial Resize Handle
                Positioned(
                  bottom: -14,
                  right: -14,
                  child: Transform.scale(
                    scale: handleCounterScale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        double nextScale = 1.0;
                        if (textItem.scale < 1.2) {
                          nextScale = 1.5;
                        } else if (textItem.scale < 1.7) {
                          nextScale = 2.0;
                        } else if (textItem.scale < 2.2) {
                          nextScale = 0.75;
                        } else {
                          nextScale = 1.0;
                        }
                        context.read<EditorBloc>().add(
                              TextUpdated(textItem.copyWith(scale: nextScale)),
                            );
                      },
                      onPanStart: (details) {
                        _center = _getGlobalCenter();
                        _startDistance =
                            (details.globalPosition - _center).distance;
                        if (_startDistance < 10) _startDistance = 10;
                        _initialScale = textItem.scale;
                      },
                      onPanUpdate: (details) {
                        final currentDistance =
                            (details.globalPosition - _center).distance;
                        final factor = currentDistance / _startDistance;
                        final newScale =
                            (_initialScale * factor).clamp(0.4, 4.0);
                        context.read<EditorBloc>().add(
                              TextUpdated(
                                textItem.copyWith(scale: newScale),
                              ),
                            );
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom-Left: Arc Rotate Handle
                Positioned(
                  bottom: -14,
                  left: -14,
                  child: Transform.scale(
                    scale: handleCounterScale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final newRotation =
                            (textItem.rotation + (math.pi / 4)) % (2 * math.pi);
                        context.read<EditorBloc>().add(
                              TextUpdated(
                                textItem.copyWith(rotation: newRotation),
                              ),
                            );
                      },
                      onPanStart: (details) {
                        _center = _getGlobalCenter();
                        _startAngle = math.atan2(
                          details.globalPosition.dy - _center.dy,
                          details.globalPosition.dx - _center.dx,
                        );
                        _initialRotation = textItem.rotation;
                      },
                      onPanUpdate: (details) {
                        final currentAngle = math.atan2(
                          details.globalPosition.dy - _center.dy,
                          details.globalPosition.dx - _center.dx,
                        );
                        final deltaAngle = currentAngle - _startAngle;
                        final newRotation = _initialRotation + deltaAngle;
                        context.read<EditorBloc>().add(
                              TextUpdated(
                                textItem.copyWith(rotation: newRotation),
                              ),
                            );
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.rotate_right_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Top-Left: Reset Scale & Rotation
                Positioned(
                  top: -14,
                  left: -14,
                  child: Transform.scale(
                    scale: handleCounterScale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        context.read<EditorBloc>().add(
                              TextUpdated(
                                textItem.copyWith(scale: 1.0, rotation: 0.0),
                              ),
                            );
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.cardBorder, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restart_alt_rounded,
                          size: 16,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tool Bar ────────────────────────────────────────────────────────────────

class _ToolBar extends StatefulWidget {
  final SessionModel session;
  final CameraFilter activeFilter;
  final ValueChanged<CameraFilter> onFilterChanged;
  final int? selectedPhotoIndex;
  final VoidCallback onRetake;
  final VoidCallback onDone;

  const _ToolBar({
    required this.session,
    required this.activeFilter,
    required this.onFilterChanged,
    this.selectedPhotoIndex,
    required this.onRetake,
    required this.onDone,
  });

  @override
  State<_ToolBar> createState() => _ToolBarState();
}

class _ToolBarState extends State<_ToolBar> {
  int _selectedTab = 0;
  int _itemCounter = 0;
  final _uuid = const Uuid();

  @override
  Widget build(BuildContext context) {
    return Container(
      // decoration: BoxDecoration(
      //   color: AppColors.surface,
      //   borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      //   border: const Border(
      //     top: BorderSide(color: AppColors.cardBorder, width: 1),
      //   ),
      //   boxShadow: [
      //     BoxShadow(
      //       color: Colors.black.withValues(alpha: 0.05),
      //       blurRadius: 10,
      //       offset: const Offset(0, -2),
      //     ),
      //   ],
      // ),
      child: Column(
        children: [
          // Segmented pill tab control
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEECE6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  _Tab(
                    label: 'Filters',
                    index: 0,
                    selected: _selectedTab,
                    onTap: (i) => setState(() => _selectedTab = i),
                  ),
                  _Tab(
                    label: 'Stickers',
                    index: 1,
                    selected: _selectedTab,
                    onTap: (i) => setState(() => _selectedTab = i),
                  ),
                  _Tab(
                    label: 'Frame',
                    index: 2,
                    selected: _selectedTab,
                    onTap: (i) => setState(() => _selectedTab = i),
                  ),
                  _Tab(
                    label: 'Text',
                    index: 3,
                    selected: _selectedTab,
                    onTap: (i) => setState(() => _selectedTab = i),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SizedBox(
            height: 130,
            child: IndexedStack(
              index: _selectedTab,
              children: [
                // 0. Filters Panel
                _FilterPanel(
                  activeFilter: widget.activeFilter,
                  onSelect: widget.onFilterChanged,
                ),

                // 1. Stickers Panel
                _StickerPanel(
                  onAdd: (path) {
                    _itemCounter++;
                    final offset = (_itemCounter % 6) * 25.0;
                    context.read<EditorBloc>().add(
                          StickerAdded(
                            StickerItem(
                              id: _uuid.v4(),
                              assetPath: path,
                              x: 80 + offset,
                              y: 80 + offset,
                            ),
                          ),
                        );
                  },
                ),

                // 2. Borders Panel
                _BorderPanel(
                  onSelect: (borderId) {
                    context.read<EditorBloc>().add(BorderSelected(borderId));
                  },
                ),

                // 3. Text Panel
                _TextPanel(
                  onAdd: (text, color) {
                    _itemCounter++;
                    final offset = (_itemCounter % 5) * 20.0;
                    context.read<EditorBloc>().add(
                          TextAdded(
                            TextItem(
                              id: _uuid.v4(),
                              text: text,
                              colorValue: color.toARGB32(),
                              fontSize: 26,
                              x: 60 + offset,
                              y: 120 + offset,
                            ),
                          ),
                        );
                  },
                ),
              ],
            ),
          ),

          // ── Bottom Action Row: Retake & Done / Print ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(
              children: [
                // Retake Button — narrow pill
                SizedBox(
                  width: 130,
                  child: OutlinedButton.icon(
                    onPressed: widget.onRetake,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text(
                      'Retake',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Done / Print Button — wide black pill
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text(
                      'Done / Print',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int index;
  final int selected;
  final ValueChanged<int> onTap;

  const _Tab({
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Filter Panel ────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final CameraFilter activeFilter;
  final ValueChanged<CameraFilter> onSelect;

  const _FilterPanel({
    required this.activeFilter,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: CameraFilter.values.length,
      itemBuilder: (context, index) {
        final filter = CameraFilter.values[index];
        final isSelected = filter == activeFilter;
        return GestureDetector(
          onTap: () => onSelect(filter),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 10),
            width: 82,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : const Color(0xFFF5F3EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.black : const Color(0xFFD6D2C8),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : _filterIcon(filter),
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  filter.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _filterSubtitle(filter),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color:
                        isSelected ? Colors.white70 : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _filterIcon(CameraFilter filter) {
    switch (filter) {
      case CameraFilter.natural:
        return Icons.wb_sunny_rounded;
      case CameraFilter.noir:
        return Icons.monochrome_photos_rounded;
      case CameraFilter.retro:
        return Icons.photo_filter_rounded;
      case CameraFilter.pop:
        return Icons.auto_awesome_rounded;
      case CameraFilter.fade:
        return Icons.blur_on_rounded;
    }
  }

  String _filterSubtitle(CameraFilter filter) {
    switch (filter) {
      case CameraFilter.natural:
        return 'Default look';
      case CameraFilter.noir:
        return 'Monochrome';
      case CameraFilter.retro:
        return 'Retro feel';
      case CameraFilter.pop:
        return 'Vivid pop';
      case CameraFilter.fade:
        return 'Soft fade';
    }
  }
}

class _StickerPanel extends StatelessWidget {
  final ValueChanged<String> onAdd;
  const _StickerPanel({required this.onAdd});

  static const _emojis = [
    '😊',
    '😂',
    '😍',
    '🥳',
    '😎',
    '😜',
    '❤️',
    '💖',
    '✨',
    '⭐',
    '🎉',
    '🔥',
    '👑',
    '🕶️',
    '🌸',
    '🐱',
    '🍕',
    '🎂',
    '💋',
    '✌️',
    '📸',
    '🦄',
    '🎀',
    '🎈',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: _emojis.length,
      itemBuilder: (context, index) {
        final emoji = _emojis[index];
        return GestureDetector(
          onTap: () => onAdd('emoji:$emoji'),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD6D2C8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 36)),
          ),
        );
      },
    );
  }
}

class _BorderPanel extends StatelessWidget {
  final ValueChanged<String?> onSelect;
  const _BorderPanel({required this.onSelect});

  static const _borders = [
    {'id': null, 'name': 'None', 'icon': Icons.block_rounded},
    {'id': 'polaroid', 'name': 'Polaroid', 'icon': Icons.crop_portrait_rounded},
    {'id': 'gold', 'name': 'Gold Frame', 'icon': Icons.star_rounded},
    {'id': 'film', 'name': 'Film Strip', 'icon': Icons.movie_creation_rounded},
    {'id': 'pastel', 'name': 'Pastel', 'icon': Icons.favorite_rounded},
    {'id': 'midnight', 'name': 'Midnight', 'icon': Icons.dark_mode_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: _borders.length,
      itemBuilder: (context, index) {
        final item = _borders[index];
        final id = item['id'] as String?;
        final name = item['name'] as String;
        final icon = item['icon'] as IconData;

        return GestureDetector(
          onTap: () => onSelect(id),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            width: 82,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD6D2C8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFF4B5563), size: 26),
                const SizedBox(height: 6),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1E1E1E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TextPanel extends StatefulWidget {
  final void Function(String text, Color color) onAdd;
  const _TextPanel({required this.onAdd});

  @override
  State<_TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends State<_TextPanel> {
  final _controller = TextEditingController();
  Color _selectedColor = Colors.white;

  static const _colors = [
    Colors.white,
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFF4081), // Pink
    Color(0xFF00E5FF), // Cyan
    Color(0xFF76FF03), // Lime
    Color(0xFFFF9100), // Orange
    Colors.black,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onAdd(text, _selectedColor);
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: AppColors.onBackground),
                  decoration: InputDecoration(
                    hintText: 'Type text overlay...',
                    hintStyle: const TextStyle(color: AppColors.onSurface),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Color picker chips
          Row(
            children: [
              const Text(
                'Color:',
                style: TextStyle(color: AppColors.onSurface, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _colors.map((c) {
                    final isSelected = _selectedColor == c;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = c),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.cardBorder,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
