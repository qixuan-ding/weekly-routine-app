# Weekly Routine App

Status: Initial specification; remaining questions are listed below.
Updated: November 8, 2026

## Purpose

A locally run app for planning a week, managing each day's schedule, completing weekly tasks, and privately tracking routine accountability. Support Windows, macOS, iOS, and Android with a shared codebase.

The app is free to users and fully usable offline without an account. Device sync is an optional feature initially restricted to the owner and explicitly approved testers.

## Confirmed design decisions

- The week starts on Monday.
- Day items have custom start and end times rather than fixed-duration slots.
- Scheduled items can be dragged to reschedule them.
- Overlapping scheduled items are disallowed. Adjacent items may share a boundary (for example, one ends at 10:00 and the next starts at 10:00).
- Dragging a weekly routine changes the selected occurrence and its schedule for all future weeks; earlier occurrences and their history remain unchanged.
- Support both fixed weekly routines and flexible weekly frequency targets. The primary workflow repeats routines at the same weekday and time every week until changed.
- The final accountability score is a time-based percentage: time following the routine divided by time following plus time not following the routine, multiplied by 100.
- Record routine outcomes with three simple controls: checkmark (100%), cross (0%), and a distinct partial/incomplete symbol (50%). The exact partial symbol is not yet chosen.
- Only scheduled routine time contributes to accountability; time without a routine is excluded.
- Unmarked routine occurrences remain unscored until marked, even after their scheduled time passes. Exclude their duration from both the numerator and denominator.
- Weekly frequency target progress is also available and remains separate from the time-based accountability score.
- Accountability is private; sharing with an accountability partner is outside the initial scope.
- Unfinished weekly tasks remain open and carry over into the next week. They are not automatically marked complete or deleted.
- Include a light/dark theme toggle: white/light blue with clouds in light mode, and black/purple with subtle obsidian crystals or edges in dark mode.
- Develop and test macOS first, while retaining the shared architecture for Windows, iOS, and Android.

## Recommended technology stack

The previously recommended stack still fits these requirements. Calendar views, drag interactions, and accountability calculations are application features; they do not require a different framework or a server for offline use.

| Layer | Technology | Responsibility |
| --- | --- | --- |
| App interface | Flutter | Responsive weekly and daily views across desktop and mobile |
| App language | Dart | Scheduling, recurring routines, task management, and tracking calculations |
| Local database | SQLite | Durable storage on each device |
| Database access | Drift | Typed queries, schema migrations, and reactive local data access |
| Optional reminders | Local notifications, if included | Schedule reminders on each device without a server |
| Backup and restore | Versioned JSON export/import | Manual backups and transfers for offline users |
| Optional shared backend | Supabase PostgreSQL | Shared data for approved sync accounts |
| Optional authentication | Supabase Auth | Sign-in for approved sync users |
| Optional sync engine | PowerSync | Exchange changes between local SQLite and the backend |

### Implementation considerations

- Choose one supported SQLite integration for Drift and PowerSync before implementation; do not create two independent local copies of the app's data. Validate migrations, queued writes, and offline-to-synced activation with a small integration prototype.
- Keep calendar and tracking logic separate from hosting and authentication so offline use does not depend on network availability.
- Use responsive layouts: desktop can show a seven-column calendar, while mobile needs readable access to all seven days through a compact overview or horizontal navigation.
- iOS builds require macOS and Apple's development tools; Windows builds require Windows tooling. Each platform needs testing.
- Notification scheduling and background sync capabilities vary by operating system. Do not promise immediate sync while an app is closed.

### Costs and distribution

- Flutter, Dart, SQLite, and Drift have no required licensing subscription for this app.
- Offline users need no hosted account or sync connection.
- Approved testers can use hosted free tiers while usage stays within their limits. Free hosted projects can be suspended for inactivity.
- Hosting may require paid plans as usage grows. Free to users does not guarantee zero operating cost.
- Public app-store distribution can introduce developer account fees independently of hosting.
- Exact plan prices should be checked again before deployment.

## Functionality

### 1. Weekly overview

- Show the selected week from Monday through Sunday.
- Show scheduled items, routine occurrences, and completion status for each day.
- Include weekly tasks and progress toward weekly routine targets in the weekly overview.
- Navigate to previous/next weeks and return to the current week.
- Open a day or an item to see and edit its details.
- Keep unscheduled weekly tasks visible alongside the calendar rather than assigning artificial times.

### 2. Day view with a time grid

- Show the selected day's schedule against a time grid.
- Position items using custom start and end times; grid markings are visual guides, not mandatory item durations.
- Add, edit, and remove items from this view.
- Drag items to change their scheduled time. For weekly routines, apply the move to the selected occurrence and all future weeks.
- Reject additions, edits, and drag destinations that overlap another scheduled item; explain the conflict and preserve the previous valid schedule.
- Validate recurring moves against affected future schedules before saving. Proposed behavior: reject the entire move if it creates a conflict rather than partially updating the series.
- Allow setting routine outcomes to complete (checkmark, 100%), not completed (cross, 0%), or partial/incomplete (distinct symbol, 50%), and correcting or clearing the selection.
- Allow completing and reopening tasks; routine scoring states are separate from a task's open/completed state.
- Clearly distinguish removing a scheduled placement from deleting the underlying task or recurring routine.

