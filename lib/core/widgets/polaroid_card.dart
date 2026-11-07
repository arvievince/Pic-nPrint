import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A realistic, rotated Polaroid card widget.
class PolaroidCard extends StatelessWidget {
  final double width;
  final double height;
  final double angleDegrees;
  final String? imagePath;
  final Widget? child;
  final VoidCallback? onTap;

  const PolaroidCard({
    super.key,
    required this.width,
    required this.height,
    this.angleDegrees = 0.0,
    this.imagePath,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double rad = angleDegrees * (math.pi / 180.0);
    final double innerPadding = width * 0.065;
    final double bottomPadding =
        width * 0.22; // Classic thick Polaroid bottom chin

    Widget content = Container(
      width: width,
      height: height,
      padding: EdgeInsets.fromLTRB(
        innerPadding,
        innerPadding,
        innerPadding,
        bottomPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.04),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.02),
        child: _buildInnerContent(),
      ),
    );

    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    if (angleDegrees == 0.0) {
      return content;
    }

    return Transform.rotate(
      angle: rad,
      child: content,
    );
  }

  Widget _buildInnerContent() {
    if (child != null) return child!;
    if (imagePath == null || imagePath!.isEmpty) {
      return const SizedBox.shrink();
    }

    final path = imagePath!;
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

