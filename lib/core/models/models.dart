import 'package:equatable/equatable.dart';
import 'enums.dart';
export 'enums.dart';

/// Represents a validated, redeemed voucher that is active for the current session.
class VoucherModel extends Equatable {
  final String code; // full code e.g. MNL1-F-00042-A7K9
  final String locationId; // e.g. MNL1
  final ShotMode shotMode; // tier determined by voucher
  final String serial; // numeric serial e.g. 00042
  final DateTime expiresAt;
  final double priceSnapshot; // price at time of redemption

  const VoucherModel({
    required this.code,
    required this.locationId,
    required this.shotMode,
    required this.serial,
    required this.expiresAt,
    required this.priceSnapshot,
  });

  @override
  List<Object?> get props => [
        code,
        locationId,
        shotMode,
        serial,
        expiresAt,
        priceSnapshot,
      ];
}

/// A single active kiosk session, created after voucher redemption.
class SessionModel extends Equatable {
  /// Unique session ID e.g. MNL1-241009-0042
  final String sessionId;
  final VoucherModel voucher;
  final ShotMode shotMode;
  final LayoutType? layout; // chosen layout (null until LayoutScreen)
  final List<String> imagePaths; // local paths of captured/uploaded images
  final String? filter; // active color filter e.g. 'natural', 'noir', 'retro', 'pop', 'fade'
  final String? composedImagePath; // final composed image path
  final String? printImagePath; // clean white-frame image dedicated for thermal receipt printing
  final String? gifPath; // optional GIF path
  final String? driveFileId; // Drive file ID after upload
  final String? driveShareUrl; // public share URL for QR code
  // ── Supabase softcopy fields ──
  final String? sessionToken;
  final String? photoUrl;
  final String? gifUrl;
  final String uploadStatus; // 'pending' | 'uploading' | 'done' | 'failed' | 'local_only'
  final DateTime createdAt;
  /// Number of retakes used so far in this session (ephemeral, not persisted to DB).
  final int retakesUsed;
  /// Whether the customer chose color / document printing for this session.
  /// true  → route to Document/Color printer at output.
  /// false → route to Thermal receipt printer at output (default).
  final bool isColorPrint;

  const SessionModel({
    required this.sessionId,
    required this.voucher,
    required this.shotMode,
    this.layout,
    this.imagePaths = const [],
    this.filter,
    this.composedImagePath,
    this.printImagePath,
    this.gifPath,
    this.driveFileId,
    this.driveShareUrl,
    this.sessionToken,
    this.photoUrl,
    this.gifUrl,
    this.uploadStatus = 'pending',
    required this.createdAt,
    this.retakesUsed = 0,
    this.isColorPrint = false,
  });

  String? get shareUrl => photoUrl ?? driveShareUrl;
  bool get hasSoftcopy => photoUrl != null || driveShareUrl != null;
  bool get hasGifSoftcopy => gifUrl != null;

  /// Print size category: 'single', 'strip' or 'grid'. Used to pick the
  /// configured physical width for color document printing.
  String get printSizeKind {
    final count = imagePaths.length;
    if (count <= 1) return 'single';
    final chosen = layout ?? LayoutType.classicStrip;
    if (chosen == LayoutType.bento || count >= 4) {
      return 'grid';
    }
    return 'strip';
  }

  /// Canonical composition aspect ratio (width / height) matching the printed paper strip.
  double get compositionAspectRatio => aspectRatioFor(
        layout ?? LayoutType.classicStrip,
        imagePaths.length,
      );

