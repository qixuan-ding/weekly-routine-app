// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $StoredEntitiesTable extends StoredEntities
    with TableInfo<$StoredEntitiesTable, StoredEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [kind, entityId, payload, revision];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, entityId};
  @override
  StoredEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredEntity(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $StoredEntitiesTable createAlias(String alias) {
    return $StoredEntitiesTable(attachedDatabase, alias);
  }
}

class StoredEntity extends DataClass implements Insertable<StoredEntity> {
  final String kind;
  final String entityId;
  final String payload;
  final int revision;
  const StoredEntity({
    required this.kind,
    required this.entityId,
    required this.payload,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['entity_id'] = Variable<String>(entityId);
    map['payload'] = Variable<String>(payload);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  StoredEntitiesCompanion toCompanion(bool nullToAbsent) {
    return StoredEntitiesCompanion(
      kind: Value(kind),
      entityId: Value(entityId),
      payload: Value(payload),
      revision: Value(revision),
    );
  }

  factory StoredEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredEntity(
      kind: serializer.fromJson<String>(json['kind']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'entityId': serializer.toJson<String>(entityId),
      'payload': serializer.toJson<String>(payload),
      'revision': serializer.toJson<int>(revision),
    };
  }

  StoredEntity copyWith({
    String? kind,
    String? entityId,
    String? payload,
    int? revision,
  }) => StoredEntity(
    kind: kind ?? this.kind,
    entityId: entityId ?? this.entityId,
    payload: payload ?? this.payload,
    revision: revision ?? this.revision,
  );
  StoredEntity copyWithCompanion(StoredEntitiesCompanion data) {
    return StoredEntity(
      kind: data.kind.present ? data.kind.value : this.kind,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredEntity(')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, entityId, payload, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredEntity &&
          other.kind == this.kind &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.revision == this.revision);
}

class StoredEntitiesCompanion extends UpdateCompanion<StoredEntity> {
  final Value<String> kind;
  final Value<String> entityId;
  final Value<String> payload;
  final Value<int> revision;
  final Value<int> rowid;
  const StoredEntitiesCompanion({
    this.kind = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredEntitiesCompanion.insert({
    required String kind,
    required String entityId,
    required String payload,
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       entityId = Value(entityId),
       payload = Value(payload);
  static Insertable<StoredEntity> custom({
    Expression<String>? kind,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredEntitiesCompanion copyWith({
    Value<String>? kind,
    Value<String>? entityId,
    Value<String>? payload,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return StoredEntitiesCompanion(
      kind: kind ?? this.kind,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredEntitiesCompanion(')
          ..write('kind: $kind, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$PlannerDatabase extends GeneratedDatabase {
  _$PlannerDatabase(QueryExecutor e) : super(e);
  $PlannerDatabaseManager get managers => $PlannerDatabaseManager(this);
  late final $StoredEntitiesTable storedEntities = $StoredEntitiesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [storedEntities];
}

typedef $$StoredEntitiesTableCreateCompanionBuilder =
    StoredEntitiesCompanion Function({
      required String kind,
      required String entityId,
      required String payload,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$StoredEntitiesTableUpdateCompanionBuilder =
    StoredEntitiesCompanion Function({
      Value<String> kind,
      Value<String> entityId,
      Value<String> payload,
      Value<int> revision,
      Value<int> rowid,
    });

class $$StoredEntitiesTableFilterComposer
    extends Composer<_$PlannerDatabase, $StoredEntitiesTable> {
  $$StoredEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredEntitiesTableOrderingComposer
    extends Composer<_$PlannerDatabase, $StoredEntitiesTable> {
  $$StoredEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredEntitiesTableAnnotationComposer
    extends Composer<_$PlannerDatabase, $StoredEntitiesTable> {
  $$StoredEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$StoredEntitiesTableTableManager
    extends
        RootTableManager<
          _$PlannerDatabase,
          $StoredEntitiesTable,
          StoredEntity,
          $$StoredEntitiesTableFilterComposer,
          $$StoredEntitiesTableOrderingComposer,
          $$StoredEntitiesTableAnnotationComposer,
          $$StoredEntitiesTableCreateCompanionBuilder,
          $$StoredEntitiesTableUpdateCompanionBuilder,
          (
            StoredEntity,
            BaseReferences<
              _$PlannerDatabase,
              $StoredEntitiesTable,
              StoredEntity
            >,
          ),
          StoredEntity,
          PrefetchHooks Function()
        > {
  $$StoredEntitiesTableTableManager(
    _$PlannerDatabase db,
    $StoredEntitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoredEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoredEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredEntitiesCompanion(
                kind: kind,
                entityId: entityId,
                payload: payload,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String entityId,
                required String payload,
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredEntitiesCompanion.insert(
                kind: kind,
                entityId: entityId,
                payload: payload,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StoredEntitiesTable, StoredEntity>(table),
                  BaseReferences<
                    _$PlannerDatabase,
                    $StoredEntitiesTable,
                    StoredEntity
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$PlannerDatabase,
      $StoredEntitiesTable,
      StoredEntity,
      $$StoredEntitiesTableFilterComposer,
      $$StoredEntitiesTableOrderingComposer,
      $$StoredEntitiesTableAnnotationComposer,
      $$StoredEntitiesTableCreateCompanionBuilder,
      $$StoredEntitiesTableUpdateCompanionBuilder,
      (
        StoredEntity,
        BaseReferences<_$PlannerDatabase, $StoredEntitiesTable, StoredEntity>,
      ),
      StoredEntity,
      PrefetchHooks Function()
    >;

class $PlannerDatabaseManager {
  final _$PlannerDatabase _db;
  $PlannerDatabaseManager(this._db);
  $$StoredEntitiesTableTableManager get storedEntities =>
      $$StoredEntitiesTableTableManager(_db, _db.storedEntities);
}