Proposed item fields: title, optional notes, date, start time, end time, item type, and completion status. Categories, colors, reminders, and drag-to-resize are pending decisions.

### 3. Weekly tasks

- Create, edit, complete, reopen, and delete tasks associated with weekly planning.
- Support tasks without a scheduled time.
- Allow placing a weekly task into the day schedule without creating a second independent task.
- Carry unfinished tasks forward as the same task, preserving their original creation date and avoiding duplicates.
- Preserve completed task history.
- Keep a carried-over task's previous schedule as history; do not invent a new day/time in the next week without a user action.

The exact presentation of carried-over tasks when viewing historical weeks remains a design question.

### 4. Recurring routines

- Define routines separately from individual scheduled occurrences.
- Primary workflow: schedule routines on selected weekdays at specific start/end times and repeat those times every week indefinitely until changed or ended.
- Also support flexible weekly frequency targets, such as exercise three times per week, without requiring fixed time placements.
- Record completions against specific occurrences or completion events, not a single completion flag on the routine.
- Distinguish editing one occurrence from changing the recurring routine.
- Dragging a weekly routine always updates that occurrence and all future weekly repetitions, with the change effective from the selected occurrence. Do not require a scope choice for this drag action.
- Enforce the no-overlap rule for recurring schedules as well as individual items; use recurrence rules to check future conflicts rather than materializing an infinite series.
- Preserve historical completion data when future routine settings change.

Single-occurrence exceptions and the scope of non-drag edits still need confirmation, as does whether a routine can combine a fixed schedule with a frequency target. Advanced recurrence patterns beyond weekly repetition are not yet required.

### 5. Private weekly accountability

- Show a time-based routine adherence percentage and separate progress against weekly frequency targets.
- Provide a per-routine breakdown and week-to-week history.
- Use three outcome controls rather than minute entry, sliders, or timers: checkmark = 100%, cross = 0%, partial/incomplete symbol = 50%.
- Support correcting or clearing an outcome and recording it later. An unrecorded outcome remains unscored indefinitely; it does not automatically become a cross. Clearing an outcome removes that occurrence's contribution from the score.
- Keep accountability personal; no public profiles, leaderboards, or social sharing in the initial scope.

Confirmed accountability formula:

```text
Accountability (%) = 100 × F / (F + N)

F = duration following the routine
N = duration not following the routine

For each scored occurrence with scheduled duration D and outcome weight w:
  w = 1 for checkmark, 0 for cross, or 0.5 for partial/incomplete
  F = D × w
  N = D × (1 − w)

Weekly accountability (%) = 100 × sum(D × w) / sum(D)
  over eligible scored routine occurrences
```

This expresses the requested ratio of percentages using scheduled durations measured against the same time base. For example, a 60-minute routine marked complete plus a 60-minute routine marked partial yields 90 followed minutes and 30 not-followed minutes, or 75% accountability. Weight by scheduled duration, not by the number of routines or an unweighted average of their percentages.

Rules and open boundaries:

- Derive followed and not-followed durations from the selected outcome and scheduled duration; do not require users to record exact minutes.
- Exclude unmarked occurrences from both followed and not-followed durations, regardless of how long ago they occurred. Only explicitly marked outcomes contribute to the score.
- Exclude all time without a scheduled routine, including gaps and unscheduled weekly tasks. Untimed weekly frequency targets have separate progress and do not contribute minutes to this score.
- Overlapping scheduled items are prohibited, so valid routine schedules do not double-count shared time.
- Define whether following a routine later than scheduled earns adherence credit.
- Future occurrences, skipped/cancelled occurrences, and midweek schedule changes need explicit scoring rules.
- If F + N is zero, show "No tracked time" rather than dividing by zero.
- Proposed weekly target progress: qualifying completion count divided by the target, capped at 100%, with extra completions shown separately. Whether a partial completion contributes half a completion toward a frequency target remains undecided.
- Show weekly task completion separately from routine accountability; unfinished tasks may carry over, while historical adherence stays attached to its original week.

### 6. Visual style and themes

- Provide an explicit toggle between light and dark mode.
- Light mode: white and light-blue surfaces with cloud visuals and a light, airy feel.
- Dark mode: black and purple surfaces with subtle obsidian crystal details or angular edges.
- Keep decorative visuals behind or around functional content so times, item titles, conflict messages, and accountability remain readable.
- Apply the selected theme consistently across weekly/day views, forms, tracking, and settings.
- Proposed default behavior: remember the user's selected theme locally between launches. Following the device theme automatically is an optional decision.
- Maintain readable contrast, visible focus indicators, and status indicators that do not rely on color alone in either theme.

