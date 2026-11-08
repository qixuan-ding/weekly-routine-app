import 'package:flutter_test/flutter_test.dart';
import 'package:weekly_routine/domain/planner.dart';

final week = DateTime.utc(2026, 11, 2);
Routine routine(
  String id, {
  int weekday = 1,
  int start = 540,
  int end = 600,
  DateTime? from,
}) => Routine(
  id: id,
  title: id,
  createdWeek: from ?? week,
  slots: [
    Slot(
      id: '$id-slot',
      revisions: [
        Revision(from: from ?? week, weekday: weekday, start: start, end: end),
      ],
    ),
  ],
);
void main() {
  test('weeks and civil dates cross year and DST boundaries', () {
    expect(monday(DateTime(2027, 1, 1)), DateTime.utc(2026, 12, 28));
    expect(monday(DateTime(2026, 11, 8)), week);
    final p = Planner()..routines.add(routine('a'));
    final next = p.items(week.add(const Duration(days: 7))).single;
    expect(next.start, 540);
    expect(next.date, DateTime.utc(2026, 11, 9));
  });
  test(
    'adjacency accepted; overlap rejected for placements and recurrence',
    () {
      final p = Planner()..routines.add(routine('a'));
      p.placements.add(
        Placement(id: 'p', title: 'Adjacent', date: week, start: 600, end: 630),
      );
      p.validate();
      p.placements.single.start = 599;
      expect(p.validate, throwsFormatException);
      p.placements.clear();
      p.routines.add(routine('b', start: 570, end: 630));
      expect(p.validate, throwsFormatException);
    },
  );
  test('recurring move rejects far-future one-off atomically', () {
    final p = Planner()..routines.add(routine('a'));
    p.placements.add(
      Placement(
        id: 'far',
        title: 'Future appointment',
        date: week.add(const Duration(days: 700)),
        start: 660,
        end: 700,
      ),
    );
    p.validate();
    final before = p.export();
    expect(
      () => p.move(p.items(week).single, week, 650),
      throwsFormatException,
    );
    expect(p.export(), before);
  });
  test('recurring move rejects future revision conflict', () {
    final p = Planner()
      ..routines.add(routine('a'))
      ..routines.add(routine('b', weekday: 2));
    p.routines.last.slots.single.revisions.add(
      Revision(
        from: week.add(const Duration(days: 7000)),
        weekday: 1,
        start: 660,
        end: 720,
      ),
    );
    p.validate();
    expect(() => p.move(p.items(week).first, week, 660), throwsFormatException);
  });
  test(
    'move changes selected and future weeks and retains earlier outcomes',
    () {
      final p = Planner()..routines.add(routine('a'));
      final old = p.items(week).single;
      p.mark(old, Outcome.partial, now: DateTime(2026, 11, 3));
      final next = week.add(const Duration(days: 7));
      p.move(p.items(next).single, next.add(const Duration(days: 2)), 630);
      expect(p.items(week).single.start, 540);
      expect(p.items(next).single.start, 630);
      expect(p.items(next).single.date.weekday, 3);
      expect(p.items(next.add(const Duration(days: 7))).single.start, 630);
      expect(p.adherence.single.duration, 60);
      expect(p.score(week).percent, 50);
    },
  );
  test(
    'duration-weighted scoring; unmarked excluded; correction and clearing',
    () {
      final p = Planner()
        ..routines.add(routine('long', start: 480, end: 600))
        ..routines.add(routine('short', start: 600, end: 660))
        ..routines.add(routine('unmarked', weekday: 2));
      final list = p.items(week);
      p.mark(list[0], Outcome.complete, now: DateTime(2026, 11, 8));
      p.mark(list[1], Outcome.partial, now: DateTime(2026, 11, 8));
      expect(p.score(week).total, 180);
      expect(p.score(week).followed, 150);
      expect(p.score(week).percent, closeTo(83.3333, .001));
      p.mark(list[1], Outcome.missed, now: DateTime(2026, 11, 8));
      expect(p.score(week).followed, 120);
      p.mark(list[0], null, now: DateTime(2026, 11, 8));
      expect(p.score(week).percent, 0);
      p.mark(list[1], null, now: DateTime(2026, 11, 8));
      expect(p.score(week).percent, isNull);
    },
  );
  test('future outcomes rejected; skipped unmarked time excluded', () {
    final p = Planner()..routines.add(routine('a'));
    final item = p.items(week).single;
    expect(
      () => p.mark(item, Outcome.complete, now: DateTime(2026, 11, 2, 8)),
      throwsFormatException,
    );
    p.excluded.add(item.id);
    expect(p.items(week), isEmpty);
    expect(p.score(week).total, 0);
    expect(p.items(week.add(const Duration(days: 7))), hasLength(1));
  });
  test('skipped boundary cannot hide a later recurring conflict', () {
    final p = Planner()
      ..routines.add(routine('a'))
      ..routines.add(routine('b'));
    p.excluded.add('b-slot:${dateKey(week)}');
    expect(p.validate, throwsFormatException);
  });
  test(
    'carryover keeps ID and creation; old schedules remain in their week',
    () {
      final p = Planner();
      final t = WeeklyTask(
        id: 't',
        title: 'Open task',
        created: DateTime(2026, 11, 2),
        originalWeek: week,
      );
      p.tasks.add(t);
      p.placements.add(
        Placement(
          id: 'p',
          title: t.title,
          date: week,
          start: 600,
          end: 630,
          taskId: t.id,
        ),
      );
      for (var n = 0; n < 20; n++) {
        expect(p.tasksFor(week.add(Duration(days: n * 7))).single.id, 't');
      }
      expect(p.tasks, hasLength(1));
      expect(p.items(week.add(const Duration(days: 7))), isEmpty);
      t.changes.add(TaskChange(DateTime(2026, 11, 10), true));
      expect(
        p.tasksFor(week).single.doneAt(week.add(const Duration(days: 6))),
        false,
      );
      expect(p.tasksFor(week.add(const Duration(days: 7))), hasLength(1));
      expect(p.tasksFor(week.add(const Duration(days: 14))), isEmpty);
      t.changes.add(TaskChange(DateTime(2026, 11, 17), false));
      expect(p.tasksFor(week.add(const Duration(days: 14))), hasLength(1));
    },
  );
  test('untimed targets do not contribute to adherence', () {
    final p = Planner()
      ..routines.add(
        Routine(id: 'r', title: 'Walk', target: 3, createdWeek: week),
      );
    p.events.add(TargetEvent(id: 'e', routineId: 'r', date: week));
    expect(p.targetCount(p.routines.single, week), 1);
    expect(p.score(week).percent, isNull);
  });
  test('backup roundtrip preserves full state and rejects unknown schema', () {
    final p = Planner()
      ..dark = true
      ..routines.add(routine('a'));
    p.mark(p.items(week).single, Outcome.complete, now: DateTime(2026, 11, 8));
    final q = Planner.fromJson(p.toJson());
    q.validate();
    expect(q.export(), p.export());
    final j = p.toJson()..['schemaVersion'] = 2;
    expect(() => Planner.fromJson(j), throwsFormatException);
  });
  test('invalid backup data fails validation', () {
    final p = Planner()..routines.add(routine('a', start: 600, end: 590));
    expect(p.validate, throwsFormatException);
    final q = Planner()
      ..routines.add(routine('a'))
      ..routines.add(routine('a', weekday: 2));
    expect(q.validate, throwsFormatException);
  });
  test('target changes preserve earlier weekly goals', () {
    final r = Routine(id: 'r', title: 'Read', target: 3, createdWeek: week);
    final next = week.add(const Duration(days: 7));
    r.changeTarget(next, 5);
    expect(r.targetAt(week), 3);
    expect(r.targetAt(next), 5);
    expect(Routine.fromJson(r.toJson()).targetAt(next), 5);
  });
  test(
    'strict dates reject invalid calendar dates and non-Monday exceptions',
    () {
      expect(() => civilDate('2026-02-31'), throwsFormatException);
      final p = Planner()..routines.add(routine('a'));
      p.excluded.add('a-slot:2026-11-03');
      expect(p.validate, throwsFormatException);
    },
  );
}
