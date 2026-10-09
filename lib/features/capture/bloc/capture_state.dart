import 'package:equatable/equatable.dart';

abstract class CaptureState extends Equatable {
  const CaptureState();
  @override
  List<Object?> get props => [];
}

/// Waiting for user to choose camera or upload.
class CaptureMethodSelection extends CaptureState {
  const CaptureMethodSelection();
}

/// Countdown is running before the next shot.
class CaptureCountingDown extends CaptureState {
  /// Seconds remaining on the countdown.
  final int secondsLeft;
  /// Which photo number we're about to take (1-based).
  final int shotNumber;
  /// Total photos needed.
  final int totalShots;

  const CaptureCountingDown({
    required this.secondsLeft,
    required this.shotNumber,
    required this.totalShots,
  });

  @override
  List<Object?> get props => [secondsLeft, shotNumber, totalShots];
}

/// Camera shutter is firing (brief flash feedback).
class CaptureTaking extends CaptureState {
  final int shotNumber;
  const CaptureTaking(this.shotNumber);
  @override
  List<Object?> get props => [shotNumber];
}

/// One or more photos captured — showing progress.
class CaptureInProgress extends CaptureState {
  final List<String> capturedPaths;
  final int totalRequired;

  const CaptureInProgress({
    required this.capturedPaths,
    required this.totalRequired,
  });

  int get remaining => totalRequired - capturedPaths.length;
  bool get isComplete => capturedPaths.length >= totalRequired;

  @override
  List<Object?> get props => [capturedPaths, totalRequired];
}

/// All photos collected — ready to go to editor.
class CaptureComplete extends CaptureState {
  final List<String> imagePaths;
  const CaptureComplete(this.imagePaths);
  @override
  List<Object?> get props => [imagePaths];
}

/// An error occurred (camera not available, permission denied, etc.)
class CaptureError extends CaptureState {
  final String message;
  const CaptureError(this.message);
  @override
  List<Object?> get props => [message];
}
