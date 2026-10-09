import 'package:equatable/equatable.dart';

abstract class VoucherEvent extends Equatable {
  const VoucherEvent();
  @override
  List<Object?> get props => [];
}

/// User typed or changed the voucher code input field.
class VoucherCodeChanged extends VoucherEvent {
  final String code;
  const VoucherCodeChanged(this.code);
  @override
  List<Object?> get props => [code];
}

/// User tapped "Submit" to validate the entered code.
class VoucherSubmitted extends VoucherEvent {
  const VoucherSubmitted();
}

/// Reset the bloc (e.g. after navigating back or on error dismiss).
class VoucherReset extends VoucherEvent {
  const VoucherReset();
}
