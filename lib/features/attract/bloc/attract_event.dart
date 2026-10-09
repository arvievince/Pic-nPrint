import 'package:equatable/equatable.dart';

/// All events that the AttractBloc can receive.
abstract class AttractEvent extends Equatable {
  const AttractEvent();
  @override
  List<Object?> get props => [];
}

/// Customer tapped the attract screen to start a session.
class AttractTapped extends AttractEvent {
  const AttractTapped();
}

/// Reset attract state back to idle.
class AttractReset extends AttractEvent {
  const AttractReset();
}

/// Periodic tick — used for slideshow animations or idle timeouts.
class AttractTimerTick extends AttractEvent {
  final int tick;
  const AttractTimerTick(this.tick);
  @override
  List<Object?> get props => [tick];
}
