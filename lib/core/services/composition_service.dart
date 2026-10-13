import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/models.dart';

/// Builds the final composed image (and optional GIF) from captured photos
/// plus editor overlays.
///
/// All heavy image operations run in [compute()] isolates so the UI stays
/// responsive during composition.
///
/// Flow:
///   EditorScreen confirms → OutputBloc.OutputStarted
///     → CompositionService.compose(session, stickers, texts, border)
///       → runs in compute() isolate
///       → returns path to composed image
///       → if mode is quad/hex, also creates GIF
///
class CompositionService {
  /// Saves high-resolution rendered canvas bytes (e.g. from RepaintBoundary) directly.
  /// Returns the local file path of the composed image.
  Future<String> saveComposedImageBytes({
    required Uint8List bytes,
    required String sessionId,
  }) async {
    final outputDir = await _getOutputDir();
    final outputPath = p.join(outputDir, '${sessionId}_composed.png');
    final file = File(outputPath);
    await file.writeAsBytes(bytes, flush: true);
    return outputPath;
  }

  /// Composes all images + overlays into a single final image.
  /// Returns the local file path of the composed image.
  Future<String> compose({
    required SessionModel session,
    required List<StickerItem> stickers,
    required List<TextItem> texts,
    required String? borderAssetPath,
  }) async {
    final outputDir = await _getOutputDir();
    final outputPath = p.join(outputDir, '${session.sessionId}_composed.jpg');

    final chosenLayout =
        session.layout ??
        (session.imagePaths.length == 4
            ? LayoutType.grid2x2
            : session.imagePaths.length == 6
            ? LayoutType.grid3x2
            : LayoutType.verticalStrip);

    // Run in isolate to avoid blocking UI
    await compute(
      _composeIsolate,
      _ComposeParams(
        imagePaths: session.imagePaths,
        layout: chosenLayout,
        shotMode: session.shotMode,
        stickers: stickers,
        texts: texts,
        borderAssetPath: borderAssetPath,
        outputPath: outputPath,
        sessionId: session.sessionId,
      ),
    );

    return outputPath;
  }

  /// Creates an animated GIF for quad/hex modes. Returns GIF file path.
  Future<String?> createGif({
    required SessionModel session,
    required int frameDelayMs,
  }) async {
    // Only for quad and hex
    if (session.shotMode != ShotMode.quad && session.shotMode != ShotMode.hex) {
      return null;
    }

    final outputDir = await _getOutputDir();
    final gifPath = p.join(outputDir, '${session.sessionId}.gif');

    await compute(
      _createGifIsolate,
      _GifParams(
        imagePaths: session.imagePaths,
        gifPath: gifPath,
        frameDelayMs: frameDelayMs,
      ),
    );

    return gifPath;
  }

  Future<String> _getOutputDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'sessions'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }
}

// ─── Isolate-safe data classes (no Flutter objects allowed in compute()) ────────

class _ComposeParams {
  final List<String> imagePaths;
  final LayoutType layout;
  final ShotMode shotMode;
  final List<StickerItem> stickers;
  final List<TextItem> texts;
  final String? borderAssetPath;
  final String outputPath;
  final String sessionId;

  _ComposeParams({
    required this.imagePaths,
    required this.layout,
    required this.shotMode,
    required this.stickers,
    required this.texts,
    required this.borderAssetPath,
    required this.outputPath,
    required this.sessionId,
  });
}

class _GifParams {
  final List<String> imagePaths;
  final String gifPath;
  final int frameDelayMs;

  _GifParams({
    required this.imagePaths,
    required this.gifPath,
    required this.frameDelayMs,
  });
}

// ─── Isolate functions ───────────────────────────────────────────────────────

/// Runs in a background isolate. No Flutter/UI objects.
Future<void> _composeIsolate(_ComposeParams params) async {
  final images = params.imagePaths
      .map((path) => img.decodeImage(File(path).readAsBytesSync()))
      .whereType<img.Image>()
      .toList();

  if (images.isEmpty) return;

  img.Image canvas;

  switch (params.layout) {
    case LayoutType.single:
      canvas = images.first;
      break;

    case LayoutType.verticalStrip:
      // Stack all images vertically (classic photo booth strip)
      final w = images.map((i) => i.width).reduce((a, b) => a > b ? a : b);
      final totalH = images.map((i) => i.height).reduce((a, b) => a + b);
      canvas = img.Image(width: w, height: totalH);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      var y = 0;
      for (final im in images) {
        img.compositeImage(canvas, im, dstX: 0, dstY: y);
        y += im.height;
      }
      break;

    case LayoutType.horizontalRow:
      // Place all images side by side horizontally
      final h = images.map((i) => i.height).reduce((a, b) => a > b ? a : b);
      final totalW = images.map((i) => i.width).reduce((a, b) => a + b);
      canvas = img.Image(width: totalW, height: h);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      var x = 0;
      for (final im in images) {
        img.compositeImage(canvas, im, dstX: x, dstY: 0);
        x += im.width;
      }
      break;

    case LayoutType.grid2x2:
      // 2 columns × 2 rows
      canvas = _buildGrid(images, columns: 2);
      break;

    case LayoutType.grid3x2:
      // 3 columns × 2 rows
      canvas = _buildGrid(images, columns: 3);
      break;
  }

  // Apply border frame if selected
  final isPolaroid = params.borderAssetPath == 'polaroid';
  if (params.borderAssetPath != null) {
    canvas = _applyBorder(canvas, params.borderAssetPath!);
  }

  // Draw text overlays onto canvas
  for (final textItem in params.texts) {
    final scaleX = canvas.width / 400.0;
    final scaleY = canvas.height / 533.0;
    final xPos = (textItem.x * scaleX).toInt().clamp(0, canvas.width - 20);
    final yPos = (textItem.y * scaleY).toInt().clamp(0, canvas.height - 20);

    img.drawString(
      canvas,
      textItem.text,
      font: img.arial24,
      x: xPos,
      y: yPos,
      color: img.ColorRgb8(
        (textItem.colorValue >> 16) & 0xFF,
        (textItem.colorValue >> 8) & 0xFF,
        textItem.colorValue & 0xFF,
      ),
    );
  }

  // Apply footer with session ID
  canvas = _addFooter(canvas, params.sessionId, isPolaroid: isPolaroid);

  File(params.outputPath).writeAsBytesSync(img.encodeJpg(canvas, quality: 92));
}

