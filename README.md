# Calligraphy Tutor Assistant

An offline-first Android app built with Flutter for calligraphy instructors to manage student attendance, fees, and exports. Core records stay local in SQLite. Optional AI analysis features require internet access and only send data to a user-configured `https://` endpoint.

## Features

- **Attendance Calendar**: Monthly calendar with color-coded status badges and fast daily record editing.
- **Quick Entry**: Three-step attendance entry flow with reusable class templates.
- **Student Management**: CRUD, search, and batch import from Excel.
- **Fee Tracking**: Automatic charge calculation, payment records, and prepaid/debt balance tracking.
- **Statistics Dashboard**: Revenue trends, rankings, distribution charts, heatmaps, and insight cards.
- **Smart Insights**: Alerts for debt risk, churn risk, peak hours, and conversion opportunities.
- **Optional AI Analysis**: Handwriting and business insight workflows can call a user-configured `https://` endpoint after explicit confirmation.
- **PDF Reports**: Multi-page reports with signature, watermark, and Chinese font support.
- **Excel Export**: Attendance detail and fee summary sheets.
- **Data Backup**: Backup and restore local database files.

## Screenshots

Coming soon.

## Tech Stack

| Category | Technology |
| --- | --- |
| Framework | Flutter (Dart) |
| Database | SQLite via `sqflite` |
| State Management | Riverpod |
| Navigation | GoRouter |
| Charts | `fl_chart` |
| Calendar | `table_calendar` |
| PDF | `pdf` + `printing` |
| Excel | `excel` |
| Sharing | `share_plus` |

## Architecture

```text
lib/
├─ main.dart
├─ app.dart
├─ core/
│  ├─ database/
│  ├─ dao/
│  ├─ models/
│  ├─ providers/
│  └─ utils/
├─ features/
│  ├─ home/
│  ├─ students/
│  ├─ statistics/
│  ├─ settings/
│  └─ export/
└─ shared/
   ├─ widgets/
   ├─ utils/
   └─ theme.dart
```

Data flow: UI -> Riverpod providers -> DAOs/services -> SQLite.

## Getting Started

### Prerequisites

- Flutter SDK 3.11+
- Android SDK
- Android device or emulator

### Commands

```bash
flutter pub get
flutter run -d <device_id>
flutter analyze
flutter test
flutter build apk --release
```

## Networking Note

- Core attendance, fee, export, and backup flows work locally.
- AI-related features are optional and can be disabled by leaving the API key unset.
- When AI analysis is used, the app may upload images, prompts, and student names to the configured `https://` endpoint after user confirmation.

## Database

Main database: `moyun.db`.

Primary tables:

- `students`
- `attendance`
- `payments`
- `class_templates`
- `settings`
- `dismissed_insights`

## License

Licensed under the [Apache License 2.0](LICENSE).
