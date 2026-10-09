import 'package:equatable/equatable.dart';
import '../../../core/models/enums.dart';

abstract class LayoutEvent extends Equatable {
  const LayoutEvent();
  @override
  List<Object?> get props => [];
}

/// User selected a layout option.
class LayoutSelected extends LayoutEvent {
  final LayoutType layout;
  const LayoutSelected(this.layout);
  @override
  List<Object?> get props => [layout];
}

/// User confirmed the selection and is ready to capture.
class LayoutConfirmed extends LayoutEvent {
  const LayoutConfirmed();
}
