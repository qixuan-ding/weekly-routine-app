# Implementation decisions

## Delivered macOS offline scope

Weekly and daily views, exact-time events, task placements, fixed weekly routines, flexible weekly targets, no-overlap validation, recurring drag updates, task carryover, outcome controls and correction, private accountability history, light/cloud and dark/crystal themes, SQLite persistence, and versioned JSON backup/restore.

All scheduled entries are linked to their underlying task or to a routine slot. Routine occurrences are projected by civil week rather than materialized indefinitely. Slot revisions carry their effective Monday, weekday, and minute range. Occurrence identity is `slotId:weekMonday`, so moving a weekday does not detach its outcome.

Conflict validation checks every recurrence revision/start/end boundary, every finite placement or exception week, and each following week. Between these boundaries the weekly pattern is constant; checking these finite representatives covers unbounded future repetition without an arbitrary horizon. Rejected edits and drags leave the original state untouched.

Outcomes store a title and duration snapshot. Editing a routine later preserves these recorded values. Historical calendar times use slot revisions. Renaming a routine updates its displayed name across the calendar; recorded accountability titles retain their snapshots.

Task completion/reopening uses dated state changes. Historical weekly lists show state as of that week's end. Completion actions are recorded today; editing an old week does not backdate a task change. Previous task placements remain in their original week and are never duplicated into a new week. Completed tasks remain visible in their completion week and original planning week.

## Resolved open questions for this version

- Outcomes become available when the occurrence starts. Late recording earns the same credit. Nothing is automatically marked missed.
- `◐` means partial and earns 50% of the scheduled duration, with an accessible text label.
- Skipping hides one placement; it excludes unmarked time. A restore control appears below the calendar. Already recorded accountability is retained even if the placement is later skipped or its weekly time ended.
- Routine time edits and drags apply to the selected week and all following weeks; there is no scope prompt for drags. One-occurrence time overrides are not implemented. Occurrences can be skipped and restored individually.
- Future revisions on a moved slot are replaced by the new weekly time. Other weekday slots in the same routine are independent.
- Flexible targets log full, untimed completion events; partial target events are not offered. They can be logged in the current or historical week; a historical week uses its Sunday as the event date. Undo removes the latest untimed event in that week. Targets can be edited from a selected week forward, preserving earlier target values. The UI creates fixed schedules and flexible targets as separate routines.
- Tasks/events have notes. Categories, priorities, reminders, subtasks, and resize handles are outside this version.
- All 24 hours are accessible. Day view starts at 06:00. Dragging snaps to 15 minutes. Form times accept minute precision, including an end of 24:00. Overnight entries must be split at midnight.
- Calendar dates use civil-date UTC containers solely for date arithmetic, while times are local wall-clock minutes. Recurrence does not shift by an hour at DST boundaries. When traveling, the same local clock times apply.
- Theme choice is persisted. Clouds and crystals are static; there is no automatic system-theme mode.
- The week overview keeps unscheduled weekly tasks alongside the calendar. Smaller windows use a day grid and previous/next day controls to reach every day.

## Persistence and future sync boundary

A single Drift `NativeDatabase` is the durable source of truth. Typed Drift rows store versioned domain records with stable IDs; JSON is the entity payload and backup representation. Schema version 1 is the initial schema. Generated bindings are checked in. SQLite close/reopen is verified by an integration test; there is no earlier released schema to migrate.

Device sync is **not implemented or enabled**. No Supabase project, approval list, credentials, or account-switch policy was supplied. The app neither signs users in nor exchanges data. Offline behavior has no backend dependency.

Before adding sync, build the spec's integration prototype with a single PowerSync-managed SQLite connection exposed to Drift. Validate schema migration, upload activation against pre-existing remote data, queued/retried writes, deterministic edit conflicts, ownership, tombstones, and revocation. The current local-only entity replacement transaction is not a sync protocol: it needs per-entity change tracking and deletion records before any remote exchange. Do not attach a second independent database or assume stable IDs alone make this sync-ready.

Backend approval must be enforced for reads and writes through server authorization/RLS, not a client toggle. Account sign-out, switching, and local/remote activation behavior require explicit design before release of sync. These are delivery stage 5 from the spec; macOS offline stages 2–4 are implemented here.

## Platform and distribution status

macOS release compilation and application launch are verified on this Apple silicon Mac. Flutter currently builds a universal macOS binary. Windows, iOS, and Android projects share the implementation but have not been built or device-tested. macOS export/import uses native file dialogs with user-selected read/write sandbox entitlement.

The local app has an ad-hoc signature. A public downloadable app needs Developer ID signing and notarization; App Store distribution has a separate setup. No deployment, store upload, or paid account changes were performed.
