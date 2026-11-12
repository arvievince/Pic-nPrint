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

/// All steps complete. [photoUrl] and [gifUrl] are softcopy cloud URLs from Supabase.
class OutputComplete extends OutputState {
  final String? photoUrl;
  final String? gifUrl;

  const OutputComplete({
    String? photoUrl,
    this.gifUrl,
    String? driveUrl,
  }) : photoUrl = photoUrl ?? driveUrl;

  /// Alias for backward compatibility
  String? get driveUrl => photoUrl;
  bool get hasSoftcopy => photoUrl != null && photoUrl!.trim().isNotEmpty;
  bool get hasGifSoftcopy => gifUrl != null && gifUrl!.trim().isNotEmpty;

  @override
  List<Object?> get props => [photoUrl, gifUrl];
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
