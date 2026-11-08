import 'dart:convert';
import 'dart:math';

/// Dates are civil calendar dates, represented in UTC to avoid DST arithmetic.
DateTime day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
DateTime civilDate(String text) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    throw const FormatException('Invalid calendar date.');
  }
  final parsed = day(DateTime.parse(text));
  if (dateKey(parsed) != text) {
    throw const FormatException('Invalid calendar date.');
  }
  return parsed;
}

DateTime monday(DateTime d) => day(d).subtract(Duration(days: d.weekday - 1));
String dateKey(DateTime d) => day(d).toIso8601String().substring(0, 10);
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(1 << 32).toRadixString(36)}';
String clock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
bool overlaps(int a, int b, int c, int d) => a < d && c < b;

enum Outcome { complete, partial, missed }

extension OutcomeValue on Outcome {
  double get weight => switch (this) {
    Outcome.complete => 1,
    Outcome.partial => .5,
    Outcome.missed => 0,
  };
  String get symbol => switch (this) {
    Outcome.complete => '✓',
    Outcome.partial => '◐',
    Outcome.missed => '×',
  };
  String get label => switch (this) {
    Outcome.complete => 'Complete',
    Outcome.partial => 'Partial',
    Outcome.missed => 'Not completed',
  };
}

class Revision {
  Revision({
    required this.from,
    required this.weekday,
    required this.start,
    required this.end,
  });
  final DateTime from;
  final int weekday, start, end;
  Map<String, dynamic> toJson() => {
    'from': dateKey(from),
    'weekday': weekday,
    'start': start,
    'end': end,
  };
  factory Revision.fromJson(Map<String, dynamic> j) => Revision(
    from: civilDate(j['from']),
    weekday: j['weekday'],
    start: j['start'],
    end: j['end'],
  );
}

class Slot {
  Slot({required this.id, required this.revisions, this.until});
  final String id;
  final List<Revision> revisions;
  DateTime? until;
  Revision? at(DateTime week) {
    if (until != null && !week.isBefore(until!)) return null;
    final valid = revisions.where((r) => !r.from.isAfter(week)).toList()
      ..sort((a, b) => a.from.compareTo(b.from));
    return valid.isEmpty ? null : valid.last;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'until': until == null ? null : dateKey(until!),
    'revisions': revisions.map((r) => r.toJson()).toList(),
  };
  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
    id: j['id'],
    until: j['until'] == null ? null : civilDate(j['until']),
    revisions: (j['revisions'] as List)
        .map((r) => Revision.fromJson(r))
        .toList(),
  );
}

class Routine {
  Routine({
    required this.id,
    required this.title,
    this.notes = '',
    this.target = 0,
    required this.createdWeek,
    List<Slot>? slots,
  }) : slots = slots ?? [];
  final String id;
  String title, notes;
  int target;
  final Map<String, int> targetChanges = {};
  int targetAt(DateTime week) {
    final applicable =
        targetChanges.keys
            .where((key) => !civilDate(key).isAfter(monday(week)))
            .toList()
          ..sort();
    return applicable.isEmpty ? target : targetChanges[applicable.last]!;
  }

  void changeTarget(DateTime week, int value) {
    targetChanges.removeWhere(
      (key, _) => !civilDate(key).isBefore(monday(week)),
    );
    targetChanges[dateKey(monday(week))] = value;
  }

  final DateTime createdWeek;
  final List<Slot> slots;
  DateTime? archivedWeek;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'target': target,
    'targetChanges': targetChanges,
    'createdWeek': dateKey(createdWeek),
    'archivedWeek': archivedWeek == null ? null : dateKey(archivedWeek!),
    'slots': slots.map((s) => s.toJson()).toList(),
  };
  factory Routine.fromJson(Map<String, dynamic> j) =>
      Routine(
          id: j['id'],
          title: j['title'],
          notes: j['notes'],
          target: j['target'],
          createdWeek: civilDate(j['createdWeek']),
          slots: (j['slots'] as List).map((s) => Slot.fromJson(s)).toList(),
        )
        ..targetChanges.addAll(Map<String, int>.from(j['targetChanges'] ?? {}))
        ..archivedWeek = j['archivedWeek'] == null
            ? null
            : civilDate(j['archivedWeek']);
}

class TaskChange {
  TaskChange(this.at, this.done);
  final DateTime at;
  final bool done;
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'done': done};
  factory TaskChange.fromJson(Map<String, dynamic> j) =>
      TaskChange(DateTime.parse(j['at']), j['done']);
}

