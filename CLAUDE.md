# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

书法私教助手 (Calligraphy Private Tutor Assistant) — an offline-first Android Flutter app for calligraphy instructors to manage student attendance, fees, and generate reports. All data is stored locally in SQLite.

## Build & Development Commands

Flutter is installed at `/d/env/flutter/bin`. All commands require PATH setup:

```bash
export PATH="/d/env/flutter/bin:$PATH"

# Install dependencies
flutter pub get

# Static analysis
dart analyze lib/

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Run on connected device
flutter devices                    # list devices
flutter run -d <device_id>

# Clean build
flutter clean
```

For China mirror environments, add before commands:
```bash
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
```

## Architecture

Layered architecture with feature-based UI organization. State management via Riverpod, navigation via GoRouter with StatefulShellRoute (4-tab bottom nav).

```
lib/
├── main.dart              # Entry: Riverpod ProviderScope + zh_CN date init
├── app.dart               # MaterialApp.router + GoRouter config
├── core/
│   ├── database/
│   │   ├── database_helper.dart   # SQLite singleton, migrations (v3), PRAGMA foreign_keys=ON
│   │   └── dao/                   # Data Access Objects (one per table)
│   ├── models/                    # Data classes with fromMap/toMap/copyWith
│   ├── providers/                 # Riverpod providers (AsyncNotifier + StateProvider)
│   └── utils/                     # Fee calculator, backup, PDF/Excel gen, seed data
├── features/                      # Feature modules: screens/ + widgets/
│   ├── home/                      # Attendance calendar + quick entry
│   ├── students/                  # Student CRUD, detail, import
│   ├── statistics/                # Metrics, charts, insights
│   ├── settings/                  # Backup, templates, signature
│   └── export/                    # PDF/Excel export config
└── shared/
    ├── widgets/                   # Reusable: empty_state, attendance_edit_sheet
    ├── utils/toast.dart           # SnackBar/dialog helpers
    └── theme.dart                 # Brand colors, Material 3 theme
```

### Data Flow

UI (screens/widgets) → Riverpod Providers → DAOs → SQLite

- Business logic lives in providers, UI only calls providers
- Database operations only in DAOs, providers call DAOs
- Models use `fromMap`/`toMap` for SQLite serialization (no ORM)

### Key Conventions

- All IDs are UUIDs (uuid package)
- Dates stored as `YYYY-MM-DD` strings, timestamps as Unix milliseconds
- `price_snapshot` on attendance records captures the student's rate at time of recording
- Fee calculation: `present`/`late` = charged at price_snapshot; `leave`/`absent`/`trial` = 0
- Balance = totalReceived - totalReceivable (positive = prepaid, negative = debt)

### Provider Invalidation Rules

After data mutations, specific providers must be invalidated:

| Operation | Invalidate |
|-----------|-----------|
| Student CRUD | `studentProvider` |
| Delete student (cascades) | `studentProvider` + all attendance/fee/stats/insight providers |
| Attendance CRUD | `attendanceProvider`, `feeSummaryProvider`, all stats providers, `insightProvider` |
| Payment CRUD | `feeSummaryProvider`, `revenueProvider`, `insightProvider` |

### Statistics Providers

All statistics providers watch `statisticsPeriodProvider` (week/month/year) and auto-refresh on period change. Exception: `revenueProvider` always shows the last 12 months regardless of selected period.

## Database

SQLite via sqflite. DB file: `calligraphy_assistant.db`, current version: 3.

6 tables: `students`, `attendance`, `payments`, `class_templates`, `settings`, `dismissed_insights`. Foreign keys with CASCADE delete enabled via PRAGMA on every open.

Schema details in `docs/database-design.md`. Any table changes must update that doc and bump the DB version.

## Routing

GoRouter with `StatefulShellRoute.indexedStack` for 4 tabs. `/students/create` registered before `/students/:id` to avoid param collision. Export config page uses `showModalBottomSheet`, not a route.

## PDF/Excel

PDF generation requires `NotoSansSC-Regular.ttf` from `assets/fonts/` — all `pw.TextStyle` must specify this font or Chinese text renders as boxes. Files are saved to Downloads via MediaStore API (Android 10+).

## Development Plan

Detailed phased plan in `docs/dev-plan.md` (P0-P7). Tech rationale in `docs/tech-stack.md`.
