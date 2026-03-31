# Calligraphy Tutor Assistant

An offline-first Android app built with Flutter for calligraphy instructors to manage student attendance, fees, and generate reports. All data is stored locally in SQLite — no internet required.

## Features

- **Attendance Calendar** — Monthly calendar view with color-coded badges (green = all present, red = absent, orange = mixed). Tap a date to view/edit records.
- **Quick Entry** — 3-step bottom sheet: select students (multi-select) -> choose time slot & status -> confirm. Supports class templates for one-tap time selection.
- **Student Management** — Full CRUD with search. Batch import students from Excel (.xlsx). Track per-student fee rates with price snapshot on each attendance record.
- **Fee Tracking** — Automatic fee calculation based on attendance status. Record payments, view balance (prepaid vs. debt) per student per month.
- **Statistics Dashboard** — Revenue trends (dual-line chart), contribution ranking (top 10 bar chart), status distribution (pie chart), time heatmap, and key metrics with period-over-period comparison.
- **Smart Insights** — Automated alerts for outstanding debt, student churn risk (21+ days inactive), peak hour detection, and trial-to-regular conversion.
- **PDF Reports** — 4-page reports with cover, attendance detail, fee summary, and custom message. Supports teacher signature, watermark, and Chinese fonts (Noto Sans SC).
- **Excel Export** — Attendance detail and fee summary sheets with conditional formatting.
- **Data Backup** — One-tap backup to Downloads folder via MediaStore API (Android 10+). Restore from any `.db` file.
- **Seal Stamp** — Customizable Chinese seal stamp (font style, layout, border) for splash screen and PDF cover.

## Screenshots

*Coming soon*

## Tech Stack

| Category | Technology |
|----------|-----------|
| Framework | Flutter (Dart) |
| Database | SQLite via sqflite |
| State Management | Riverpod (AsyncNotifier) |
| Navigation | GoRouter (StatefulShellRoute) |
| Charts | fl_chart |
| Calendar | table_calendar |
| PDF Generation | pdf + printing |
| Excel | excel package |
| File Sharing | share_plus |

## Architecture

```
lib/
├── main.dart                  # Entry point: Riverpod ProviderScope
├── app.dart                   # MaterialApp.router + GoRouter config
├── core/
│   ├── database/
│   │   ├── database_helper.dart   # SQLite singleton, migrations (v4)
│   │   └── dao/                   # Data Access Objects (one per table)
│   ├── models/                    # Data classes with fromMap/toMap/copyWith
│   ├── providers/                 # Riverpod providers (AsyncNotifier + StateProvider)
│   └── utils/                     # Fee calculator, backup, PDF/Excel generation
├── features/
│   ├── home/                      # Attendance calendar + quick entry
│   ├── students/                  # Student CRUD, detail, import
│   ├── statistics/                # Metrics, charts, insights
│   ├── settings/                  # Backup, templates, signature, seal
│   └── export/                    # PDF/Excel export config
└── shared/
    ├── widgets/                   # Reusable components
    ├── utils/                     # Toast/dialog helpers
    └── theme.dart                 # Brand colors, Material 3 theme
```

**Data flow:** UI -> Riverpod Providers -> DAOs -> SQLite

## Getting Started

### Prerequisites

- Flutter SDK 3.11+
- Android SDK (min API 26 / Android 8.0)
- A connected Android device or emulator

### Build & Run

```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter devices
flutter run -d <device_id>

# Build release APK
flutter build apk --release
```

For users in China, set mirrors before running:

```bash
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
```

### Output

Release APK: `build/app/outputs/flutter-apk/app-release.apk`

## Database

SQLite database `moyun.db` with 6 tables. Legacy installs are migrated from `calligraphy_assistant.db` on startup:

| Table | Purpose |
|-------|---------|
| `students` | Student profiles (name, parent info, fee rate, status) |
| `attendance` | Attendance records with price snapshot and calculated fee |
| `payments` | Payment records |
| `class_templates` | Reusable time slot templates |
| `settings` | Key-value app settings |
| `dismissed_insights` | Tracks dismissed smart insight alerts |

All IDs are UUIDs. Dates stored as `YYYY-MM-DD` strings. Foreign keys with CASCADE delete enabled.

## Fee Calculation

| Status | Charged |
|--------|---------|
| Present / Late | price_snapshot amount |
| Leave / Absent / Trial | 0 |

**Balance** = Total Received - Total Receivable (positive = prepaid, negative = debt)

## License

Licensed under the [Apache License 2.0](LICENSE).
