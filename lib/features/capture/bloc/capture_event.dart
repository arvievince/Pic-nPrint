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

/// User selected a photo in the review screen to be retaken.
class CapturePhotoSelectedForRetake extends CaptureEvent {
  final int index;
  const CapturePhotoSelectedForRetake(this.index);
  @override
  List<Object?> get props => [index];
}

/// User confirmed they want to retake the selected photo.
class CaptureRetakeConfirmed extends CaptureEvent {
  const CaptureRetakeConfirmed();
}

/// User accepted all photos in review and wants to proceed to editor.
class CaptureReviewConfirmed extends CaptureEvent {
  const CaptureReviewConfirmed();
}

/// Gap timer completed — start countdown for next shot.
class CaptureNextShotStarted extends CaptureEvent {
  const CaptureNextShotStarted();
}

/// All required photos are collected — proceed to editor.
class CaptureCompleted extends CaptureEvent {
  const CaptureCompleted();
}

/// An error occurred during capture (camera unavailable, shutter error, etc.)
class CaptureFailed extends CaptureEvent {
  final String message;
  const CaptureFailed(this.message);
  @override
  List<Object?> get props => [message];
}
