import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekly_routine/data/database.dart';
import 'package:weekly_routine/domain/planner.dart';
import 'package:weekly_routine/ui/app.dart';

void main() {
  testWidgets(
    'desktop creates event, rejects overlap, and remembers dark theme',
    (tester) async {
      tester.view.physicalSize = const Size(1360, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = PlannerDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        WeeklyRoutineApp(database: db, initial: Planner()),
      );
      await tester.pumpAndSettle();
      expect(find.text('A week with intention.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'A focused hour',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add to my week'));
      await tester.pumpAndSettle();
      expect((await db.load()).placements.single.title, 'A focused hour');
      await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Conflicting event',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add to my week'));
      await tester.pumpAndSettle();
      expect((await db.load()).placements, hasLength(1));
      expect(find.textContaining('conflicts with'), findsOneWidget);
      await tester.tap(find.byTooltip('Switch to dark theme'));
      await tester.pumpAndSettle();
      expect((await db.load()).dark, isTrue);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Routines').first);
      await tester.pumpAndSettle();
      expect(find.text('Build a rhythm that fits.'), findsOneWidget);
      await tester.tap(find.text('Accountability').first);
      await tester.pumpAndSettle();
      expect(find.text('An honest look at your week.'), findsOneWidget);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      expect(find.text('Backup & restore'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('compact window exposes readable day schedule and navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = PlannerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(WeeklyRoutineApp(database: db, initial: Planner()));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('Next day'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Insights'));
    await tester.pumpAndSettle();
    expect(find.text('An honest look at your week.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('day grid drag moves the persisted event by an hour', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = PlannerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final p = Planner()
      ..placements.add(
        Placement(
          id: 'event',
          title: 'Deep work',
          date: day(DateTime.now()),
          start: 540,
          end: 600,
        ),
      );
    await tester.pumpWidget(WeeklyRoutineApp(database: db, initial: p));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    final item = find.text('09:00–10:00   Deep work');
    await tester.ensureVisible(item);
    await tester.drag(item, const Offset(0, 69));
    await tester.pumpAndSettle();
    final saved = (await db.load()).placements.single;
    expect(saved.start, 600);
    expect(saved.end, 660);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('routine partial outcome and clearing change the saved score', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = PlannerDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final today = day(DateTime.now()), week = monday(DateTime.now());
    final p = Planner()
      ..routines.add(
        Routine(
          id: 'r',
          title: 'Morning reset',
          createdWeek: week,
          slots: [
            Slot(
              id: 's',
              revisions: [
                Revision(from: week, weekday: today.weekday, start: 0, end: 60),
              ],
            ),
          ],
        ),
      );
    await tester.pumpWidget(WeeklyRoutineApp(database: db, initial: p));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partial'));
    await tester.pumpAndSettle();
    expect((await db.load()).score(week).percent, 50);
    await tester.tap(find.text('Morning reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear outcome'));
    await tester.pumpAndSettle();
    expect((await db.load()).score(week).percent, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
