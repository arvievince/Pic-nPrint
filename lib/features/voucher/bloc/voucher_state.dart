import 'package:equatable/equatable.dart';
import '../../../core/models/models.dart';

abstract class VoucherState extends Equatable {
  const VoucherState();
  @override
  List<Object?> get props => [];
}

/// Waiting for the user to type a code.
class VoucherInitial extends VoucherState {
  final String currentCode;
  const VoucherInitial({this.currentCode = ''});
  @override
  List<Object?> get props => [currentCode];
}

/// Validation is in progress (show spinner).
class VoucherValidating extends VoucherState {
  const VoucherValidating();
}

/// Code is valid — navigate to capture screen with this voucher.
class VoucherValid extends VoucherState {
  /// The validated voucher — passed to the next screen via navigation.
  final VoucherModel voucher;
  const VoucherValid(this.voucher);
  @override
  List<Object?> get props => [voucher];
}

/// Code is invalid — show error message.
class VoucherInvalid extends VoucherState {
  final String errorMessage;
  const VoucherInvalid(this.errorMessage);
  @override
  List<Object?> get props => [errorMessage];
}

/// Too many wrong attempts — show lockout message with remaining time.
class VoucherLocked extends VoucherState {
  final int remainingSeconds;
  const VoucherLocked(this.remainingSeconds);
  @override
  List<Object?> get props => [remainingSeconds];
}
