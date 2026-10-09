import 'package:equatable/equatable.dart';

abstract class OutputEvent extends Equatable {
  const OutputEvent();
  @override
  List<Object?> get props => [];
}

/// Begin the output pipeline: save → upload → print.
class OutputStarted extends OutputEvent {
  const OutputStarted();
}

/// Retry a failed upload.
class UploadRetried extends OutputEvent {
  const UploadRetried();
}

/// User explicitly requested a print (or reprint).
class PrintRequested extends OutputEvent {
  const PrintRequested();
}

/// User dismissed the QR screen (Done or auto-timeout).
class QrDismissed extends OutputEvent {
  const QrDismissed();
}
