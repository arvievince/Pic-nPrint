import 'package:flutter/material.dart';

/// Screen device category based on window width.
enum ScreenType {
  /// Small devices (smartphones, small embedded displays, width < 600).
  compact,

  /// Medium devices (tablets, foldables, vertical kiosks, 600 <= width < 960).
  medium,

  /// Desktop / wide screens (laptops, standard 1080p kiosk, 960 <= width < 1440).
  expanded,

  /// Ultra-wide / 4K kiosk displays (width >= 1440).
  large;

  bool get isCompact => this == ScreenType.compact;
  bool get isMedium => this == ScreenType.medium;
  bool get isExpanded => this == ScreenType.expanded;
  bool get isLarge => this == ScreenType.large;
}

/// Centralized responsive layout utility for PicnPrint.
class Responsive {
  Responsive._();

  static const double compactBreakpoint = 600.0;
  static const double mediumBreakpoint = 960.0;
  static const double expandedBreakpoint = 1440.0;

  /// Returns the current [ScreenType] from [width].
  static ScreenType fromWidth(double width) {
    if (width < compactBreakpoint) return ScreenType.compact;
    if (width < mediumBreakpoint) return ScreenType.medium;
    if (width < expandedBreakpoint) return ScreenType.expanded;
    return ScreenType.large;
  }

  /// Returns the current [ScreenType] from [BuildContext].
  static ScreenType getScreenType(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  static bool isCompact(BuildContext context) =>
      getScreenType(context) == ScreenType.compact;

  static bool isMedium(BuildContext context) =>
      getScreenType(context) == ScreenType.medium;

  static bool isExpanded(BuildContext context) =>
      getScreenType(context) == ScreenType.expanded;

  static bool isLarge(BuildContext context) =>
      getScreenType(context) == ScreenType.large;

  /// Selects a responsive value based on device category.
  static T value<T>({
    required BuildContext context,
    required T compact,
    T? medium,
    T? expanded,
    T? large,
  }) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.compact:
        return compact;
      case ScreenType.medium:
        return medium ?? compact;
      case ScreenType.expanded:
        return expanded ?? medium ?? compact;
      case ScreenType.large:
        return large ?? expanded ?? medium ?? compact;
    }
  }

  /// Calculates a smooth scaled font size based on screen width.
  static double scaledFont(
    BuildContext context, {
    required double baseSize,
    double minScale = 0.75,
    double maxScale = 1.35,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    // Normalized around 1024px reference width
    final scale = (width / 1024.0).clamp(minScale, maxScale);
    return (baseSize * scale).roundToDouble();
  }
}

/// Extension on [BuildContext] for ergonomic responsive access.
extension ResponsiveContext on BuildContext {
  ScreenType get screenType => Responsive.getScreenType(this);
  bool get isCompact => Responsive.isCompact(this);
  bool get isMedium => Responsive.isMedium(this);
  bool get isExpanded => Responsive.isExpanded(this);
  bool get isLarge => Responsive.isLarge(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Returns a responsive value matching the active screen size.
  T responsive<T>({
    required T compact,
    T? medium,
    T? expanded,
    T? large,
  }) {
    return Responsive.value<T>(
      context: this,
      compact: compact,
      medium: medium,
      expanded: expanded,
      large: large,
    );
  }

  /// Returns a responsive font size.
  double responsiveFont({
    required double compact,
    double? medium,
    double? expanded,
    double? large,
  }) {
    return responsive<double>(
      compact: compact,
      medium: medium,
      expanded: expanded,
      large: large,
    );
  }
}

/// A responsive widget builder that provides constraints and [ScreenType].
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    ScreenType screenType,
  ) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = Responsive.fromWidth(constraints.maxWidth);
        return builder(context, constraints, screenType);
      },
    );
  }
}