class WeeklyTask {
  WeeklyTask({
    required this.id,
    required this.title,
    required this.created,
    required this.originalWeek,
    this.notes = '',
    List<TaskChange>? changes,
  }) : changes = changes ?? [];
  final String id;
  String title, notes;
  final DateTime created, originalWeek;
  final List<TaskChange> changes;
  bool doneAt(DateTime date) {
    final eligible =
        changes.where((e) => !day(e.at.toLocal()).isAfter(day(date))).toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    return eligible.isNotEmpty && eligible.last.done;
  }

  bool get done => changes.isNotEmpty && changes.last.done;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'created': created.toIso8601String(),
    'originalWeek': dateKey(originalWeek),
    'changes': changes.map((c) => c.toJson()).toList(),
  };
  factory WeeklyTask.fromJson(Map<String, dynamic> j) => WeeklyTask(
    id: j['id'],
    title: j['title'],
    notes: j['notes'],
    created: DateTime.parse(j['created']),
    originalWeek: civilDate(j['originalWeek']),
    changes: (j['changes'] as List).map((c) => TaskChange.fromJson(c)).toList(),
  );
}

class Placement {
  Placement({
    required this.id,
    required this.title,
    required this.date,
    required this.start,
    required this.end,
    this.taskId,
    this.notes = '',
  });
  final String id;
  String title, notes;
  DateTime date;
  int start, end;
  String? taskId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': dateKey(date),
    'start': start,
    'end': end,
    'taskId': taskId,
    'notes': notes,
  };
  factory Placement.fromJson(Map<String, dynamic> j) => Placement(
    id: j['id'],
    title: j['title'],
    date: civilDate(j['date']),
    start: j['start'],
    end: j['end'],
    taskId: j['taskId'],
    notes: j['notes'],
  );
}

class Adherence {
  Adherence({
    required this.id,
    required this.routineId,
    required this.title,
    required this.date,
    required this.duration,
    required this.outcome,
  });
  final String id, routineId, title;
  final DateTime date;
  final int duration;
  final Outcome outcome;
  Map<String, dynamic> toJson() => {
    'id': id,
    'routineId': routineId,
    'title': title,
    'date': dateKey(date),
    'duration': duration,
    'outcome': outcome.name,
  };
  factory Adherence.fromJson(Map<String, dynamic> j) => Adherence(
    id: j['id'],
    routineId: j['routineId'],
    title: j['title'],
    date: civilDate(j['date']),
    duration: j['duration'],
    outcome: Outcome.values.byName(j['outcome']),
  );
}

class TargetEvent {
  TargetEvent({required this.id, required this.routineId, required this.date});
  final String id, routineId;
  final DateTime date;
  Map<String, dynamic> toJson() => {
    'id': id,
    'routineId': routineId,
    'date': dateKey(date),
  };
  factory TargetEvent.fromJson(Map<String, dynamic> j) => TargetEvent(
    id: j['id'],
    routineId: j['routineId'],
    date: civilDate(j['date']),
  );
}

class CalendarItem {
  CalendarItem({
    required this.id,
    required this.title,
    required this.notes,
    required this.date,
    required this.start,
    required this.end,
    this.routineId,
    this.slotId,
    this.taskId,
  });
  final String id, title, notes;
  final DateTime date;
  final int start, end;
  final String? routineId, slotId, taskId;
  bool get isRoutine => routineId != null;
}

class Score {
  Score(Iterable<Adherence> records)
    : total = records.fold(0, (n, r) => n + r.duration),
      followed = records.fold(0, (n, r) => n + r.duration * r.outcome.weight);
  final int total;
  final double followed;
  double? get percent => total == 0 ? null : 100 * followed / total;
}

