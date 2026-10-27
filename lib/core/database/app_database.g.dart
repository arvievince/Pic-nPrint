// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SettingsTableTable extends SettingsTable
    with TableInfo<$SettingsTableTable, SettingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings_table';
  @override
  VerificationContext validateIntegrity(Insertable<SettingEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingEntry(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTableTable createAlias(String alias) {
    return $SettingsTableTable(attachedDatabase, alias);
  }
}

class SettingEntry extends DataClass implements Insertable<SettingEntry> {
  final String key;
  final String value;
  const SettingEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsTableCompanion toCompanion(bool nullToAbsent) {
    return SettingsTableCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory SettingEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingEntry copyWith({String? key, String? value}) => SettingEntry(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  SettingEntry copyWithCompanion(SettingsTableCompanion data) {
    return SettingEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsTableCompanion extends UpdateCompanion<SettingEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsTableCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<SettingEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsTableCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PricesTableTable extends PricesTable
    with TableInfo<$PricesTableTable, PriceEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PricesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tierCharMeta =
      const VerificationMeta('tierChar');
  @override
  late final GeneratedColumn<String> tierChar = GeneratedColumn<String>(
      'tier_char', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
      'price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [tierChar, price];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prices_table';
  @override
  VerificationContext validateIntegrity(Insertable<PriceEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tier_char')) {
      context.handle(_tierCharMeta,
          tierChar.isAcceptableOrUnknown(data['tier_char']!, _tierCharMeta));
    } else if (isInserting) {
      context.missing(_tierCharMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
          _priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tierChar};
  @override
  PriceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PriceEntry(
      tierChar: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tier_char'])!,
      price: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price'])!,
    );
  }

  @override
  $PricesTableTable createAlias(String alias) {
    return $PricesTableTable(attachedDatabase, alias);
  }
}

class PriceEntry extends DataClass implements Insertable<PriceEntry> {
  /// Tier char: S / T / F / X  (maps to ShotMode)
  final String tierChar;
  final double price;
  const PriceEntry({required this.tierChar, required this.price});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tier_char'] = Variable<String>(tierChar);
    map['price'] = Variable<double>(price);
    return map;
  }

  PricesTableCompanion toCompanion(bool nullToAbsent) {
    return PricesTableCompanion(
      tierChar: Value(tierChar),
      price: Value(price),
    );
  }

  factory PriceEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PriceEntry(
      tierChar: serializer.fromJson<String>(json['tierChar']),
      price: serializer.fromJson<double>(json['price']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tierChar': serializer.toJson<String>(tierChar),
      'price': serializer.toJson<double>(price),
    };
  }

  PriceEntry copyWith({String? tierChar, double? price}) => PriceEntry(
        tierChar: tierChar ?? this.tierChar,
        price: price ?? this.price,
      );
  PriceEntry copyWithCompanion(PricesTableCompanion data) {
    return PriceEntry(
      tierChar: data.tierChar.present ? data.tierChar.value : this.tierChar,
      price: data.price.present ? data.price.value : this.price,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PriceEntry(')
          ..write('tierChar: $tierChar, ')
          ..write('price: $price')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tierChar, price);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceEntry &&
          other.tierChar == this.tierChar &&
          other.price == this.price);
}

class PricesTableCompanion extends UpdateCompanion<PriceEntry> {
  final Value<String> tierChar;
  final Value<double> price;
  final Value<int> rowid;
  const PricesTableCompanion({
    this.tierChar = const Value.absent(),
    this.price = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricesTableCompanion.insert({
    required String tierChar,
    required double price,
    this.rowid = const Value.absent(),
  })  : tierChar = Value(tierChar),
        price = Value(price);
  static Insertable<PriceEntry> custom({
    Expression<String>? tierChar,
    Expression<double>? price,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tierChar != null) 'tier_char': tierChar,
      if (price != null) 'price': price,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricesTableCompanion copyWith(
      {Value<String>? tierChar, Value<double>? price, Value<int>? rowid}) {
    return PricesTableCompanion(
      tierChar: tierChar ?? this.tierChar,
      price: price ?? this.price,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tierChar.present) {
      map['tier_char'] = Variable<String>(tierChar.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricesTableCompanion(')
          ..write('tierChar: $tierChar, ')
          ..write('price: $price, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssetsTableTable extends AssetsTable
    with TableInfo<$AssetsTableTable, AssetEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, type, name, filePath, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assets_table';
  @override
  VerificationContext validateIntegrity(Insertable<AssetEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssetEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $AssetsTableTable createAlias(String alias) {
    return $AssetsTableTable(attachedDatabase, alias);
  }
}

class AssetEntry extends DataClass implements Insertable<AssetEntry> {
  final int id;
  final String type;
  final String name;
  final String filePath;
  final DateTime addedAt;
  const AssetEntry(
      {required this.id,
      required this.type,
      required this.name,
      required this.filePath,
      required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    map['file_path'] = Variable<String>(filePath);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  AssetsTableCompanion toCompanion(bool nullToAbsent) {
    return AssetsTableCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      filePath: Value(filePath),
      addedAt: Value(addedAt),
    );
  }

  factory AssetEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetEntry(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      filePath: serializer.fromJson<String>(json['filePath']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'filePath': serializer.toJson<String>(filePath),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  AssetEntry copyWith(
          {int? id,
          String? type,
          String? name,
          String? filePath,
          DateTime? addedAt}) =>
      AssetEntry(
        id: id ?? this.id,
        type: type ?? this.type,
        name: name ?? this.name,
        filePath: filePath ?? this.filePath,
        addedAt: addedAt ?? this.addedAt,
      );
  AssetEntry copyWithCompanion(AssetsTableCompanion data) {
    return AssetEntry(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetEntry(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('filePath: $filePath, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, name, filePath, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetEntry &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.filePath == this.filePath &&
          other.addedAt == this.addedAt);
}

class AssetsTableCompanion extends UpdateCompanion<AssetEntry> {
  final Value<int> id;
  final Value<String> type;
  final Value<String> name;
  final Value<String> filePath;
  final Value<DateTime> addedAt;
  const AssetsTableCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.filePath = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  AssetsTableCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required String name,
    required String filePath,
    required DateTime addedAt,
  })  : type = Value(type),
        name = Value(name),
        filePath = Value(filePath),
        addedAt = Value(addedAt);
  static Insertable<AssetEntry> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? filePath,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (filePath != null) 'file_path': filePath,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  AssetsTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? type,
      Value<String>? name,
      Value<String>? filePath,
      Value<DateTime>? addedAt}) {
    return AssetsTableCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetsTableCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('filePath: $filePath, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $PrintersTableTable extends PrintersTable
    with TableInfo<$PrintersTableTable, PrinterEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrintersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _transportMeta =
      const VerificationMeta('transport');
  @override
  late final GeneratedColumn<String> transport = GeneratedColumn<String>(
      'transport', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _paperWidthMmMeta =
      const VerificationMeta('paperWidthMm');
  @override
  late final GeneratedColumn<int> paperWidthMm = GeneratedColumn<int>(
      'paper_width_mm', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(80));
  static const VerificationMeta _isDefaultMeta =
      const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
      'is_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, transport, address, paperWidthMm, isDefault];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'printers_table';
  @override
  VerificationContext validateIntegrity(Insertable<PrinterEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('transport')) {
      context.handle(_transportMeta,
          transport.isAcceptableOrUnknown(data['transport']!, _transportMeta));
    } else if (isInserting) {
      context.missing(_transportMeta);
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('paper_width_mm')) {
      context.handle(
          _paperWidthMmMeta,
          paperWidthMm.isAcceptableOrUnknown(
              data['paper_width_mm']!, _paperWidthMmMeta));
    }
    if (data.containsKey('is_default')) {
      context.handle(_isDefaultMeta,
          isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrinterEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrinterEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      transport: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transport'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address'])!,
      paperWidthMm: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}paper_width_mm'])!,
      isDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_default'])!,
    );
  }

  @override
  $PrintersTableTable createAlias(String alias) {
    return $PrintersTableTable(attachedDatabase, alias);
  }
}

class PrinterEntry extends DataClass implements Insertable<PrinterEntry> {
  final String id;
  final String name;
  final String transport;
  final String address;
  final int paperWidthMm;
  final bool isDefault;
  const PrinterEntry(
      {required this.id,
      required this.name,
      required this.transport,
      required this.address,
      required this.paperWidthMm,
      required this.isDefault});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['transport'] = Variable<String>(transport);
    map['address'] = Variable<String>(address);
    map['paper_width_mm'] = Variable<int>(paperWidthMm);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  PrintersTableCompanion toCompanion(bool nullToAbsent) {
    return PrintersTableCompanion(
      id: Value(id),
      name: Value(name),
      transport: Value(transport),
      address: Value(address),
      paperWidthMm: Value(paperWidthMm),
      isDefault: Value(isDefault),
    );
  }

  factory PrinterEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrinterEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      transport: serializer.fromJson<String>(json['transport']),
      address: serializer.fromJson<String>(json['address']),
      paperWidthMm: serializer.fromJson<int>(json['paperWidthMm']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'transport': serializer.toJson<String>(transport),
      'address': serializer.toJson<String>(address),
      'paperWidthMm': serializer.toJson<int>(paperWidthMm),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  PrinterEntry copyWith(
          {String? id,
          String? name,
          String? transport,
          String? address,
          int? paperWidthMm,
          bool? isDefault}) =>
      PrinterEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        transport: transport ?? this.transport,
        address: address ?? this.address,
        paperWidthMm: paperWidthMm ?? this.paperWidthMm,
        isDefault: isDefault ?? this.isDefault,
      );
  PrinterEntry copyWithCompanion(PrintersTableCompanion data) {
    return PrinterEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      transport: data.transport.present ? data.transport.value : this.transport,
      address: data.address.present ? data.address.value : this.address,
      paperWidthMm: data.paperWidthMm.present
          ? data.paperWidthMm.value
          : this.paperWidthMm,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrinterEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('transport: $transport, ')
          ..write('address: $address, ')
          ..write('paperWidthMm: $paperWidthMm, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, transport, address, paperWidthMm, isDefault);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrinterEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.transport == this.transport &&
          other.address == this.address &&
          other.paperWidthMm == this.paperWidthMm &&
          other.isDefault == this.isDefault);
}

class PrintersTableCompanion extends UpdateCompanion<PrinterEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> transport;
  final Value<String> address;
  final Value<int> paperWidthMm;
  final Value<bool> isDefault;
  final Value<int> rowid;
  const PrintersTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.transport = const Value.absent(),
    this.address = const Value.absent(),
    this.paperWidthMm = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrintersTableCompanion.insert({
    required String id,
    required String name,
    required String transport,
    required String address,
    this.paperWidthMm = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        transport = Value(transport),
        address = Value(address);
  static Insertable<PrinterEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? transport,
    Expression<String>? address,
    Expression<int>? paperWidthMm,
    Expression<bool>? isDefault,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (transport != null) 'transport': transport,
      if (address != null) 'address': address,
      if (paperWidthMm != null) 'paper_width_mm': paperWidthMm,
      if (isDefault != null) 'is_default': isDefault,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrintersTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? transport,
      Value<String>? address,
      Value<int>? paperWidthMm,
      Value<bool>? isDefault,
      Value<int>? rowid}) {
    return PrintersTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      transport: transport ?? this.transport,
      address: address ?? this.address,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      isDefault: isDefault ?? this.isDefault,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (transport.present) {
      map['transport'] = Variable<String>(transport.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (paperWidthMm.present) {
      map['paper_width_mm'] = Variable<int>(paperWidthMm.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrintersTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('transport: $transport, ')
          ..write('address: $address, ')
          ..write('paperWidthMm: $paperWidthMm, ')
          ..write('isDefault: $isDefault, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VouchersTableTable extends VouchersTable
    with TableInfo<$VouchersTableTable, VoucherEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VouchersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
      'location_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tierCharMeta =
      const VerificationMeta('tierChar');
  @override
  late final GeneratedColumn<String> tierChar = GeneratedColumn<String>(
      'tier_char', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serialMeta = const VerificationMeta('serial');
  @override
  late final GeneratedColumn<String> serial = GeneratedColumn<String>(
      'serial', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceSnapshotMeta =
      const VerificationMeta('priceSnapshot');
  @override
  late final GeneratedColumn<double> priceSnapshot = GeneratedColumn<double>(
      'price_snapshot', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _redeemedAtMeta =
      const VerificationMeta('redeemedAt');
  @override
  late final GeneratedColumn<DateTime> redeemedAt = GeneratedColumn<DateTime>(
      'redeemed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _voidReasonMeta =
      const VerificationMeta('voidReason');
  @override
  late final GeneratedColumn<String> voidReason = GeneratedColumn<String>(
      'void_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        code,
        locationId,
        tierChar,
        serial,
        priceSnapshot,
        status,
        expiresAt,
        createdAt,
        redeemedAt,
        voidReason
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vouchers_table';
  @override
  VerificationContext validateIntegrity(Insertable<VoucherEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('tier_char')) {
      context.handle(_tierCharMeta,
          tierChar.isAcceptableOrUnknown(data['tier_char']!, _tierCharMeta));
    } else if (isInserting) {
      context.missing(_tierCharMeta);
    }
    if (data.containsKey('serial')) {
      context.handle(_serialMeta,
          serial.isAcceptableOrUnknown(data['serial']!, _serialMeta));
    } else if (isInserting) {
      context.missing(_serialMeta);
    }
    if (data.containsKey('price_snapshot')) {
      context.handle(
          _priceSnapshotMeta,
          priceSnapshot.isAcceptableOrUnknown(
              data['price_snapshot']!, _priceSnapshotMeta));
    } else if (isInserting) {
      context.missing(_priceSnapshotMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('redeemed_at')) {
      context.handle(
          _redeemedAtMeta,
          redeemedAt.isAcceptableOrUnknown(
              data['redeemed_at']!, _redeemedAtMeta));
    }
    if (data.containsKey('void_reason')) {
      context.handle(
          _voidReasonMeta,
          voidReason.isAcceptableOrUnknown(
              data['void_reason']!, _voidReasonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  VoucherEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoucherEntry(
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_id'])!,
      tierChar: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tier_char'])!,
      serial: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serial'])!,
      priceSnapshot: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price_snapshot'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      redeemedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}redeemed_at']),
      voidReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}void_reason']),
    );
  }

  @override
  $VouchersTableTable createAlias(String alias) {
    return $VouchersTableTable(attachedDatabase, alias);
  }
}

class VoucherEntry extends DataClass implements Insertable<VoucherEntry> {
  final String code;
  final String locationId;
  final String tierChar;
  final String serial;
  final double priceSnapshot;
  final int status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? redeemedAt;
  final String? voidReason;
  const VoucherEntry(
      {required this.code,
      required this.locationId,
      required this.tierChar,
      required this.serial,
      required this.priceSnapshot,
      required this.status,
      required this.expiresAt,
      required this.createdAt,
      this.redeemedAt,
      this.voidReason});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['location_id'] = Variable<String>(locationId);
    map['tier_char'] = Variable<String>(tierChar);
    map['serial'] = Variable<String>(serial);
    map['price_snapshot'] = Variable<double>(priceSnapshot);
    map['status'] = Variable<int>(status);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || redeemedAt != null) {
      map['redeemed_at'] = Variable<DateTime>(redeemedAt);
    }
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    return map;
  }

  VouchersTableCompanion toCompanion(bool nullToAbsent) {
    return VouchersTableCompanion(
      code: Value(code),
      locationId: Value(locationId),
      tierChar: Value(tierChar),
      serial: Value(serial),
      priceSnapshot: Value(priceSnapshot),
      status: Value(status),
      expiresAt: Value(expiresAt),
      createdAt: Value(createdAt),
      redeemedAt: redeemedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(redeemedAt),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
    );
  }

  factory VoucherEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoucherEntry(
      code: serializer.fromJson<String>(json['code']),
      locationId: serializer.fromJson<String>(json['locationId']),
      tierChar: serializer.fromJson<String>(json['tierChar']),
      serial: serializer.fromJson<String>(json['serial']),
      priceSnapshot: serializer.fromJson<double>(json['priceSnapshot']),
      status: serializer.fromJson<int>(json['status']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      redeemedAt: serializer.fromJson<DateTime?>(json['redeemedAt']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'locationId': serializer.toJson<String>(locationId),
      'tierChar': serializer.toJson<String>(tierChar),
      'serial': serializer.toJson<String>(serial),
      'priceSnapshot': serializer.toJson<double>(priceSnapshot),
      'status': serializer.toJson<int>(status),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'redeemedAt': serializer.toJson<DateTime?>(redeemedAt),
      'voidReason': serializer.toJson<String?>(voidReason),
    };
  }

  VoucherEntry copyWith(
          {String? code,
          String? locationId,
          String? tierChar,
          String? serial,
          double? priceSnapshot,
          int? status,
          DateTime? expiresAt,
          DateTime? createdAt,
          Value<DateTime?> redeemedAt = const Value.absent(),
          Value<String?> voidReason = const Value.absent()}) =>
      VoucherEntry(
        code: code ?? this.code,
        locationId: locationId ?? this.locationId,
        tierChar: tierChar ?? this.tierChar,
        serial: serial ?? this.serial,
        priceSnapshot: priceSnapshot ?? this.priceSnapshot,
        status: status ?? this.status,
        expiresAt: expiresAt ?? this.expiresAt,
        createdAt: createdAt ?? this.createdAt,
        redeemedAt: redeemedAt.present ? redeemedAt.value : this.redeemedAt,
        voidReason: voidReason.present ? voidReason.value : this.voidReason,
      );
  VoucherEntry copyWithCompanion(VouchersTableCompanion data) {
    return VoucherEntry(
      code: data.code.present ? data.code.value : this.code,
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      tierChar: data.tierChar.present ? data.tierChar.value : this.tierChar,
      serial: data.serial.present ? data.serial.value : this.serial,
      priceSnapshot: data.priceSnapshot.present
          ? data.priceSnapshot.value
          : this.priceSnapshot,
      status: data.status.present ? data.status.value : this.status,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      redeemedAt:
          data.redeemedAt.present ? data.redeemedAt.value : this.redeemedAt,
      voidReason:
          data.voidReason.present ? data.voidReason.value : this.voidReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoucherEntry(')
          ..write('code: $code, ')
          ..write('locationId: $locationId, ')
          ..write('tierChar: $tierChar, ')
          ..write('serial: $serial, ')
          ..write('priceSnapshot: $priceSnapshot, ')
          ..write('status: $status, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('redeemedAt: $redeemedAt, ')
          ..write('voidReason: $voidReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(code, locationId, tierChar, serial,
      priceSnapshot, status, expiresAt, createdAt, redeemedAt, voidReason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoucherEntry &&
          other.code == this.code &&
          other.locationId == this.locationId &&
          other.tierChar == this.tierChar &&
          other.serial == this.serial &&
          other.priceSnapshot == this.priceSnapshot &&
          other.status == this.status &&
          other.expiresAt == this.expiresAt &&
          other.createdAt == this.createdAt &&
          other.redeemedAt == this.redeemedAt &&
          other.voidReason == this.voidReason);
}

class VouchersTableCompanion extends UpdateCompanion<VoucherEntry> {
  final Value<String> code;
  final Value<String> locationId;
  final Value<String> tierChar;
  final Value<String> serial;
  final Value<double> priceSnapshot;
  final Value<int> status;
  final Value<DateTime> expiresAt;
  final Value<DateTime> createdAt;
  final Value<DateTime?> redeemedAt;
  final Value<String?> voidReason;
  final Value<int> rowid;
  const VouchersTableCompanion({
    this.code = const Value.absent(),
    this.locationId = const Value.absent(),
    this.tierChar = const Value.absent(),
    this.serial = const Value.absent(),
    this.priceSnapshot = const Value.absent(),
    this.status = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.redeemedAt = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VouchersTableCompanion.insert({
    required String code,
    required String locationId,
    required String tierChar,
    required String serial,
    required double priceSnapshot,
    this.status = const Value.absent(),
    required DateTime expiresAt,
    required DateTime createdAt,
    this.redeemedAt = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : code = Value(code),
        locationId = Value(locationId),
        tierChar = Value(tierChar),
        serial = Value(serial),
        priceSnapshot = Value(priceSnapshot),
        expiresAt = Value(expiresAt),
        createdAt = Value(createdAt);
  static Insertable<VoucherEntry> custom({
    Expression<String>? code,
    Expression<String>? locationId,
    Expression<String>? tierChar,
    Expression<String>? serial,
    Expression<double>? priceSnapshot,
    Expression<int>? status,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? redeemedAt,
    Expression<String>? voidReason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (locationId != null) 'location_id': locationId,
      if (tierChar != null) 'tier_char': tierChar,
      if (serial != null) 'serial': serial,
      if (priceSnapshot != null) 'price_snapshot': priceSnapshot,
      if (status != null) 'status': status,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (createdAt != null) 'created_at': createdAt,
      if (redeemedAt != null) 'redeemed_at': redeemedAt,
      if (voidReason != null) 'void_reason': voidReason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VouchersTableCompanion copyWith(
      {Value<String>? code,
      Value<String>? locationId,
      Value<String>? tierChar,
      Value<String>? serial,
      Value<double>? priceSnapshot,
      Value<int>? status,
      Value<DateTime>? expiresAt,
      Value<DateTime>? createdAt,
      Value<DateTime?>? redeemedAt,
      Value<String?>? voidReason,
      Value<int>? rowid}) {
    return VouchersTableCompanion(
      code: code ?? this.code,
      locationId: locationId ?? this.locationId,
      tierChar: tierChar ?? this.tierChar,
      serial: serial ?? this.serial,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      redeemedAt: redeemedAt ?? this.redeemedAt,
      voidReason: voidReason ?? this.voidReason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (tierChar.present) {
      map['tier_char'] = Variable<String>(tierChar.value);
    }
    if (serial.present) {
      map['serial'] = Variable<String>(serial.value);
    }
    if (priceSnapshot.present) {
      map['price_snapshot'] = Variable<double>(priceSnapshot.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (redeemedAt.present) {
      map['redeemed_at'] = Variable<DateTime>(redeemedAt.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VouchersTableCompanion(')
          ..write('code: $code, ')
          ..write('locationId: $locationId, ')
          ..write('tierChar: $tierChar, ')
          ..write('serial: $serial, ')
          ..write('priceSnapshot: $priceSnapshot, ')
          ..write('status: $status, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('redeemedAt: $redeemedAt, ')
          ..write('voidReason: $voidReason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SalesTableTable extends SalesTable
    with TableInfo<$SalesTableTable, SaleEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
      'location_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tierCharMeta =
      const VerificationMeta('tierChar');
  @override
  late final GeneratedColumn<String> tierChar = GeneratedColumn<String>(
      'tier_char', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serialMeta = const VerificationMeta('serial');
  @override
  late final GeneratedColumn<String> serial = GeneratedColumn<String>(
      'serial', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceSnapshotMeta =
      const VerificationMeta('priceSnapshot');
  @override
  late final GeneratedColumn<double> priceSnapshot = GeneratedColumn<double>(
      'price_snapshot', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _redeemedAtMeta =
      const VerificationMeta('redeemedAt');
  @override
  late final GeneratedColumn<DateTime> redeemedAt = GeneratedColumn<DateTime>(
      'redeemed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        code,
        locationId,
        tierChar,
        serial,
        priceSnapshot,
        status,
        expiresAt,
        createdAt,
        redeemedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales_table';
  @override
  VerificationContext validateIntegrity(Insertable<SaleEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('tier_char')) {
      context.handle(_tierCharMeta,
          tierChar.isAcceptableOrUnknown(data['tier_char']!, _tierCharMeta));
    } else if (isInserting) {
      context.missing(_tierCharMeta);
    }
    if (data.containsKey('serial')) {
      context.handle(_serialMeta,
          serial.isAcceptableOrUnknown(data['serial']!, _serialMeta));
    } else if (isInserting) {
      context.missing(_serialMeta);
    }
    if (data.containsKey('price_snapshot')) {
      context.handle(
          _priceSnapshotMeta,
          priceSnapshot.isAcceptableOrUnknown(
              data['price_snapshot']!, _priceSnapshotMeta));
    } else if (isInserting) {
      context.missing(_priceSnapshotMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('redeemed_at')) {
      context.handle(
          _redeemedAtMeta,
          redeemedAt.isAcceptableOrUnknown(
              data['redeemed_at']!, _redeemedAtMeta));
    } else if (isInserting) {
      context.missing(_redeemedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  SaleEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleEntry(
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_id'])!,
      tierChar: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tier_char'])!,
      serial: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serial'])!,
      priceSnapshot: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price_snapshot'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      redeemedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}redeemed_at'])!,
    );
  }

  @override
  $SalesTableTable createAlias(String alias) {
    return $SalesTableTable(attachedDatabase, alias);
  }
}

class SaleEntry extends DataClass implements Insertable<SaleEntry> {
  final String code;
  final String locationId;
  final String tierChar;
  final String serial;
  final double priceSnapshot;
  final int status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime redeemedAt;
  const SaleEntry(
      {required this.code,
      required this.locationId,
      required this.tierChar,
      required this.serial,
      required this.priceSnapshot,
      required this.status,
      required this.expiresAt,
      required this.createdAt,
      required this.redeemedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['location_id'] = Variable<String>(locationId);
    map['tier_char'] = Variable<String>(tierChar);
    map['serial'] = Variable<String>(serial);
    map['price_snapshot'] = Variable<double>(priceSnapshot);
    map['status'] = Variable<int>(status);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['redeemed_at'] = Variable<DateTime>(redeemedAt);
    return map;
  }

  SalesTableCompanion toCompanion(bool nullToAbsent) {
    return SalesTableCompanion(
      code: Value(code),
      locationId: Value(locationId),
      tierChar: Value(tierChar),
      serial: Value(serial),
      priceSnapshot: Value(priceSnapshot),
      status: Value(status),
      expiresAt: Value(expiresAt),
      createdAt: Value(createdAt),
      redeemedAt: Value(redeemedAt),
    );
  }

  factory SaleEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleEntry(
      code: serializer.fromJson<String>(json['code']),
      locationId: serializer.fromJson<String>(json['locationId']),
      tierChar: serializer.fromJson<String>(json['tierChar']),
      serial: serializer.fromJson<String>(json['serial']),
      priceSnapshot: serializer.fromJson<double>(json['priceSnapshot']),
      status: serializer.fromJson<int>(json['status']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      redeemedAt: serializer.fromJson<DateTime>(json['redeemedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'locationId': serializer.toJson<String>(locationId),
      'tierChar': serializer.toJson<String>(tierChar),
      'serial': serializer.toJson<String>(serial),
      'priceSnapshot': serializer.toJson<double>(priceSnapshot),
      'status': serializer.toJson<int>(status),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'redeemedAt': serializer.toJson<DateTime>(redeemedAt),
    };
  }

  SaleEntry copyWith(
          {String? code,
          String? locationId,
          String? tierChar,
          String? serial,
          double? priceSnapshot,
          int? status,
          DateTime? expiresAt,
          DateTime? createdAt,
          DateTime? redeemedAt}) =>
      SaleEntry(
        code: code ?? this.code,
        locationId: locationId ?? this.locationId,
        tierChar: tierChar ?? this.tierChar,
        serial: serial ?? this.serial,
        priceSnapshot: priceSnapshot ?? this.priceSnapshot,
        status: status ?? this.status,
        expiresAt: expiresAt ?? this.expiresAt,
        createdAt: createdAt ?? this.createdAt,
        redeemedAt: redeemedAt ?? this.redeemedAt,
      );
  SaleEntry copyWithCompanion(SalesTableCompanion data) {
    return SaleEntry(
      code: data.code.present ? data.code.value : this.code,
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      tierChar: data.tierChar.present ? data.tierChar.value : this.tierChar,
      serial: data.serial.present ? data.serial.value : this.serial,
      priceSnapshot: data.priceSnapshot.present
          ? data.priceSnapshot.value
          : this.priceSnapshot,
      status: data.status.present ? data.status.value : this.status,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      redeemedAt:
          data.redeemedAt.present ? data.redeemedAt.value : this.redeemedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleEntry(')
          ..write('code: $code, ')
          ..write('locationId: $locationId, ')
          ..write('tierChar: $tierChar, ')
          ..write('serial: $serial, ')
          ..write('priceSnapshot: $priceSnapshot, ')
          ..write('status: $status, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('redeemedAt: $redeemedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(code, locationId, tierChar, serial,
      priceSnapshot, status, expiresAt, createdAt, redeemedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleEntry &&
          other.code == this.code &&
          other.locationId == this.locationId &&
          other.tierChar == this.tierChar &&
          other.serial == this.serial &&
          other.priceSnapshot == this.priceSnapshot &&
          other.status == this.status &&
          other.expiresAt == this.expiresAt &&
          other.createdAt == this.createdAt &&
          other.redeemedAt == this.redeemedAt);
}

class SalesTableCompanion extends UpdateCompanion<SaleEntry> {
  final Value<String> code;
  final Value<String> locationId;
  final Value<String> tierChar;
  final Value<String> serial;
  final Value<double> priceSnapshot;
  final Value<int> status;
  final Value<DateTime> expiresAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> redeemedAt;
  final Value<int> rowid;
  const SalesTableCompanion({
    this.code = const Value.absent(),
    this.locationId = const Value.absent(),
    this.tierChar = const Value.absent(),
    this.serial = const Value.absent(),
    this.priceSnapshot = const Value.absent(),
    this.status = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.redeemedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalesTableCompanion.insert({
    required String code,
    required String locationId,
    required String tierChar,
    required String serial,
    required double priceSnapshot,
    this.status = const Value.absent(),
    required DateTime expiresAt,
    required DateTime createdAt,
    required DateTime redeemedAt,
    this.rowid = const Value.absent(),
  })  : code = Value(code),
        locationId = Value(locationId),
        tierChar = Value(tierChar),
        serial = Value(serial),
        priceSnapshot = Value(priceSnapshot),
        expiresAt = Value(expiresAt),
        createdAt = Value(createdAt),
        redeemedAt = Value(redeemedAt);
  static Insertable<SaleEntry> custom({
    Expression<String>? code,
    Expression<String>? locationId,
    Expression<String>? tierChar,
    Expression<String>? serial,
    Expression<double>? priceSnapshot,
    Expression<int>? status,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? redeemedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (locationId != null) 'location_id': locationId,
      if (tierChar != null) 'tier_char': tierChar,
      if (serial != null) 'serial': serial,
      if (priceSnapshot != null) 'price_snapshot': priceSnapshot,
      if (status != null) 'status': status,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (createdAt != null) 'created_at': createdAt,
      if (redeemedAt != null) 'redeemed_at': redeemedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalesTableCompanion copyWith(
      {Value<String>? code,
      Value<String>? locationId,
      Value<String>? tierChar,
      Value<String>? serial,
      Value<double>? priceSnapshot,
      Value<int>? status,
      Value<DateTime>? expiresAt,
      Value<DateTime>? createdAt,
      Value<DateTime>? redeemedAt,
      Value<int>? rowid}) {
    return SalesTableCompanion(
      code: code ?? this.code,
      locationId: locationId ?? this.locationId,
      tierChar: tierChar ?? this.tierChar,
      serial: serial ?? this.serial,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      redeemedAt: redeemedAt ?? this.redeemedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (tierChar.present) {
      map['tier_char'] = Variable<String>(tierChar.value);
    }
    if (serial.present) {
      map['serial'] = Variable<String>(serial.value);
    }
    if (priceSnapshot.present) {
      map['price_snapshot'] = Variable<double>(priceSnapshot.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (redeemedAt.present) {
      map['redeemed_at'] = Variable<DateTime>(redeemedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesTableCompanion(')
          ..write('code: $code, ')
          ..write('locationId: $locationId, ')
          ..write('tierChar: $tierChar, ')
          ..write('serial: $serial, ')
          ..write('priceSnapshot: $priceSnapshot, ')
          ..write('status: $status, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('redeemedAt: $redeemedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTableTable extends SessionsTable
    with TableInfo<$SessionsTableTable, SessionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _voucherCodeMeta =
      const VerificationMeta('voucherCode');
  @override
  late final GeneratedColumn<String> voucherCode = GeneratedColumn<String>(
      'voucher_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tierCharMeta =
      const VerificationMeta('tierChar');
  @override
  late final GeneratedColumn<String> tierChar = GeneratedColumn<String>(
      'tier_char', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _layoutTypeMeta =
      const VerificationMeta('layoutType');
  @override
  late final GeneratedColumn<String> layoutType = GeneratedColumn<String>(
      'layout_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _localImagePathsMeta =
      const VerificationMeta('localImagePaths');
  @override
  late final GeneratedColumn<String> localImagePaths = GeneratedColumn<String>(
      'local_image_paths', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _composedImagePathMeta =
      const VerificationMeta('composedImagePath');
  @override
  late final GeneratedColumn<String> composedImagePath =
      GeneratedColumn<String>('composed_image_path', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _gifPathMeta =
      const VerificationMeta('gifPath');
  @override
  late final GeneratedColumn<String> gifPath = GeneratedColumn<String>(
      'gif_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _driveFileIdMeta =
      const VerificationMeta('driveFileId');
  @override
  late final GeneratedColumn<String> driveFileId = GeneratedColumn<String>(
      'drive_file_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _driveShareUrlMeta =
      const VerificationMeta('driveShareUrl');
  @override
  late final GeneratedColumn<String> driveShareUrl = GeneratedColumn<String>(
      'drive_share_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isUploadedMeta =
      const VerificationMeta('isUploaded');
  @override
  late final GeneratedColumn<bool> isUploaded = GeneratedColumn<bool>(
      'is_uploaded', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_uploaded" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isPrintedMeta =
      const VerificationMeta('isPrinted');
  @override
  late final GeneratedColumn<bool> isPrinted = GeneratedColumn<bool>(
      'is_printed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_printed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        sessionId,
        voucherCode,
        tierChar,
        layoutType,
        localImagePaths,
        composedImagePath,
        gifPath,
        driveFileId,
        driveShareUrl,
        isUploaded,
        isPrinted,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions_table';
  @override
  VerificationContext validateIntegrity(Insertable<SessionEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('voucher_code')) {
      context.handle(
          _voucherCodeMeta,
          voucherCode.isAcceptableOrUnknown(
              data['voucher_code']!, _voucherCodeMeta));
    } else if (isInserting) {
      context.missing(_voucherCodeMeta);
    }
    if (data.containsKey('tier_char')) {
      context.handle(_tierCharMeta,
          tierChar.isAcceptableOrUnknown(data['tier_char']!, _tierCharMeta));
    } else if (isInserting) {
      context.missing(_tierCharMeta);
    }
    if (data.containsKey('layout_type')) {
      context.handle(
          _layoutTypeMeta,
          layoutType.isAcceptableOrUnknown(
              data['layout_type']!, _layoutTypeMeta));
    }
    if (data.containsKey('local_image_paths')) {
      context.handle(
          _localImagePathsMeta,
          localImagePaths.isAcceptableOrUnknown(
              data['local_image_paths']!, _localImagePathsMeta));
    } else if (isInserting) {
      context.missing(_localImagePathsMeta);
    }
    if (data.containsKey('composed_image_path')) {
      context.handle(
          _composedImagePathMeta,
          composedImagePath.isAcceptableOrUnknown(
              data['composed_image_path']!, _composedImagePathMeta));
    }
    if (data.containsKey('gif_path')) {
      context.handle(_gifPathMeta,
          gifPath.isAcceptableOrUnknown(data['gif_path']!, _gifPathMeta));
    }
    if (data.containsKey('drive_file_id')) {
      context.handle(
          _driveFileIdMeta,
          driveFileId.isAcceptableOrUnknown(
              data['drive_file_id']!, _driveFileIdMeta));
    }
    if (data.containsKey('drive_share_url')) {
      context.handle(
          _driveShareUrlMeta,
          driveShareUrl.isAcceptableOrUnknown(
              data['drive_share_url']!, _driveShareUrlMeta));
    }
    if (data.containsKey('is_uploaded')) {
      context.handle(
          _isUploadedMeta,
          isUploaded.isAcceptableOrUnknown(
              data['is_uploaded']!, _isUploadedMeta));
    }
    if (data.containsKey('is_printed')) {
      context.handle(_isPrintedMeta,
          isPrinted.isAcceptableOrUnknown(data['is_printed']!, _isPrintedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  SessionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionEntry(
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      voucherCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}voucher_code'])!,
      tierChar: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tier_char'])!,
      layoutType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}layout_type']),
      localImagePaths: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_image_paths'])!,
      composedImagePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}composed_image_path']),
      gifPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gif_path']),
      driveFileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}drive_file_id']),
      driveShareUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}drive_share_url']),
      isUploaded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_uploaded'])!,
      isPrinted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_printed'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SessionsTableTable createAlias(String alias) {
    return $SessionsTableTable(attachedDatabase, alias);
  }
}

class SessionEntry extends DataClass implements Insertable<SessionEntry> {
  final String sessionId;
  final String voucherCode;
  final String tierChar;
  final String? layoutType;
  final String localImagePaths;
  final String? composedImagePath;
  final String? gifPath;
  final String? driveFileId;
  final String? driveShareUrl;
  final bool isUploaded;
  final bool isPrinted;
  final DateTime createdAt;
  const SessionEntry(
      {required this.sessionId,
      required this.voucherCode,
      required this.tierChar,
      this.layoutType,
      required this.localImagePaths,
      this.composedImagePath,
      this.gifPath,
      this.driveFileId,
      this.driveShareUrl,
      required this.isUploaded,
      required this.isPrinted,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['voucher_code'] = Variable<String>(voucherCode);
    map['tier_char'] = Variable<String>(tierChar);
    if (!nullToAbsent || layoutType != null) {
      map['layout_type'] = Variable<String>(layoutType);
    }
    map['local_image_paths'] = Variable<String>(localImagePaths);
    if (!nullToAbsent || composedImagePath != null) {
      map['composed_image_path'] = Variable<String>(composedImagePath);
    }
    if (!nullToAbsent || gifPath != null) {
      map['gif_path'] = Variable<String>(gifPath);
    }
    if (!nullToAbsent || driveFileId != null) {
      map['drive_file_id'] = Variable<String>(driveFileId);
    }
    if (!nullToAbsent || driveShareUrl != null) {
      map['drive_share_url'] = Variable<String>(driveShareUrl);
    }
    map['is_uploaded'] = Variable<bool>(isUploaded);
    map['is_printed'] = Variable<bool>(isPrinted);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SessionsTableCompanion toCompanion(bool nullToAbsent) {
    return SessionsTableCompanion(
      sessionId: Value(sessionId),
      voucherCode: Value(voucherCode),
      tierChar: Value(tierChar),
      layoutType: layoutType == null && nullToAbsent
          ? const Value.absent()
          : Value(layoutType),
      localImagePaths: Value(localImagePaths),
      composedImagePath: composedImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(composedImagePath),
      gifPath: gifPath == null && nullToAbsent
          ? const Value.absent()
          : Value(gifPath),
      driveFileId: driveFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(driveFileId),
      driveShareUrl: driveShareUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(driveShareUrl),
      isUploaded: Value(isUploaded),
      isPrinted: Value(isPrinted),
      createdAt: Value(createdAt),
    );
  }

  factory SessionEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionEntry(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      voucherCode: serializer.fromJson<String>(json['voucherCode']),
      tierChar: serializer.fromJson<String>(json['tierChar']),
      layoutType: serializer.fromJson<String?>(json['layoutType']),
      localImagePaths: serializer.fromJson<String>(json['localImagePaths']),
      composedImagePath:
          serializer.fromJson<String?>(json['composedImagePath']),
      gifPath: serializer.fromJson<String?>(json['gifPath']),
      driveFileId: serializer.fromJson<String?>(json['driveFileId']),
      driveShareUrl: serializer.fromJson<String?>(json['driveShareUrl']),
      isUploaded: serializer.fromJson<bool>(json['isUploaded']),
      isPrinted: serializer.fromJson<bool>(json['isPrinted']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'voucherCode': serializer.toJson<String>(voucherCode),
      'tierChar': serializer.toJson<String>(tierChar),
      'layoutType': serializer.toJson<String?>(layoutType),
      'localImagePaths': serializer.toJson<String>(localImagePaths),
      'composedImagePath': serializer.toJson<String?>(composedImagePath),
      'gifPath': serializer.toJson<String?>(gifPath),
      'driveFileId': serializer.toJson<String?>(driveFileId),
      'driveShareUrl': serializer.toJson<String?>(driveShareUrl),
      'isUploaded': serializer.toJson<bool>(isUploaded),
      'isPrinted': serializer.toJson<bool>(isPrinted),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SessionEntry copyWith(
          {String? sessionId,
          String? voucherCode,
          String? tierChar,
          Value<String?> layoutType = const Value.absent(),
          String? localImagePaths,
          Value<String?> composedImagePath = const Value.absent(),
          Value<String?> gifPath = const Value.absent(),
          Value<String?> driveFileId = const Value.absent(),
          Value<String?> driveShareUrl = const Value.absent(),
          bool? isUploaded,
          bool? isPrinted,
          DateTime? createdAt}) =>
      SessionEntry(
        sessionId: sessionId ?? this.sessionId,
        voucherCode: voucherCode ?? this.voucherCode,
        tierChar: tierChar ?? this.tierChar,
        layoutType: layoutType.present ? layoutType.value : this.layoutType,
        localImagePaths: localImagePaths ?? this.localImagePaths,
        composedImagePath: composedImagePath.present
            ? composedImagePath.value
            : this.composedImagePath,
        gifPath: gifPath.present ? gifPath.value : this.gifPath,
        driveFileId: driveFileId.present ? driveFileId.value : this.driveFileId,
        driveShareUrl:
            driveShareUrl.present ? driveShareUrl.value : this.driveShareUrl,
        isUploaded: isUploaded ?? this.isUploaded,
        isPrinted: isPrinted ?? this.isPrinted,
        createdAt: createdAt ?? this.createdAt,
      );
  SessionEntry copyWithCompanion(SessionsTableCompanion data) {
    return SessionEntry(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      voucherCode:
          data.voucherCode.present ? data.voucherCode.value : this.voucherCode,
      tierChar: data.tierChar.present ? data.tierChar.value : this.tierChar,
      layoutType:
          data.layoutType.present ? data.layoutType.value : this.layoutType,
      localImagePaths: data.localImagePaths.present
          ? data.localImagePaths.value
          : this.localImagePaths,
      composedImagePath: data.composedImagePath.present
          ? data.composedImagePath.value
          : this.composedImagePath,
      gifPath: data.gifPath.present ? data.gifPath.value : this.gifPath,
      driveFileId:
          data.driveFileId.present ? data.driveFileId.value : this.driveFileId,
      driveShareUrl: data.driveShareUrl.present
          ? data.driveShareUrl.value
          : this.driveShareUrl,
      isUploaded:
          data.isUploaded.present ? data.isUploaded.value : this.isUploaded,
      isPrinted: data.isPrinted.present ? data.isPrinted.value : this.isPrinted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionEntry(')
          ..write('sessionId: $sessionId, ')
          ..write('voucherCode: $voucherCode, ')
          ..write('tierChar: $tierChar, ')
          ..write('layoutType: $layoutType, ')
          ..write('localImagePaths: $localImagePaths, ')
          ..write('composedImagePath: $composedImagePath, ')
          ..write('gifPath: $gifPath, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('driveShareUrl: $driveShareUrl, ')
          ..write('isUploaded: $isUploaded, ')
          ..write('isPrinted: $isPrinted, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      sessionId,
      voucherCode,
      tierChar,
      layoutType,
      localImagePaths,
      composedImagePath,
      gifPath,
      driveFileId,
      driveShareUrl,
      isUploaded,
      isPrinted,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionEntry &&
          other.sessionId == this.sessionId &&
          other.voucherCode == this.voucherCode &&
          other.tierChar == this.tierChar &&
          other.layoutType == this.layoutType &&
          other.localImagePaths == this.localImagePaths &&
          other.composedImagePath == this.composedImagePath &&
          other.gifPath == this.gifPath &&
          other.driveFileId == this.driveFileId &&
          other.driveShareUrl == this.driveShareUrl &&
          other.isUploaded == this.isUploaded &&
          other.isPrinted == this.isPrinted &&
          other.createdAt == this.createdAt);
}

class SessionsTableCompanion extends UpdateCompanion<SessionEntry> {
  final Value<String> sessionId;
  final Value<String> voucherCode;
  final Value<String> tierChar;
  final Value<String?> layoutType;
  final Value<String> localImagePaths;
  final Value<String?> composedImagePath;
  final Value<String?> gifPath;
  final Value<String?> driveFileId;
  final Value<String?> driveShareUrl;
  final Value<bool> isUploaded;
  final Value<bool> isPrinted;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SessionsTableCompanion({
    this.sessionId = const Value.absent(),
    this.voucherCode = const Value.absent(),
    this.tierChar = const Value.absent(),
    this.layoutType = const Value.absent(),
    this.localImagePaths = const Value.absent(),
    this.composedImagePath = const Value.absent(),
    this.gifPath = const Value.absent(),
    this.driveFileId = const Value.absent(),
    this.driveShareUrl = const Value.absent(),
    this.isUploaded = const Value.absent(),
    this.isPrinted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsTableCompanion.insert({
    required String sessionId,
    required String voucherCode,
    required String tierChar,
    this.layoutType = const Value.absent(),
    required String localImagePaths,
    this.composedImagePath = const Value.absent(),
    this.gifPath = const Value.absent(),
    this.driveFileId = const Value.absent(),
    this.driveShareUrl = const Value.absent(),
    this.isUploaded = const Value.absent(),
    this.isPrinted = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : sessionId = Value(sessionId),
        voucherCode = Value(voucherCode),
        tierChar = Value(tierChar),
        localImagePaths = Value(localImagePaths),
        createdAt = Value(createdAt);
  static Insertable<SessionEntry> custom({
    Expression<String>? sessionId,
    Expression<String>? voucherCode,
    Expression<String>? tierChar,
    Expression<String>? layoutType,
    Expression<String>? localImagePaths,
    Expression<String>? composedImagePath,
    Expression<String>? gifPath,
    Expression<String>? driveFileId,
    Expression<String>? driveShareUrl,
    Expression<bool>? isUploaded,
    Expression<bool>? isPrinted,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (voucherCode != null) 'voucher_code': voucherCode,
      if (tierChar != null) 'tier_char': tierChar,
      if (layoutType != null) 'layout_type': layoutType,
      if (localImagePaths != null) 'local_image_paths': localImagePaths,
      if (composedImagePath != null) 'composed_image_path': composedImagePath,
      if (gifPath != null) 'gif_path': gifPath,
      if (driveFileId != null) 'drive_file_id': driveFileId,
      if (driveShareUrl != null) 'drive_share_url': driveShareUrl,
      if (isUploaded != null) 'is_uploaded': isUploaded,
      if (isPrinted != null) 'is_printed': isPrinted,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsTableCompanion copyWith(
      {Value<String>? sessionId,
      Value<String>? voucherCode,
      Value<String>? tierChar,
      Value<String?>? layoutType,
      Value<String>? localImagePaths,
      Value<String?>? composedImagePath,
      Value<String?>? gifPath,
      Value<String?>? driveFileId,
      Value<String?>? driveShareUrl,
      Value<bool>? isUploaded,
      Value<bool>? isPrinted,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return SessionsTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      voucherCode: voucherCode ?? this.voucherCode,
      tierChar: tierChar ?? this.tierChar,
      layoutType: layoutType ?? this.layoutType,
      localImagePaths: localImagePaths ?? this.localImagePaths,
      composedImagePath: composedImagePath ?? this.composedImagePath,
      gifPath: gifPath ?? this.gifPath,
      driveFileId: driveFileId ?? this.driveFileId,
      driveShareUrl: driveShareUrl ?? this.driveShareUrl,
      isUploaded: isUploaded ?? this.isUploaded,
      isPrinted: isPrinted ?? this.isPrinted,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (voucherCode.present) {
      map['voucher_code'] = Variable<String>(voucherCode.value);
    }
    if (tierChar.present) {
      map['tier_char'] = Variable<String>(tierChar.value);
    }
    if (layoutType.present) {
      map['layout_type'] = Variable<String>(layoutType.value);
    }
    if (localImagePaths.present) {
      map['local_image_paths'] = Variable<String>(localImagePaths.value);
    }
    if (composedImagePath.present) {
      map['composed_image_path'] = Variable<String>(composedImagePath.value);
    }
    if (gifPath.present) {
      map['gif_path'] = Variable<String>(gifPath.value);
    }
    if (driveFileId.present) {
      map['drive_file_id'] = Variable<String>(driveFileId.value);
    }
    if (driveShareUrl.present) {
      map['drive_share_url'] = Variable<String>(driveShareUrl.value);
    }
    if (isUploaded.present) {
      map['is_uploaded'] = Variable<bool>(isUploaded.value);
    }
    if (isPrinted.present) {
      map['is_printed'] = Variable<bool>(isPrinted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('voucherCode: $voucherCode, ')
          ..write('tierChar: $tierChar, ')
          ..write('layoutType: $layoutType, ')
          ..write('localImagePaths: $localImagePaths, ')
          ..write('composedImagePath: $composedImagePath, ')
          ..write('gifPath: $gifPath, ')
          ..write('driveFileId: $driveFileId, ')
          ..write('driveShareUrl: $driveShareUrl, ')
          ..write('isUploaded: $isUploaded, ')
          ..write('isPrinted: $isPrinted, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AdminAuthTableTable extends AdminAuthTable
    with TableInfo<$AdminAuthTableTable, AdminAuthEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AdminAuthTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _passwordHashMeta =
      const VerificationMeta('passwordHash');
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
      'password_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, passwordHash, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'admin_auth_table';
  @override
  VerificationContext validateIntegrity(Insertable<AdminAuthEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('password_hash')) {
      context.handle(
          _passwordHashMeta,
          passwordHash.isAcceptableOrUnknown(
              data['password_hash']!, _passwordHashMeta));
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AdminAuthEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AdminAuthEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      passwordHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}password_hash'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AdminAuthTableTable createAlias(String alias) {
    return $AdminAuthTableTable(attachedDatabase, alias);
  }
}

class AdminAuthEntry extends DataClass implements Insertable<AdminAuthEntry> {
  final int id;
  final String passwordHash;
  final DateTime updatedAt;
  const AdminAuthEntry(
      {required this.id, required this.passwordHash, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['password_hash'] = Variable<String>(passwordHash);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AdminAuthTableCompanion toCompanion(bool nullToAbsent) {
    return AdminAuthTableCompanion(
      id: Value(id),
      passwordHash: Value(passwordHash),
      updatedAt: Value(updatedAt),
    );
  }

  factory AdminAuthEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AdminAuthEntry(
      id: serializer.fromJson<int>(json['id']),
      passwordHash: serializer.fromJson<String>(json['passwordHash']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'passwordHash': serializer.toJson<String>(passwordHash),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AdminAuthEntry copyWith(
          {int? id, String? passwordHash, DateTime? updatedAt}) =>
      AdminAuthEntry(
        id: id ?? this.id,
        passwordHash: passwordHash ?? this.passwordHash,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AdminAuthEntry copyWithCompanion(AdminAuthTableCompanion data) {
    return AdminAuthEntry(
      id: data.id.present ? data.id.value : this.id,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AdminAuthEntry(')
          ..write('id: $id, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, passwordHash, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AdminAuthEntry &&
          other.id == this.id &&
          other.passwordHash == this.passwordHash &&
          other.updatedAt == this.updatedAt);
}

class AdminAuthTableCompanion extends UpdateCompanion<AdminAuthEntry> {
  final Value<int> id;
  final Value<String> passwordHash;
  final Value<DateTime> updatedAt;
  const AdminAuthTableCompanion({
    this.id = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AdminAuthTableCompanion.insert({
    this.id = const Value.absent(),
    required String passwordHash,
    required DateTime updatedAt,
  })  : passwordHash = Value(passwordHash),
        updatedAt = Value(updatedAt);
  static Insertable<AdminAuthEntry> custom({
    Expression<int>? id,
    Expression<String>? passwordHash,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AdminAuthTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? passwordHash,
      Value<DateTime>? updatedAt}) {
    return AdminAuthTableCompanion(
      id: id ?? this.id,
      passwordHash: passwordHash ?? this.passwordHash,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AdminAuthTableCompanion(')
          ..write('id: $id, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTableTable settingsTable = $SettingsTableTable(this);
  late final $PricesTableTable pricesTable = $PricesTableTable(this);
  late final $AssetsTableTable assetsTable = $AssetsTableTable(this);
  late final $PrintersTableTable printersTable = $PrintersTableTable(this);
  late final $VouchersTableTable vouchersTable = $VouchersTableTable(this);
  late final $SalesTableTable salesTable = $SalesTableTable(this);
  late final $SessionsTableTable sessionsTable = $SessionsTableTable(this);
  late final $AdminAuthTableTable adminAuthTable = $AdminAuthTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        settingsTable,
        pricesTable,
        assetsTable,
        printersTable,
        vouchersTable,
        salesTable,
        sessionsTable,
        adminAuthTable
      ];
}

typedef $$SettingsTableTableCreateCompanionBuilder = SettingsTableCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableTableUpdateCompanionBuilder = SettingsTableCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTableTable> {
  $$SettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTableTable> {
  $$SettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTableTable> {
  $$SettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTableTable,
    SettingEntry,
    $$SettingsTableTableFilterComposer,
    $$SettingsTableTableOrderingComposer,
    $$SettingsTableTableAnnotationComposer,
    $$SettingsTableTableCreateCompanionBuilder,
    $$SettingsTableTableUpdateCompanionBuilder,
    (
      SettingEntry,
      BaseReferences<_$AppDatabase, $SettingsTableTable, SettingEntry>
    ),
    SettingEntry,
    PrefetchHooks Function()> {
  $$SettingsTableTableTableManager(_$AppDatabase db, $SettingsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsTableCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsTableCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTableTable,
    SettingEntry,
    $$SettingsTableTableFilterComposer,
    $$SettingsTableTableOrderingComposer,
    $$SettingsTableTableAnnotationComposer,
    $$SettingsTableTableCreateCompanionBuilder,
    $$SettingsTableTableUpdateCompanionBuilder,
    (
      SettingEntry,
      BaseReferences<_$AppDatabase, $SettingsTableTable, SettingEntry>
    ),
    SettingEntry,
    PrefetchHooks Function()>;
typedef $$PricesTableTableCreateCompanionBuilder = PricesTableCompanion
    Function({
  required String tierChar,
  required double price,
  Value<int> rowid,
});
typedef $$PricesTableTableUpdateCompanionBuilder = PricesTableCompanion
    Function({
  Value<String> tierChar,
  Value<double> price,
  Value<int> rowid,
});

class $$PricesTableTableFilterComposer
    extends Composer<_$AppDatabase, $PricesTableTable> {
  $$PricesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tierChar => $composableBuilder(
      column: $table.tierChar, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnFilters(column));
}

class $$PricesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PricesTableTable> {
  $$PricesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tierChar => $composableBuilder(
      column: $table.tierChar, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnOrderings(column));
}

class $$PricesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PricesTableTable> {
  $$PricesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tierChar =>
      $composableBuilder(column: $table.tierChar, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);
}

class $$PricesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PricesTableTable,
    PriceEntry,
    $$PricesTableTableFilterComposer,
    $$PricesTableTableOrderingComposer,
    $$PricesTableTableAnnotationComposer,
    $$PricesTableTableCreateCompanionBuilder,
    $$PricesTableTableUpdateCompanionBuilder,
    (PriceEntry, BaseReferences<_$AppDatabase, $PricesTableTable, PriceEntry>),
    PriceEntry,
    PrefetchHooks Function()> {
  $$PricesTableTableTableManager(_$AppDatabase db, $PricesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PricesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PricesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PricesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> tierChar = const Value.absent(),
            Value<double> price = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PricesTableCompanion(
            tierChar: tierChar,
            price: price,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String tierChar,
            required double price,
            Value<int> rowid = const Value.absent(),
          }) =>
              PricesTableCompanion.insert(
            tierChar: tierChar,
            price: price,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PricesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PricesTableTable,
    PriceEntry,
    $$PricesTableTableFilterComposer,
    $$PricesTableTableOrderingComposer,
    $$PricesTableTableAnnotationComposer,
    $$PricesTableTableCreateCompanionBuilder,
    $$PricesTableTableUpdateCompanionBuilder,
    (PriceEntry, BaseReferences<_$AppDatabase, $PricesTableTable, PriceEntry>),
    PriceEntry,
    PrefetchHooks Function()>;
typedef $$AssetsTableTableCreateCompanionBuilder = AssetsTableCompanion
    Function({
  Value<int> id,
  required String type,
  required String name,
  required String filePath,
  required DateTime addedAt,
});
typedef $$AssetsTableTableUpdateCompanionBuilder = AssetsTableCompanion
    Function({
  Value<int> id,
  Value<String> type,
  Value<String> name,
  Value<String> filePath,
  Value<DateTime> addedAt,
});

class $$AssetsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AssetsTableTable> {
  $$AssetsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$AssetsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetsTableTable> {
  $$AssetsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$AssetsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetsTableTable> {
  $$AssetsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$AssetsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AssetsTableTable,
    AssetEntry,
    $$AssetsTableTableFilterComposer,
    $$AssetsTableTableOrderingComposer,
    $$AssetsTableTableAnnotationComposer,
    $$AssetsTableTableCreateCompanionBuilder,
    $$AssetsTableTableUpdateCompanionBuilder,
    (AssetEntry, BaseReferences<_$AppDatabase, $AssetsTableTable, AssetEntry>),
    AssetEntry,
    PrefetchHooks Function()> {
  $$AssetsTableTableTableManager(_$AppDatabase db, $AssetsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
          }) =>
              AssetsTableCompanion(
            id: id,
            type: type,
            name: name,
            filePath: filePath,
            addedAt: addedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String type,
            required String name,
            required String filePath,
            required DateTime addedAt,
          }) =>
              AssetsTableCompanion.insert(
            id: id,
            type: type,
            name: name,
            filePath: filePath,
            addedAt: addedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AssetsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AssetsTableTable,
    AssetEntry,
    $$AssetsTableTableFilterComposer,
    $$AssetsTableTableOrderingComposer,
    $$AssetsTableTableAnnotationComposer,
    $$AssetsTableTableCreateCompanionBuilder,
    $$AssetsTableTableUpdateCompanionBuilder,
    (AssetEntry, BaseReferences<_$AppDatabase, $AssetsTableTable, AssetEntry>),
    AssetEntry,
    PrefetchHooks Function()>;
typedef $$PrintersTableTableCreateCompanionBuilder = PrintersTableCompanion
    Function({
  required String id,
  required String name,
  required String transport,
  required String address,
  Value<int> paperWidthMm,
  Value<bool> isDefault,
  Value<int> rowid,
});
typedef $$PrintersTableTableUpdateCompanionBuilder = PrintersTableCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> transport,
  Value<String> address,
  Value<int> paperWidthMm,
  Value<bool> isDefault,
  Value<int> rowid,
});

class $$PrintersTableTableFilterComposer
    extends Composer<_$AppDatabase, $PrintersTableTable> {
  $$PrintersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transport => $composableBuilder(
      column: $table.transport, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paperWidthMm => $composableBuilder(
      column: $table.paperWidthMm, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnFilters(column));
}

class $$PrintersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PrintersTableTable> {
  $$PrintersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transport => $composableBuilder(
      column: $table.transport, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paperWidthMm => $composableBuilder(
      column: $table.paperWidthMm,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnOrderings(column));
}

class $$PrintersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrintersTableTable> {
  $$PrintersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get transport =>
      $composableBuilder(column: $table.transport, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<int> get paperWidthMm => $composableBuilder(
      column: $table.paperWidthMm, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);
}

class $$PrintersTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PrintersTableTable,
    PrinterEntry,
    $$PrintersTableTableFilterComposer,
    $$PrintersTableTableOrderingComposer,
    $$PrintersTableTableAnnotationComposer,
    $$PrintersTableTableCreateCompanionBuilder,
    $$PrintersTableTableUpdateCompanionBuilder,
    (
      PrinterEntry,
      BaseReferences<_$AppDatabase, $PrintersTableTable, PrinterEntry>
    ),
    PrinterEntry,
    PrefetchHooks Function()> {
  $$PrintersTableTableTableManager(_$AppDatabase db, $PrintersTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrintersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrintersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrintersTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> transport = const Value.absent(),
            Value<String> address = const Value.absent(),
            Value<int> paperWidthMm = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PrintersTableCompanion(
            id: id,
            name: name,
            transport: transport,
            address: address,
            paperWidthMm: paperWidthMm,
            isDefault: isDefault,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String transport,
            required String address,
            Value<int> paperWidthMm = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PrintersTableCompanion.insert(
            id: id,
            name: name,
            transport: transport,
            address: address,
            paperWidthMm: paperWidthMm,
            isDefault: isDefault,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PrintersTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PrintersTableTable,
    PrinterEntry,
    $$PrintersTableTableFilterComposer,
    $$PrintersTableTableOrderingComposer,
    $$PrintersTableTableAnnotationComposer,
    $$PrintersTableTableCreateCompanionBuilder,
    $$PrintersTableTableUpdateCompanionBuilder,
    (
      PrinterEntry,
      BaseReferences<_$AppDatabase, $PrintersTableTable, PrinterEntry>
    ),
    PrinterEntry,
    PrefetchHooks Function()>;
typedef $$VouchersTableTableCreateCompanionBuilder = VouchersTableCompanion
    Function({
  required String code,
  required String locationId,
  required String tierChar,
  required String serial,
  required double priceSnapshot,
  Value<int> status,
  required DateTime expiresAt,
  required DateTime createdAt,
  Value<DateTime?> redeemedAt,
  Value<String?> voidReason,
  Value<int> rowid,
});
typedef $$VouchersTableTableUpdateCompanionBuilder = VouchersTableCompanion
    Function({
  Value<String> code,
  Value<String> locationId,
  Value<String> tierChar,
  Value<String> serial,
  Value<double> priceSnapshot,
  Value<int> status,
  Value<DateTime> expiresAt,
  Value<DateTime> createdAt,
  Value<DateTime?> redeemedAt,
  Value<String?> voidReason,
  Value<int> rowid,
});

class $$VouchersTableTableFilterComposer
    extends Composer<_$AppDatabase, $VouchersTableTable> {
  $$VouchersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tierChar => $composableBuilder(
      column: $table.tierChar, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serial => $composableBuilder(
      column: $table.serial, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get priceSnapshot => $composableBuilder(
      column: $table.priceSnapshot, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get redeemedAt => $composableBuilder(
      column: $table.redeemedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get voidReason => $composableBuilder(
      column: $table.voidReason, builder: (column) => ColumnFilters(column));
}

class $$VouchersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $VouchersTableTable> {
  $$VouchersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tierChar => $composableBuilder(
      column: $table.tierChar, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serial => $composableBuilder(
      column: $table.serial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get priceSnapshot => $composableBuilder(
      column: $table.priceSnapshot,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get redeemedAt => $composableBuilder(
      column: $table.redeemedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get voidReason => $composableBuilder(
      column: $table.voidReason, builder: (column) => ColumnOrderings(column));
}

class $$VouchersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $VouchersTableTable> {
  $$VouchersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => column);

  GeneratedColumn<String> get tierChar =>
      $composableBuilder(column: $table.tierChar, builder: (column) => column);

  GeneratedColumn<String> get serial =>
      $composableBuilder(column: $table.serial, builder: (column) => column);

  GeneratedColumn<double> get priceSnapshot => $composableBuilder(
      column: $table.priceSnapshot, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get redeemedAt => $composableBuilder(
      column: $table.redeemedAt, builder: (column) => column);

  GeneratedColumn<String> get voidReason => $composableBuilder(
      column: $table.voidReason, builder: (column) => column);
}

class $$VouchersTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VouchersTableTable,
    VoucherEntry,
    $$VouchersTableTableFilterComposer,
    $$VouchersTableTableOrderingComposer,
    $$VouchersTableTableAnnotationComposer,
    $$VouchersTableTableCreateCompanionBuilder,
    $$VouchersTableTableUpdateCompanionBuilder,
    (
      VoucherEntry,
      BaseReferences<_$AppDatabase, $VouchersTableTable, VoucherEntry>
    ),
    VoucherEntry,
    PrefetchHooks Function()> {
  $$VouchersTableTableTableManager(_$AppDatabase db, $VouchersTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VouchersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VouchersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VouchersTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> code = const Value.absent(),
            Value<String> locationId = const Value.absent(),
            Value<String> tierChar = const Value.absent(),
            Value<String> serial = const Value.absent(),
            Value<double> priceSnapshot = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<DateTime> expiresAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> redeemedAt = const Value.absent(),
            Value<String?> voidReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VouchersTableCompanion(
            code: code,
            locationId: locationId,
            tierChar: tierChar,
            serial: serial,
            priceSnapshot: priceSnapshot,
            status: status,
            expiresAt: expiresAt,
            createdAt: createdAt,
            redeemedAt: redeemedAt,
            voidReason: voidReason,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String code,
            required String locationId,
            required String tierChar,
            required String serial,
            required double priceSnapshot,
            Value<int> status = const Value.absent(),
            required DateTime expiresAt,
            required DateTime createdAt,
            Value<DateTime?> redeemedAt = const Value.absent(),
            Value<String?> voidReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VouchersTableCompanion.insert(
            code: code,
            locationId: locationId,
            tierChar: tierChar,
            serial: serial,
            priceSnapshot: priceSnapshot,
            status: status,
            expiresAt: expiresAt,
            createdAt: createdAt,
            redeemedAt: redeemedAt,
            voidReason: voidReason,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$VouchersTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $VouchersTableTable,
    VoucherEntry,
    $$VouchersTableTableFilterComposer,
    $$VouchersTableTableOrderingComposer,
    $$VouchersTableTableAnnotationComposer,
    $$VouchersTableTableCreateCompanionBuilder,
    $$VouchersTableTableUpdateCompanionBuilder,
    (
      VoucherEntry,
      BaseReferences<_$AppDatabase, $VouchersTableTable, VoucherEntry>
    ),
    VoucherEntry,
    PrefetchHooks Function()>;
typedef $$SalesTableTableCreateCompanionBuilder = SalesTableCompanion Function({
  required String code,
  required String locationId,
  required String tierChar,
  required String serial,
  required double priceSnapshot,
  Value<int> status,
  required DateTime expiresAt,
  required DateTime createdAt,
  required DateTime redeemedAt,
  Value<int> rowid,
});
typedef $$SalesTableTableUpdateCompanionBuilder = SalesTableCompanion Function({
  Value<String> code,
  Value<String> locationId,
  Value<String> tierChar,
  Value<String> serial,
  Value<double> priceSnapshot,
  Value<int> status,
  Value<DateTime> expiresAt,
  Value<DateTime> createdAt,
  Value<DateTime> redeemedAt,
  Value<int> rowid,
});

class $$SalesTableTableFilterComposer
    extends Composer<_$AppDatabase, $SalesTableTable> {
  $$SalesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tierChar => $composableBuilder(
      column: $table.tierChar, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serial => $composableBuilder(
      column: $table.serial, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get priceSnapshot => $composableBuilder(
      column: $table.priceSnapshot, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get redeemedAt => $composableBuilder(
      column: $table.redeemedAt, builder: (column) => ColumnFilters(column));
}

class $$SalesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SalesTableTable> {
  $$SalesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tierChar => $composableBuilder(
      column: $table.tierChar, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serial => $composableBuilder(
      column: $table.serial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get priceSnapshot => $composableBuilder(
      column: $table.priceSnapshot,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get redeemedAt => $composableBuilder(
      column: $table.redeemedAt, builder: (column) => ColumnOrderings(column));
}

class $$SalesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalesTableTable> {
  $$SalesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => column);

  GeneratedColumn<String> get tierChar =>
      $composableBuilder(column: $table.tierChar, builder: (column) => column);

  GeneratedColumn<String> get serial =>
      $composableBuilder(column: $table.serial, builder: (column) => column);

  GeneratedColumn<double> get priceSnapshot => $composableBuilder(
      column: $table.priceSnapshot, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get redeemedAt => $composableBuilder(
      column: $table.redeemedAt, builder: (column) => column);
}

class $$SalesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SalesTableTable,
    SaleEntry,
    $$SalesTableTableFilterComposer,
    $$SalesTableTableOrderingComposer,
    $$SalesTableTableAnnotationComposer,
    $$SalesTableTableCreateCompanionBuilder,
    $$SalesTableTableUpdateCompanionBuilder,
    (SaleEntry, BaseReferences<_$AppDatabase, $SalesTableTable, SaleEntry>),
    SaleEntry,
    PrefetchHooks Function()> {
  $$SalesTableTableTableManager(_$AppDatabase db, $SalesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> code = const Value.absent(),
            Value<String> locationId = const Value.absent(),
            Value<String> tierChar = const Value.absent(),
            Value<String> serial = const Value.absent(),
            Value<double> priceSnapshot = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<DateTime> expiresAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> redeemedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SalesTableCompanion(
            code: code,
            locationId: locationId,
            tierChar: tierChar,
            serial: serial,
            priceSnapshot: priceSnapshot,
            status: status,
            expiresAt: expiresAt,
            createdAt: createdAt,
            redeemedAt: redeemedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String code,
            required String locationId,
            required String tierChar,
            required String serial,
            required double priceSnapshot,
            Value<int> status = const Value.absent(),
            required DateTime expiresAt,
            required DateTime createdAt,
            required DateTime redeemedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SalesTableCompanion.insert(
            code: code,
            locationId: locationId,
            tierChar: tierChar,
            serial: serial,
            priceSnapshot: priceSnapshot,
            status: status,
            expiresAt: expiresAt,
            createdAt: createdAt,
            redeemedAt: redeemedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SalesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SalesTableTable,
    SaleEntry,
    $$SalesTableTableFilterComposer,
    $$SalesTableTableOrderingComposer,
    $$SalesTableTableAnnotationComposer,
    $$SalesTableTableCreateCompanionBuilder,
    $$SalesTableTableUpdateCompanionBuilder,
    (SaleEntry, BaseReferences<_$AppDatabase, $SalesTableTable, SaleEntry>),
    SaleEntry,
    PrefetchHooks Function()>;
typedef $$SessionsTableTableCreateCompanionBuilder = SessionsTableCompanion
    Function({
  required String sessionId,
  required String voucherCode,
  required String tierChar,
  Value<String?> layoutType,
  required String localImagePaths,
  Value<String?> composedImagePath,
  Value<String?> gifPath,
  Value<String?> driveFileId,
  Value<String?> driveShareUrl,
  Value<bool> isUploaded,
  Value<bool> isPrinted,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$SessionsTableTableUpdateCompanionBuilder = SessionsTableCompanion
    Function({
  Value<String> sessionId,
  Value<String> voucherCode,
  Value<String> tierChar,
  Value<String?> layoutType,
  Value<String> localImagePaths,
  Value<String?> composedImagePath,
  Value<String?> gifPath,
  Value<String?> driveFileId,
  Value<String?> driveShareUrl,
  Value<bool> isUploaded,
  Value<bool> isPrinted,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$SessionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTableTable> {
  $$SessionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get voucherCode => $composableBuilder(
      column: $table.voucherCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tierChar => $composableBuilder(
      column: $table.tierChar, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get layoutType => $composableBuilder(
      column: $table.layoutType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localImagePaths => $composableBuilder(
      column: $table.localImagePaths,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get composedImagePath => $composableBuilder(
      column: $table.composedImagePath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gifPath => $composableBuilder(
      column: $table.gifPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get driveFileId => $composableBuilder(
      column: $table.driveFileId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get driveShareUrl => $composableBuilder(
      column: $table.driveShareUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isUploaded => $composableBuilder(
      column: $table.isUploaded, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPrinted => $composableBuilder(
      column: $table.isPrinted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SessionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTableTable> {
  $$SessionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get voucherCode => $composableBuilder(
      column: $table.voucherCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tierChar => $composableBuilder(
      column: $table.tierChar, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get layoutType => $composableBuilder(
      column: $table.layoutType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localImagePaths => $composableBuilder(
      column: $table.localImagePaths,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get composedImagePath => $composableBuilder(
      column: $table.composedImagePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gifPath => $composableBuilder(
      column: $table.gifPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get driveFileId => $composableBuilder(
      column: $table.driveFileId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get driveShareUrl => $composableBuilder(
      column: $table.driveShareUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isUploaded => $composableBuilder(
      column: $table.isUploaded, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPrinted => $composableBuilder(
      column: $table.isPrinted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SessionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTableTable> {
  $$SessionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get voucherCode => $composableBuilder(
      column: $table.voucherCode, builder: (column) => column);

  GeneratedColumn<String> get tierChar =>
      $composableBuilder(column: $table.tierChar, builder: (column) => column);

  GeneratedColumn<String> get layoutType => $composableBuilder(
      column: $table.layoutType, builder: (column) => column);

  GeneratedColumn<String> get localImagePaths => $composableBuilder(
      column: $table.localImagePaths, builder: (column) => column);

  GeneratedColumn<String> get composedImagePath => $composableBuilder(
      column: $table.composedImagePath, builder: (column) => column);

  GeneratedColumn<String> get gifPath =>
      $composableBuilder(column: $table.gifPath, builder: (column) => column);

  GeneratedColumn<String> get driveFileId => $composableBuilder(
      column: $table.driveFileId, builder: (column) => column);

  GeneratedColumn<String> get driveShareUrl => $composableBuilder(
      column: $table.driveShareUrl, builder: (column) => column);

  GeneratedColumn<bool> get isUploaded => $composableBuilder(
      column: $table.isUploaded, builder: (column) => column);

  GeneratedColumn<bool> get isPrinted =>
      $composableBuilder(column: $table.isPrinted, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SessionsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionsTableTable,
    SessionEntry,
    $$SessionsTableTableFilterComposer,
    $$SessionsTableTableOrderingComposer,
    $$SessionsTableTableAnnotationComposer,
    $$SessionsTableTableCreateCompanionBuilder,
    $$SessionsTableTableUpdateCompanionBuilder,
    (
      SessionEntry,
      BaseReferences<_$AppDatabase, $SessionsTableTable, SessionEntry>
    ),
    SessionEntry,
    PrefetchHooks Function()> {
  $$SessionsTableTableTableManager(_$AppDatabase db, $SessionsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> sessionId = const Value.absent(),
            Value<String> voucherCode = const Value.absent(),
            Value<String> tierChar = const Value.absent(),
            Value<String?> layoutType = const Value.absent(),
            Value<String> localImagePaths = const Value.absent(),
            Value<String?> composedImagePath = const Value.absent(),
            Value<String?> gifPath = const Value.absent(),
            Value<String?> driveFileId = const Value.absent(),
            Value<String?> driveShareUrl = const Value.absent(),
            Value<bool> isUploaded = const Value.absent(),
            Value<bool> isPrinted = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsTableCompanion(
            sessionId: sessionId,
            voucherCode: voucherCode,
            tierChar: tierChar,
            layoutType: layoutType,
            localImagePaths: localImagePaths,
            composedImagePath: composedImagePath,
            gifPath: gifPath,
            driveFileId: driveFileId,
            driveShareUrl: driveShareUrl,
            isUploaded: isUploaded,
            isPrinted: isPrinted,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String sessionId,
            required String voucherCode,
            required String tierChar,
            Value<String?> layoutType = const Value.absent(),
            required String localImagePaths,
            Value<String?> composedImagePath = const Value.absent(),
            Value<String?> gifPath = const Value.absent(),
            Value<String?> driveFileId = const Value.absent(),
            Value<String?> driveShareUrl = const Value.absent(),
            Value<bool> isUploaded = const Value.absent(),
            Value<bool> isPrinted = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsTableCompanion.insert(
            sessionId: sessionId,
            voucherCode: voucherCode,
            tierChar: tierChar,
            layoutType: layoutType,
            localImagePaths: localImagePaths,
            composedImagePath: composedImagePath,
            gifPath: gifPath,
            driveFileId: driveFileId,
            driveShareUrl: driveShareUrl,
            isUploaded: isUploaded,
            isPrinted: isPrinted,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SessionsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionsTableTable,
    SessionEntry,
    $$SessionsTableTableFilterComposer,
    $$SessionsTableTableOrderingComposer,
    $$SessionsTableTableAnnotationComposer,
    $$SessionsTableTableCreateCompanionBuilder,
    $$SessionsTableTableUpdateCompanionBuilder,
    (
      SessionEntry,
      BaseReferences<_$AppDatabase, $SessionsTableTable, SessionEntry>
    ),
    SessionEntry,
    PrefetchHooks Function()>;
typedef $$AdminAuthTableTableCreateCompanionBuilder = AdminAuthTableCompanion
    Function({
  Value<int> id,
  required String passwordHash,
  required DateTime updatedAt,
});
typedef $$AdminAuthTableTableUpdateCompanionBuilder = AdminAuthTableCompanion
    Function({
  Value<int> id,
  Value<String> passwordHash,
  Value<DateTime> updatedAt,
});

class $$AdminAuthTableTableFilterComposer
    extends Composer<_$AppDatabase, $AdminAuthTableTable> {
  $$AdminAuthTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AdminAuthTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AdminAuthTableTable> {
  $$AdminAuthTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AdminAuthTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AdminAuthTableTable> {
  $$AdminAuthTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get passwordHash => $composableBuilder(
      column: $table.passwordHash, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AdminAuthTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AdminAuthTableTable,
    AdminAuthEntry,
    $$AdminAuthTableTableFilterComposer,
    $$AdminAuthTableTableOrderingComposer,
    $$AdminAuthTableTableAnnotationComposer,
    $$AdminAuthTableTableCreateCompanionBuilder,
    $$AdminAuthTableTableUpdateCompanionBuilder,
    (
      AdminAuthEntry,
      BaseReferences<_$AppDatabase, $AdminAuthTableTable, AdminAuthEntry>
    ),
    AdminAuthEntry,
    PrefetchHooks Function()> {
  $$AdminAuthTableTableTableManager(
      _$AppDatabase db, $AdminAuthTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AdminAuthTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AdminAuthTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AdminAuthTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> passwordHash = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AdminAuthTableCompanion(
            id: id,
            passwordHash: passwordHash,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String passwordHash,
            required DateTime updatedAt,
          }) =>
              AdminAuthTableCompanion.insert(
            id: id,
            passwordHash: passwordHash,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AdminAuthTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AdminAuthTableTable,
    AdminAuthEntry,
    $$AdminAuthTableTableFilterComposer,
    $$AdminAuthTableTableOrderingComposer,
    $$AdminAuthTableTableAnnotationComposer,
    $$AdminAuthTableTableCreateCompanionBuilder,
    $$AdminAuthTableTableUpdateCompanionBuilder,
    (
      AdminAuthEntry,
      BaseReferences<_$AppDatabase, $AdminAuthTableTable, AdminAuthEntry>
    ),
    AdminAuthEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableTableManager get settingsTable =>
      $$SettingsTableTableTableManager(_db, _db.settingsTable);
  $$PricesTableTableTableManager get pricesTable =>
      $$PricesTableTableTableManager(_db, _db.pricesTable);
  $$AssetsTableTableTableManager get assetsTable =>
      $$AssetsTableTableTableManager(_db, _db.assetsTable);
  $$PrintersTableTableTableManager get printersTable =>
      $$PrintersTableTableTableManager(_db, _db.printersTable);
  $$VouchersTableTableTableManager get vouchersTable =>
      $$VouchersTableTableTableManager(_db, _db.vouchersTable);
  $$SalesTableTableTableManager get salesTable =>
      $$SalesTableTableTableManager(_db, _db.salesTable);
  $$SessionsTableTableTableManager get sessionsTable =>
      $$SessionsTableTableTableManager(_db, _db.sessionsTable);
  $$AdminAuthTableTableTableManager get adminAuthTable =>
      $$AdminAuthTableTableTableManager(_db, _db.adminAuthTable);
}
