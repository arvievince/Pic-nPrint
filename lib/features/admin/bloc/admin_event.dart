import 'package:equatable/equatable.dart';
import '../../../core/models/enums.dart';

abstract class AdminEvent extends Equatable {
  const AdminEvent();
  @override
  List<Object?> get props => [];
}

/// User entered the admin password.
class AdminPasswordSubmitted extends AdminEvent {
  final String password;
  const AdminPasswordSubmitted(this.password);
  @override
  List<Object?> get props => [password];
}

/// Admin tapped a section tab.
class AdminSectionChanged extends AdminEvent {
  final AdminSection section;
  const AdminSectionChanged(this.section);
  @override
  List<Object?> get props => [section];
}

/// A setting was changed (key-value pair).
class AdminSettingUpdated extends AdminEvent {
  final String key;
  final String value;
  const AdminSettingUpdated({required this.key, required this.value});
  @override
  List<Object?> get props => [key, value];
}

/// Multiple settings were updated simultaneously.
class AdminMultipleSettingsUpdated extends AdminEvent {
  final Map<String, String> settings;
  const AdminMultipleSettingsUpdated(this.settings);
  @override
  List<Object?> get props => [settings];
}

/// Admin updated multiple tier prices at once.
class AdminPricesUpdated extends AdminEvent {
  final Map<ShotMode, double> prices;
  const AdminPricesUpdated(this.prices);
  @override
  List<Object?> get props => [prices];
}

/// Admin tapped "Lock / Exit".
class AdminLocked extends AdminEvent {
  const AdminLocked();
}

/// Available admin panel sections (maps to section tabs).
enum AdminSection {
  pricing,
  camera,
  printers,
  drive,
  branding,
  vouchers,
  sales,
  data,
}
