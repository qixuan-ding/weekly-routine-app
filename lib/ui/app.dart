import 'dart:convert';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../domain/planner.dart';
import 'editors.dart';

const blue = Color(0xFF426DD4);
const violet = Color(0xFF9C89F5);
const weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class WeeklyRoutineApp extends StatefulWidget {
  const WeeklyRoutineApp({
    super.key,
    required this.database,
    required this.initial,
  });
  final PlannerDatabase database;
  final Planner initial;
  @override
  State<WeeklyRoutineApp> createState() => _WeeklyRoutineAppState();
}

class _WeeklyRoutineAppState extends State<WeeklyRoutineApp> {
  late Planner planner = widget.initial;
  DateTime week = monday(DateTime.now());
  DateTime selectedDay = day(DateTime.now());
  int page = 0;
  bool dayView = false, busy = false;
  final messenger = GlobalKey<ScaffoldMessengerState>();
  final navigator = GlobalKey<NavigatorState>();
  final dayScroll = ScrollController(initialScrollOffset: 6 * 60 * 1.15);
  @override
  void dispose() {
    dayScroll.dispose();
    super.dispose();
  }

  Color get accent => planner.dark ? violet : blue;
  Color get muted =>
      planner.dark ? const Color(0xFFA9A5BC) : const Color(0xFF768199);
  Color get surface => planner.dark ? const Color(0xFF191722) : Colors.white;
  Color get line =>
      planner.dark ? const Color(0xFF302C40) : const Color(0xFFE4EAF3);

