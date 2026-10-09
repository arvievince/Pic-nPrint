import 'package:equatable/equatable.dart';

/// All possible states the AttractScreen can be in.
abstract class AttractState extends Equatable {
  const AttractState();
  @override
  List<Object?> get props => [];
}

/// The idle attract screen is displaying normally.
class AttractIdle extends AttractState {
  /// Index of the currently shown background image (for slideshow).
  final int slideIndex;
  const AttractIdle({this.slideIndex = 0});
  @override
  List<Object?> get props => [slideIndex];
}

/// A tap was received — navigate to the voucher screen.
class AttractNavigating extends AttractState {
  const AttractNavigating();
}
