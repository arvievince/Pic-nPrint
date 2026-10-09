import 'package:equatable/equatable.dart';
import '../../../core/models/enums.dart';

abstract class CaptureEvent extends Equatable {
  const CaptureEvent();
  @override
  List<Object?> get props => [];
}

/// User chose camera mode — start the countdown flow.
class CaptureMethodChosen extends CaptureEvent {
  final CaptureMethod method;
  const CaptureMethodChosen(this.method);
  @override
  List<Object?> get props => [method];
}

/// Countdown timer ticked down by one second.
class CaptureCountdownTick extends CaptureEvent {
  const CaptureCountdownTick();
}

/// Camera controller signalled a photo was taken.
class PhotoCaptured extends CaptureEvent {
  final String imagePath;
  const PhotoCaptured(this.imagePath);
  @override
  List<Object?> get props => [imagePath];
}

/// User uploaded images from gallery/file picker.
class ImagesUploaded extends CaptureEvent {
  final List<String> imagePaths;
  const ImagesUploaded(this.imagePaths);
  @override
  List<Object?> get props => [imagePaths];
}

/// User wants to retake the last photo.
class CaptureRetake extends CaptureEvent {
  const CaptureRetake();
}

/// All required photos are collected — proceed to editor.
class CaptureCompleted extends CaptureEvent {
  const CaptureCompleted();
}
