import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/models.dart';
import '../../../core/services/voucher_service.dart';
import 'voucher_event.dart';
import 'voucher_state.dart';

/// Validates a customer-entered voucher code and creates a session.
///
/// Flow:
///   VoucherScreen types code → VoucherCodeChanged (updates input)
///   VoucherScreen taps Submit → VoucherSubmitted
///     → calls VoucherService.redeemVoucher(code)
///     → on success: emits VoucherValid(voucher)
///       → screen navigates: context.goNamed(AppRoute.capture, extra: session)
///     → on VoucherException: emits VoucherInvalid(message)
///     → on AdminLockedException: emits VoucherLocked(seconds)
///
class VoucherBloc extends Bloc<VoucherEvent, VoucherState> {
  final VoucherService _voucherService;

  int _failedAttempts = 0;
  static const int _maxAttempts = 5;

  VoucherBloc({required VoucherService voucherService})
      : _voucherService = voucherService,
        super(const VoucherInitial()) {
    on<VoucherCodeChanged>(_onCodeChanged);
    on<VoucherSubmitted>(_onSubmitted);
    on<VoucherReset>(_onReset);
  }

  // ─── Handlers ────────────────────────────────────────────────────────────────

  void _onCodeChanged(VoucherCodeChanged event, Emitter<VoucherState> emit) {
    // Only update input if not locked
    if (state is! VoucherLocked) {
      emit(VoucherInitial(currentCode: event.code));
    }
  }

  Future<void> _onSubmitted(
      VoucherSubmitted event, Emitter<VoucherState> emit) async {
    // Guard: must be in VoucherInitial to have a code
    if (state is! VoucherInitial) return;
    final code = (state as VoucherInitial).currentCode.trim();
    if (code.isEmpty) return;

    emit(const VoucherValidating());

    try {
      final voucher = await _voucherService.redeemVoucher(code);
      _failedAttempts = 0;

      emit(VoucherValid(voucher));

      // NOTE: The screen uses BlocListener to navigate and passes [session]
      // as the GoRouter extra. We store it in state so the listener can access it.
    } on VoucherException catch (e) {
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        emit(const VoucherLocked(900)); // 15 minutes in seconds
      } else {
        emit(VoucherInvalid(e.message));
      }
    } catch (e) {
      emit(VoucherInvalid('An unexpected error occurred. Please try again.'));
    }
  }

  void _onReset(VoucherReset event, Emitter<VoucherState> emit) {
    emit(const VoucherInitial());
  }

  // ─── Session Builder ─────────────────────────────────────────────────────────

  /// Creates a new [SessionModel] from a validated voucher.
  /// Session ID format: LOC-YYMMDD-SERIAL (e.g. MNL1-241009-0042)
  SessionModel buildSession(VoucherModel voucher) {
    final now = DateTime.now();
    final date = '${now.year.toString().substring(2)}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final sessionId = '${voucher.locationId}-$date-${voucher.serial}';

    return SessionModel(
      sessionId: sessionId,
      voucher: voucher,
      shotMode: voucher.shotMode,
      createdAt: now,
    );
  }

  /// Expose the built session — used by the screen's BlocListener.
  SessionModel? buildSessionFromCurrentState() {
    if (state is VoucherValid) {
      return buildSession((state as VoucherValid).voucher);
    }
    return null;
  }
}
