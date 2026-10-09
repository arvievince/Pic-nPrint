import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/enums.dart';
import 'layout_event.dart';
import 'layout_state.dart';

/// Manages layout selection for multi-shot modes.
///
/// Available layouts by mode:
///   triple → [horizontalRow] only
///   quad   → [horizontalRow, grid2x2]
///   hex    → [horizontalRow, grid3x2]
///
/// Flow:
///   LayoutScreen → LayoutSelected (highlights option)
///   LayoutScreen → LayoutConfirmed → emits LayoutChosen
///     → screen navigates: context.goNamed(AppRoute.capture, extra: updatedSession)
///
class LayoutBloc extends Bloc<LayoutEvent, LayoutState> {
  final ShotMode shotMode;

  LayoutBloc({required this.shotMode})
      : super(LayoutInitial(availableLayouts: _layoutsFor(shotMode))) {
    on<LayoutSelected>(_onSelected);
    on<LayoutConfirmed>(_onConfirmed);
  }

  void _onSelected(LayoutSelected event, Emitter<LayoutState> emit) {
    final current = state as LayoutInitial;
    emit(LayoutInitial(
      availableLayouts: current.availableLayouts,
      highlighted: event.layout,
    ));
  }

  void _onConfirmed(LayoutConfirmed event, Emitter<LayoutState> emit) {
    final current = state as LayoutInitial;
    final chosen = current.highlighted ?? current.availableLayouts.first;
    emit(LayoutChosen(chosen));
  }

  static List<LayoutType> _layoutsFor(ShotMode mode) {
    switch (mode) {
      case ShotMode.single: return [LayoutType.single];
      case ShotMode.triple: return [LayoutType.horizontalRow];
      case ShotMode.quad:   return [LayoutType.horizontalRow, LayoutType.grid2x2];
      case ShotMode.hex:    return [LayoutType.horizontalRow, LayoutType.grid3x2];
    }
  }
}
