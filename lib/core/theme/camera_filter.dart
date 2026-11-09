import 'package:flutter/material.dart';

/// Preset color filters used across Camera viewfinder, Review, Editor canvas, and Print composition.
enum CameraFilter {
  natural('Natural', [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  noir('Noir', [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]),
  retro('Retro', [
    0.393, 0.769, 0.189, 0, 0,
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0,     0,     0,     1, 0,
  ]),
  pop('Pop', [
    1.25, 0,    0,    0, -10,
    0,    1.25, 0,    0, -10,
    0,    0,    1.25, 0, -10,
    0,    0,    0,    1,   0,
  ]),
  fade('Fade', [
    0.88, 0.06, 0.06, 0, 18,
    0.06, 0.88, 0.06, 0, 18,
    0.06, 0.06, 0.88, 0, 18,
    0,    0,    0,    1,  0,
  ]);

  final String label;
  final List<double> matrix;
  const CameraFilter(this.label, this.matrix);

  ColorFilter get colorFilter => ColorFilter.matrix(matrix);

  static CameraFilter fromName(String? name) {
    if (name == null || name.trim().isEmpty) return CameraFilter.natural;
    final normalized = name.trim().toLowerCase();
    return CameraFilter.values.firstWhere(
      (f) => f.name.toLowerCase() == normalized || f.label.toLowerCase() == normalized,
      orElse: () => CameraFilter.natural,
    );
  }
}

