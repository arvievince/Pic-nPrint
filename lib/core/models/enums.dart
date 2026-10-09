/// Enum representing the shot/tier mode locked by the voucher.
/// Single = 1 photo, triple = 3 photos, quad = 4 photos, hex = 6 photos.
enum ShotMode {
  single,  // 1 photo, no layout choice
  triple,  // 3 shots, horizontal row only
  quad,    // 4 shots, side by side (2×2) or horizontal row
  hex,     // 6 shots, side by side (3×2) or horizontal row
}

extension ShotModeExtension on ShotMode {
  /// How many photos this mode requires.
  int get photoCount {
    switch (this) {
      case ShotMode.single: return 1;
      case ShotMode.triple: return 3;
      case ShotMode.quad:   return 4;
      case ShotMode.hex:    return 6;
    }
  }

  /// The voucher tier character used in the code format: LOC-T-SERIAL-CHK
  String get tierChar {
    switch (this) {
      case ShotMode.single: return 'S';
      case ShotMode.triple: return 'T';
      case ShotMode.quad:   return 'F';
      case ShotMode.hex:    return 'X';
    }
  }

  /// Human-readable label.
  String get label {
    switch (this) {
      case ShotMode.single: return 'Single';
      case ShotMode.triple: return '3 Shots';
      case ShotMode.quad:   return '4 Shots';
      case ShotMode.hex:    return '6 Shots';
    }
  }

  /// Parse from tier character.
  static ShotMode fromTierChar(String char) {
    switch (char.toUpperCase()) {
      case 'S': return ShotMode.single;
      case 'T': return ShotMode.triple;
      case 'F': return ShotMode.quad;
      case 'X': return ShotMode.hex;
      default:  throw ArgumentError('Unknown tier char: $char');
    }
  }
}

/// Available print/display layouts.
enum LayoutType {
  single,        // 1 photo, full frame
  verticalStrip, // photos in a vertical photo-booth strip
  horizontalRow, // all photos in one horizontal strip
  grid2x2,       // 4 photos in 2×2 grid
  grid3x2,       // 6 photos in 3×2 grid
}

extension LayoutTypeExtension on LayoutType {
  String get label {
    switch (this) {
      case LayoutType.single:        return 'Single';
      case LayoutType.verticalStrip: return 'Vertical Strip';
      case LayoutType.horizontalRow: return 'Horizontal Strip';
      case LayoutType.grid2x2:       return '2×2 Grid';
      case LayoutType.grid3x2:       return '3×2 Grid';
    }
  }
}

/// Which input method the customer chose.
enum CaptureMethod { camera, upload }

/// Status of a voucher in the database.
enum VoucherStatus { active, used, voided, expired }
