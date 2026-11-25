/// Enum representing the shot/tier mode locked by the voucher.
/// Single = 1 photo, triple = 3 photos, quad = 4 photos, hex = 6 photos.
enum ShotMode {
  single, // 1 photo, no layout choice
  double, // 2 shots, vertical strip
  triple, // 3 shots, horizontal row only
  quad, // 4 shots, side by side (2×2) or horizontal row
  hex, // 6 shots, side by side (3×2) or horizontal row
  octa, // 8 shots, 2×4 grid or bendo
}

extension ShotModeExtension on ShotMode {
  /// How many photos this mode requires.
  int get photoCount {
    switch (this) {
      case ShotMode.single:
        return 1;
      case ShotMode.double:
        return 2;
      case ShotMode.triple:
        return 3;
      case ShotMode.quad:
        return 4;
      case ShotMode.hex:
        return 6;
      case ShotMode.octa:
        return 8;
    }
  }

  /// The voucher tier character used in the code format: LOC-T-SERIAL-CHK
  String get tierChar {
    switch (this) {
      case ShotMode.single:
        return 'S';
      case ShotMode.double:
        return 'D';
      case ShotMode.triple:
        return 'T';
      case ShotMode.quad:
        return 'F';
      case ShotMode.hex:
        return 'X';
      case ShotMode.octa:
        return 'O';
    }
  }

  /// Human-readable label.
  String get label {
    switch (this) {
      case ShotMode.single:
        return 'Single';
      case ShotMode.double:
        return 'Double';
      case ShotMode.triple:
        return 'Triple';
      case ShotMode.quad:
        return 'Quad';
      case ShotMode.hex:
        return 'Six pack';
      case ShotMode.octa:
        return '8 Pack';
    }
  }

  /// Parse from tier character.
  static ShotMode fromTierChar(String char) {
    switch (char.toUpperCase()) {
      case 'S':
        return ShotMode.single;
      case 'D':
        return ShotMode.double;
      case 'T':
        return ShotMode.triple;
      case 'F':
        return ShotMode.quad;
      case 'X':
        return ShotMode.hex;
      case 'O':
        return ShotMode.octa;
      default:
        throw ArgumentError('Unknown tier char: $char');
    }
  }
}

/// Available print/display photobooth theme layouts.
enum LayoutType {
  classicStrip,
  receipt,
  spotify,
  filmStrip,
  boardingPass,
  polaroid,
  instagram,
  bento,
  onePieceWanted,
  theaterTicket,
}

extension LayoutTypeExtension on LayoutType {
  String get label {
    switch (this) {
      case LayoutType.classicStrip:
        return 'Classic';
      case LayoutType.receipt:
        return 'Receipt';
      case LayoutType.spotify:
        return 'Spotify';
      case LayoutType.filmStrip:
        return 'Film Strip';
      case LayoutType.boardingPass:
        return 'Boarding';
      case LayoutType.polaroid:
        return 'Polaroid';
      case LayoutType.instagram:
        return 'Instagram';
      case LayoutType.bento:
        return 'Bento';
      case LayoutType.onePieceWanted:
        return 'Wanted';
      case LayoutType.theaterTicket:
        return 'Ticket';
    }
  }

  /// Whether this layout is available for the given number of captured photos.
  /// Bento is only available when there are more than 2 images.
  bool isAvailableForCount(int photoCount) {
    if (this == LayoutType.bento) {
      return photoCount > 2;
    }
    return true;
  }

  /// Safely parses a stored layout name, falling back to [LayoutType.classicStrip].
  static LayoutType fromNameOrDefault(String? name) {
    if (name == null || name.isEmpty) return LayoutType.classicStrip;
    for (final value in LayoutType.values) {
      if (value.name == name) return value;
    }
    return LayoutType.classicStrip;
  }
}

/// Which input method the customer chose.
enum CaptureMethod { camera, upload }

/// Status of a voucher in the database.
enum VoucherStatus { active, used, voided, expired }
