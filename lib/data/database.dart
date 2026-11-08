import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/planner.dart';
part 'database.g.dart';

class StoredEntities extends Table {
  TextColumn get kind => text()();
  TextColumn get entityId => text()();
  TextColumn get payload => text()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {kind, entityId};
}

@DriftDatabase(tables: [StoredEntities])
class PlannerDatabase extends _$PlannerDatabase {
  PlannerDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  static Future<PlannerDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return PlannerDatabase(
      NativeDatabase.createInBackground(
        File('${dir.path}/weekly_routine.sqlite'),
      ),
    );
  }

  Future<Planner> load() async {
    final rows = await select(storedEntities).get();
    if (rows.isEmpty) return Planner();
    final data = <String, dynamic>{
      'schemaVersion': 1,
      'dark': false,
      'routines': [],
      'tasks': [],
      'placements': [],
      'adherence': [],
      'events': [],
      'excluded': [],
    };
    for (final row in rows) {
      final value = jsonDecode(row.payload);
      if (row.kind == 'preferences') {
        data['dark'] = value['dark'];
        data['excluded'] = value['excluded'];
      } else if (data[row.kind] is List) {
        (data[row.kind] as List).add(value);
      }
    }
    final planner = Planner.fromJson(data);
    planner.validate();
    return planner;
  }

  Future<void> save(Planner planner) => transaction(() async {
    final data = planner.toJson();
    await delete(storedEntities).go();
    await batch((batch) {
      for (final kind in [
        'routines',
        'tasks',
        'placements',
        'adherence',
        'events',
      ]) {
        batch.insertAll(
          storedEntities,
          (data[kind] as List)
              .map(
                (entity) => StoredEntitiesCompanion.insert(
                  kind: kind,
                  entityId: entity['id'],
                  payload: jsonEncode(entity),
                ),
              )
              .toList(),
        );
      }
      batch.insert(
        storedEntities,
        StoredEntitiesCompanion.insert(
          kind: 'preferences',
          entityId: 'local',
          payload: jsonEncode({
            'dark': planner.dark,
            'excluded': planner.excluded.toList(),
          }),
        ),
      );
    });
  });
}
