import 'package:drift/drift.dart';

/// Kiosk-wide settings: one row, key-value store.
@DataClassName('SettingEntry')
class SettingsTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Price per shot mode.
@DataClassName('PriceEntry')
class PricesTable extends Table {
  /// Tier char: S / T / F / X  (maps to ShotMode)
  TextColumn get tierChar => text()();
  RealColumn get price => real()();

  @override
  Set<Column> get primaryKey => {tierChar};
}

/// Sticker and border asset catalog.
@DataClassName('AssetEntry')
class AssetsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // 'sticker' | 'border'
  TextColumn get name => text()();
  TextColumn get filePath => text()();
  DateTimeColumn get addedAt => dateTime()();
}

/// Configured printers.
@DataClassName('PrinterEntry')
class PrintersTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get transport => text()(); // 'network' | 'usb' | 'bluetooth'
  TextColumn get address => text()();
  IntColumn get paperWidthMm => integer().withDefault(const Constant(80))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Voucher records — one row per generated voucher.
@DataClassName('VoucherEntry')
class VouchersTable extends Table {
  TextColumn get code => text()();         // full code
  TextColumn get locationId => text()();
  TextColumn get tierChar => text()();
  TextColumn get serial => text()();
  RealColumn get priceSnapshot => real()();
  IntColumn get status => integer().withDefault(const Constant(0))(); // 0 = active, 1 = used, 2 = voided
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get redeemedAt => dateTime().nullable()();
  TextColumn get voidReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {code};
}

/// Sales records — one row per redeemed (used) voucher.
@DataClassName('SaleEntry')
class SalesTable extends Table {
  TextColumn get code => text()();         // voucher code
  TextColumn get locationId => text()();
  TextColumn get tierChar => text()();
  TextColumn get serial => text()();
  RealColumn get priceSnapshot => real()();
  IntColumn get status => integer().withDefault(const Constant(1))(); // 1 = used
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get redeemedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {code};
}

/// Session records — one row per customer session.
@DataClassName('SessionEntry')
class SessionsTable extends Table {
  TextColumn get sessionId => text()();
  TextColumn get voucherCode => text()();
  TextColumn get tierChar => text()();     // redundant for fast queries
  TextColumn get layoutType => text().nullable()();
  TextColumn get localImagePaths => text()(); // JSON array of paths
  TextColumn get composedImagePath => text().nullable()();
  TextColumn get gifPath => text().nullable()();
  TextColumn get driveFileId => text().nullable()();
  TextColumn get driveShareUrl => text().nullable()();
  BoolColumn get isUploaded => boolean().withDefault(const Constant(false))();
  BoolColumn get isPrinted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// Admin authentication — bcrypt-hashed password.
@DataClassName('AdminAuthEntry')
class AdminAuthTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get passwordHash => text()();
  DateTimeColumn get updatedAt => dateTime()();
}
