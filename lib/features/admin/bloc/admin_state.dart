import 'package:equatable/equatable.dart';
import 'admin_event.dart';

abstract class AdminState extends Equatable {
  const AdminState();
  @override
  List<Object?> get props => [];
}

/// Password has not been entered yet.
class AdminLockedState extends AdminState {
  const AdminLockedState();
}

/// Verifying password.
class AdminUnlocking extends AdminState {
  const AdminUnlocking();
}

/// Wrong password entered.
class AdminPasswordWrong extends AdminState {
  final int attemptsRemaining;
  const AdminPasswordWrong([this.attemptsRemaining = 0]);
  @override
  List<Object?> get props => [attemptsRemaining];
}

/// Locked out after too many failures.
class AdminPasswordLocked extends AdminState {
  final Duration remaining;
  const AdminPasswordLocked(this.remaining);
  @override
  List<Object?> get props => [remaining];
}

/// Password accepted — admin panel is open.
class AdminUnlockedState extends AdminState {
  final AdminSection activeSection;
  final Map<String, String> settings; // current settings map

  const AdminUnlockedState({
    this.activeSection = AdminSection.pricing,
    this.settings = const {},
  });

  AdminUnlockedState copyWith({
    AdminSection? activeSection,
    Map<String, String>? settings,
  }) {
    return AdminUnlockedState(
      activeSection: activeSection ?? this.activeSection,
      settings: settings ?? this.settings,
    );
  }

  @override
  List<Object?> get props => [activeSection, settings];
}