  void notice(Object message) {
    messenger.currentState?.hideCurrentSnackBar();
    messenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(message.toString().replaceFirst('FormatException: ', '')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> commit(void Function(Planner) change) async {
    if (busy) return false;
    setState(() => busy = true);
    try {
      final draft = Planner.fromJson(planner.toJson());
      change(draft);
      draft.validate();
      await widget.database.save(draft);
      if (mounted) setState(() => planner = draft);
      return true;
    } catch (error) {
      notice(error);
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void changeWeek(int amount) => setState(() {
    week = week.add(Duration(days: 7 * amount));
    selectedDay = week.add(Duration(days: selectedDay.weekday - 1));
  });
  void today() => setState(() {
    week = monday(DateTime.now());
    selectedDay = day(DateTime.now());
  });

  Future<void> addItem({
    DateTime? date,
    int? minute,
    CalendarItem? item,
    WeeklyTask? task,
    String? initialKind,
  }) async {
    final result = await showDialog<EditorResult>(
      context: navigator.currentState!.overlay!.context,
      builder: (context) => ScheduleEditor(
        date: date ?? selectedDay,
        minute: minute ?? 540,
        item: item,
        task: task,
        initialKind: initialKind,
      ),
    );
    if (result == null) return;
    final ok = await commit((p) {
      if (item?.isRoutine == true) {
        final routine = p.routines.firstWhere((r) => r.id == item!.routineId);
        routine.title = result.title;
        routine.notes = result.notes;
        final slot = routine.slots.firstWhere((s) => s.id == item!.slotId);
        slot.revisions.removeWhere((r) => !r.from.isBefore(monday(item!.date)));
        slot.revisions.add(
          Revision(
            from: monday(item!.date),
            weekday: result.date.weekday,
            start: result.start,
            end: result.end,
          ),
        );
      } else if (item != null) {
        final placement = p.placements.firstWhere((s) => s.id == item.id);
        placement
          ..title = result.title
          ..notes = result.notes
          ..date = result.date
          ..start = result.start
          ..end = result.end;
        if (item.taskId != null) {
          final linked = p.tasks.firstWhere((t) => t.id == item.taskId);
          linked
            ..title = result.title
            ..notes = result.notes;
        }
      } else if (result.kind == 'routine' || result.kind == 'target') {
        p.routines.add(
          Routine(
            id: newId(),
            title: result.title,
            notes: result.notes,
            target: result.kind == 'target' ? result.target : 0,
            createdWeek: monday(result.date),
            slots: result.kind == 'target'
                ? []
                : result.days
                      .map(
                        (d) => Slot(
                          id: newId(),
                          revisions: [
                            Revision(
                              from: monday(result.date),
                              weekday: d,
                              start: result.start,
                              end: result.end,
                            ),
                          ],
                        ),
                      )
                      .toList(),
          ),
        );
      } else if (result.kind == 'task') {
        p.tasks.add(
          WeeklyTask(
            id: newId(),
            title: result.title,
            notes: result.notes,
            created: DateTime.now(),
            originalWeek: week,
          ),
        );
      } else {
        if (task != null &&
            p.placements.any(
              (s) =>
                  s.taskId == task.id && monday(s.date) == monday(result.date),
            )) {
          throw const FormatException(
            'This task is already scheduled this week. Open its placement to move it.',
          );
        }
        p.placements.add(
          Placement(
            id: newId(),
            title: result.title,
            notes: result.notes,
            date: result.date,
            start: result.start,
            end: result.end,
            taskId: task?.id,
          ),
        );
      }
    });
    if (ok) notice(item != null ? 'Changes saved.' : 'Added to your week.');
  }

  Future<void> editTask(WeeklyTask task) async {
    final result = await showDialog<EditorResult>(
      context: navigator.currentState!.overlay!.context,
      builder: (_) => ScheduleEditor(
        date: week,
        minute: 540,
        task: task,
        initialKind: 'task',
        editingTask: true,
      ),
    );
    if (result != null) {
      await commit((p) {
        final t = p.tasks.firstWhere((t) => t.id == task.id);
        t
          ..title = result.title
          ..notes = result.notes;
      });
    }
  }

  Future<bool> confirm(String title, String description, String action) async =>
      await showDialog<bool>(
        context: navigator.currentState!.overlay!.context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SizedBox(width: 400, child: Text(description)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> details(CalendarItem item) async {
    final result = await showDialog<String>(
      context: navigator.currentState!.overlay!.context,
      builder: (context) {
        final outcome = planner.adherence
            .where((a) => a.id == item.id)
            .firstOrNull
            ?.outcome;
        final task = planner.tasks
            .where((t) => t.id == item.taskId)
            .firstOrNull;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                item.isRoutine
                    ? Icons.autorenew_rounded
                    : Icons.event_note_rounded,
                color: accent,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(item.title)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('EEEE, MMMM d').format(item.date)}  ·  ${clock(item.start)}–${clock(item.end)}',
                  style: TextStyle(color: muted),
                ),
                if (item.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(item.notes),
                  ),
                if (item.isRoutine) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Record your outcome',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: Outcome.values
                        .map(
                          (o) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: outcome == o
                                      ? accent.withValues(alpha: .15)
                                      : null,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context, o.name),
                                child: Column(
                                  children: [
                                    Text(
                                      o.symbol,
                                      style: const TextStyle(fontSize: 25),
                                    ),
                                    Text(
                                      o.label,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (outcome != null)
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'clear'),
                      child: const Text('Clear outcome'),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Unmarked time stays unscored. Partial earns 50% of the scheduled duration.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
                if (task != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.pop(context, 'toggleTask'),
                      icon: Icon(task.done ? Icons.undo : Icons.check),
                      label: Text(task.done ? 'Reopen task' : 'Complete task'),
                    ),
                  ),
                const SizedBox(height: 22),
                Divider(color: line),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'edit'),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: Text(
                    item.isRoutine
                        ? 'Edit from this week forward'
                        : 'Edit schedule',
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'remove'),
                  icon: const Icon(Icons.event_busy_outlined, size: 17),
                  label: Text(
                    item.isRoutine
                        ? 'Skip this occurrence'
                        : 'Remove scheduled placement',
                  ),
                ),
                if (item.isRoutine)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, 'end'),
                    icon: const Icon(Icons.stop_circle_outlined, size: 17),
                    label: const Text('End this weekly time from here'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    if (result == 'edit') {
      await addItem(item: item);
      return;
    }
    if (result == 'end') {
      if (!await confirm(
        'End this weekly time?',
        'This occurrence and later repetitions will be removed. Earlier weeks and recorded accountability stay in your history.',
        'End weekly time',
      )) {
        return;
      }
      await commit(
        (p) =>
            p.routines
                .firstWhere((r) => r.id == item.routineId)
                .slots
                .firstWhere((s) => s.id == item.slotId)
                .until = monday(
              item.date,
            ),
      );
    } else if (result == 'remove') {
      await commit((p) {
        if (item.isRoutine) {
          p.excluded.add(item.id);
        } else {
          p.placements.removeWhere((s) => s.id == item.id);
        }
      });
      notice(
        item.taskId != null
            ? 'Placement removed. Your weekly task is still available.'
            : 'Occurrence removed. Recorded history is retained.',
      );
    } else if (result == 'toggleTask') {
      await commit((p) {
        final t = p.tasks.firstWhere((t) => t.id == item.taskId);
        t.changes.add(TaskChange(DateTime.now(), !t.done));
      });
    } else {
      await commit(
        (p) => p.mark(
          item,
          result == 'clear' ? null : Outcome.values.byName(result),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: planner.dark ? violet : blue,
      brightness: planner.dark ? Brightness.dark : Brightness.light,
      surface: surface,
    );
    return MaterialApp(
      title: 'Weekly Routine',
      navigatorKey: navigator,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messenger,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: planner.dark
            ? const Color(0xFF111017)
            : const Color(0xFFF5F8FD),
        fontFamily: '.AppleSystemUIFont',
        dividerColor: line,
        textTheme: ThemeData(brightness: scheme.brightness).textTheme.apply(
          fontFamily: '.AppleSystemUIFont',
          bodyColor: planner.dark
              ? const Color(0xFFECEAF5)
              : const Color(0xFF25334B),
          displayColor: planner.dark
              ? const Color(0xFFECEAF5)
              : const Color(0xFF25334B),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: planner.dark
                ? const Color(0xFF171323)
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.all(16),
        ),
        tooltipTheme: const TooltipThemeData(
          waitDuration: Duration(milliseconds: 350),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: Builder(
        builder: (context) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
                addItem(),
            const SingleActivator(LogicalKeyboardKey.keyT, meta: true): today,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1000;
                  return Row(
                    children: [
                      if (wide) sidebar(),
                      Expanded(
                        child: Column(
                          children: [
                            topbar(wide),
                            if (busy)
                              LinearProgressIndicator(
                                minHeight: 2,
                                color: accent,
                              ),
                            Expanded(
                              child: switch (page) {
                                0 => plannerPage(wide),
                                1 => routinesPage(),
                                2 => insightsPage(),
                                _ => settingsPage(),
                              },
                            ),
                            if (!wide)
                              NavigationBar(
                                selectedIndex: page,
                                onDestinationSelected: (v) =>
                                    setState(() => page = v),
                                destinations: const [
                                  NavigationDestination(
                                    icon: Icon(Icons.calendar_today_outlined),
                                    label: 'Week',
                                  ),
                                  NavigationDestination(
                                    icon: Icon(Icons.autorenew),
                                    label: 'Routines',
                                  ),
                                  NavigationDestination(
                                    icon: Icon(Icons.insights),
                                    label: 'Insights',
                                  ),
                                  NavigationDestination(
                                    icon: Icon(Icons.tune),
                                    label: 'Settings',
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget sidebar() => Container(
    width: 208,
    decoration: BoxDecoration(
      color: surface,
      border: Border(right: BorderSide(color: line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 16, 32),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.wb_cloudy_outlined,
                  color: planner.dark ? Colors.black : Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'weekly',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.7,
                      ),
                    ),
                    Text(
                      'A little more intentional.',
                      style: TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26, bottom: 12),
          child: Text(
            'YOUR SPACE',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Material(
              color: page == i
                  ? accent.withValues(alpha: .1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Icon(
                  [
                    Icons.calendar_view_week_rounded,
                    Icons.autorenew_rounded,
                    Icons.bar_chart_rounded,
                    Icons.tune_rounded,
                  ][i],
                  color: page == i ? accent : muted,
                  size: 20,
                ),
                title: Text(
                  ['My week', 'Routines', 'Accountability', 'Settings'][i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: page == i ? FontWeight.w600 : FontWeight.w400,
                    color: page == i ? accent : null,
                  ),
                ),
                onTap: () => setState(() => page = i),
              ),
            ),
          ),
        const Spacer(),
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.spa_outlined, color: accent, size: 23),
              const SizedBox(height: 10),
              const Text(
                'Progress, at your pace.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Make room for what matters. Every week is a fresh start.',
                style: TextStyle(color: muted, fontSize: 11, height: 1.6),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 20, 22),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 13, color: muted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Private & saved on this Mac',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget topbar(bool wide) => Container(
    height: 77,
    padding: EdgeInsets.symmetric(horizontal: wide ? 30 : 18),
    decoration: BoxDecoration(
      color: surface,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Text(
          ['My week', 'My routines', 'Accountability', 'Settings'][page],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (wide) ...[
          Icon(Icons.cloud_done_outlined, size: 16, color: muted),
          const SizedBox(width: 7),
          Text(
            'Offline, always yours',
            style: TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(width: 22),
        ],
        IconButton(
          tooltip: planner.dark
              ? 'Switch to light theme'
              : 'Switch to dark theme',
          onPressed: () => commit((p) => p.dark = !p.dark),
          icon: Icon(
            planner.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        FilledButton.icon(
          onPressed: busy ? null : () => addItem(),
          icon: const Icon(Icons.add, size: 17),
          label: const Text('Add item', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );

  Widget card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) => Material(
    color: surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: BorderSide(color: line),
    ),
    child: Padding(padding: padding, child: child),
  );
  Widget sectionLabel(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 8),
      Text(subtitle, style: TextStyle(color: muted, fontSize: 13)),
    ],
  );
  Widget weekNavigation() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Previous week',
        onPressed: () => changeWeek(-1),
        icon: const Icon(Icons.chevron_left, size: 21),
      ),
      Text(
        '${DateFormat('MMM d').format(week)} – ${DateFormat('MMM d, y').format(week.add(const Duration(days: 6)))}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      IconButton(
        tooltip: 'Next week',
        onPressed: () => changeWeek(1),
        icon: const Icon(Icons.chevron_right, size: 21),
      ),
      const SizedBox(width: 8),
      OutlinedButton(
        onPressed: today,
        child: const Text('Today', style: TextStyle(fontSize: 11)),
      ),
    ],
  );

  Widget plannerPage(bool wide) {
    final score = planner.score(week),
        tasks = planner.tasksFor(week),
        items = planner.items(week);
    return SingleChildScrollView(
      padding: EdgeInsets.all(wide ? 30 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 132,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: planner.dark
                    ? [const Color(0xFF292039), const Color(0xFF1C1827)]
                    : [const Color(0xFFE6EFFD), const Color(0xFFF0F6FF)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: AtmospherePainter(planner.dark)),
                ),
                Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'A week with intention.',
                        style: TextStyle(
                          fontSize: wide ? 28 : 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.9,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Small routines. A little structure. More space for you.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                metric(
                  'Routine accountability',
                  score.percent == null
                      ? 'No tracked time'
                      : '${score.percent!.round()}%',
                  score.total == 0
                      ? 'Record an outcome to begin'
                      : '${score.followed.round()} of ${score.total} minutes followed',
                  Icons.donut_large_rounded,
                  (c.maxWidth - (wide ? 24 : 0)) / (wide ? 3 : 1),
                ),
                if (wide) ...[
                  metric(
                    'Weekly tasks',
                    '${tasks.where((t) => t.doneAt(week.add(const Duration(days: 6)))).length} / ${tasks.length}',
                    'Completed, one step at a time',
                    Icons.check_circle_outline,
                    (c.maxWidth - 24) / 3,
                  ),
                  metric(
                    'On the calendar',
                    '${items.length} items',
                    'A little room for what matters',
                    Icons.calendar_today_outlined,
                    (c.maxWidth - 24) / 3,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 20,
            runSpacing: 10,
            children: [
              weekNavigation(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Week', style: TextStyle(fontSize: 11)),
                    icon: Icon(Icons.view_week_outlined, size: 15),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Day', style: TextStyle(fontSize: 11)),
                    icon: Icon(Icons.view_day_outlined, size: 15),
                  ),
                ],
                selected: {dayView},
                onSelectionChanged: (s) => setState(() => dayView = s.first),
                showSelectedIcon: false,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (dayView || !wide) dayCalendar() else weekCalendar(),
          if (planner.excluded.any((id) => id.endsWith(dateKey(week))))
            skippedPanel(),
          const SizedBox(height: 22),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: tasksPanel()),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: targetsPanel()),
              ],
            )
          else ...[
            tasksPanel(),
            const SizedBox(height: 16),
            targetsPanel(),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: muted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Drag an item to reschedule · Click to record an outcome · Unmarked routines stay unscored',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget skippedPanel() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skipped this week',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          for (final routine in planner.routines)
            for (final slot in routine.slots)
              if (slot.at(week) != null &&
                  planner.excluded.contains('${slot.id}:${dateKey(week)}'))
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${routine.title} · ${weekdays[slot.at(week)!.weekday - 1]}',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                    TextButton(
                      onPressed: () => commit(
                        (p) => p.excluded.remove('${slot.id}:${dateKey(week)}'),
                      ),
                      child: const Text('Restore occurrence'),
                    ),
                  ],
                ),
        ],
      ),
    ),
  );

  Widget metric(
    String label,
    String value,
    String subtitle,
    IconData icon,
    double width,
  ) => SizedBox(
    width: width,
    child: card(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: muted, fontSize: 11)),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: value.length > 8 ? 21 : 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(subtitle, style: TextStyle(color: muted, fontSize: 10)),
              ],
            ),
          ),
          Icon(icon, color: accent.withValues(alpha: .7), size: 29),
        ],
      ),
    ),
  );

  Widget weekCalendar() {
    final items = planner.items(week);
    return card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            children: List.generate(7, (i) {
              final d = week.add(Duration(days: i)),
                  isToday = d == day(DateTime.now());
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    selectedDay = d;
                    dayView = true;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: i < 6 ? line : Colors.transparent,
                        ),
                        bottom: BorderSide(color: line),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          weekdays[i].substring(0, 3).toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: muted,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 31,
                          height: 31,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday ? accent : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? (planner.dark ? Colors.black : Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          SizedBox(
            height: 290,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(7, (i) {
                final date = week.add(Duration(days: i));
                final daily = items.where((a) => a.date == date).toList();
                return Expanded(
                  child: DragTarget<CalendarItem>(
                    onWillAcceptWithDetails: (d) => true,
                    onAcceptWithDetails: (d) =>
                        commit((p) => p.move(d.data, date, d.data.start)),
                    builder: (context, candidates, rejected) => Container(
                      decoration: BoxDecoration(
                        color: candidates.isNotEmpty
                            ? accent.withValues(alpha: .1)
                            : null,
                        border: Border(
                          right: BorderSide(
                            color: i < 6 ? line : Colors.transparent,
                          ),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(7),
                        child: Column(
                          children: [
                            ...daily.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: draggableItem(item, compact: true),
                              ),
                            ),
                            const SizedBox(height: 5),
                            IconButton(
                              tooltip: 'Add to ${weekdays[i]}',
                              onPressed: () => addItem(date: date),
                              icon: Icon(
                                Icons.add_circle_outline,
                                size: 18,
                                color: muted.withValues(alpha: .6),
                              ),
                            ),
                            if (daily.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 25),
                                child: Text(
                                  'Room to\nbreathe',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: muted.withValues(alpha: .5),
                                    fontSize: 10,
                                    height: 1.7,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                legend(accent, 'Routine'),
                const SizedBox(width: 18),
                legend(const Color(0xFF4C9D8E), 'Task / event'),
                const Spacer(),
                Text(
                  'MONDAY START',
                  style: TextStyle(color: muted, fontSize: 8, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 9, color: muted)),
    ],
  );
  Widget draggableItem(CalendarItem item, {bool compact = false}) =>
      Draggable<CalendarItem>(
        data: item,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 180, child: itemTile(item, compact: compact)),
        ),
        childWhenDragging: Opacity(
          opacity: .3,
          child: itemTile(item, compact: compact),
        ),
        child: itemTile(item, compact: compact),
      );
  Widget itemTile(CalendarItem item, {bool compact = false}) {
    final color = item.isRoutine ? accent : const Color(0xFF378879);
    final outcome = planner.adherence
        .where((a) => a.id == item.id)
        .firstOrNull
        ?.outcome;
    final task = planner.tasks.where((t) => t.id == item.taskId).firstOrNull;
    return Tooltip(
      message:
          '${item.title}\n${clock(item.start)}–${clock(item.end)}${item.isRoutine ? ' · Repeats weekly' : ''}',
      child: Material(
        color: color.withValues(alpha: planner.dark ? .15 : .08),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () => details(item),
          child: Container(
            padding: EdgeInsets.all(compact ? 9 : 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 3)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${clock(item.start)}–${clock(item.end)}',
                  style: TextStyle(
                    color: planner.dark ? color.withValues(alpha: .95) : color,
                    fontSize: compact ? 9 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.title,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    decoration: task?.done == true
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      item.isRoutine
                          ? Icons.autorenew
                          : Icons.event_note_outlined,
                      size: 10,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        outcome?.label ??
                            (task?.done == true
                                ? 'Completed'
                                : item.isRoutine
                                ? 'Weekly routine'
                                : task != null
                                ? 'Weekly task'
                                : 'Event'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 8),
                      ),
                    ),
                    if (outcome != null)
                      Text(
                        outcome.symbol,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget dayCalendar() {
    final items = planner
        .items(week)
        .where((i) => i.date == selectedDay)
        .toList();
    const pixels = 1.15;
    return card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous day',
                  onPressed: () => setState(() {
                    selectedDay = selectedDay.subtract(const Duration(days: 1));
                    week = monday(selectedDay);
                  }),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMMM d').format(selectedDay),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Next day',
                  onPressed: () => setState(() {
                    selectedDay = selectedDay.add(const Duration(days: 1));
                    week = monday(selectedDay);
                  }),
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton.icon(
                  onPressed: () => addItem(date: selectedDay),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 560,
            child: SingleChildScrollView(
              controller: dayScroll,
              child: SizedBox(
                height: 1440 * pixels + 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 62,
                      child: Stack(
                        children: List.generate(
                          24,
                          (h) => Positioned(
                            top: h * 60 * pixels + 5,
                            right: 12,
                            child: Text(
                              clock(h * 60),
                              style: TextStyle(color: muted, fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: DragTarget<CalendarItem>(
                        onWillAcceptWithDetails: (d) => true,
                        onAcceptWithDetails: (d) {
                          final box =
                              contextForGrid?.findRenderObject() as RenderBox?;
                          if (box == null) return;
                          final y = box.globalToLocal(d.offset).dy;
                          final start = ((y / pixels / 15).round() * 15).clamp(
                            0,
                            1440 - (d.data.end - d.data.start),
                          );
                          commit((p) => p.move(d.data, selectedDay, start));
                        },
                        builder: (context, candidates, rejected) {
                          contextForGrid = context;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTapDown: (d) => addItem(
                              date: selectedDay,
                              minute:
                                  ((d.localPosition.dy / pixels / 15).floor() *
                                          15)
                                      .clamp(0, 1425),
                            ),
                            onDoubleTap: () {},
                            child: Stack(
                              children: [
                                for (var h = 0; h < 24; h++)
                                  Positioned(
                                    top: h * 60 * pixels,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 60 * pixels,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(color: line),
                                        ),
                                      ),
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: Divider(
                                          color: line.withValues(alpha: .5),
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                for (final item in items)
                                  Positioned(
                                    top: item.start * pixels,
                                    left: 6,
                                    right: 16,
                                    height: math.max(
                                      2,
                                      (item.end - item.start) * pixels - 2,
                                    ),
                                    child: ClipRect(
                                      child: draggableDayItem(item),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Double-click a time to add · Drag snaps to 15 minutes · Edit for exact times',
              style: TextStyle(color: muted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  BuildContext? contextForGrid;
  Widget draggableDayItem(CalendarItem item) => Draggable<CalendarItem>(
    data: item,
    feedback: Material(
      color: Colors.transparent,
      child: SizedBox(width: 300, child: itemTile(item)),
    ),
    childWhenDragging: Opacity(opacity: .25, child: dayBlock(item)),
    child: dayBlock(item),
  );
  Widget dayBlock(CalendarItem item) {
    final color = item.isRoutine ? accent : const Color(0xFF378879);
    final outcome = planner.adherence
        .where((a) => a.id == item.id)
        .firstOrNull
        ?.outcome;
    return Material(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => details(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${clock(item.start)}–${clock(item.end)}   ${item.title}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (outcome != null) Text(outcome.symbol),
              if (item.isRoutine) Icon(Icons.autorenew, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget tasksPanel() {
    final tasks = planner.tasksFor(week);
    return card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Weekly tasks',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => addItem(initialKind: 'task'),
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Add task', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          Text(
            'A place for the things without a time slot.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            emptySmall(
              Icons.checklist_rounded,
              'A clear list, a fresh start.',
              'Add a task for this week.',
            ),
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Checkbox(
                    value: task.doneAt(week.add(const Duration(days: 6))),
                    onChanged: busy
                        ? null
                        : (v) => commit((p) {
                            final t = p.tasks.firstWhere(
                              (t) => t.id == task.id,
                            );
                            t.changes.add(TaskChange(DateTime.now(), !t.done));
                          }),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => editTask(task),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 12,
                              decoration:
                                  task.doneAt(week.add(const Duration(days: 6)))
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (task.originalWeek.isBefore(week))
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                'Carried from ${DateFormat('MMM d').format(task.originalWeek)}',
                                style: TextStyle(fontSize: 9, color: muted),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Task options',
                    icon: Icon(Icons.more_horiz, size: 18, color: muted),
                    onSelected: (v) async {
                      if (v == 'schedule') {
                        await addItem(task: task, initialKind: 'event');
                      } else if (v == 'edit') {
                        await editTask(task);
                      } else if (await confirm(
                        'Delete task?',
                        'The task and its scheduled placements will be deleted.',
                        'Delete',
                      )) {
                        await commit((p) {
                          p.tasks.removeWhere((t) => t.id == task.id);
                          p.placements.removeWhere((s) => s.taskId == task.id);
                        });
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'schedule',
                        child: Text('Place in schedule'),
                      ),
                      PopupMenuItem(value: 'edit', child: Text('Edit task')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete task'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (tasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Open tasks carry forward automatically. Completion is separate from routine accountability.',
                style: TextStyle(color: muted, fontSize: 10, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget emptySmall(IconData icon, String title, String sub) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      children: [
        Icon(icon, color: accent.withValues(alpha: .5), size: 29),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 5),
              Text(sub, style: TextStyle(fontSize: 10, color: muted)),
            ],
          ),
        ),
      ],
    ),
  );
  Widget targetsPanel() {
    final routines = planner.routines
        .where(
          (r) =>
              r.target > 0 &&
              !r.createdWeek.isAfter(week) &&
              (r.archivedWeek == null || week.isBefore(r.archivedWeek!)),
        )
        .toList();
    return card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Weekly targets',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const Spacer(),
              Icon(Icons.flag_outlined, size: 18, color: accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Flexible goals, on your own schedule.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (routines.isEmpty) ...[
            emptySmall(
              Icons.track_changes_outlined,
              'Find your rhythm.',
              'Try reading three times a week.',
            ),
            TextButton.icon(
              onPressed: () => addItem(initialKind: 'target'),
              icon: const Icon(Icons.add, size: 15),
              label: const Text(
                'Add a weekly target',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
          for (final routine in routines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          routine.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${planner.targetCount(routine, week)} / ${routine.targetAt(week)}',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                      IconButton(
                        tooltip: 'Undo latest completion this week',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => commit((p) {
                          final e = p.events
                              .where(
                                (e) =>
                                    e.routineId == routine.id &&
                                    monday(e.date) == week,
                              )
                              .lastOrNull;
                          if (e != null) p.events.remove(e);
                        }),
                        icon: Icon(
                          Icons.remove_circle_outline,
                          size: 17,
                          color: muted,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Log completion',
                        visualDensity: VisualDensity.compact,
                        onPressed: week.isAfter(monday(DateTime.now()))
                            ? null
                            : () => commit(
                                (p) => p.events.add(
                                  TargetEvent(
                                    id: newId(),
                                    routineId: routine.id,
                                    date: week == monday(DateTime.now())
                                        ? day(DateTime.now())
                                        : week.add(const Duration(days: 6)),
                                  ),
                                ),
                              ),
                        icon: Icon(
                          Icons.add_circle_outline,
                          size: 19,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:
                          (planner.targetCount(routine, week) /
                                  routine.targetAt(week))
                              .clamp(0, 1),
                      minHeight: 5,
                      color: accent,
                      backgroundColor: accent.withValues(alpha: .1),
                    ),
                  ),
                ],
              ),
            ),
          if (routines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Untimed completions stay separate from your time-based score.',
                style: TextStyle(fontSize: 10, color: muted, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget routinesPage() => SingleChildScrollView(
    padding: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionLabel(
          'Build a rhythm that fits.',
          'Weekly routines repeat until you change them. Flexible targets leave the timing to you.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => addItem(initialKind: 'routine'),
              icon: const Icon(Icons.autorenew, size: 17),
              label: const Text('New weekly routine'),
            ),
            OutlinedButton.icon(
              onPressed: () => addItem(initialKind: 'target'),
              icon: const Icon(Icons.flag_outlined, size: 17),
              label: const Text('New flexible target'),
            ),
          ],
        ),
        const SizedBox(height: 26),
        if (planner.routines.isEmpty)
          card(
            child: emptySmall(
              Icons.spa_outlined,
              'Your routines begin here.',
              'Choose a weekly time or set a flexible goal.',
            ),
          ),
        for (final routine in planner.routines)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: card(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      routine.slots.isEmpty
                          ? Icons.flag_outlined
                          : Icons.autorenew,
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (routine.notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              routine.notes,
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          ),
                        const SizedBox(height: 9),
                        if (routine.target > 0)
                          Text(
                            '${routine.targetAt(week)} times each week${routine.archivedWeek != null ? ' · Archived' : ''}',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        for (final slot in routine.slots)
                          Builder(
                            builder: (_) {
                              final rev = slot.at(week);
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  rev == null
                                      ? 'Ended or not yet active in this week'
                                      : '${weekdays[rev.weekday - 1]} · ${clock(rev.start)}–${clock(rev.end)}',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Routine options',
                    onSelected: (v) async {
                      if (v == 'edit') {
                        await editRoutine(routine);
                      } else if (await confirm(
                        'Archive routine?',
                        'All weekly times will end from the selected week (${dateKey(week)}). Earlier schedules, outcomes, and completion history remain available.',
                        'Archive',
                      )) {
                        await commit((p) {
                          final r = p.routines.firstWhere(
                            (r) => r.id == routine.id,
                          );
                          r.archivedWeek = week;
                          for (final slot in r.slots) {
                            if (slot.until == null ||
                                week.isBefore(slot.until!)) {
                              slot.until = week;
                            }
                          }
                        });
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit routine')),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text('Archive from selected week'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Select a routine occurrence in My week to edit its time from that week onward. Dragging follows the same rule.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 12),
        weekNavigation(),
      ],
    ),
  );
  Future<void> editRoutine(Routine routine) async {
    final result = await showDialog<EditorResult>(
      context: navigator.currentState!.overlay!.context,
      builder: (_) => ScheduleEditor(
        date: week,
        minute: 540,
        initialKind: 'task',
        editingTask: true,
        task: WeeklyTask(
          id: routine.id,
          title: routine.title,
          notes: routine.notes,
          created: DateTime.now(),
          originalWeek: week,
        ),
        routineMetadata: true,
        initialTarget: routine.target > 0 ? routine.targetAt(week) : null,
      ),
    );
    if (result != null) {
      await commit((p) {
        final r = p.routines.firstWhere((r) => r.id == routine.id);
        r
          ..title = result.title
          ..notes = result.notes;
        if (r.target > 0) r.changeTarget(week, result.target);
      });
    }
  }

  Widget insightsPage() {
    final score = planner.score(week), records = planner.records(week).toList();
    final grouped = <String, List<Adherence>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.routineId, () => []).add(record);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(
            'An honest look at your week.',
            'Private accountability, weighted by the time you planned.',
          ),
          const SizedBox(height: 18),
          weekNavigation(),
          const SizedBox(height: 20),
          card(
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: (score.percent ?? 0) / 100,
                          strokeWidth: 8,
                          color: accent,
                          backgroundColor: accent.withValues(alpha: .12),
                        ),
                      ),
                      Text(
                        score.percent == null
                            ? '—'
                            : '${score.percent!.round()}%',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        score.percent == null
                            ? 'No tracked time'
                            : 'Routine accountability',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${score.followed.round()} minutes followed · ${(score.total - score.followed).round()} minutes not followed',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${records.length} scored occurrences. Unmarked and unscheduled time is excluded.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'By routine',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                if (grouped.isEmpty)
                  emptySmall(
                    Icons.donut_large,
                    'Your history is yours to write.',
                    'Record a routine outcome in the calendar.',
                  ),
                for (final group in grouped.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.last.title,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${group.length} outcomes · ${Score(group).total} min',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                        const SizedBox(width: 24),
                        Text(
                          '${Score(group).percent!.round()}%',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Week-to-week',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 22),
                for (var i = 0; i < 8; i++)
                  Builder(
                    builder: (_) {
                      final w = week.subtract(Duration(days: i * 7)),
                          s = planner.score(w);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () => setState(() => week = w),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 98,
                                child: Text(
                                  DateFormat('MMM d').format(w),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    minHeight: 8,
                                    value: (s.percent ?? 0) / 100,
                                    color: accent,
                                    backgroundColor: accent.withValues(
                                      alpha: .1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  s.percent == null
                                      ? 'No tracked time'
                                      : '${s.percent!.round()}%',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: muted, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          targetsPanel(),
          const SizedBox(height: 18),
          Text(
            '✓ Complete = 100%   ·   ◐ Partial = 50%   ·   × Not completed = 0%\nScore = followed minutes ÷ scored scheduled minutes. Late recording earns the same credit. Recorded durations stay attached to their original week.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.8),
          ),
        ],
      ),
    );
  }

  Widget settingsPage() => SingleChildScrollView(
    padding: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionLabel(
          'Make yourself at home.',
          'Your preferences and your data, kept on this device.',
        ),
        const SizedBox(height: 26),
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Appearance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Obsidian night',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Black and purple, with a little edge. Switch off for blue skies.',
                  style: TextStyle(fontSize: 11),
                ),
                value: planner.dark,
                onChanged: (v) => commit((p) => p.dark = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Backup & restore',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                'Export a versioned JSON backup of all routines, tasks, outcomes, and preferences. Keep a copy somewhere safe.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.7),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: exportBackup,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Export backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: importBackup,
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: const Text('Restore backup'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline, color: accent, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Offline & private',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'No account is needed. Everything is stored in a local SQLite database on this Mac.\n\nDevice sync is not configured in this version. Approved-account sync needs a backend and access rules before activation.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A few helpful details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Weeks start Monday. Times follow your local clock, including after a time-zone change. Overnight items can be split across two days.\n\nDrag in the day view to snap to 15-minute intervals, or edit an item for exact start and end times. A routine move changes the selected week and all future weeks.\n\nOutcomes can be recorded once a routine has started, including later. Skipped occurrences are excluded; existing recorded history is retained. Flexible targets count full completions only.\n\n⌘N  Add item     ⌘T  Return to this week',
                style: TextStyle(color: muted, fontSize: 12, height: 1.8),
              ),
            ],
          ),
        ),
        if (planner.tasks.isEmpty &&
            planner.routines.isEmpty &&
            planner.placements.isEmpty) ...[
          const SizedBox(height: 18),
          card(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Take a look around',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add a small example week to explore the app.',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: loadDemo,
                  child: const Text('Add example week'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Weekly Routine · 1.0.0 · Made for a more intentional week.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    ),
  );

  Future<void> exportBackup() async {
    try {
      final location = await getSaveLocation(
        suggestedName: 'weekly-routine-${dateKey(DateTime.now())}.json',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'JSON backup', extensions: ['json']),
        ],
      );
      if (location == null) return;
      await XFile.fromData(
        utf8.encode(planner.export()),
        mimeType: 'application/json',
        name: 'backup.json',
      ).saveTo(location.path);
      notice('Backup exported.');
    } catch (error) {
      notice('Could not export: $error');
    }
  }

  Future<void> importBackup() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'JSON backup', extensions: ['json']),
        ],
      );
      if (file == null) return;
      if (await file.length() > 20 * 1024 * 1024) {
        throw const FormatException(
          'This backup is too large (maximum 20 MB).',
        );
      }
      final candidate = Planner.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
      candidate.validate();
      if (!await confirm(
        'Restore this backup?',
        '${candidate.routines.length} routines, ${candidate.tasks.length} tasks, and ${candidate.adherence.length} outcomes will replace the current data. Export your current data first if you want to keep it.',
        'Restore',
      )) {
        return;
      }
      if (await commit((p) => p.replace(candidate))) notice('Backup restored.');
    } catch (error) {
      notice('Could not restore: $error');
    }
  }

  Future<void> loadDemo() async {
    await commit((p) {
      final w = monday(DateTime.now());
      for (final (title, days, start, end) in [
        ('Morning reset', [1, 2, 3, 4, 5], 480, 510),
        ('Move & recharge', [1, 3, 5], 1020, 1080),
        ('A chapter a day', [2, 4, 6], 1200, 1230),
      ]) {
        p.routines.add(
          Routine(
            id: newId(),
            title: title,
            createdWeek: w,
            slots: days
                .map(
                  (d) => Slot(
                    id: newId(),
                    revisions: [
                      Revision(from: w, weekday: d, start: start, end: end),
                    ],
                  ),
                )
                .toList(),
          ),
        );
      }
      p.routines.add(
        Routine(id: newId(), title: 'Get outside', target: 3, createdWeek: w),
      );
      for (final title in [
        'Plan meals for the week',
        'Call someone you miss',
        'Make space for a creative project',
      ]) {
        p.tasks.add(
          WeeklyTask(
            id: newId(),
            title: title,
            created: DateTime.now(),
            originalWeek: w,
          ),
        );
      }
      final list = p.items(w);
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        if (item.date.isBefore(day(DateTime.now()))) {
          p.mark(item, i % 4 == 0 ? Outcome.partial : Outcome.complete);
        }
      }
    });
    if (mounted) {
      setState(() => page = 0);
      today();
    }
  }
}

class AtmospherePainter extends CustomPainter {
  AtmospherePainter(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? violet : Colors.white).withValues(
        alpha: dark ? .09 : .65,
      );
    if (dark) {
      for (var i = 0; i < 5; i++) {
        final x = size.width - 50 - i * 65;
        final path = Path()
          ..moveTo(x, size.height)
          ..lineTo(x - 35, 70 + i * 7)
          ..lineTo(x - 10, 12 + i * 9)
          ..lineTo(x + 25, 50 + i * 8)
          ..lineTo(x + 45, size.height)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawLine(
          Offset(x - 10, 12 + i * 9),
          Offset(x + 5, size.height),
          Paint()
            ..color = violet.withValues(alpha: .12)
            ..strokeWidth = 1,
        );
      }
    } else {
      for (var i = 0; i < 3; i++) {
        final x = size.width - 70 - i * 100, y = 55.0 + i * 30;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 50, y, 135, 40),
            const Radius.circular(30),
          ),
          paint,
        );
        canvas.drawCircle(Offset(x, y), 31, paint);
        canvas.drawCircle(Offset(x + 35, y + 2), 23, paint);
      }
    }
  }

  @override
  bool shouldRepaint(AtmospherePainter old) => old.dark != dark;
}
