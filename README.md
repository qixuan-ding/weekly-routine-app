# Weekly Routine

An offline Flutter app for weekly planning, recurring routines, weekly tasks, and private, duration-weighted accountability. macOS is the first supported and verified desktop target. The Dart application and platform scaffolds are shared with Windows, iOS, and Android.

## Run on this Mac

Open `build/macos/Build/Products/Release/Weekly Routine.app`. A portable release archive is at `dist/Weekly-Routine-macOS.zip`; unzip and drag the app into Applications if desired. No Flutter installation or account is needed to run the built app.

This local build is ad-hoc signed. Public distribution still needs a Developer ID, signing, and Apple notarization.

## Develop

Use Flutter **3.47.9** / Dart **3.13.7** or a compatible later stable SDK, Xcode, and the macOS platform tools. The SDK provisioned for this build is at `/tmp/weekly_sdk/flutter`; this temporary SDK may be removed by macOS.

```sh
flutter pub get
flutter run -d macos
```

Create a validated release and ZIP:

```sh
./scripts/build_macos.sh
# With the SDK provisioned in this session:
FLUTTER_BIN=/tmp/weekly_sdk/flutter/bin/flutter ./scripts/build_macos.sh
```

After changing Drift tables, regenerate the checked-in database bindings:

```sh
dart run build_runner build
```

## Use

- Add events with exact start/end times, weekly routines on one or more weekdays, unscheduled tasks, or flexible frequency targets.
- Open a day for its scrollable midnight-to-midnight time grid. Double-click to add. Drag snaps to 15 minutes; forms accept exact minutes.
- Drag a routine within its week to update that occurrence and every future week. A conflict anywhere in the affected recurrence rejects the entire change. Earlier weeks remain intact.
- Click a routine for **✓ Complete**, **◐ Partial**, **× Not completed**, or clear its outcome. Only explicitly scored scheduled routine time contributes to accountability.
- Open tasks carry forward as the same task. Use the task menu to place it in the calendar; removing a placement keeps the task.
- Settings provides light/dark themes, JSON export/restore, and an optional example week for an empty planner.
- **⌘N** adds an item. **⌘T** returns to the current week.

## Storage and privacy

Drift opens one SQLite database in the app's Application Support directory (`weekly_routine.sqlite`). macOS sandboxing places it under the app's container. Each mutation is validated on a draft, then persisted in a transaction before the UI accepts it. Backups contain the whole planner, including theme, recurrence revisions, exclusions, task history, and recorded durations.

There is no analytics, runtime network connection, authentication, or configured device sync. Keep exported backups independently of the app.

## Validation

```sh
flutter analyze
flutter test
flutter build macos --release
```

Tests cover recurrence and DST-safe dates, adjacent boundaries, far-future conflict rejection, atomic moves, historical schedules, duration-weighted scoring, unrecorded time, future outcome restrictions, duplicate-free carryover, historical task states, target history, JSON validation, SQLite reopen, desktop save/conflict workflows, themes, and compact window navigation.

See [implementation decisions](docs/IMPLEMENTATION.md) for resolutions of the spec's open questions and delivery boundaries. [APP_SPEC.md](APP_SPEC.md) remains the product specification.
