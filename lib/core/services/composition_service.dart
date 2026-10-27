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
    String? logoPath,
    String? brandText,
  }) async {
    final outputDir = await _getOutputDir();
    final outputPath = p.join(outputDir, '${session.sessionId}_composed.jpg');

    final chosenLayout = session.layout ??
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
        logoPath: logoPath,
        brandText: brandText,
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
  final String? logoPath;
  final String? brandText;
  final String outputPath;
  final String sessionId;

  _ComposeParams({
    required this.imagePaths,
    required this.layout,
    required this.shotMode,
    required this.stickers,
    required this.texts,
    required this.borderAssetPath,
    this.logoPath,
    this.brandText,
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

    case LayoutType.bendo:
      // 2 columns staggered bento collage (3, 4, or 6 photos)
      canvas = _buildBendo(images, brandText: params.brandText);
      break;
  }

  // Apply border frame if selected
  final isPolaroid = params.borderAssetPath == 'polaroid';
  if (params.borderAssetPath != null) {
    canvas = _applyBorder(canvas, params.borderAssetPath!);
  }

  // Wrap canvas in white frame with top logo bar and matching bottom chin
  if (params.logoPath != null && File(params.logoPath!).existsSync()) {
    final headerH = (canvas.height * 0.08).toInt().clamp(60, 180);
    final footerH = headerH; // same height as top header
    const sideBorder = 0;

    final framedCanvas = img.Image(
      width: canvas.width + sideBorder * 2,
      height: canvas.height + headerH + footerH,
    );
    img.fill(framedCanvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(framedCanvas, canvas, dstX: sideBorder, dstY: headerH);

    try {
      final logoImg = img.decodeImage(File(params.logoPath!).readAsBytesSync());
      if (logoImg != null) {
        final targetH = (headerH * 0.75).toInt();
        final targetW = (logoImg.width * (targetH / logoImg.height)).toInt();
        final resizedLogo =
            img.copyResize(logoImg, width: targetW, height: targetH);
        final dstX = (framedCanvas.width - resizedLogo.width) ~/ 2;
        final dstY = (headerH - resizedLogo.height) ~/ 2;
        img.compositeImage(framedCanvas, resizedLogo, dstX: dstX, dstY: dstY);
      }
    } catch (_) {}

    canvas = framedCanvas;
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
      // Polaroid style: padding on top and wide bottom chin (no side padding)
      const padSide = 0;
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

img.Image _cropAndResizeImage(img.Image src, int targetW, int targetH) {
  final srcRatio = src.width / src.height;
  final targetRatio = targetW / targetH;

  int cropW, cropH, cropX, cropY;
  if (srcRatio > targetRatio) {
    cropH = src.height;
    cropW = (src.height * targetRatio).toInt();
    cropX = (src.width - cropW) ~/ 2;
    cropY = 0;
  } else {
    cropW = src.width;
    cropH = (src.width / targetRatio).toInt();
    cropX = 0;
    cropY = (src.height - cropH) ~/ 2;
  }

  final cropped =
      img.copyCrop(src, x: cropX, y: cropY, width: cropW, height: cropH);
  final resized = img.copyResize(cropped, width: targetW, height: targetH);

  img.drawRect(
    resized,
    x1: 0,
    y1: 0,
    x2: targetW - 1,
    y2: targetH - 1,
    color: img.ColorRgb8(40, 40, 40),
    thickness: 4,
  );

  return resized;
}

img.Image _buildBendo(List<img.Image> images, {String? brandText}) {
  const canvasW = 1200;
  const canvasH = 1800; // 2:3 ratio
  final canvas = img.Image(width: canvasW, height: canvasH);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

  const gap = 20;
  const margin = 24;
  final colW = (canvasW - (margin * 2) - gap) ~/ 2;
  final leftX = margin;
  final rightX = margin + colW + gap;
  final colH = canvasH - (margin * 2);

  void drawBrandBadge(int x, int y, int width, int height) {
    final text = (brandText != null && brandText.trim().isNotEmpty)
        ? brandText.trim()
        : 'Pic-nPrint';
    final textX = x + (width - (text.length * 14)) ~/ 2;
    final textY = y + (height - 24) ~/ 2;
    img.drawString(
      canvas,
      text,
      font: img.arial24,
      x: textX.clamp(x, x + width - 10),
      y: textY.clamp(y, y + height - 10),
      color: img.ColorRgb8(40, 40, 40),
    );
  }

  if (images.length <= 3) {
    // 3 Shots: Left hero photo + Right 2 photos with brand badge
    final im0 = _cropAndResizeImage(images[0], colW, colH);
    img.compositeImage(canvas, im0, dstX: leftX, dstY: margin);

    const brandH = 60;
    final rightPhotoH = (colH - brandH - (gap * 2)) ~/ 2;
    final im1 = _cropAndResizeImage(
        images.length > 1 ? images[1] : images[0], colW, rightPhotoH);
    final im2 = _cropAndResizeImage(
        images.length > 2 ? images[2] : images[0], colW, rightPhotoH);

    img.compositeImage(canvas, im1, dstX: rightX, dstY: margin);
    drawBrandBadge(rightX, margin + rightPhotoH + gap, colW, brandH);
    img.compositeImage(canvas, im2,
        dstX: rightX, dstY: margin + rightPhotoH + gap + brandH + gap);
  } else if (images.length <= 4) {
    // 4 Shots: Left 2 photos (flex 2, flex 3) + Right 2 photos (flex 3, flex 2) + brand badge
    final leftAvailH = colH - gap;
    final lh0 = (leftAvailH * 2) ~/ 5;
    final lh1 = leftAvailH - lh0;

    final im0 = _cropAndResizeImage(images[0], colW, lh0);
    final im1 = _cropAndResizeImage(images[1], colW, lh1);
    img.compositeImage(canvas, im0, dstX: leftX, dstY: margin);
    img.compositeImage(canvas, im1, dstX: leftX, dstY: margin + lh0 + gap);

    const brandH = 50;
    final rightAvailH = colH - brandH - (gap * 2);
    final rh0 = (rightAvailH * 3) ~/ 5;
    final rh1 = rightAvailH - rh0;

    final im2 = _cropAndResizeImage(images[2], colW, rh0);
    final im3 = _cropAndResizeImage(images[3], colW, rh1);

    img.compositeImage(canvas, im2, dstX: rightX, dstY: margin);
    drawBrandBadge(rightX, margin + rh0 + gap, colW, brandH);
    img.compositeImage(canvas, im3,
        dstX: rightX, dstY: margin + rh0 + gap + brandH + gap);
  } else {
    // 6 Shots (or 5+): Left 3 photos + Right 3 photos + brand badge
    final leftAvailH = colH - (gap * 2);
    final lh0 = (leftAvailH * 2) ~/ 7;
    final lh1 = (leftAvailH * 3) ~/ 7;
    final lh2 = leftAvailH - lh0 - lh1;

    final im0 = _cropAndResizeImage(images[0], colW, lh0);
    final im1 = _cropAndResizeImage(images[1], colW, lh1);
    final im2 = _cropAndResizeImage(images[2], colW, lh2);

    img.compositeImage(canvas, im0, dstX: leftX, dstY: margin);
    img.compositeImage(canvas, im1, dstX: leftX, dstY: margin + lh0 + gap);
    img.compositeImage(canvas, im2,
        dstX: leftX, dstY: margin + lh0 + gap + lh1 + gap);

    const brandH = 50;
    final rightAvailH = colH - brandH - (gap * 3);
    final rh0 = (rightAvailH * 3) ~/ 7;
    final rh1 = (rightAvailH * 2) ~/ 7;
    final rh2 = rightAvailH - rh0 - rh1;

    final im3 = _cropAndResizeImage(images[3], colW, rh0);
    final im4 = _cropAndResizeImage(
        images.length > 4 ? images[4] : images[0], colW, rh1);
    final im5 = _cropAndResizeImage(
        images.length > 5 ? images[5] : images[0], colW, rh2);

    img.compositeImage(canvas, im3, dstX: rightX, dstY: margin);
    drawBrandBadge(rightX, margin + rh0 + gap, colW, brandH);
    img.compositeImage(canvas, im4,
        dstX: rightX, dstY: margin + rh0 + gap + brandH + gap);
    img.compositeImage(canvas, im5,
        dstX: rightX, dstY: margin + rh0 + gap + brandH + gap + rh1 + gap);
  }

  return canvas;
}

img.Image _addFooter(img.Image source, String sessionId,
    {bool isPolaroid = false}) {
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
  final resized =
      frames.map((f) => img.copyResize(f, width: w, height: h)).toList();

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