## Offline access and restricted sync

### Offline users

- No sign-in required.
- All planning, completion tracking, and history work locally.
- Restarting the app preserves saved data.
- Export/import provides a manual backup path.
- No automatic cross-device synchronization.

### Approved sync users

- Sign in and activate sync only when their account has server-side approval.
- Upload existing local data through an explicit activation flow that handles an account already containing data.
- Save changes locally immediately and queue them while offline.
- Exchange queued changes when connectivity and app execution permit.
- Sync only the authenticated user's authorized records.
- Enforce approval for backend writes and sync reads; hiding a switch in the interface is insufficient.
- Revoking access prevents future exchanges while retaining locally stored data. Already downloaded data cannot be remotely withdrawn by simply revoking sync access.
- Define account switching and sign-out behavior before implementation to avoid mixing two accounts' local data.

### Sync correctness

- Use stable unique identifiers and retry-safe writes to prevent duplicate tasks or completions.
- Maintain version information and deletion records so older devices cannot silently recreate deleted items.
- Define deterministic conflict rules for simultaneous edits and completion changes.
- Treat sync as separate from backup because deletions and mistakes can propagate.
- Keep routine definitions, dated occurrences, and completion events distinct to preserve history.

## Proposed data model

| Record | Purpose |
| --- | --- |
| Routine | Name, repeat settings, weekly target, and active dates |
| Routine occurrence | A dated instance with any schedule or single-occurrence override |
| Completion | A dated completion linked to a routine and optionally its occurrence |
| Adherence record | An occurrence outcome (complete, not completed, partial/incomplete, or unrecorded) and the historical scheduled duration used to derive 100%/0%/50% time-weighted credit |
| Task | Weekly work item with open/completed state and original planning week |
| Schedule entry | Start/end time linked to a task, routine occurrence, or standalone calendar item |
| Preferences | Light/dark theme selection, week display, time format, time-zone policy, and optional reminder settings |
| Sync access | Server-managed account approval and revocation |

Use stable local identifiers even before sign-in. Sync-enabled records also need ownership, change tracking, and deletion metadata. Preserve historical settings where needed for accurate past reports.

## Recommended delivery order

1. Validate the local database and future sync integration with a small prototype.
2. Build offline routine/task storage, weekly overview, and editable day schedule for macOS first, including overlap prevention and recurring drag updates.
3. Add task carryover, recurring occurrences, and private accountability history.
4. Add backup/restore and verify data persistence and migrations.
5. Enable restricted sync for the owner and approved testers.
6. Add optional reminders and other confirmed enhancements.

Validate on macOS: recurrence across week boundaries and daylight-saving changes, rejection of individual and recurring overlaps, adjacent item boundaries, recurring drag changes preserving earlier history, duration-weighted 100%/0%/50% accountability excluding unscheduled time, empty/unrecorded data, duplicate-free task carryover, historical tracking accuracy, theme readability, backup restoration, and sync permission enforcement before release.

## Remaining design and functionality questions

1. Should future routine occurrences be markable before their scheduled time? Should skipped/cancelled occurrences be excluded or explicitly marked as not completed? Unmarked occurrences are already defined to remain unscored indefinitely.
2. Does completing a routine later than scheduled earn the same credit?
3. Which symbol should represent partial/incomplete: a half-filled circle, a dash, or another symbol? Use accessible text labels regardless of the symbol.
4. For flexible weekly targets, can completions be logged at any time, and does a partial completion count as half toward the target? Can one routine combine a fixed schedule and a frequency target?
5. Should non-drag edits and deletions affect one occurrence or future occurrences? Dragging is already defined to affect the selected occurrence and future weeks.
6. When opening an old week, should carried-over tasks appear as they stood at that week's end or show their current state?
7. Do you need standalone calendar events, subtasks, priorities, categories/colors, notes, or duration estimates in the first version?
8. Should reminders be included initially? If so, which items need them and how far in advance?
9. What hours should the day view show by default? Should dragging snap to a time interval, and should resizing change duration?
10. Do overnight items need support? When traveling, should routines stay at the same local clock time or keep their original time zone?
11. Should themes optionally follow the device setting, and should the decorative clouds/crystals be static or subtly animated?
12. How should sync testers be approved: an owner-maintained email allowlist or an invitation flow?

## Reference documentation

- [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms)
- [Flutter platform build setup](https://docs.flutter.dev/platform-integration)
- [Drift supported platforms](https://drift.simonbinder.eu/platforms/)
- [PowerSync Flutter SDK](https://pub.dev/packages/powersync)
- [Supabase Flutter setup](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Supabase and PowerSync integration](https://supabase.com/partners/catalog/powersync)
- [Local notifications](https://pub.dev/packages/flutter_local_notifications)
- [Supabase pricing](https://supabase.com/pricing)
- [PowerSync pricing](https://powersync.com/pricing)
