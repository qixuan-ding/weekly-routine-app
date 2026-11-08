import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekly_routine/data/database.dart';
import 'package:weekly_routine/domain/planner.dart';

void main() {
  test(
    'SQLite persists complete backup across close and reopen, schema v1',
    () async {
      final dir = await Directory.systemTemp.createTemp('weekly-db-test');
      final file = File('${dir.path}/planner.sqlite');
      final db = PlannerDatabase(NativeDatabase(file));
      final p = Planner()..dark = true;
      final week = DateTime.utc(2026, 11, 2);
      p.tasks.add(
        WeeklyTask(
          id: 'task',
          title: 'Persisted task',
          created: week,
          originalWeek: week,
        ),
      );
      p.routines.add(
        Routine(
          id: 'r',
          title: 'Persisted routine',
          createdWeek: week,
          slots: [
            Slot(
              id: 's',
              revisions: [
                Revision(from: week, weekday: 1, start: 540, end: 600),
              ],
            ),
          ],
        ),
      );
      p.mark(p.items(week).single, Outcome.partial, now: DateTime(2026, 11, 8));
      p.excluded.add('s:2026-11-09');
      await db.save(p);
      await db.close();
      final reopened = PlannerDatabase(NativeDatabase(file));
      final loaded = await reopened.load();
      expect(loaded.export(), p.export());
      expect(loaded.score(week).percent, 50);
      expect(reopened.schemaVersion, 1);
      await reopened.close();
      await dir.delete(recursive: true);
    },
  );
}
