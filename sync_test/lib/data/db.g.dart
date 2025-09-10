// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeCompanyIdMeta = const VerificationMeta(
    'scopeCompanyId',
  );
  @override
  late final GeneratedColumn<String> scopeCompanyId = GeneratedColumn<String>(
    'scope_company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeLocationIdMeta = const VerificationMeta(
    'scopeLocationId',
  );
  @override
  late final GeneratedColumn<String> scopeLocationId = GeneratedColumn<String>(
    'scope_location_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tblNameMeta = const VerificationMeta(
    'tblName',
  );
  @override
  late final GeneratedColumn<String> tblName = GeneratedColumn<String>(
    'tbl_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastServerUpdatedAtMeta =
      const VerificationMeta('lastServerUpdatedAt');
  @override
  late final GeneratedColumn<DateTime> lastServerUpdatedAt =
      GeneratedColumn<DateTime>(
        'last_server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastLocalPushedAtMeta = const VerificationMeta(
    'lastLocalPushedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastLocalPushedAt =
      GeneratedColumn<DateTime>(
        'last_local_pushed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    scopeCompanyId,
    scopeLocationId,
    tblName,
    lastServerUpdatedAt,
    lastLocalPushedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope_company_id')) {
      context.handle(
        _scopeCompanyIdMeta,
        scopeCompanyId.isAcceptableOrUnknown(
          data['scope_company_id']!,
          _scopeCompanyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scopeCompanyIdMeta);
    }
    if (data.containsKey('scope_location_id')) {
      context.handle(
        _scopeLocationIdMeta,
        scopeLocationId.isAcceptableOrUnknown(
          data['scope_location_id']!,
          _scopeLocationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scopeLocationIdMeta);
    }
    if (data.containsKey('tbl_name')) {
      context.handle(
        _tblNameMeta,
        tblName.isAcceptableOrUnknown(data['tbl_name']!, _tblNameMeta),
      );
    } else if (isInserting) {
      context.missing(_tblNameMeta);
    }
    if (data.containsKey('last_server_updated_at')) {
      context.handle(
        _lastServerUpdatedAtMeta,
        lastServerUpdatedAt.isAcceptableOrUnknown(
          data['last_server_updated_at']!,
          _lastServerUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_local_pushed_at')) {
      context.handle(
        _lastLocalPushedAtMeta,
        lastLocalPushedAt.isAcceptableOrUnknown(
          data['last_local_pushed_at']!,
          _lastLocalPushedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    scopeCompanyId,
    scopeLocationId,
    tblName,
  };
  @override
  SyncMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaData(
      scopeCompanyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_company_id'],
      )!,
      scopeLocationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_location_id'],
      )!,
      tblName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tbl_name'],
      )!,
      lastServerUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_server_updated_at'],
      ),
      lastLocalPushedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_local_pushed_at'],
      ),
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaData extends DataClass implements Insertable<SyncMetaData> {
  final String scopeCompanyId;
  final String scopeLocationId;
  final String tblName;
  final DateTime? lastServerUpdatedAt;
  final DateTime? lastLocalPushedAt;
  const SyncMetaData({
    required this.scopeCompanyId,
    required this.scopeLocationId,
    required this.tblName,
    this.lastServerUpdatedAt,
    this.lastLocalPushedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope_company_id'] = Variable<String>(scopeCompanyId);
    map['scope_location_id'] = Variable<String>(scopeLocationId);
    map['tbl_name'] = Variable<String>(tblName);
    if (!nullToAbsent || lastServerUpdatedAt != null) {
      map['last_server_updated_at'] = Variable<DateTime>(lastServerUpdatedAt);
    }
    if (!nullToAbsent || lastLocalPushedAt != null) {
      map['last_local_pushed_at'] = Variable<DateTime>(lastLocalPushedAt);
    }
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      scopeCompanyId: Value(scopeCompanyId),
      scopeLocationId: Value(scopeLocationId),
      tblName: Value(tblName),
      lastServerUpdatedAt: lastServerUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastServerUpdatedAt),
      lastLocalPushedAt: lastLocalPushedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLocalPushedAt),
    );
  }

  factory SyncMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaData(
      scopeCompanyId: serializer.fromJson<String>(json['scopeCompanyId']),
      scopeLocationId: serializer.fromJson<String>(json['scopeLocationId']),
      tblName: serializer.fromJson<String>(json['tblName']),
      lastServerUpdatedAt: serializer.fromJson<DateTime?>(
        json['lastServerUpdatedAt'],
      ),
      lastLocalPushedAt: serializer.fromJson<DateTime?>(
        json['lastLocalPushedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scopeCompanyId': serializer.toJson<String>(scopeCompanyId),
      'scopeLocationId': serializer.toJson<String>(scopeLocationId),
      'tblName': serializer.toJson<String>(tblName),
      'lastServerUpdatedAt': serializer.toJson<DateTime?>(lastServerUpdatedAt),
      'lastLocalPushedAt': serializer.toJson<DateTime?>(lastLocalPushedAt),
    };
  }

  SyncMetaData copyWith({
    String? scopeCompanyId,
    String? scopeLocationId,
    String? tblName,
    Value<DateTime?> lastServerUpdatedAt = const Value.absent(),
    Value<DateTime?> lastLocalPushedAt = const Value.absent(),
  }) => SyncMetaData(
    scopeCompanyId: scopeCompanyId ?? this.scopeCompanyId,
    scopeLocationId: scopeLocationId ?? this.scopeLocationId,
    tblName: tblName ?? this.tblName,
    lastServerUpdatedAt: lastServerUpdatedAt.present
        ? lastServerUpdatedAt.value
        : this.lastServerUpdatedAt,
    lastLocalPushedAt: lastLocalPushedAt.present
        ? lastLocalPushedAt.value
        : this.lastLocalPushedAt,
  );
  SyncMetaData copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaData(
      scopeCompanyId: data.scopeCompanyId.present
          ? data.scopeCompanyId.value
          : this.scopeCompanyId,
      scopeLocationId: data.scopeLocationId.present
          ? data.scopeLocationId.value
          : this.scopeLocationId,
      tblName: data.tblName.present ? data.tblName.value : this.tblName,
      lastServerUpdatedAt: data.lastServerUpdatedAt.present
          ? data.lastServerUpdatedAt.value
          : this.lastServerUpdatedAt,
      lastLocalPushedAt: data.lastLocalPushedAt.present
          ? data.lastLocalPushedAt.value
          : this.lastLocalPushedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaData(')
          ..write('scopeCompanyId: $scopeCompanyId, ')
          ..write('scopeLocationId: $scopeLocationId, ')
          ..write('tblName: $tblName, ')
          ..write('lastServerUpdatedAt: $lastServerUpdatedAt, ')
          ..write('lastLocalPushedAt: $lastLocalPushedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scopeCompanyId,
    scopeLocationId,
    tblName,
    lastServerUpdatedAt,
    lastLocalPushedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaData &&
          other.scopeCompanyId == this.scopeCompanyId &&
          other.scopeLocationId == this.scopeLocationId &&
          other.tblName == this.tblName &&
          other.lastServerUpdatedAt == this.lastServerUpdatedAt &&
          other.lastLocalPushedAt == this.lastLocalPushedAt);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaData> {
  final Value<String> scopeCompanyId;
  final Value<String> scopeLocationId;
  final Value<String> tblName;
  final Value<DateTime?> lastServerUpdatedAt;
  final Value<DateTime?> lastLocalPushedAt;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.scopeCompanyId = const Value.absent(),
    this.scopeLocationId = const Value.absent(),
    this.tblName = const Value.absent(),
    this.lastServerUpdatedAt = const Value.absent(),
    this.lastLocalPushedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String scopeCompanyId,
    required String scopeLocationId,
    required String tblName,
    this.lastServerUpdatedAt = const Value.absent(),
    this.lastLocalPushedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scopeCompanyId = Value(scopeCompanyId),
       scopeLocationId = Value(scopeLocationId),
       tblName = Value(tblName);
  static Insertable<SyncMetaData> custom({
    Expression<String>? scopeCompanyId,
    Expression<String>? scopeLocationId,
    Expression<String>? tblName,
    Expression<DateTime>? lastServerUpdatedAt,
    Expression<DateTime>? lastLocalPushedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scopeCompanyId != null) 'scope_company_id': scopeCompanyId,
      if (scopeLocationId != null) 'scope_location_id': scopeLocationId,
      if (tblName != null) 'tbl_name': tblName,
      if (lastServerUpdatedAt != null)
        'last_server_updated_at': lastServerUpdatedAt,
      if (lastLocalPushedAt != null) 'last_local_pushed_at': lastLocalPushedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({
    Value<String>? scopeCompanyId,
    Value<String>? scopeLocationId,
    Value<String>? tblName,
    Value<DateTime?>? lastServerUpdatedAt,
    Value<DateTime?>? lastLocalPushedAt,
    Value<int>? rowid,
  }) {
    return SyncMetaCompanion(
      scopeCompanyId: scopeCompanyId ?? this.scopeCompanyId,
      scopeLocationId: scopeLocationId ?? this.scopeLocationId,
      tblName: tblName ?? this.tblName,
      lastServerUpdatedAt: lastServerUpdatedAt ?? this.lastServerUpdatedAt,
      lastLocalPushedAt: lastLocalPushedAt ?? this.lastLocalPushedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scopeCompanyId.present) {
      map['scope_company_id'] = Variable<String>(scopeCompanyId.value);
    }
    if (scopeLocationId.present) {
      map['scope_location_id'] = Variable<String>(scopeLocationId.value);
    }
    if (tblName.present) {
      map['tbl_name'] = Variable<String>(tblName.value);
    }
    if (lastServerUpdatedAt.present) {
      map['last_server_updated_at'] = Variable<DateTime>(
        lastServerUpdatedAt.value,
      );
    }
    if (lastLocalPushedAt.present) {
      map['last_local_pushed_at'] = Variable<DateTime>(lastLocalPushedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('scopeCompanyId: $scopeCompanyId, ')
          ..write('scopeLocationId: $scopeLocationId, ')
          ..write('tblName: $tblName, ')
          ..write('lastServerUpdatedAt: $lastServerUpdatedAt, ')
          ..write('lastLocalPushedAt: $lastLocalPushedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tblNameMeta = const VerificationMeta(
    'tblName',
  );
  @override
  late final GeneratedColumn<String> tblName = GeneratedColumn<String>(
    'tbl_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tblName,
    op,
    payloadJson,
    rowId,
    createdAt,
    nextAttemptAt,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tbl_name')) {
      context.handle(
        _tblNameMeta,
        tblName.isAcceptableOrUnknown(data['tbl_name']!, _tblNameMeta),
      );
    } else if (isInserting) {
      context.missing(_tblNameMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tblName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tbl_name'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String id;
  final String tblName;
  final String op;
  final String payloadJson;
  final String? rowId;
  final DateTime createdAt;
  final DateTime? nextAttemptAt;
  final int attempts;
  const OutboxData({
    required this.id,
    required this.tblName,
    required this.op,
    required this.payloadJson,
    this.rowId,
    required this.createdAt,
    this.nextAttemptAt,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tbl_name'] = Variable<String>(tblName);
    map['op'] = Variable<String>(op);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || rowId != null) {
      map['row_id'] = Variable<String>(rowId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      tblName: Value(tblName),
      op: Value(op),
      payloadJson: Value(payloadJson),
      rowId: rowId == null && nullToAbsent
          ? const Value.absent()
          : Value(rowId),
      createdAt: Value(createdAt),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      attempts: Value(attempts),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<String>(json['id']),
      tblName: serializer.fromJson<String>(json['tblName']),
      op: serializer.fromJson<String>(json['op']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      rowId: serializer.fromJson<String?>(json['rowId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tblName': serializer.toJson<String>(tblName),
      'op': serializer.toJson<String>(op),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'rowId': serializer.toJson<String?>(rowId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  OutboxData copyWith({
    String? id,
    String? tblName,
    String? op,
    String? payloadJson,
    Value<String?> rowId = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    int? attempts,
  }) => OutboxData(
    id: id ?? this.id,
    tblName: tblName ?? this.tblName,
    op: op ?? this.op,
    payloadJson: payloadJson ?? this.payloadJson,
    rowId: rowId.present ? rowId.value : this.rowId,
    createdAt: createdAt ?? this.createdAt,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    attempts: attempts ?? this.attempts,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      tblName: data.tblName.present ? data.tblName.value : this.tblName,
      op: data.op.present ? data.op.value : this.op,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('tblName: $tblName, ')
          ..write('op: $op, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowId: $rowId, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tblName,
    op,
    payloadJson,
    rowId,
    createdAt,
    nextAttemptAt,
    attempts,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.tblName == this.tblName &&
          other.op == this.op &&
          other.payloadJson == this.payloadJson &&
          other.rowId == this.rowId &&
          other.createdAt == this.createdAt &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.attempts == this.attempts);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> id;
  final Value<String> tblName;
  final Value<String> op;
  final Value<String> payloadJson;
  final Value<String?> rowId;
  final Value<DateTime> createdAt;
  final Value<DateTime?> nextAttemptAt;
  final Value<int> attempts;
  final Value<int> rowid;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.tblName = const Value.absent(),
    this.op = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String id,
    required String tblName,
    required String op,
    required String payloadJson,
    this.rowId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tblName = Value(tblName),
       op = Value(op),
       payloadJson = Value(payloadJson);
  static Insertable<OutboxData> custom({
    Expression<String>? id,
    Expression<String>? tblName,
    Expression<String>? op,
    Expression<String>? payloadJson,
    Expression<String>? rowId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? nextAttemptAt,
    Expression<int>? attempts,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tblName != null) 'tbl_name': tblName,
      if (op != null) 'op': op,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (rowId != null) 'row_id': rowId,
      if (createdAt != null) 'created_at': createdAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (attempts != null) 'attempts': attempts,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? id,
    Value<String>? tblName,
    Value<String>? op,
    Value<String>? payloadJson,
    Value<String?>? rowId,
    Value<DateTime>? createdAt,
    Value<DateTime?>? nextAttemptAt,
    Value<int>? attempts,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      tblName: tblName ?? this.tblName,
      op: op ?? this.op,
      payloadJson: payloadJson ?? this.payloadJson,
      rowId: rowId ?? this.rowId,
      createdAt: createdAt ?? this.createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      attempts: attempts ?? this.attempts,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tblName.present) {
      map['tbl_name'] = Variable<String>(tblName.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('tblName: $tblName, ')
          ..write('op: $op, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowId: $rowId, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('attempts: $attempts, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    locationId,
    code,
    name,
    price,
    deleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final String id;
  final String companyId;
  final String? locationId;
  final String code;
  final String name;
  final double price;
  final bool deleted;
  final DateTime updatedAt;
  const Product({
    required this.id,
    required this.companyId,
    this.locationId,
    required this.code,
    required this.name,
    required this.price,
    required this.deleted,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['price'] = Variable<double>(price);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      companyId: Value(companyId),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      code: Value(code),
      name: Value(name),
      price: Value(price),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      locationId: serializer.fromJson<String?>(json['locationId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<double>(json['price']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'locationId': serializer.toJson<String?>(locationId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<double>(price),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Product copyWith({
    String? id,
    String? companyId,
    Value<String?> locationId = const Value.absent(),
    String? code,
    String? name,
    double? price,
    bool? deleted,
    DateTime? updatedAt,
  }) => Product(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    locationId: locationId.present ? locationId.value : this.locationId,
    code: code ?? this.code,
    name: name ?? this.name,
    price: price ?? this.price,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('locationId: $locationId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    locationId,
    code,
    name,
    price,
    deleted,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.locationId == this.locationId &&
          other.code == this.code &&
          other.name == this.name &&
          other.price == this.price &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String?> locationId;
  final Value<String> code;
  final Value<String> name;
  final Value<double> price;
  final Value<bool> deleted;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    required String companyId,
    this.locationId = const Value.absent(),
    required String code,
    required String name,
    this.price = const Value.absent(),
    this.deleted = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       code = Value(code),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<Product> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? locationId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<double>? price,
    Expression<bool>? deleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (locationId != null) 'location_id': locationId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String?>? locationId,
    Value<String>? code,
    Value<String>? name,
    Value<double>? price,
    Value<bool>? deleted,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      locationId: locationId ?? this.locationId,
      code: code ?? this.code,
      name: name ?? this.name,
      price: price ?? this.price,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('locationId: $locationId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SalesTable extends Sales with TableInfo<$SalesTable, Sale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _txnDateMeta = const VerificationMeta(
    'txnDate',
  );
  @override
  late final GeneratedColumn<DateTime> txnDate = GeneratedColumn<DateTime>(
    'txn_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    locationId,
    txnDate,
    total,
    deleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sale> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('txn_date')) {
      context.handle(
        _txnDateMeta,
        txnDate.isAcceptableOrUnknown(data['txn_date']!, _txnDateMeta),
      );
    } else if (isInserting) {
      context.missing(_txnDateMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sale(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      )!,
      txnDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}txn_date'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SalesTable createAlias(String alias) {
    return $SalesTable(attachedDatabase, alias);
  }
}

class Sale extends DataClass implements Insertable<Sale> {
  final String id;
  final String companyId;
  final String locationId;
  final DateTime txnDate;
  final double total;
  final bool deleted;
  final DateTime updatedAt;
  const Sale({
    required this.id,
    required this.companyId,
    required this.locationId,
    required this.txnDate,
    required this.total,
    required this.deleted,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['location_id'] = Variable<String>(locationId);
    map['txn_date'] = Variable<DateTime>(txnDate);
    map['total'] = Variable<double>(total);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      locationId: Value(locationId),
      txnDate: Value(txnDate),
      total: Value(total),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
    );
  }

  factory Sale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sale(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      locationId: serializer.fromJson<String>(json['locationId']),
      txnDate: serializer.fromJson<DateTime>(json['txnDate']),
      total: serializer.fromJson<double>(json['total']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'locationId': serializer.toJson<String>(locationId),
      'txnDate': serializer.toJson<DateTime>(txnDate),
      'total': serializer.toJson<double>(total),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Sale copyWith({
    String? id,
    String? companyId,
    String? locationId,
    DateTime? txnDate,
    double? total,
    bool? deleted,
    DateTime? updatedAt,
  }) => Sale(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    locationId: locationId ?? this.locationId,
    txnDate: txnDate ?? this.txnDate,
    total: total ?? this.total,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Sale copyWithCompanion(SalesCompanion data) {
    return Sale(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      txnDate: data.txnDate.present ? data.txnDate.value : this.txnDate,
      total: data.total.present ? data.total.value : this.total,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sale(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('locationId: $locationId, ')
          ..write('txnDate: $txnDate, ')
          ..write('total: $total, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    locationId,
    txnDate,
    total,
    deleted,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sale &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.locationId == this.locationId &&
          other.txnDate == this.txnDate &&
          other.total == this.total &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> locationId;
  final Value<DateTime> txnDate;
  final Value<double> total;
  final Value<bool> deleted;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.txnDate = const Value.absent(),
    this.total = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalesCompanion.insert({
    required String id,
    required String companyId,
    required String locationId,
    required DateTime txnDate,
    required double total,
    this.deleted = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       locationId = Value(locationId),
       txnDate = Value(txnDate),
       total = Value(total),
       updatedAt = Value(updatedAt);
  static Insertable<Sale> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? locationId,
    Expression<DateTime>? txnDate,
    Expression<double>? total,
    Expression<bool>? deleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (locationId != null) 'location_id': locationId,
      if (txnDate != null) 'txn_date': txnDate,
      if (total != null) 'total': total,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? locationId,
    Value<DateTime>? txnDate,
    Value<double>? total,
    Value<bool>? deleted,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SalesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      locationId: locationId ?? this.locationId,
      txnDate: txnDate ?? this.txnDate,
      total: total ?? this.total,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (txnDate.present) {
      map['txn_date'] = Variable<DateTime>(txnDate.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('locationId: $locationId, ')
          ..write('txnDate: $txnDate, ')
          ..write('total: $total, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $SalesTable sales = $SalesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncMeta,
    outbox,
    products,
    sales,
  ];
}

typedef $$SyncMetaTableCreateCompanionBuilder =
    SyncMetaCompanion Function({
      required String scopeCompanyId,
      required String scopeLocationId,
      required String tblName,
      Value<DateTime?> lastServerUpdatedAt,
      Value<DateTime?> lastLocalPushedAt,
      Value<int> rowid,
    });
typedef $$SyncMetaTableUpdateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<String> scopeCompanyId,
      Value<String> scopeLocationId,
      Value<String> tblName,
      Value<DateTime?> lastServerUpdatedAt,
      Value<DateTime?> lastLocalPushedAt,
      Value<int> rowid,
    });

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scopeCompanyId => $composableBuilder(
    column: $table.scopeCompanyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeLocationId => $composableBuilder(
    column: $table.scopeLocationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tblName => $composableBuilder(
    column: $table.tblName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastServerUpdatedAt => $composableBuilder(
    column: $table.lastServerUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastLocalPushedAt => $composableBuilder(
    column: $table.lastLocalPushedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scopeCompanyId => $composableBuilder(
    column: $table.scopeCompanyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeLocationId => $composableBuilder(
    column: $table.scopeLocationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tblName => $composableBuilder(
    column: $table.tblName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastServerUpdatedAt => $composableBuilder(
    column: $table.lastServerUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastLocalPushedAt => $composableBuilder(
    column: $table.lastLocalPushedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scopeCompanyId => $composableBuilder(
    column: $table.scopeCompanyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scopeLocationId => $composableBuilder(
    column: $table.scopeLocationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tblName =>
      $composableBuilder(column: $table.tblName, builder: (column) => column);

  GeneratedColumn<DateTime> get lastServerUpdatedAt => $composableBuilder(
    column: $table.lastServerUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastLocalPushedAt => $composableBuilder(
    column: $table.lastLocalPushedAt,
    builder: (column) => column,
  );
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          SyncMetaData,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaData,
            BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
          ),
          SyncMetaData,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scopeCompanyId = const Value.absent(),
                Value<String> scopeLocationId = const Value.absent(),
                Value<String> tblName = const Value.absent(),
                Value<DateTime?> lastServerUpdatedAt = const Value.absent(),
                Value<DateTime?> lastLocalPushedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaCompanion(
                scopeCompanyId: scopeCompanyId,
                scopeLocationId: scopeLocationId,
                tblName: tblName,
                lastServerUpdatedAt: lastServerUpdatedAt,
                lastLocalPushedAt: lastLocalPushedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scopeCompanyId,
                required String scopeLocationId,
                required String tblName,
                Value<DateTime?> lastServerUpdatedAt = const Value.absent(),
                Value<DateTime?> lastLocalPushedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaCompanion.insert(
                scopeCompanyId: scopeCompanyId,
                scopeLocationId: scopeLocationId,
                tblName: tblName,
                lastServerUpdatedAt: lastServerUpdatedAt,
                lastLocalPushedAt: lastLocalPushedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      SyncMetaData,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (
        SyncMetaData,
        BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
      ),
      SyncMetaData,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      required String id,
      required String tblName,
      required String op,
      required String payloadJson,
      Value<String?> rowId,
      Value<DateTime> createdAt,
      Value<DateTime?> nextAttemptAt,
      Value<int> attempts,
      Value<int> rowid,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<String> id,
      Value<String> tblName,
      Value<String> op,
      Value<String> payloadJson,
      Value<String?> rowId,
      Value<DateTime> createdAt,
      Value<DateTime?> nextAttemptAt,
      Value<int> attempts,
      Value<int> rowid,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tblName => $composableBuilder(
    column: $table.tblName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tblName => $composableBuilder(
    column: $table.tblName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tblName =>
      $composableBuilder(column: $table.tblName, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tblName = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String?> rowId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                tblName: tblName,
                op: op,
                payloadJson: payloadJson,
                rowId: rowId,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                attempts: attempts,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tblName,
                required String op,
                required String payloadJson,
                Value<String?> rowId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                tblName: tblName,
                op: op,
                payloadJson: payloadJson,
                rowId: rowId,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                attempts: attempts,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      required String id,
      required String companyId,
      Value<String?> locationId,
      required String code,
      required String name,
      Value<double> price,
      Value<bool> deleted,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String?> locationId,
      Value<String> code,
      Value<String> name,
      Value<double> price,
      Value<bool> deleted,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
          Product,
          PrefetchHooks Function()
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                companyId: companyId,
                locationId: locationId,
                code: code,
                name: name,
                price: price,
                deleted: deleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                Value<String?> locationId = const Value.absent(),
                required String code,
                required String name,
                Value<double> price = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                companyId: companyId,
                locationId: locationId,
                code: code,
                name: name,
                price: price,
                deleted: deleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
      Product,
      PrefetchHooks Function()
    >;
typedef $$SalesTableCreateCompanionBuilder =
    SalesCompanion Function({
      required String id,
      required String companyId,
      required String locationId,
      required DateTime txnDate,
      required double total,
      Value<bool> deleted,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SalesTableUpdateCompanionBuilder =
    SalesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> locationId,
      Value<DateTime> txnDate,
      Value<double> total,
      Value<bool> deleted,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SalesTableFilterComposer extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get txnDate => $composableBuilder(
    column: $table.txnDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SalesTableOrderingComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get txnDate => $composableBuilder(
    column: $table.txnDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get txnDate =>
      $composableBuilder(column: $table.txnDate, builder: (column) => column);

  GeneratedColumn<double> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SalesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SalesTable,
          Sale,
          $$SalesTableFilterComposer,
          $$SalesTableOrderingComposer,
          $$SalesTableAnnotationComposer,
          $$SalesTableCreateCompanionBuilder,
          $$SalesTableUpdateCompanionBuilder,
          (Sale, BaseReferences<_$AppDatabase, $SalesTable, Sale>),
          Sale,
          PrefetchHooks Function()
        > {
  $$SalesTableTableManager(_$AppDatabase db, $SalesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> locationId = const Value.absent(),
                Value<DateTime> txnDate = const Value.absent(),
                Value<double> total = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalesCompanion(
                id: id,
                companyId: companyId,
                locationId: locationId,
                txnDate: txnDate,
                total: total,
                deleted: deleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String locationId,
                required DateTime txnDate,
                required double total,
                Value<bool> deleted = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SalesCompanion.insert(
                id: id,
                companyId: companyId,
                locationId: locationId,
                txnDate: txnDate,
                total: total,
                deleted: deleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SalesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SalesTable,
      Sale,
      $$SalesTableFilterComposer,
      $$SalesTableOrderingComposer,
      $$SalesTableAnnotationComposer,
      $$SalesTableCreateCompanionBuilder,
      $$SalesTableUpdateCompanionBuilder,
      (Sale, BaseReferences<_$AppDatabase, $SalesTable, Sale>),
      Sale,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
}