img.Image _applyBorder(img.Image source, String borderId) {
  switch (borderId) {
    case 'polaroid':
      // Polaroid style: padding on top, left, right and wide bottom chin
      final padSide = (source.width * 0.05).toInt().clamp(24, 60);
      final padTop = (source.width * 0.05).toInt().clamp(24, 60);
      final padBottom = (source.width * 0.16).toInt().clamp(70, 180);
      final canvas = img.Image(
        width: source.width + padSide * 2,
        height: source.height + padTop + padBottom,
      );
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(canvas, source, dstX: padSide, dstY: padTop);
      return canvas;

    case 'gold':
      img.drawRect(
        source,
        x1: 15,
        y1: 15,
        x2: source.width - 15,
        y2: source.height - 15,
        color: img.ColorRgb8(255, 215, 0),
        thickness: 12,
      );
      return source;

    case 'neon':
      img.drawRect(
        source,
        x1: 15,
        y1: 15,
        x2: source.width - 15,
        y2: source.height - 15,
        color: img.ColorRgb8(0, 229, 255),
        thickness: 10,
      );
      return source;

    case 'pastel':
      img.drawRect(
        source,
        x1: 15,
        y1: 15,
        x2: source.width - 15,
        y2: source.height - 15,
        color: img.ColorRgb8(255, 128, 171),
        thickness: 12,
      );
      return source;

    case 'midnight':
      img.drawRect(
        source,
        x1: 0,
        y1: 0,
        x2: source.width,
        y2: source.height,
        color: img.ColorRgb8(33, 33, 33),
        thickness: 24,
      );
      return source;

    default:
      return source;
  }
}

img.Image _buildGrid(List<img.Image> images, {required int columns}) {
  final cellW = images.map((i) => i.width).reduce((a, b) => a > b ? a : b);
  final cellH = images.map((i) => i.height).reduce((a, b) => a > b ? a : b);
  final rows = (images.length / columns).ceil();
  final canvas = img.Image(width: cellW * columns, height: cellH * rows);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

  for (int i = 0; i < images.length; i++) {
    final col = i % columns;
    final row = i ~/ columns;
    img.compositeImage(canvas, images[i], dstX: col * cellW, dstY: row * cellH);
  }

  return canvas;
}

img.Image _addFooter(img.Image source, String sessionId, {bool isPolaroid = false}) {
  if (isPolaroid) {
    // Polaroid already has a wide bottom chin! Draw subtle session ID right on the chin
    img.drawString(
      source,
      'Session: $sessionId',
      font: img.arial14,
      x: 16,
      y: source.height - 24,
      color: img.ColorRgb8(120, 120, 120),
    );
    return source;
  }

  // Footer height = 40px; white background with session ID text
  const footerH = 40;
  final canvas = img.Image(
    width: source.width,
    height: source.height + footerH,
  );
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(canvas, source, dstX: 0, dstY: 0);
  img.drawString(
    canvas,
    'Session: $sessionId',
    font: img.arial14,
    x: 10,
    y: source.height + 8,
    color: img.ColorRgb8(0, 0, 0),
  );
  return canvas;
}

Future<void> _createGifIsolate(_GifParams params) async {
  final frames = params.imagePaths
      .map((path) => img.decodeImage(File(path).readAsBytesSync()))
      .whereType<img.Image>()
      .toList();

  if (frames.isEmpty) return;

  // Resize all frames to the same size
  final w = frames.first.width;
  final h = frames.first.height;
  final resized = frames
      .map((f) => img.copyResize(f, width: w, height: h))
      .toList();

  // Build GIF animation
  final gifEncoder = img.GifEncoder(
    delay: params.frameDelayMs ~/ 10,
  ); // centiseconds
  for (final frame in resized) {
    gifEncoder.addFrame(frame);
  }

  final bytes = gifEncoder.finish();
  if (bytes != null) {
    File(params.gifPath).writeAsBytesSync(bytes);
  }
}
