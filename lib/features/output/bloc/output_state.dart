import 'package:equatable/equatable.dart';

abstract class OutputState extends Equatable {
  const OutputState();
  @override
  List<Object?> get props => [];
}

/// Saving to local storage.
class OutputSaving extends OutputState {
  const OutputSaving();
}

/// Uploading to Google Drive.
class OutputUploading extends OutputState {
  const OutputUploading();
}

/// Sending to the printer.
class OutputPrinting extends OutputState {
  const OutputPrinting();
}

/// All steps complete. [driveUrl] is null if Drive is not configured.
class OutputComplete extends OutputState {
  final String? driveUrl;
  const OutputComplete({this.driveUrl});
  @override
  List<Object?> get props => [driveUrl];
}

/// An upload failed but the admin chose to print without waiting.
class OutputUploadFailed extends OutputState {
  final String error;
  const OutputUploadFailed(this.error);
  @override
  List<Object?> get props => [error];
}

/// Printing failed.
class OutputPrintFailed extends OutputState {
  final String error;
  const OutputPrintFailed(this.error);
  @override
  List<Object?> get props => [error];
}
