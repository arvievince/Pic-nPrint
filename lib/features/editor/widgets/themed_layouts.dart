import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

/// Builds a photo widget for slot [index] inside a themed layout.
typedef PhotoSlotBuilder = Widget Function(int index);

/// Renders the active [LayoutType] photobooth theme inside `_EditorCanvas`.
class ThemedLayoutCanvas extends StatelessWidget {
  final LayoutType layout;
  final SessionModel session;
  final Color frameColor;
  final bool renderForPrint;
  final String? logoPath;
  final String? brandText;
  final String? cloudQrUrl;
  final PhotoSlotBuilder buildPhotoSlot;

  const ThemedLayoutCanvas({
    super.key,
    required this.layout,
    required this.session,
    required this.frameColor,
    required this.renderForPrint,
    required this.logoPath,
    required this.brandText,
    required this.cloudQrUrl,
    required this.buildPhotoSlot,
  });

  bool get _hasLogo => logoPath != null && File(logoPath!).existsSync();

  String get _displayBrand =>
      (brandText != null && brandText!.trim().isNotEmpty)
          ? brandText!.trim()
          : 'Pic & Print';

  Widget _buildLogoWidget({
    required Color tintColor,
    bool applyTint = false,
    double maxHeight = 44,
    double fontSize = 15,
  }) {
    if (_hasLogo) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Image.file(
          File(logoPath!),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          color: applyTint ? tintColor : null,
          colorBlendMode: applyTint ? BlendMode.srcIn : null,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt_rounded, color: tintColor, size: fontSize + 3),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _displayBrand,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tintColor,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  /// Standard adaptive photo arrangement for 1, 2, 3, 4, 6, 8 shots.
  Widget _buildStandardPhotoGrid({
    double gap = 6,
    double borderRadius = 0,
    Color? slotBorderColor,
    double slotBorderWidth = 0,
    bool twoShotSideBySide = false,
  }) {
    final count = session.imagePaths.length;
    if (count == 0) {
      return const Center(child: Icon(Icons.broken_image_rounded, size: 48));
    }

    Widget slot(int index) {
      final safeIndex = index < count ? index : 0;
      Widget child = buildPhotoSlot(safeIndex);
      if (borderRadius > 0) {
        child = ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: child,
        );
      }
      if (slotBorderColor != null && slotBorderWidth > 0) {
        child = Container(
          decoration: BoxDecoration(
            border: Border.all(color: slotBorderColor, width: slotBorderWidth),
            borderRadius:
                borderRadius > 0 ? BorderRadius.circular(borderRadius) : null,
          ),
          child: child,
        );
      }
      return child;
    }

    if (count == 1) {
      return slot(0);
    }

    if (count == 2 && twoShotSideBySide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: slot(0)),
          SizedBox(width: gap),
          Expanded(child: slot(1)),
        ],
      );
    }

    if (count <= 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < count; i++) ...[
            if (i > 0) SizedBox(height: gap),
            Expanded(child: slot(i)),
          ],
        ],
      );
    }

    // 4, 6, 8 shots → 2-column grid
    final rows = (count / 2).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int r = 0; r < rows; r++) ...[
          if (r > 0) SizedBox(height: gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: slot(r * 2)),
                SizedBox(width: gap),
                Expanded(
                  child: (r * 2 + 1 < count)
                      ? slot(r * 2 + 1)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (layout) {
      case LayoutType.classicStrip:
        return _buildClassicStrip();
      case LayoutType.receipt:
        return _buildReceipt();
      case LayoutType.spotify:
        return _buildSpotify();
      case LayoutType.filmStrip:
        return _buildFilmStrip();
      case LayoutType.boardingPass:
        return _buildBoardingPass();
      case LayoutType.polaroid:
        return _buildPolaroid();
      case LayoutType.instagram:
        return _buildInstagram();
      case LayoutType.bento:
        return _buildBento();
      case LayoutType.onePieceWanted:
        return _buildOnePieceWanted();
      case LayoutType.theaterTicket:
        return _buildTheaterTicket();
    }
  }

  // ── 1. Classic Strip ────────────────────────────────────────────────────────
  Widget _buildClassicStrip() {
    final bg = renderForPrint ? Colors.white : frameColor;
    final isDark = bg.computeLuminance() < 0.5;
    final ink = isDark ? Colors.white : Colors.black;
    final customColor = bg.toARGB32() != Colors.white.toARGB32();

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildStandardPhotoGrid(gap: 6)),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: Center(
              child: _buildLogoWidget(
                tintColor: ink,
                applyTint: customColor,
                maxHeight: 46,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Receipt ──────────────────────────────────────────────────────────────
  Widget _buildReceipt() {
    final bg = renderForPrint ? Colors.white : const Color(0xFFF6F5F0);
    const ink = Color(0xFF1A1A1A);
    final dateStr =
        DateFormat('MMM dd, yyyy').format(session.createdAt).toUpperCase();
    final showQr = cloudQrUrl != null && cloudQrUrl!.isNotEmpty;
    final mono = GoogleFonts.courierPrime(color: ink);

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top uploaded logo
          Center(
            child: _buildLogoWidget(
              tintColor: ink,
              applyTint: renderForPrint,
              maxHeight: 36,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'TRACK ORDER',
            textAlign: TextAlign.center,
            style: mono.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            dateStr,
            textAlign: TextAlign.center,
            style: mono.copyWith(fontSize: 8.5, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          _DashedDivider(color: ink.withValues(alpha: 0.65)),
          const SizedBox(height: 4),
          _receiptLine(
            mono,
            '01  ${session.shotMode.label.toUpperCase()} SESSION',
            '03:31',
          ),
          _receiptLine(
            mono,
            '02  ${session.imagePaths.length}x CAPTURED MOMENTS',
            '04:00',
          ),
          const SizedBox(height: 3),
          _DashedDivider(color: ink.withValues(alpha: 0.65)),
          const SizedBox(height: 3),
          _receiptLine(mono, 'TOTAL', 'PRICELESS', bold: true),
          _DashedDivider(color: ink.withValues(alpha: 0.65)),
          const SizedBox(height: 8),

          // Photos
          Expanded(
            child: _buildStandardPhotoGrid(gap: 5),
          ),
          const SizedBox(height: 8),

          // Keepsake quote
          Text(
            'Crafted for the now means made for what matters most. '
            'Because some moments deserve to be felt, not just remembered.',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: mono.copyWith(fontSize: 7.5, height: 1.25),
          ),
          const SizedBox(height: 4),
          Text(
            'ALL RIGHTS RESERVED',
            textAlign: TextAlign.center,
            style: mono.copyWith(fontSize: 7.5, letterSpacing: 1.2),
          ),

          // Conditional QR code only when Cloud is set up
          if (showQr) ...[
            const SizedBox(height: 6),
            Center(
              child: QrImageView(
                data: cloudQrUrl!,
                version: QrVersions.auto,
                size: 54,
                padding: EdgeInsets.zero,
                backgroundColor: bg,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: ink,
                ),
              ),
            ),
          ],
          const SizedBox(height: 5),
          _DashedDivider(color: ink.withValues(alpha: 0.65)),
          const SizedBox(height: 4),
          Text(
            'THE ART OF THE MOMENT',
            textAlign: TextAlign.center,
            style: mono.copyWith(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptLine(TextStyle mono, String left, String right,
      {bool bold = false}) {
    final style = mono.copyWith(
      fontSize: 8.5,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(left, style: style, overflow: TextOverflow.ellipsis),
        ),
        Text(right, style: style),
      ],
    );
  }

  // ── 3. Spotify Theme ────────────────────────────────────────────────────────
  Widget _buildSpotify() {
    final bg = renderForPrint ? Colors.white : frameColor;
    final isDark = bg.computeLuminance() < 0.5;
    final ink = isDark ? Colors.white : const Color(0xFF111827);
    final customColor = bg.toARGB32() != Colors.white.toARGB32();
    final dateStr = DateFormat('MMM dd, yyyy').format(session.createdAt);

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top uploaded logo + soundwave graphic
          SizedBox(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: _buildLogoWidget(
                    tintColor: ink,
                    applyTint: customColor,
                    maxHeight: 26,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 82,
                  height: 22,
                  child: CustomPaint(
                    painter: _SpotifyWavePainter(color: ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Rounded dark-bordered photos
          Expanded(
            child: _buildStandardPhotoGrid(
              gap: 7,
              borderRadius: 10,
              slotBorderColor: ink,
              slotBorderWidth: 1.8,
            ),
          ),
          const SizedBox(height: 10),

          // Song title & subtitle
          Text(
            _displayBrand,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Photo booth session · $dateStr',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ink.withValues(alpha: 0.65),
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Progress scrubber
          Row(
            children: [
              Text(
                '0:24',
                style: TextStyle(
                  color: ink.withValues(alpha: 0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 10,
                  child: CustomPaint(
                    painter: _ScrubberPainter(color: ink, progress: 0.35),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '4:20',
                style: TextStyle(
                  color: ink.withValues(alpha: 0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Media player controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(Icons.shuffle_rounded,
                  size: 16, color: ink.withValues(alpha: 0.7)),
              Icon(Icons.skip_previous_rounded, size: 24, color: ink),
              Icon(Icons.pause_circle_filled_rounded, size: 34, color: ink),
              Icon(Icons.skip_next_rounded, size: 24, color: ink),
              Icon(Icons.repeat_rounded,
                  size: 16, color: ink.withValues(alpha: 0.7)),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. Film Strip ───────────────────────────────────────────────────────────
  Widget _buildFilmStrip() {
    const stripBg = Color(0xFF111111);
    const ink = Colors.white;
    final dateStr = DateFormat('yyyy-MM-dd').format(session.createdAt);

    return Container(
      color: stripBg,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sprocket rails + photo frames
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 18,
                  child: CustomPaint(painter: _FilmSprocketPainter()),
                ),
                Expanded(
                  child: _buildStandardPhotoGrid(gap: 7),
                ),
                SizedBox(
                  width: 18,
                  child: CustomPaint(painter: _FilmSprocketPainter()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Clapperboard slate footer + uploaded logo on bottom
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              border: Border.all(color: Colors.white54, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Diagonal clapper stripes
                SizedBox(
                  height: 12,
                  width: double.infinity,
                  child: CustomPaint(painter: _ClapperStripePainter()),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DATE: $dateStr',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'TAKE: ${session.imagePaths.length}   SCENE: BOOTH',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Flexible(
                        child: _buildLogoWidget(
                          tintColor: ink,
                          applyTint: true,
                          maxHeight: 28,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Boarding Pass ────────────────────────────────────────────────────────
  Widget _buildBoardingPass() {
    final bg = renderForPrint ? Colors.white : const Color(0xFFFDFCF9);
    final accent =
        renderForPrint ? Colors.black : const Color(0xFFDC2626); // Airline red
    const ink = Color(0xFF111827);
    final loc = session.voucher.locationId.toUpperCase();
    final dateStr = DateFormat('ddMMM').format(session.createdAt).toUpperCase();
    final timeStr = DateFormat('hh:mma').format(session.createdAt);

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top airline banner with uploaded logo
          Container(
            color: accent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: _buildLogoWidget(
                    tintColor: Colors.white,
                    applyTint: true,
                    maxHeight: 22,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'BOARDING PASS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.flight_takeoff_rounded,
                        color: Colors.white, size: 14),
                  ],
                ),
              ],
            ),
          ),

          // Flight details block
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _flightField('FLIGHT', 'PNP 380', ink, large: true),
                    _flightField(
                      'FROM / TO',
                      '$loc ✈ MEM',
                      ink,
                      large: true,
                      alignEnd: true,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _flightField('DATE', dateStr, ink),
                    _flightField('GATE', 'A34', ink),
                    _flightField('TIME', timeStr, ink),
                    _flightField(
                      'SEAT',
                      '${session.imagePaths.length}D',
                      ink,
                      alignEnd: true,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Photo area + vertical microtext
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RotatedBox(
                    quarterTurns: 3,
                    child: Center(
                      child: Text(
                        'GATE CLOSES 25 MINUTES BEFORE DEPARTURE',
                        style: TextStyle(
                          color: accent,
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(child: _buildStandardPhotoGrid(gap: 5)),
                ],
              ),
            ),
          ),

          // Dashed tear-line + 1D Barcode stub
          const SizedBox(height: 6),
          _DashedDivider(color: Colors.black38),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: SizedBox(
              height: 36,
              child: BarcodeWidget(
                barcode: Barcode.code128(),
                data: session.sessionId,
                drawText: false,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flightField(String label, String value, Color ink,
      {bool large = false, bool alignEnd = false}) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: ink.withValues(alpha: 0.55),
            fontSize: 7,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: ink,
            fontSize: large ? 13 : 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  // ── 6. Polaroid ─────────────────────────────────────────────────────────────
  Widget _buildPolaroid() {
    final bg = renderForPrint ? Colors.white : frameColor;
    final isDark = bg.computeLuminance() < 0.5;
    final ink = isDark ? Colors.white : const Color(0xFF111827);
    final customColor = bg.toARGB32() != Colors.white.toARGB32();

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                  width: 1,
                ),
              ),
              child: _buildStandardPhotoGrid(gap: 5),
            ),
          ),
          // Signature deep Polaroid bottom chin with uploaded logo
          SizedBox(
            height: 70,
            child: Center(
              child: _buildLogoWidget(
                tintColor: ink,
                applyTint: customColor,
                maxHeight: 46,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. Instagram ────────────────────────────────────────────────────────────
  Widget _buildInstagram() {
    final bg = renderForPrint ? Colors.white : const Color(0xFFFAF9F5);
    const ink = Color(0xFF111827);
    final handle = _displayBrand.toLowerCase().replaceAll(' ', '');
    final dateStr = DateFormat('MMM d').format(session.createdAt).toLowerCase();

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top IG profile bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                // Story-ring circular avatar with uploaded logo
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: renderForPrint
                        ? null
                        : const LinearGradient(
                            colors: [
                              Color(0xFFFEDA75),
                              Color(0xFFFA7E1E),
                              Color(0xFFD62976),
                              Color(0xFF962FBF),
                            ],
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                          ),
                    border: renderForPrint
                        ? Border.all(color: Colors.black, width: 1.5)
                        : null,
                  ),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _hasLogo
                        ? Image.file(File(logoPath!), fit: BoxFit.contain)
                        : const Icon(Icons.camera_alt_rounded,
                            size: 13, color: ink),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Icon(Icons.more_horiz_rounded, color: ink, size: 18),
              ],
            ),
          ),

          // Edge-to-edge photos (2-shot uses 2x1 side-by-side split)
          Expanded(
            child: _buildStandardPhotoGrid(
              gap: 2.5,
              twoShotSideBySide: true,
            ),
          ),

          // Bottom action icons + likes + caption
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 19,
                      color: renderForPrint ? ink : const Color(0xFFE11D48),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 18, color: ink),
                    const SizedBox(width: 10),
                    const Icon(Icons.send_outlined, size: 18, color: ink),
                    const Spacer(),
                    const Icon(Icons.bookmark_border_rounded,
                        size: 19, color: ink),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '1,204 likes',
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 1),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(color: ink, fontSize: 10),
                    children: [
                      TextSpan(
                        text: '$handle ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: 'Photo booth day · $dateStr'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 8. Bento (only > 2 images) ──────────────────────────────────────────────
  Widget _buildBento() {
    final bg = renderForPrint ? Colors.white : frameColor;
    final isDark = bg.computeLuminance() < 0.5;
    final ink = isDark ? Colors.white : Colors.black;
    final customColor = bg.toARGB32() != Colors.white.toARGB32();
    final paths = session.imagePaths;
    final total = paths.length;
    final leftCount = (total == 3) ? 1 : (total / 2).ceil();

    List<int> getFlexes(int count, bool startWithTall) {
      return List.generate(count, (i) {
        if (count == 1) return 1;
        final isTall = startWithTall ? (i % 2 == 0) : (i % 2 == 1);
        return isTall ? 3 : 2;
      });
    }

    final leftFlexes = getFlexes(leftCount, true);
    final rightCount = total - leftCount;
    final rightFlexes = getFlexes(rightCount, false);
    const gap = 7.0;

    Widget card(int idx) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: buildPhotoSlot(idx),
        );

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: total <= 1
                ? card(0)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < leftCount; i++) ...[
                              if (i > 0) const SizedBox(height: gap),
                              Expanded(flex: leftFlexes[i], child: card(i)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: gap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < rightCount; i++) ...[
                              if (i > 0) const SizedBox(height: gap),
                              Expanded(
                                flex: rightFlexes[i],
                                child: card(leftCount + i),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: Center(
              child: _buildLogoWidget(
                tintColor: ink,
                applyTint: customColor,
                maxHeight: 42,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 9. One Piece Wanted ─────────────────────────────────────────────────────
  Widget _buildOnePieceWanted() {
    final bg = renderForPrint ? Colors.white : const Color(0xFFEAE0C8);
    final ink = renderForPrint ? Colors.black : const Color(0xFF3B2818);
    final serif = GoogleFonts.playfairDisplay(color: ink);
    final posterName = _displayBrand.toUpperCase().replaceAll(' ', ' · ');

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'WANTED',
              style: serif.copyWith(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.0,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 5),

          // Dark-bordered photo window(s)
          Expanded(
            child: _buildStandardPhotoGrid(
              gap: 6,
              slotBorderColor: ink,
              slotBorderWidth: 2.0,
            ),
          ),
          const SizedBox(height: 6),

          // DEAD OR ALIVE + Name + Bounty
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'DEAD OR ALIVE',
              style: serif.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              posterName,
              style: serif.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(
            '฿  - 1,500,000,000 -',
            textAlign: TextAlign.center,
            style: serif.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'KONO SAKUHIN WA FICTION DETHU NODE\n'
                  'SHITATOSHITEMO JITSUZAI NO MONOTOWA ISSAI MUKAAKEIDETH',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.75),
                    fontSize: 5.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'MARINE',
                style: serif.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 10. Theater Ticket ──────────────────────────────────────────────────────
  Widget _buildTheaterTicket() {
    final bg = renderForPrint ? Colors.white : const Color(0xFFFBF5E6);
    final ink = renderForPrint ? Colors.black : const Color(0xFF7F1D1D);
    final dateStr =
        DateFormat('MM·dd·yy').format(session.createdAt).toUpperCase();

    return Container(
      color: bg,
      padding: const EdgeInsets.all(8),
      child: CustomPaint(
        painter: _TicketBorderPainter(color: ink),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '★  ADMIT ONE  ★',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text('ROW A',
                      style: TextStyle(
                          color: ink,
                          fontSize: 8,
                          fontWeight: FontWeight.w700)),
                  Text('SEAT ${session.imagePaths.length}0',
                      style: TextStyle(
                          color: ink,
                          fontSize: 8,
                          fontWeight: FontWeight.w700)),
                  Text(dateStr,
                      style: TextStyle(
                          color: ink,
                          fontSize: 8,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 7),

              // Photo window(s)
              Expanded(
                child: _buildStandardPhotoGrid(
                  gap: 6,
                  slotBorderColor: ink,
                  slotBorderWidth: 1.5,
                ),
              ),
              const SizedBox(height: 8),

              // Tear line + uploaded logo on bottom stub
              _DashedDivider(color: ink.withValues(alpha: 0.6)),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: Center(
                  child: _buildLogoWidget(
                    tintColor: ink,
                    applyTint: renderForPrint,
                    maxHeight: 38,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Horizontal In-Editor Layout Selector Panel ───────────────────────────────

class LayoutSelectorPanel extends StatelessWidget {
  final LayoutType selectedLayout;
  final int photoCount;
  final ValueChanged<LayoutType> onSelect;

  const LayoutSelectorPanel({
    super.key,
    required this.selectedLayout,
    required this.photoCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final layouts = LayoutType.values
        .where((l) => l.isAvailableForCount(photoCount))
        .toList();

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: layouts.length,
      itemBuilder: (context, index) {
        final layout = layouts[index];
        final isSelected = layout == selectedLayout;
        return GestureDetector(
          onTap: () => onSelect(layout),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 10),
            width: 84,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : const Color(0xFFF5F3EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : const Color(0xFFD6D2C8),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
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
                  _iconFor(layout),
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  layout.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitleFor(layout),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  IconData _iconFor(LayoutType layout) {
    switch (layout) {
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
        return Icons.dashboard_rounded;
      case LayoutType.onePieceWanted:
        return Icons.workspace_premium_rounded;
      case LayoutType.theaterTicket:
        return Icons.confirmation_number_rounded;
    }
  }

  String _subtitleFor(LayoutType layout) {
    switch (layout) {
      case LayoutType.classicStrip:
        return 'Signature';
      case LayoutType.receipt:
        return 'Order slip';
      case LayoutType.spotify:
        return 'Now playing';
      case LayoutType.filmStrip:
        return '35mm slate';
      case LayoutType.boardingPass:
        return 'Flight pass';
      case LayoutType.polaroid:
        return 'Instant film';
      case LayoutType.instagram:
        return 'Social post';
      case LayoutType.bento:
        return 'Masonry';
      case LayoutType.onePieceWanted:
        return 'Bounty';
      case LayoutType.theaterTicket:
        return 'Admit one';
    }
  }
}

// ─── Custom Painters & Helpers ────────────────────────────────────────────────

class _DashedDivider extends StatelessWidget {
  final Color color;
  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashedLinePainter(color: color)),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SpotifyWavePainter extends CustomPainter {
  final Color color;
  _SpotifyWavePainter({required this.color});

  static const _heights = [
    0.25,
    0.55,
    0.35,
    0.85,
    0.50,
    0.95,
    0.40,
    0.70,
    0.30,
    0.90,
    0.60,
    0.35,
    0.75,
    0.45,
    0.85,
    0.30,
    0.55,
    0.25,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final step = size.width / _heights.length;
    final midY = size.height / 2;
    for (int i = 0; i < _heights.length; i++) {
      final h = size.height * _heights[i] * 0.45;
      final x = i * step + step / 2;
      canvas.drawLine(Offset(x, midY - h), Offset(x, midY + h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotifyWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ScrubberPainter extends CustomPainter {
  final Color color;
  final double progress;
  _ScrubberPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), trackPaint);
    final knobX = size.width * progress;
    canvas.drawLine(Offset(0, y), Offset(knobX, y), activePaint);
    canvas.drawCircle(Offset(knobX, y), 4.0, activePaint);
  }

  @override
  bool shouldRepaint(covariant _ScrubberPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}

class _FilmSprocketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    const holeW = 7.0;
    const holeH = 9.0;
    const spacing = 16.0;
    final left = (size.width - holeW) / 2;
    for (double y = 6; y + holeH < size.height; y += spacing) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, y, holeW, holeH),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ClapperStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final dark = Paint()..color = const Color(0xFF111111);
    final light = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, dark);
    const stripeW = 14.0;
    for (double x = -size.height;
        x < size.width + size.height;
        x += stripeW * 2) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + stripeW, 0)
        ..lineTo(x + stripeW, size.height)
        ..close();
      canvas.drawPath(path, light);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TicketBorderPainter extends CustomPainter {
  final Color color;
  _TicketBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final inner = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const r = 12.0;
    Path buildNotchedPath(Rect rect, double notch) {
      return Path()
        ..moveTo(rect.left + notch, rect.top)
        ..lineTo(rect.right - notch, rect.top)
        ..arcToPoint(Offset(rect.right, rect.top + notch),
            radius: Radius.circular(notch), clockwise: false)
        ..lineTo(rect.right, rect.bottom - notch)
        ..arcToPoint(Offset(rect.right - notch, rect.bottom),
            radius: Radius.circular(notch), clockwise: false)
        ..lineTo(rect.left + notch, rect.bottom)
        ..arcToPoint(Offset(rect.left, rect.bottom - notch),
            radius: Radius.circular(notch), clockwise: false)
        ..lineTo(rect.left, rect.top + notch)
        ..arcToPoint(Offset(rect.left + notch, rect.top),
            radius: Radius.circular(notch), clockwise: false)
        ..close();
    }

    canvas.drawPath(buildNotchedPath(Offset.zero & size, r), outer);
    canvas.drawPath(
      buildNotchedPath(
        Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
        r - 2,
      ),
      inner,
    );
  }

  @override
  bool shouldRepaint(covariant _TicketBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
