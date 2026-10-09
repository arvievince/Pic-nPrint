import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'attract_event.dart';
import 'attract_state.dart';

/// Controls the attract / idle screen.
///
/// Responsibilities:
///   - Advance the background slideshow on each timer tick.
///   - Respond to a customer tap by emitting [AttractNavigating] so the
///     screen can navigate to /voucher.
///
/// The screen listens for [AttractNavigating] and calls:
///   context.goNamed(AppRoute.voucher);
///
class AttractBloc extends Bloc<AttractEvent, AttractState> {
  Timer? _slideshowTimer;
  int _tick = 0;

  AttractBloc() : super(const AttractIdle()) {
    on<AttractTapped>(_onTapped);
    on<AttractTimerTick>(_onTimerTick);
    on<AttractReset>(_onReset);
    _startSlideshow();
  }

  // ─── Event Handlers ──────────────────────────────────────────────────────────

  void _onTapped(AttractTapped event, Emitter<AttractState> emit) {
    _slideshowTimer?.cancel();
    emit(const AttractNavigating());
  }

  void _onReset(AttractReset event, Emitter<AttractState> emit) {
    _tick = 0;
    _startSlideshow();
    emit(const AttractIdle());
  }

  void _onTimerTick(AttractTimerTick event, Emitter<AttractState> emit) {
    final currentSlide = state is AttractIdle
        ? (state as AttractIdle).slideIndex
        : 0;
    emit(AttractIdle(slideIndex: (currentSlide + 1) % 5)); // max 5 slides
  }

  // ─── Slideshow Timer ─────────────────────────────────────────────────────────

  void _startSlideshow() {
    _slideshowTimer?.cancel();
    _slideshowTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (state is AttractIdle) {
        add(AttractTimerTick(++_tick));
      }
    });
  }

  /// Call this when returning to the attract screen to reset state.
  void reset() {
    add(const AttractReset());
  }

  @override
  Future<void> close() {
    _slideshowTimer?.cancel();
    return super.close();
  }
}
