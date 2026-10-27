import 'dart:io';
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
          compositionService: context.read(), session: widget.session),
      child: BlocConsumer<EditorBloc, EditorState>(
        listener: (context, state) {
          if (state.composedPath != null && !state.isComposing) {
            final updated = widget.session.copyWith(
              composedImagePath: state.composedPath,
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
              title: const Text('Edit Photo'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: isProcessing ? null : () => context.pop(),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton(
                    onPressed: isProcessing ? null : () => _handleDone(context),
                    child: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Done',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                // ── Canvas ────────────────────────────────────────────────────
                Expanded(
                  child: _EditorCanvas(
                    session: widget.session,
                    editorState: state,
                    canvasKey: _canvasKey,
                    isCapturing: _isCapturing,
                  ),
                ),

                // ── Tool Tabs ─────────────────────────────────────────────────
                _ToolBar(session: widget.session),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Canvas ───────────────────────────────────────────────────────────────────

class _EditorCanvas extends StatelessWidget {
  final SessionModel session;
  final EditorState editorState;
  final GlobalKey canvasKey;
  final bool isCapturing;

  const _EditorCanvas({
    required this.session,
    required this.editorState,
    required this.canvasKey,
    required this.isCapturing,
  });

  double _getAspectRatio() {
    final paths = session.imagePaths;
    if (paths.length <= 1) return 3 / 4;

    final layout = session.layout ??
        (paths.length == 4
            ? LayoutType.grid2x2
            : paths.length == 6
                ? LayoutType.grid3x2
                : LayoutType.verticalStrip);

    switch (layout) {
      case LayoutType.single:
        return 3 / 4;
      case LayoutType.verticalStrip:
        return paths.length >= 3 ? 1 / 2.2 : 9 / 16;
      case LayoutType.horizontalRow:
        return paths.length >= 3 ? 16 / 10 : 4 / 3;
      case LayoutType.grid2x2:
        return 1.0;
      case LayoutType.grid3x2:
        return 3 / 2;
    }
  }

  EdgeInsets _getBorderPadding() {
    switch (editorState.borderAssetPath) {
      case 'polaroid':
        return const EdgeInsets.fromLTRB(16, 16, 16, 56);
      case 'gold':
        return const EdgeInsets.all(14);
      case 'film':
        return const EdgeInsets.symmetric(vertical: 30, horizontal: 8);
      case 'pastel':
        return const EdgeInsets.all(12);
      case 'midnight':
        return const EdgeInsets.all(16);
      default:
        return EdgeInsets.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPolaroid = editorState.borderAssetPath == 'polaroid';
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 520),
        child: AspectRatio(
          aspectRatio: _getAspectRatio(),
          child: RepaintBoundary(
            key: canvasKey,
            child: Container(
              decoration: BoxDecoration(
                color: isPolaroid ? Colors.white : Colors.black,
                borderRadius:
                    isCapturing ? BorderRadius.zero : BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius:
                    isCapturing ? BorderRadius.zero : BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── 1. Base Multi-Photo Layer (Centered with Border Inset) ─────
                    Padding(
                        padding: _getBorderPadding(),
                        child: _buildPhotoLayout()),

                    // ── 2. Border Frame Overlay Layer ─────────────────────────────
                    if (editorState.borderAssetPath != null)
                      _BorderOverlay(borderId: editorState.borderAssetPath!),

                    // ── 3. Polaroid Session ID Chin Text ──────────────────────────
                    if (isPolaroid)
                      Positioned(
                        bottom: 14,
                        left: 20,
                        child: Text(
                          'Session: ${session.sessionId}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                    // ── 4. Sticker Overlays Layer ─────────────────────────────────
                    ...editorState.stickers.map(
                      (s) =>
                          _StickerWidget(sticker: s, isCapturing: isCapturing),
                    ),

                    // ── 5. Text Overlays Layer ────────────────────────────────────
                    ...editorState.texts.map(
                      (t) => _TextWidget(textItem: t, isCapturing: isCapturing),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoLayout() {
    final paths = session.imagePaths;
    final hasBorder = editorState.borderAssetPath != null;

    if (paths.isEmpty) return _errorPlaceholder();
    if (paths.length == 1) return _buildBaseImage(paths.first);
    final layout = session.layout ??
        (paths.length == 4
            ? LayoutType.grid2x2
            : paths.length == 6
                ? LayoutType.grid3x2
                : LayoutType.verticalStrip);

    switch (layout) {
      case LayoutType.single:
        return _buildBaseImage(paths.first);

      case LayoutType.verticalStrip:
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border:
                hasBorder ? null : Border.all(color: Colors.white, width: 4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < paths.length; i++) ...[
                if (i > 0) Container(height: 4, color: Colors.white),
                Expanded(child: _buildBaseImage(paths[i])),
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
                Expanded(child: _buildBaseImage(paths[i])),
              ],
            ],
          ),
        );

      case LayoutType.grid2x2:
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border:
                hasBorder ? null : Border.all(color: Colors.white, width: 4),
          ),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildBaseImage(paths[0])),
                    Container(width: 4, color: Colors.white),
                    Expanded(
                      child: _buildBaseImage(
                        paths.length > 1 ? paths[1] : paths[0],
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
                      child: _buildBaseImage(
                        paths.length > 2 ? paths[2] : paths[0],
                      ),
                    ),
                    Container(width: 4, color: Colors.white),
                    Expanded(
                      child: _buildBaseImage(
                        paths.length > 3 ? paths[3] : paths[0],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case LayoutType.grid3x2:
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border:
                hasBorder ? null : Border.all(color: Colors.white, width: 4),
          ),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) Container(width: 4, color: Colors.white),
                      Expanded(
                        child: _buildBaseImage(
                          paths.length > i ? paths[i] : paths[0],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(height: 4, color: Colors.white),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 3; i < 6; i++) ...[
                      if (i > 3) Container(width: 4, color: Colors.white),
                      Expanded(
                        child: _buildBaseImage(
                          paths.length > i ? paths[i] : paths[0],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildBaseImage(String path) {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
      );
    }

    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
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

// ─── Border Frame Overlay ─────────────────────────────────────────────────────

class _BorderOverlay extends StatelessWidget {
  final String borderId;
  const _BorderOverlay({required this.borderId});

  @override
  Widget build(BuildContext context) {
    switch (borderId) {
      case 'polaroid':
        // Polaroid frame is created cleanly by container background and padding
        return const SizedBox.shrink();

      case 'gold':
        return Container(
          padding: const EdgeInsets.all(10),
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
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF80AB), width: 6),
          ),
        );

      case 'midnight':
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF212121), width: 16),
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

// ─── Sticker Widget ───────────────────────────────────────────────────────────

class _StickerWidget extends StatelessWidget {
  final StickerItem sticker;
  final bool isCapturing;
  const _StickerWidget({required this.sticker, this.isCapturing = false});

  @override
  Widget build(BuildContext context) {
    final isEmoji = sticker.assetPath.startsWith('emoji:');
    final emojiChar =
        isEmoji ? sticker.assetPath.replaceFirst('emoji:', '') : '';

    return Positioned(
      left: sticker.x,
      top: sticker.y,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Drag and long-press area
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: isCapturing
                ? null
                : (d) {
                    context.read<EditorBloc>().add(
                          StickerUpdated(
                            sticker.copyWith(
                              x: sticker.x + d.delta.dx,
                              y: sticker.y + d.delta.dy,
                            ),
                          ),
                        );
                  },
            onLongPress: isCapturing
                ? null
                : () =>
                    context.read<EditorBloc>().add(StickerDeleted(sticker.id)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Transform.rotate(
                angle: sticker.rotation,
                child: Transform.scale(
                  scale: sticker.scale,
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
            ),
          ),

          // Delete button (hidden when capturing final snapshot)
          if (!isCapturing)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  context.read<EditorBloc>().add(StickerDeleted(sticker.id));
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Text Widget ──────────────────────────────────────────────────────────────

class _TextWidget extends StatelessWidget {
  final TextItem textItem;
  final bool isCapturing;
  const _TextWidget({required this.textItem, this.isCapturing = false});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: textItem.x,
      top: textItem.y,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Drag and long-press area
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: isCapturing
                ? null
                : (d) {
                    context.read<EditorBloc>().add(
                          TextUpdated(
                            textItem.copyWith(
                              x: textItem.x + d.delta.dx,
                              y: textItem.y + d.delta.dy,
                            ),
                          ),
                        );
                  },
            onLongPress: isCapturing
                ? null
                : () =>
                    context.read<EditorBloc>().add(TextDeleted(textItem.id)),
            child: Padding(
              padding: isCapturing
                  ? const EdgeInsets.all(6.0)
                  : const EdgeInsets.fromLTRB(6, 6, 20, 6),
              child: Text(
                textItem.text,
                style: TextStyle(
                  fontSize: textItem.fontSize,
                  fontWeight: FontWeight.bold,
                  color: Color(textItem.colorValue),
                  fontFamily: textItem.fontFamily,
                  shadows: const [
                    Shadow(
                      blurRadius: 6,
                      color: Colors.black,
                      offset: Offset(1.5, 1.5),
                    ),
                    Shadow(
                      blurRadius: 6,
                      color: Colors.black87,
                      offset: Offset(-1, -1),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Delete button (hidden when capturing final snapshot)
          if (!isCapturing)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  context.read<EditorBloc>().add(TextDeleted(textItem.id));
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Tool Bar ─────────────────────────────────────────────────────────────────

class _ToolBar extends StatefulWidget {
  final SessionModel session;
  const _ToolBar({required this.session});

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
      height: 210,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Tab selector
          Row(
            children: [
              _Tab(
                label: 'Stickers',
                icon: Icons.emoji_emotions_rounded,
                index: 0,
                selected: _selectedTab,
                onTap: (i) => setState(() => _selectedTab = i),
              ),
              _Tab(
                label: 'Borders',
                icon: Icons.crop_square_rounded,
                index: 1,
                selected: _selectedTab,
                onTap: (i) => setState(() => _selectedTab = i),
              ),
              _Tab(
                label: 'Text',
                icon: Icons.text_fields_rounded,
                index: 2,
                selected: _selectedTab,
                onTap: (i) => setState(() => _selectedTab = i),
              ),
            ],
          ),

          const Divider(height: 1, color: Colors.white12),

          // Content
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
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
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final int index;
  final int selected;
  final ValueChanged<int> onTap;

  const _Tab({
    required this.label,
    required this.icon,
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.onSurface,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 34)),
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
            width: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.primary, size: 28),
                const SizedBox(height: 6),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type text overlay...',
                    hintStyle: const TextStyle(color: Colors.white38),
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                style: TextStyle(color: Colors.white70, fontSize: 12),
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
                            color:
                                isSelected ? AppColors.primary : Colors.white30,
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