class Planner {
  final List<Routine> routines = [];
  final List<WeeklyTask> tasks = [];
  final List<Placement> placements = [];
  final List<Adherence> adherence = [];
  final List<TargetEvent> events = [];
  final Set<String> excluded = {};
  bool dark = false;
  Iterable<Adherence> records(DateTime week) =>
      adherence.where((a) => monday(a.date) == monday(week));
  Score score(DateTime week) => Score(records(week));
  List<WeeklyTask> tasksFor(DateTime week) => tasks
      .where(
        (t) =>
            !t.originalWeek.isAfter(week) &&
            (t.originalWeek == week ||
                !t.doneAt(week.subtract(const Duration(days: 1))) ||
                t.changes.any((c) => monday(c.at.toLocal()) == week)),
      )
      .toList();
  List<CalendarItem> items(DateTime week) {
    week = monday(week);
    final result = <CalendarItem>[];
    for (final r in routines) {
      for (final s in r.slots) {
        final rev = s.at(week), id = '${s.id}:${dateKey(week)}';
        if (rev == null || excluded.contains(id)) continue;
        result.add(
          CalendarItem(
            id: id,
            title: r.title,
            notes: r.notes,
            date: week.add(Duration(days: rev.weekday - 1)),
            start: rev.start,
            end: rev.end,
            routineId: r.id,
            slotId: s.id,
          ),
        );
      }
    }
    for (final p in placements.where((p) => monday(p.date) == week)) {
      final task = tasks.where((t) => t.id == p.taskId).firstOrNull;
      result.add(
        CalendarItem(
          id: p.id,
          title: task?.title ?? p.title,
          notes: task?.notes ?? p.notes,
          date: p.date,
          start: p.start,
          end: p.end,
          taskId: p.taskId,
        ),
      );
    }
    result.sort(
      (a, b) => a.date == b.date
          ? a.start.compareTo(b.start)
          : a.date.compareTo(b.date),
    );
    return result;
  }

  void mark(CalendarItem item, Outcome? outcome, {DateTime? now}) {
    if (!item.isRoutine) {
      throw const FormatException(
        'Only routines receive accountability outcomes.',
      );
    }
    final local = now ?? DateTime.now();
    if (item.date.isAfter(day(local)) ||
        (item.date == day(local) &&
            item.start > local.hour * 60 + local.minute)) {
      throw const FormatException(
        'Record outcomes once the routine has started.',
      );
    }
    final previous = adherence.where((a) => a.id == item.id).firstOrNull;
    adherence.removeWhere((a) => a.id == item.id);
    if (outcome != null) {
      adherence.add(
        Adherence(
          id: item.id,
          routineId: item.routineId!,
          title: previous?.title ?? item.title,
          date: previous?.date ?? item.date,
          duration: previous?.duration ?? item.end - item.start,
          outcome: outcome,
        ),
      );
    }
  }

  int targetCount(Routine r, DateTime week) =>
      events
          .where((e) => e.routineId == r.id && monday(e.date) == week)
          .length +
      records(week)
          .where((a) => a.routineId == r.id && a.outcome == Outcome.complete)
          .length;
  void move(CalendarItem item, DateTime date, int start) {
    final end = start + item.end - item.start;
    final draft = Planner.fromJson(toJson());
    if (item.isRoutine) {
      final slot = draft.routines
          .firstWhere((r) => r.id == item.routineId)
          .slots
          .firstWhere((s) => s.id == item.slotId);
      final week = monday(item.date);
      if (monday(date) != week) {
        throw const FormatException(
          'Move a routine within its week. Use week navigation to change a later occurrence.',
        );
      }
      slot.revisions.removeWhere((r) => !r.from.isBefore(week));
      slot.revisions.add(
        Revision(from: week, weekday: date.weekday, start: start, end: end),
      );
    } else {
      final p = draft.placements.firstWhere((p) => p.id == item.id);
      p.date = day(date);
      p.start = start;
      p.end = end;
    }
    draft.validate();
    replace(draft);
  }