  /// Computes the canonical canvas aspect ratio (width / height) for a given
  /// [layout] and [photoCount]. Shared between EditorCanvas and OutputScreen.
  static double aspectRatioFor(LayoutType layout, int photoCount) {
    final count = photoCount <= 0 ? 1 : photoCount;
    switch (layout) {
      case LayoutType.classicStrip:
        if (count == 1) return 1.0 / 1.18;
        if (count == 2) return 1.0 / 2.22;
        if (count == 3) return 1.0 / 3.25;
        if (count == 4) return 1.0 / 1.18;
        if (count == 6) return 2.0 / 3.35;
        if (count >= 8) return 2.0 / 4.35;
        return 1.0 / (count + 0.25);

      case LayoutType.polaroid:
        if (count == 1) return 1.0 / 1.28;
        if (count == 2) return 1.0 / 2.32;
        if (count == 3) return 1.0 / 3.36;
        if (count == 4) return 1.0 / 1.28;
        if (count == 6) return 2.0 / 3.48;
        if (count >= 8) return 2.0 / 4.48;
        return 1.0 / (count + 0.35);

      case LayoutType.receipt:
        if (count == 1) return 1.0 / 1.72;
        if (count == 2) return 1.0 / 2.65;
        if (count == 3) return 1.0 / 3.65;
        if (count == 4) return 1.0 / 1.68;
        if (count == 6) return 2.0 / 3.85;
        if (count >= 8) return 2.0 / 4.85;
        return 1.0 / (count + 0.65);

      case LayoutType.spotify:
        if (count == 1) return 1.0 / 1.48;
        if (count == 2) return 1.0 / 2.45;
        if (count == 3) return 1.0 / 3.45;
        if (count == 4) return 1.0 / 1.48;
        if (count == 6) return 2.0 / 3.65;
        if (count >= 8) return 2.0 / 4.65;
        return 1.0 / (count + 0.45);

      case LayoutType.filmStrip:
        if (count == 1) return 1.0 / 1.32;
        if (count == 2) return 1.0 / 2.32;
        if (count == 3) return 1.0 / 3.35;
        if (count == 4) return 1.0 / 1.30;
        if (count == 6) return 2.0 / 3.48;
        if (count >= 8) return 2.0 / 4.48;
        return 1.0 / (count + 0.35);

      case LayoutType.boardingPass:
        if (count == 1) return 1.0 / 1.65;
        if (count == 2) return 1.0 / 2.60;
        if (count == 3) return 1.0 / 3.60;
        if (count == 4) return 1.0 / 1.62;
        if (count == 6) return 2.0 / 3.80;
        if (count >= 8) return 2.0 / 4.80;
        return 1.0 / (count + 0.60);

      case LayoutType.instagram:
        if (count == 1) return 1.0 / 1.32;
        if (count == 2) return 1.0 / 1.28; // 2x1 side-by-side split
        if (count == 3) return 1.0 / 3.25;
        if (count == 4) return 1.0 / 1.32;
        if (count == 6) return 2.0 / 3.45;
        if (count >= 8) return 2.0 / 4.45;
        return 1.0 / (count + 0.32);

      case LayoutType.bento:
        if (count <= 4) return 2.0 / 2.65;
        if (count <= 6) return 2.0 / 3.35;
        return 2.0 / 4.15;

      case LayoutType.onePieceWanted:
        if (count == 1) return 1.0 / 1.52;
        if (count == 2) return 1.0 / 2.50;
        if (count == 3) return 1.0 / 3.55;
        if (count == 4) return 1.0 / 1.52;
        if (count == 6) return 2.0 / 3.70;
        if (count >= 8) return 2.0 / 4.70;
        return 1.0 / (count + 0.52);

      case LayoutType.theaterTicket:
        if (count == 1) return 1.0 / 1.45;
        if (count == 2) return 1.0 / 2.45;
        if (count == 3) return 1.0 / 3.48;
        if (count == 4) return 1.0 / 1.45;
        if (count == 6) return 2.0 / 3.62;
        if (count >= 8) return 2.0 / 4.62;
        return 1.0 / (count + 0.45);
    }
  }

