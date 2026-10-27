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
///     → [gap timer fires] → CaptureNextShotStarted
///     → CaptureCountingDown(3, 2, 1…)
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
  Timer? _gapTimer;
  int _initialCountdown = 3;
  int _currentCountdown = 3;
  int _shotGapSeconds = 2;
  int _currentShotNumber = 1;
  int _maxRetakes = 1;
  int _retakesRemaining = 1;
  int _selectedRetakeIndex = 0;
  int? _retakeTargetIndex;
  final List<String> _capturedPaths = [];

  CaptureBloc({required AppDatabase db, required this.shotMode})
      : _db = db,
        super(const CaptureMethodSelection()) {
    on<CaptureMethodChosen>(_onMethodChosen);
    on<CaptureCountdownTick>(_onCountdownTick);
    on<PhotoCaptured>(_onPhotoCaptured);
    on<CaptureNextShotStarted>(_onNextShotStarted);
    on<ImagesUploaded>(_onImagesUploaded);
    on<CapturePhotoSelectedForRetake>(_onPhotoSelectedForRetake);
    on<CaptureRetakeConfirmed>(_onRetakeConfirmed);
    on<CaptureReviewConfirmed>(_onReviewConfirmed);
    on<CaptureRetake>(_onRetake);
    on<CaptureCompleted>(_onCompleted);
    on<CaptureFailed>(_onFailed);
  }

  // ─── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _onMethodChosen(
      CaptureMethodChosen event, Emitter<CaptureState> emit) async {
    if (event.method == CaptureMethod.upload) {
      // Upload mode: screen opens picker and dispatches ImagesUploaded
      return;
    }

    // Camera mode: load settings then start countdown for first shot
    _initialCountdown =
        int.tryParse(await _db.getSetting('countdown_seconds') ?? '3') ?? 3;
    _currentCountdown = _initialCountdown;
    _shotGapSeconds =
        int.tryParse(await _db.getSetting('shot_gap_seconds') ?? '2') ?? 2;
    _maxRetakes = int.tryParse(await _db.getSetting('max_retakes') ?? '1') ?? 1;
    _retakesRemaining = _maxRetakes;
    _selectedRetakeIndex = 0;
    _retakeTargetIndex = null;
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
    // If this was a retake shot for a specific slot
    if (_retakeTargetIndex != null) {
      final target = _retakeTargetIndex!;
      if (target >= 0 && target < _capturedPaths.length) {
        _capturedPaths[target] = event.imagePath;
      }
      _retakeTargetIndex = null;
      emit(CaptureReview(
        capturedPaths: List.unmodifiable(_capturedPaths),
        retakesRemaining: _retakesRemaining,
        maxRetakes: _maxRetakes,
        selectedIndex: _selectedRetakeIndex,
      ));
      return;
    }

    _capturedPaths.add(event.imagePath);

    if (_capturedPaths.length >= shotMode.photoCount) {
      if (_maxRetakes > 0) {
        _selectedRetakeIndex = 0;
        emit(CaptureReview(
          capturedPaths: List.unmodifiable(_capturedPaths),
          retakesRemaining: _retakesRemaining,
          maxRetakes: _maxRetakes,
          selectedIndex: 0,
        ));
      } else {
        emit(CaptureComplete(List.unmodifiable(_capturedPaths)));
      }
    } else {
      emit(CaptureInProgress(
        capturedPaths: List.unmodifiable(_capturedPaths),
        totalRequired: shotMode.photoCount,
      ));

      // Start gap timer, then dispatch event to start next countdown safely
      _gapTimer?.cancel();
      _gapTimer = Timer(Duration(seconds: _shotGapSeconds), () {
        add(const CaptureNextShotStarted());
      });
    }
  }

  void _onNextShotStarted(
      CaptureNextShotStarted event, Emitter<CaptureState> emit) {
    _gapTimer?.cancel();
    _countdownTimer?.cancel();
    _currentShotNumber = _capturedPaths.length + 1;
    _currentCountdown = _initialCountdown;
    _startCountdown(emit);
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

  void _onPhotoSelectedForRetake(
      CapturePhotoSelectedForRetake event, Emitter<CaptureState> emit) {
    if (state is CaptureReview) {
      _selectedRetakeIndex = event.index.clamp(0, _capturedPaths.length - 1);
      emit((state as CaptureReview)
          .copyWith(selectedIndex: _selectedRetakeIndex));
    }
  }

  void _onRetakeConfirmed(
      CaptureRetakeConfirmed event, Emitter<CaptureState> emit) {
    if (_retakesRemaining <= 0) return;
    _retakesRemaining--;
    _retakeTargetIndex = _selectedRetakeIndex;
    _currentShotNumber = _retakeTargetIndex! + 1;
    _currentCountdown = _initialCountdown;
    _startCountdown(emit);
  }

  void _onReviewConfirmed(
      CaptureReviewConfirmed event, Emitter<CaptureState> emit) {
    emit(CaptureComplete(List.unmodifiable(_capturedPaths)));
  }

  void _onRetake(CaptureRetake event, Emitter<CaptureState> emit) {
    if (_retakesRemaining <= 0) return;
    _retakesRemaining--;
    _gapTimer?.cancel();
    _countdownTimer?.cancel();
    if (_capturedPaths.isNotEmpty) _capturedPaths.removeLast();
    _currentShotNumber = _capturedPaths.length + 1;
    _currentCountdown = _initialCountdown;
    _startCountdown(emit);
  }

  void _onCompleted(CaptureCompleted event, Emitter<CaptureState> emit) {
    // No-op: screen navigates when it sees CaptureComplete state.
  }

  void _onFailed(CaptureFailed event, Emitter<CaptureState> emit) {
    _countdownTimer?.cancel();
    _gapTimer?.cancel();
    emit(CaptureError(event.message));
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  void _startCountdown(Emitter<CaptureState> emit) {
    _countdownTimer?.cancel();
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
    _gapTimer?.cancel();
    return super.close();
  }
}
