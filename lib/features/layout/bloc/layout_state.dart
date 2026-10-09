import 'package:equatable/equatable.dart';
import '../../../core/models/enums.dart';

abstract class LayoutState extends Equatable {
  const LayoutState();
  @override
  List<Object?> get props => [];
}

/// Waiting for user to pick a layout.
class LayoutInitial extends LayoutState {
  /// Which layout options are available (depends on ShotMode).
  final List<LayoutType> availableLayouts;
  /// Currently highlighted option (not yet confirmed).
  final LayoutType? highlighted;

  const LayoutInitial({
    required this.availableLayouts,
    this.highlighted,
  });

  @override
  List<Object?> get props => [availableLayouts, highlighted];
}

/// User has confirmed a layout — navigate to capture.
class LayoutChosen extends LayoutState {
  final LayoutType layout;
  const LayoutChosen(this.layout);
  @override
  List<Object?> get props => [layout];
}
