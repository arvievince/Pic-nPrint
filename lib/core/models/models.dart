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
  final String? composedImagePath; // final composed image path
  final String? gifPath; // optional GIF path
  final String? driveFileId; // Drive file ID after upload
  final String? driveShareUrl; // public share URL for QR code
  final DateTime createdAt;

  const SessionModel({
    required this.sessionId,
    required this.voucher,
    required this.shotMode,
    this.layout,
    this.imagePaths = const [],
    this.composedImagePath,
    this.gifPath,
    this.driveFileId,
    this.driveShareUrl,
    required this.createdAt,
  });

  SessionModel copyWith({
    LayoutType? layout,
    List<String>? imagePaths,
    String? composedImagePath,
    String? gifPath,
    String? driveFileId,
    String? driveShareUrl,
  }) {
    return SessionModel(
      sessionId: sessionId,
      voucher: voucher,
      shotMode: shotMode,
      layout: layout ?? this.layout,
      imagePaths: imagePaths ?? this.imagePaths,
      composedImagePath: composedImagePath ?? this.composedImagePath,
      gifPath: gifPath ?? this.gifPath,
      driveFileId: driveFileId ?? this.driveFileId,
      driveShareUrl: driveShareUrl ?? this.driveShareUrl,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    voucher,
    shotMode,
    layout,
    imagePaths,
    composedImagePath,
    createdAt,
  ];
}

/// Represents a configured printer.
class PrinterModel extends Equatable {
  final String id;
  final String name;
  final PrinterTransport transport; // network / usb / bluetooth
  final String address; // IP address, COM port, or BT MAC
  final int paperWidthMm; // 80 or 58
  final bool isDefault;

  const PrinterModel({
    required this.id,
    required this.name,
    required this.transport,
    required this.address,
    this.paperWidthMm = 80,
    this.isDefault = false,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    transport,
    address,
    paperWidthMm,
    isDefault,
  ];
}

/// Printer connection transport type.
enum PrinterTransport { network, usb, bluetooth }

extension PrinterTransportExtension on PrinterTransport {
  String get label {
    switch (this) {
      case PrinterTransport.network:
        return 'Network (TCP/IP)';
      case PrinterTransport.usb:
        return 'USB';
      case PrinterTransport.bluetooth:
        return 'Bluetooth';
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

  const TextItem({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    this.fontSize = 24,
    this.colorValue = 0xFFFFFFFF,
    this.fontFamily = 'Roboto',
  });

  TextItem copyWith({
    String? text,
    double? x,
    double? y,
    double? fontSize,
    int? colorValue,
    String? fontFamily,
  }) {
    return TextItem(
      id: id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      fontSize: fontSize ?? this.fontSize,
      colorValue: colorValue ?? this.colorValue,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  @override
  List<Object?> get props => [id, text, x, y, fontSize, colorValue, fontFamily];
}