  SessionModel copyWith({
    LayoutType? layout,
    List<String>? imagePaths,
    String? filter,
    String? composedImagePath,
    String? printImagePath,
    String? gifPath,
    String? driveFileId,
    String? driveShareUrl,
    String? sessionToken,
    String? photoUrl,
    String? gifUrl,
    String? uploadStatus,
    int? retakesUsed,
    bool? isColorPrint,
  }) {
    return SessionModel(
      sessionId: sessionId,
      voucher: voucher,
      shotMode: shotMode,
      layout: layout ?? this.layout,
      imagePaths: imagePaths ?? this.imagePaths,
      filter: filter ?? this.filter,
      composedImagePath: composedImagePath ?? this.composedImagePath,
      printImagePath: printImagePath ?? this.printImagePath,
      gifPath: gifPath ?? this.gifPath,
      driveFileId: driveFileId ?? this.driveFileId,
      driveShareUrl: driveShareUrl ?? this.driveShareUrl,
      sessionToken: sessionToken ?? this.sessionToken,
      photoUrl: photoUrl ?? this.photoUrl,
      gifUrl: gifUrl ?? this.gifUrl,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      createdAt: createdAt,
      retakesUsed: retakesUsed ?? this.retakesUsed,
      isColorPrint: isColorPrint ?? this.isColorPrint,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        voucher,
        shotMode,
        layout,
        imagePaths,
        filter,
        composedImagePath,
        printImagePath,
        createdAt,
      ];
}

/// Represents a configured printer.
class PrinterModel extends Equatable {
  final String id;
  final String name;
  final PrinterType printerType; // thermal | document
  final PrinterTransport transport; // network / usb / bluetooth / system
  final String address; // IP address, COM port, BT MAC, or system printer name
  final int paperWidthMm; // 80 or 58 (for thermal)
  final String paperSize; // '80mm' | '58mm' | '4x6' | 'A6' | '5x7' | '2x6' | 'square4x4' | 'A4' | 'Letter' | 'Legal'
  final bool isDefault;

  const PrinterModel({
    required this.id,
    required this.name,
    this.printerType = PrinterType.thermal,
    required this.transport,
    required this.address,
    this.paperWidthMm = 80,
    this.paperSize = '80mm',
    this.isDefault = false,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        printerType,
        transport,
        address,
        paperWidthMm,
        paperSize,
        isDefault,
      ];
}

/// Printer purpose / category.
enum PrinterType { thermal, document }

extension PrinterTypeExtension on PrinterType {
  String get label {
    switch (this) {
      case PrinterType.thermal:
        return 'Thermal Receipt Printer';
      case PrinterType.document:
        return 'Document / Color Photo Printer';
    }
  }

  String get dbValue => name; // 'thermal' | 'document'

  static PrinterType fromDb(String? value) {
    if (value == 'document') return PrinterType.document;
    return PrinterType.thermal;
  }
}

/// Printer connection transport type.
enum PrinterTransport { network, usb, bluetooth, system }

extension PrinterTransportExtension on PrinterTransport {
  String get label {
    switch (this) {
      case PrinterTransport.network:
        return 'Network (TCP/IP)';
      case PrinterTransport.usb:
        return 'USB';
      case PrinterTransport.bluetooth:
        return 'Bluetooth';
      case PrinterTransport.system:
        return 'Installed System Printer';
    }
  }
}

/// A sticker/emoji overlay item on the editor canvas.
class StickerItem extends Equatable {
  final String id;
  final String assetPath; // local or bundled asset path
  final double x;
  final double y;
  final double scale;
  final double rotation; // radians

  const StickerItem({
    required this.id,
    required this.assetPath,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  StickerItem copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return StickerItem(
      id: id,
      assetPath: assetPath,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  List<Object?> get props => [id, assetPath, x, y, scale, rotation];
}

/// A text overlay item on the editor canvas.
class TextItem extends Equatable {
  final String id;
  final String text;
  final double x;
  final double y;
  final double fontSize;
  final int colorValue; // ARGB int
  final String fontFamily;
  final double scale;
  final double rotation;

  const TextItem({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    this.fontSize = 24,
    this.colorValue = 0xFFFFFFFF,
    this.fontFamily = 'Roboto',
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  TextItem copyWith({
    String? text,
    double? x,
    double? y,
    double? fontSize,
    int? colorValue,
    String? fontFamily,
    double? scale,
    double? rotation,
  }) {
    return TextItem(
      id: id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      fontSize: fontSize ?? this.fontSize,
      colorValue: colorValue ?? this.colorValue,
      fontFamily: fontFamily ?? this.fontFamily,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  List<Object?> get props => [
        id,
        text,
        x,
        y,
        fontSize,
        colorValue,
        fontFamily,
        scale,
        rotation,
      ];
}
