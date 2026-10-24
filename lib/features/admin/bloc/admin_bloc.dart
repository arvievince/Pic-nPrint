import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:picnprint/core/models/enums.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/security_service.dart';
import 'admin_event.dart';
import 'admin_state.dart';

/// Controls the password-protected admin panel.
///
/// Flow:
///   AdminScreen → user enters password → AdminPasswordSubmitted
///     → SecurityService.verifyPassword()
///     → success: emits AdminUnlockedState (loads all settings)
///     → failure: emits AdminPasswordWrong (or AdminPasswordLocked)
///
///   AdminUnlockedState → user changes setting → AdminSettingUpdated
///     → DB updated → settings map refreshed
///
///   Admin taps "Exit" → AdminLocked → returns to AdminLockedState
///
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final SecurityService _securityService;
  final AppDatabase _db;

  AdminBloc({
    required SecurityService securityService,
    required AppDatabase db,
  })  : _securityService = securityService,
        _db = db,
        super(const AdminLockedState()) {
    on<AdminPasswordSubmitted>(_onPasswordSubmitted);
    on<AdminSectionChanged>(_onSectionChanged);
    on<AdminSettingUpdated>(_onSettingUpdated);
    on<AdminMultipleSettingsUpdated>(_onMultipleSettingsUpdated);
    on<AdminPricesUpdated>(_onPricesUpdated);
    on<AdminLocked>(_onLocked);
  }

  // ─── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _onPasswordSubmitted(
      AdminPasswordSubmitted event, Emitter<AdminState> emit) async {
    emit(const AdminUnlocking());

    try {
      final correct = await _securityService.verifyPassword(event.password);
      if (correct) {
        final settings = await _loadSettings();
        emit(AdminUnlockedState(settings: settings));
      } else {
        emit(const AdminPasswordWrong(
            5)); // placeholder — real count from SecurityService
      }
    } on AdminLockedException catch (e) {
      emit(AdminPasswordLocked(e.remaining));
    } catch (e) {
      emit(const AdminPasswordWrong(0));
    }
  }

  void _onSectionChanged(AdminSectionChanged event, Emitter<AdminState> emit) {
    if (state is AdminUnlockedState) {
      emit(
          (state as AdminUnlockedState).copyWith(activeSection: event.section));
    }
  }

  Future<void> _onSettingUpdated(
      AdminSettingUpdated event, Emitter<AdminState> emit) async {
    await _db.setSetting(event.key, event.value);

    if (state is AdminUnlockedState) {
      final current = (state as AdminUnlockedState).settings;
      final updated = Map<String, String>.from(current)
        ..[event.key] = event.value;
      emit((state as AdminUnlockedState).copyWith(settings: updated));
    }
  }

  Future<void> _onMultipleSettingsUpdated(
      AdminMultipleSettingsUpdated event, Emitter<AdminState> emit) async {
    for (final entry in event.settings.entries) {
      await _db.setSetting(entry.key, entry.value);
    }

    if (state is AdminUnlockedState) {
      final current = (state as AdminUnlockedState).settings;
      final updated = Map<String, String>.from(current)..addAll(event.settings);
      emit((state as AdminUnlockedState).copyWith(settings: updated));
    }
  }

  void _onPricesUpdated(AdminPricesUpdated event, Emitter<AdminState> emit) {
    if (state is AdminUnlockedState) {
      final current = (state as AdminUnlockedState).settings;
      final updated = Map<String, String>.from(current);
      for (final entry in event.prices.entries) {
        updated['price_${entry.key.tierChar}'] = entry.value.toStringAsFixed(2);
      }
      emit((state as AdminUnlockedState).copyWith(settings: updated));
    }
  }

  void _onLocked(AdminLocked event, Emitter<AdminState> emit) {
    emit(const AdminLockedState());
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _loadSettings() async {
    final rows = await _db.getAllSettings();
    return {for (final r in rows) r.key: r.value};
  }
}
