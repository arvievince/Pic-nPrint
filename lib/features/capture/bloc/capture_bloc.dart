import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import 'capture_event.dart';
import 'capture_state.dart';

/// Controls the camera countdown + capture flow.
///
/// Flow (camera mode):
///   CaptureMethodChosen(camera)
///     → CaptureCountingDown(3, 2, 1…)
///     → CaptureTaking (camera fires)
///     → PhotoCaptured(path) → CaptureInProgress
///     → [repeat for remaining shots]
///     → CaptureComplete(paths)
///
/// Flow (upload mode):
///   CaptureMethodChosen(upload)
///     → Screen opens image picker
///     → ImagesUploaded(paths)
///     → CaptureComplete(paths)
///
/// Config (loaded from AppDatabase settings):
///   countdown_seconds  — default 3
///   shot_gap_seconds   — gap between shots, default 2
///
class CaptureBloc extends Bloc<CaptureEvent, CaptureState> {
  final AppDatabase _db;
  final ShotMode shotMode;

  Timer? _countdownTimer;
  int _currentCountdown = 3;
  int _shotGapSeconds = 2;
  int _currentShotNumber = 1;
  final List<String> _capturedPaths = [];

  CaptureBloc({required AppDatabase db, required this.shotMode})
      : _db = db,
        super(const CaptureMethodSelection()) {
    on<CaptureMethodChosen>(_onMethodChosen);
    on<CaptureCountdownTick>(_onCountdownTick);
    on<PhotoCaptured>(_onPhotoCaptured);
    on<ImagesUploaded>(_onImagesUploaded);
    on<CaptureRetake>(_onRetake);
    on<CaptureCompleted>(_onCompleted);
  }

  // ─── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _onMethodChosen(
      CaptureMethodChosen event, Emitter<CaptureState> emit) async {
    if (event.method == CaptureMethod.upload) {
      // Upload mode: the screen will open a picker and dispatch ImagesUploaded
      // Nothing to do here — just wait for ImagesUploaded
      return;
    }

    // Camera mode: load settings then start countdown for first shot
    _currentCountdown = int.tryParse(
            await _db.getSetting('countdown_seconds') ?? '3') ??
        3;
    _shotGapSeconds = int.tryParse(
            await _db.getSetting('shot_gap_seconds') ?? '2') ??
        2;
    _currentShotNumber = 1;
    _capturedPaths.clear();
    _startCountdown(emit);
  }

  void _onCountdownTick(
      CaptureCountdownTick event, Emitter<CaptureState> emit) {
    _currentCountdown--;
    if (_currentCountdown <= 0) {
      _countdownTimer?.cancel();
      emit(CaptureTaking(_currentShotNumber));
      // The screen observes CaptureTaking and triggers the camera shutter,
      // then dispatches PhotoCaptured(path).
    } else {
      emit(CaptureCountingDown(
        secondsLeft: _currentCountdown,
        shotNumber: _currentShotNumber,
        totalShots: shotMode.photoCount,
      ));
    }
  }

  void _onPhotoCaptured(PhotoCaptured event, Emitter<CaptureState> emit) {
    _capturedPaths.add(event.imagePath);

    if (_capturedPaths.length >= shotMode.photoCount) {
      emit(CaptureComplete(List.unmodifiable(_capturedPaths)));
    } else {
      emit(CaptureInProgress(
        capturedPaths: List.unmodifiable(_capturedPaths),
        totalRequired: shotMode.photoCount,
      ));
      // Start gap timer, then countdown for next shot
      _currentShotNumber++;
      _countdownTimer = Timer(Duration(seconds: _shotGapSeconds), () {
        _currentCountdown = int.parse('3'); // reset, will be reloaded from settings
        _startCountdown(emit);
      });
    }
  }

  void _onImagesUploaded(ImagesUploaded event, Emitter<CaptureState> emit) {
    if (event.imagePaths.length == shotMode.photoCount) {
      emit(CaptureComplete(List.unmodifiable(event.imagePaths)));
    } else {
      emit(CaptureError(
        'Please select exactly ${shotMode.photoCount} image(s). '
        'You selected ${event.imagePaths.length}.',
      ));
    }
  }

  void _onRetake(CaptureRetake event, Emitter<CaptureState> emit) {
    _countdownTimer?.cancel();
    if (_capturedPaths.isNotEmpty) _capturedPaths.removeLast();
    _currentShotNumber = _capturedPaths.length + 1;
    _startCountdown(emit);
  }

  void _onCompleted(CaptureCompleted event, Emitter<CaptureState> emit) {
    // No-op: screen navigates when it sees CaptureComplete state.
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  void _startCountdown(Emitter<CaptureState> emit) {
    emit(CaptureCountingDown(
      secondsLeft: _currentCountdown,
      shotNumber: _currentShotNumber,
      totalShots: shotMode.photoCount,
    ));
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const CaptureCountdownTick());
    });
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }
}
