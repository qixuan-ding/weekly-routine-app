import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/planner.dart';

class EditorResult {
  EditorResult({
    required this.title,
    required this.notes,
    required this.kind,
    required this.date,
    required this.start,
    required this.end,
    required this.days,
    required this.target,
  });
  final String title, notes, kind;
  final DateTime date;
  final int start, end, target;
  final Set<int> days;
}

class ScheduleEditor extends StatefulWidget {
  const ScheduleEditor({
    super.key,
    required this.date,
    required this.minute,
    this.item,
    this.task,
    this.initialKind,
    this.editingTask = false,
    this.routineMetadata = false,
    this.initialTarget,
  });
  final DateTime date;
  final int minute;
  final int? initialTarget;
  final CalendarItem? item;
  final WeeklyTask? task;
  final String? initialKind;
  final bool editingTask, routineMetadata;
  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<ScheduleEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(
    text: widget.item?.title ?? widget.task?.title ?? '',
  );
  late final notes = TextEditingController(
    text: widget.item?.notes ?? widget.task?.notes ?? '',
  );
  late final start = TextEditingController(
    text: clock(widget.item?.start ?? widget.minute),
  );
  late final end = TextEditingController(
    text: clock(widget.item?.end ?? (widget.minute + 60).clamp(1, 1440)),
  );
  late final target = TextEditingController(
    text: (widget.initialTarget ?? 3).toString(),
  );
  late String kind = widget.item?.isRoutine == true
      ? 'routine'
      : widget.initialKind ?? 'event';
  late DateTime date = widget.item?.date ?? widget.date;
  late Set<int> days = {date.weekday};
  bool get timed => kind == 'routine' || kind == 'event';
  bool get locked =>
      widget.item != null || widget.task != null || widget.editingTask;
  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    start.dispose();
    end.dispose();
    target.dispose();
    super.dispose();
  }

  int? parse(String? text) {
    final parts = (text ?? '').split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (h == null ||
        m == null ||
        h < 0 ||
        h > 24 ||
        m < 0 ||
        m > 59 ||
        (h == 24 && m != 0)) {
      return null;
    }
    return h * 60 + m;
  }

  void save() {
    if (!form.currentState!.validate()) return;
    if (kind == 'routine' && days.isEmpty) {
      setState(() => dayError = true);
      return;
    }
    Navigator.pop(
      context,
      EditorResult(
        title: title.text.trim(),
        notes: notes.text.trim(),
        kind: kind,
        date: date,
        start: parse(start.text) ?? 0,
        end: parse(end.text) ?? 60,
        days: days,
        target: int.tryParse(target.text) ?? 3,
      ),
    );
  }

  bool dayError = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.routineMetadata
          ? 'Edit routine'
          : widget.editingTask
          ? 'Edit weekly task'
          : widget.item != null
          ? 'Edit ${widget.item!.isRoutine ? 'weekly routine' : 'schedule'}'
          : widget.task != null
          ? 'Place task in schedule'
          : 'Make a little space',
    ),
    content: SizedBox(
      width: 510,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!locked) ...[
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    for (final (value, label, icon) in [
                      ('event', 'Event', Icons.event_outlined),
                      ('routine', 'Routine', Icons.autorenew),
                      ('task', 'Weekly task', Icons.checklist),
                      ('target', 'Target', Icons.flag_outlined),
                    ])
                      ChoiceChip(
                        avatar: Icon(icon, size: 16),
                        label: Text(
                          label,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: kind == value,
                        onSelected: (_) => setState(() => kind = value),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
              ],
              TextFormField(
                controller: title,
                autofocus: true,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What would you like to make time for?',
                  counterText: '',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Give this item a title.'
                    : null,
                onFieldSubmitted: (_) => save(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notes,
                minLines: 2,
                maxLines: 4,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  counterText: '',
                ),
              ),
              if (widget.routineMetadata && widget.initialTarget != null) ...[
                const SizedBox(height: 18),
                TextFormField(
                  controller: target,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Completions per week',
                    helperText: 'Applies from ${dateKey(monday(date))} onward.',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 1 || n > 99
                        ? 'Choose a target from 1 to 99.'
                        : null;
                  },
                ),
              ],
              if (!widget.editingTask) ...[
                const SizedBox(height: 18),
                if (kind != 'task')
                  OutlinedButton.icon(
                    onPressed: () async {
                      final chosen = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: widget.item?.isRoutine == true
                            ? monday(widget.item!.date)
                            : DateTime(2000),
                        lastDate: widget.item?.isRoutine == true
                            ? monday(widget.item!.date)
                                  .add(const Duration(days: 6))
                            : DateTime(2100),
                      );
                      if (chosen != null) {
                        setState(() {
                          date = day(chosen);
                          if (widget.item?.isRoutine == true) {
                            days = {date.weekday};
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    label: Text(
                      widget.item?.isRoutine == true
                          ? DateFormat('EEEE, MMM d, y').format(date)
                          : '${kind == 'routine' || kind == 'target' ? 'Starts week of ' : ''}${DateFormat('EEE, MMM d, y').format(kind == 'routine' || kind == 'target' ? monday(date) : date)}',
                    ),
                  ),
                if (timed) ...[
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: start,
                          decoration: const InputDecoration(
                            labelText: 'Start time',
                            hintText: '09:00',
                            helperText: '24-hour time · HH:mm',
                          ),
                          validator: (v) {
                            final n = parse(v);
                            return n == null || n >= 1440
                                ? 'Use 00:00–23:59.'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: end,
                          decoration: const InputDecoration(
                            labelText: 'End time',
                            hintText: '10:00',
                          ),
                          validator: (v) {
                            final n = parse(v), s = parse(start.text);
                            if (n == null) return 'Use HH:mm (up to 24:00).';
                            if (s != null && n <= s) {
                              return 'Must be after the start.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                if (kind == 'routine' && widget.item == null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Repeat every week on',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 5,
                    runSpacing: 7,
                    children: List.generate(
                      7,
                      (i) => FilterChip(
                        label: Text(
                          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: days.contains(i + 1),
                        showCheckmark: false,
                        onSelected: (v) => setState(() {
                          if (v) {
                            days.add(i + 1);
                          } else {
                            days.remove(i + 1);
                          }
                          dayError = false;
                        }),
                      ),
                    ),
                  ),
                  if (dayError)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Choose at least one day.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
                if (kind == 'target') ...[
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: target,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Completions per week',
                      helperText:
                          'Log full completions with + in Weekly targets.',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 99
                          ? 'Choose a target from 1 to 99.'
                          : null;
                    },
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  widget.item?.isRoutine == true
                      ? 'Time changes apply to this occurrence and all future weeks. Name and notes update the routine. Earlier scheduled times and recorded durations are preserved.'
                      : kind == 'task'
                      ? 'Unscheduled tasks stay in your weekly list and carry forward until completed.'
                      : kind == 'routine'
                      ? 'Repeats at these local clock times until changed. Conflicting schedules are rejected, including future weeks.'
                      : kind == 'target'
                      ? 'A flexible, untimed goal. Completion counts are separate from time-based accountability.'
                      : 'Choose any start and end time within one day. Adjacent items can share a boundary.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: save,
        child: Text(
          widget.item != null || widget.editingTask
              ? 'Save changes'
              : widget.task != null
              ? 'Place in schedule'
              : 'Add to my week',
        ),
      ),
    ],
  );
}