  void validate() {
    final ids = <String>{};
    void unique(String id) {
      if (id.isEmpty || !ids.add(id)) {
        throw const FormatException('Duplicate or empty record ID.');
      }
    }

    void title(String t) {
      if (t.trim().isEmpty || t.length > 200) {
        throw const FormatException('Use a title of 1–200 characters.');
      }
    }

    void time(int start, int end) {
      if (start < 0 || end > 1440 || end <= start) {
        throw const FormatException(
          'End time must be after start time, within the same day.',
        );
      }
    }

    for (final t in tasks) {
      unique(t.id);
      title(t.title);
      if (monday(t.originalWeek) != t.originalWeek) {
        throw const FormatException('Invalid task week.');
      }
    }
    for (final r in routines) {
      unique(r.id);
      title(r.title);
      if (r.target < 0 || r.target > 99) {
        throw const FormatException('Weekly targets must be between 1 and 99.');
      }
      if (r.createdWeek != monday(r.createdWeek) ||
          (r.archivedWeek != null &&
              r.archivedWeek != monday(r.archivedWeek!))) {
        throw const FormatException('Invalid routine week.');
      }
      for (final change in r.targetChanges.entries) {
        if (civilDate(change.key) != monday(civilDate(change.key)) ||
            change.value < 1 ||
            change.value > 99) {
          throw const FormatException('Invalid weekly target change.');
        }
      }
      for (final s in r.slots) {
        unique(s.id);
        if (s.revisions.isEmpty ||
            (s.until != null && s.until != monday(s.until!))) {
          throw const FormatException('Invalid routine schedule.');
        }
        final weeks = <String>{};
        for (final v in s.revisions) {
          time(v.start, v.end);
          if (v.weekday < 1 ||
              v.weekday > 7 ||
              v.from != monday(v.from) ||
              !weeks.add(dateKey(v.from))) {
            throw const FormatException('Invalid weekly recurrence.');
          }
        }
      }
    }
    for (final p in placements) {
      unique(p.id);
      title(p.title);
      time(p.start, p.end);
      if (p.taskId != null && !tasks.any((t) => t.id == p.taskId)) {
        throw const FormatException('A placement refers to a missing task.');
      }
    }
    for (final a in adherence) {
      if (a.duration <= 0 ||
          a.duration > 1440 ||
          !routines.any((r) => r.id == a.routineId)) {
        throw const FormatException('Invalid tracked duration.');
      }
    }
    if (adherence.map((a) => a.id).toSet().length != adherence.length) {
      throw const FormatException('Duplicate outcome.');
    }
    for (final e in events) {
      unique(e.id);
      if (!routines.any((r) => r.id == e.routineId)) {
        throw const FormatException(
          'A target event refers to a missing routine.',
        );
      }
    }
    // Weekly patterns only change at revision boundaries. Checking each boundary
    // plus every finite exception/placement week proves the unbounded schedule.
    final weeks = <DateTime>{};
    for (final r in routines) {
      for (final s in r.slots) {
        weeks.addAll(s.revisions.map((r) => r.from));
        if (s.until != null) weeks.add(s.until!);
      }
    }
    weeks.addAll(placements.map((p) => monday(p.date)));
    for (final key in excluded) {
      final parts = key.split(':');
      final date = civilDate(parts.last);
      if (parts.length != 2 ||
          date != monday(date) ||
          !routines.any((r) => r.slots.any((s) => s.id == parts.first))) {
        throw const FormatException('Invalid occurrence exception.');
      }
      weeks.add(monday(date));
    }
    final checks = {
      ...weeks,
      ...weeks.map((w) => w.add(const Duration(days: 7))),
    };
    for (final w in checks) {
      final list = items(w);
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final a = list[i], b = list[j];
          if (a.date == b.date && overlaps(a.start, a.end, b.start, b.end)) {
            throw FormatException(
              '“${a.title}” conflicts with “${b.title}” on ${dateKey(a.date)} at ${clock(b.start)}. Choose another time.',
            );
          }
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'dark': dark,
    'routines': routines.map((r) => r.toJson()).toList(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'placements': placements.map((p) => p.toJson()).toList(),
    'adherence': adherence.map((a) => a.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'excluded': excluded.toList(),
  };
  factory Planner.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Unsupported backup version.');
    }
    return Planner()
      ..dark = j['dark'] as bool
      ..routines.addAll((j['routines'] as List).map((r) => Routine.fromJson(r)))
      ..tasks.addAll((j['tasks'] as List).map((t) => WeeklyTask.fromJson(t)))
      ..placements.addAll(
        (j['placements'] as List).map((p) => Placement.fromJson(p)),
      )
      ..adherence.addAll(
        (j['adherence'] as List).map((a) => Adherence.fromJson(a)),
      )
      ..events.addAll((j['events'] as List).map((e) => TargetEvent.fromJson(e)))
      ..excluded.addAll((j['excluded'] as List).cast<String>());
  }
  Planner();
  void replace(Planner p) {
    dark = p.dark;
    routines
      ..clear()
      ..addAll(p.routines);
    tasks
      ..clear()
      ..addAll(p.tasks);
    placements
      ..clear()
      ..addAll(p.placements);
    adherence
      ..clear()
      ..addAll(p.adherence);
    events
      ..clear()
      ..addAll(p.events);
    excluded
      ..clear()
      ..addAll(p.excluded);
  }

  String export() => const JsonEncoder.withIndent('  ').convert(toJson());
}
