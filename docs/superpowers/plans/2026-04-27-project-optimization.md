# Project Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve maintainability, product polish, performance confidence, and release quality without changing the verified user behavior of the Flutter app.

**Architecture:** Keep the current Riverpod + DAO + service architecture. Add small pure services and test helpers around the largest files, then have existing screens delegate to those services while preserving routes, labels, provider invalidation, and export/backup behavior.

**Tech Stack:** Flutter, Dart 3.11, Riverpod, sqflite, go_router, pdf, excel, share_plus, flutter_test.

---

## Current Evidence

- `flutter analyze --no-pub`: passed with no issues.
- `flutter test --no-pub`: 246 tests passed.
- One test run prints a recoverable settings/database warning from a widget test path that does not override `settingsProvider`.
- Largest current files:
  - `lib/features/home/widgets/quick_entry_sheet.dart`: 1638 lines.
  - `lib/features/export/screens/export_config_screen.dart`: 1638 lines.
  - `lib/core/utils/pdf_generator.dart`: 1303 lines.
  - `lib/features/students/screens/student_detail_screen.dart`: 1287 lines.
  - `lib/features/settings/screens/settings_screen.dart`: 1223 lines.
  - `lib/features/settings/screens/backup_screen.dart`: 964 lines.
  - `lib/core/utils/backup_helper.dart`: 822 lines.
- Documentation drift exists: `docs/database-design.md` says database version `5`, but `lib/core/database/database_helper.dart` uses `databaseVersion = 6` and runtime indexes not documented there.

## Parallelization Map

Run the batches in order. Inside each batch, listed tasks can run in parallel because their write sets are disjoint or have explicit dependencies.

| Batch | Parallel Tasks | Dependency |
| --- | --- | --- |
| 0 | Task 1, Task 2 | None |
| 1 | Task 3, Task 4, Task 6, Task 8 | Batch 0 |
| 2 | Task 5, Task 7, Task 9, Task 10 | Related Batch 1 task in same lane |
| 3 | Task 11, Task 12 | Batch 2 |
| 4 | Task 13 | All implementation tasks |

Review after every task:

```powershell
dart format .
flutter analyze --no-pub
```

Run the targeted test named in each task before the full suite. After each batch:

```powershell
flutter test --no-pub
```

Each task ends with a Lore-style commit message. Keep commits separate so regressions can be bisected.

---

## File Structure

Create these focused files:

- `test/docs/database_design_consistency_test.dart`: prevents database docs from drifting from runtime constants and indexes.
- `test/helpers/fake_settings_notifier.dart`: reusable settings provider override for widget tests.
- `lib/core/services/app_clock.dart`: injectable clock used by providers and services that currently call `DateTime.now()`.
- `lib/core/providers/clock_provider.dart`: Riverpod provider for `AppClock`.
- `test/core/services/app_clock_test.dart`: clock behavior tests.
- `lib/features/home/services/quick_entry_record_builder.dart`: pure builder for quick-entry attendance records.
- `test/features/home/services/quick_entry_record_builder_test.dart`: regression tests for conflict overwrite preservation and invalid price rejection.
- `lib/features/export/services/export_parent_snapshot_service.dart`: pure builder for export parent snapshot data.
- `test/features/export/services/export_parent_snapshot_service_test.dart`: export snapshot tests.
- `lib/features/export/services/export_temp_file_cleaner.dart`: temp file cleanup behavior separated from the export screen.
- `lib/core/services/pdf_report_summary_service.dart`: pure PDF report summary calculations.
- `test/core/services/pdf_report_summary_service_test.dart`: report summary tests.
- `lib/core/services/backup/backup_file_naming.dart`: backup filename and extension checks.
- `lib/core/services/backup/backup_crypto_codec.dart`: encrypted backup envelope encode/decode.
- `lib/core/services/backup/backup_bundle_codec.dart`: backup bundle encode/decode.
- `test/core/services/backup/backup_file_naming_test.dart`: file naming tests.
- `test/core/services/backup/backup_crypto_codec_test.dart`: encryption tests.
- `test/core/services/backup/backup_bundle_codec_test.dart`: bundle tests.
- `lib/features/settings/widgets/settings_text_edit_sheet.dart`: extracted settings text edit sheet.
- `lib/features/students/widgets/student_detail_anchor_bar.dart`: extracted student detail anchor widgets.

Modify these existing files:

- `docs/database-design.md`: version and index documentation.
- `docs/iteration-roadmap.md`: current verification state and remaining optimization lanes.
- `test/shared/widgets/attendance_edit_sheet_test.dart`: add settings override to avoid accidental database access.
- `lib/core/providers/attendance_provider.dart`: use `appClockProvider`.
- `lib/core/providers/home_workbench_provider.dart`: use `appClockProvider`.
- `lib/core/providers/insight_provider.dart`: use `appClockProvider`.
- `lib/core/providers/statistics_period_provider.dart`: use `appClockProvider`.
- `lib/features/home/widgets/quick_entry_sheet.dart`: delegate record construction to `QuickEntryRecordBuilder`.
- `lib/features/export/screens/export_config_screen.dart`: delegate snapshot and temp file cleanup.
- `lib/core/utils/pdf_generator.dart`: delegate summary calculation.
- `lib/core/utils/backup_helper.dart`: delegate naming, crypto, and bundle codec logic.
- `lib/features/settings/screens/settings_screen.dart`: use extracted text edit sheet.
- `lib/features/students/screens/student_detail_screen.dart`: use extracted anchor bar.

---

### Task 1: Documentation Drift Guard

**Files:**
- Create: `test/docs/database_design_consistency_test.dart`
- Modify: `docs/database-design.md`
- Modify: `docs/iteration-roadmap.md`

- [ ] **Step 1: Write the failing documentation consistency test**

Create `test/docs/database_design_consistency_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database design document matches runtime version and indexes', () {
    final helper = File(
      'lib/core/database/database_helper.dart',
    ).readAsStringSync();
    final docs = File('docs/database-design.md').readAsStringSync();

    final versionMatch = RegExp(
      r'databaseVersion\s*=\s*(\d+)',
    ).firstMatch(helper);

    expect(versionMatch, isNotNull);
    final version = versionMatch!.group(1)!;
    expect(docs, contains('当前版本：`$version`'));

    const indexNames = [
      'idx_attendance_student_date',
      'idx_attendance_date',
      'idx_attendance_date_status',
      'idx_attendance_student_timeline',
      'idx_attendance_student_status_date',
      'idx_students_status_created',
      'idx_payments_student',
      'idx_payments_payment_date',
      'idx_payments_student_date',
    ];

    for (final indexName in indexNames) {
      expect(docs, contains(indexName));
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test --no-pub test/docs/database_design_consistency_test.dart
```

Expected: FAIL because `docs/database-design.md` still contains `当前版本：\`5\`` and does not list all v6 indexes.

- [ ] **Step 3: Update database documentation**

In `docs/database-design.md`, change:

```md
- 当前版本：`5`
```

to:

```md
- 当前版本：`6`
```

Under the database initialization section, document the v6 index set:

```md
### v6 索引补充

v6 不改变表结构，只补齐高频查询索引：

```sql
CREATE INDEX IF NOT EXISTS idx_attendance_date_status
ON attendance(date, status);

CREATE INDEX IF NOT EXISTS idx_attendance_student_timeline
ON attendance(student_id, date DESC, start_time DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_attendance_student_status_date
ON attendance(student_id, status, date DESC);

CREATE INDEX IF NOT EXISTS idx_students_status_created
ON students(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payments_payment_date
ON payments(payment_date);

CREATE INDEX IF NOT EXISTS idx_payments_student_date
ON payments(student_id, payment_date DESC);
```
```

Also update the migration snippet:

```dart
static const int databaseVersion = 6;
```

- [ ] **Step 4: Update roadmap verification status**

In `docs/iteration-roadmap.md`, replace the current boundary lines:

```md
- 未执行全量 `flutter test`
- 未执行 `dart analyze`
```

with:

```md
- `flutter analyze --no-pub` 已通过。
- `flutter test --no-pub` 已通过，全量 246 项测试通过。
- 全量测试仍会输出一条可恢复的 settings/database 测试噪声，后续通过共享测试替身消除。
```

- [ ] **Step 5: Run tests and review**

Run:

```powershell
flutter test --no-pub test/docs/database_design_consistency_test.dart
flutter analyze --no-pub
```

Expected: both pass.

- [ ] **Step 6: Commit**

```powershell
git add docs/database-design.md docs/iteration-roadmap.md test/docs/database_design_consistency_test.dart
git commit -m "Keep database documentation aligned with runtime schema" -m "Adds a test that checks the database design document against the runtime version and index names so documentation drift is caught during regression runs.`n`nConstraint: Runtime database version is already 6.`nConfidence: high`nScope-risk: narrow`nTested: flutter test --no-pub test/docs/database_design_consistency_test.dart; flutter analyze --no-pub"
```

---

### Task 2: Shared Settings Test Override

**Files:**
- Create: `test/helpers/fake_settings_notifier.dart`
- Modify: `test/shared/widgets/attendance_edit_sheet_test.dart`

- [ ] **Step 1: Create shared test settings notifier**

Create `test/helpers/fake_settings_notifier.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moyun/core/providers/settings_provider.dart';
import 'package:moyun/shared/utils/interaction_feedback.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  static Map<String, String> seededSettings = const {
    InteractionFeedback.hapticsEnabledKey: 'false',
    InteractionFeedback.soundEnabledKey: 'false',
  };

  static void reset() {
    seededSettings = const {
      InteractionFeedback.hapticsEnabledKey: 'false',
      InteractionFeedback.soundEnabledKey: 'false',
    };
  }

  @override
  Future<Map<String, String>> build() async => seededSettings;

  @override
  Future<void> set(String key, String value) async {
    seededSettings = {...seededSettings, key: value};
    state = AsyncData(seededSettings);
  }

  @override
  Future<void> setAll(Map<String, String> entries) async {
    seededSettings = {...seededSettings, ...entries};
    state = AsyncData(seededSettings);
  }
}
```

- [ ] **Step 2: Wire the helper into attendance edit sheet tests**

In `test/shared/widgets/attendance_edit_sheet_test.dart`, add imports:

```dart
import 'package:moyun/core/providers/settings_provider.dart';

import '../../helpers/fake_settings_notifier.dart';
```

Add setup:

```dart
void main() {
  setUp(FakeSettingsNotifier.reset);

  // existing tests stay below
}
```

Wrap every `ProviderScope(` in this file with the settings override. For scopes with no existing overrides:

```dart
ProviderScope(
  overrides: [settingsProvider.overrideWith(FakeSettingsNotifier.new)],
  child: MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: AttendanceEditSheet(record: record)),
  ),
)
```

For scopes that already override `attendanceDaoProvider`:

```dart
ProviderScope(
  overrides: [
    settingsProvider.overrideWith(FakeSettingsNotifier.new),
    attendanceDaoProvider.overrideWithValue(fakeDao),
  ],
  child: MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: AttendanceEditSheet(
        record: record,
        onAnalyzeArtwork: () async {
          analyzed = true;
        },
      ),
    ),
  ),
)
```

- [ ] **Step 3: Run targeted test**

Run:

```powershell
flutter test --no-pub test/shared/widgets/attendance_edit_sheet_test.dart
```

Expected: PASS with no `databaseFactory not initialized` warning from this test file.

- [ ] **Step 4: Run full regression**

Run:

```powershell
flutter test --no-pub
```

Expected: PASS. If a settings/database warning remains, search for un-overridden `SettingsNotifier` in widget tests:

```powershell
Get-ChildItem -Path test -Recurse -Filter *.dart | Select-String -Pattern "ProviderScope\\("
```

- [ ] **Step 5: Commit**

```powershell
git add test/helpers/fake_settings_notifier.dart test/shared/widgets/attendance_edit_sheet_test.dart
git commit -m "Isolate widget tests from settings database access" -m "Adds a shared settings notifier override and applies it to attendance edit sheet tests so widget tests do not accidentally touch sqflite globals.`n`nConstraint: No new test dependencies.`nConfidence: high`nScope-risk: narrow`nTested: flutter test --no-pub test/shared/widgets/attendance_edit_sheet_test.dart; flutter test --no-pub"
```

---

### Task 3: Injectable Clock Foundation

**Files:**
- Create: `lib/core/services/app_clock.dart`
- Create: `lib/core/providers/clock_provider.dart`
- Test: `test/core/services/app_clock_test.dart`

- [ ] **Step 1: Write clock tests**

Create `test/core/services/app_clock_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/app_clock.dart';

void main() {
  test('AppClock.now returns injected time', () {
    final clock = AppClock.fixed(DateTime(2026, 4, 27, 9, 30));

    expect(clock.now(), DateTime(2026, 4, 27, 9, 30));
    expect(clock.nowMs(), DateTime(2026, 4, 27, 9, 30).millisecondsSinceEpoch);
    expect(clock.todayKey(), '2026-04-27');
  });

  test('AppClock.system creates a non-null current time', () {
    final clock = AppClock.system();

    expect(clock.now(), isA<DateTime>());
    expect(clock.nowMs(), isA<int>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test --no-pub test/core/services/app_clock_test.dart
```

Expected: FAIL because `AppClock` does not exist.

- [ ] **Step 3: Implement clock**

Create `lib/core/services/app_clock.dart`:

```dart
import '../../shared/constants.dart';

typedef DateTimeFactory = DateTime Function();

class AppClock {
  final DateTimeFactory _now;

  const AppClock({required DateTimeFactory now}) : _now = now;

  factory AppClock.system() {
    return AppClock(now: DateTime.now);
  }

  factory AppClock.fixed(DateTime value) {
    return AppClock(now: () => value);
  }

  DateTime now() => _now();

  int nowMs() => now().millisecondsSinceEpoch;

  String todayKey() => formatDate(now());
}
```

Create `lib/core/providers/clock_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_clock.dart';

final appClockProvider = Provider<AppClock>((ref) {
  return AppClock.system();
});
```

- [ ] **Step 4: Run test**

Run:

```powershell
flutter test --no-pub test/core/services/app_clock_test.dart
flutter analyze --no-pub
```

Expected: both pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/services/app_clock.dart lib/core/providers/clock_provider.dart test/core/services/app_clock_test.dart
git commit -m "Add injectable application clock" -m "Introduces a small clock abstraction so time-sensitive providers and services can be tested without direct DateTime.now calls.`n`nRejected: Add a clock package | unnecessary dependency for a simple wrapper.`nConfidence: high`nScope-risk: narrow`nTested: flutter test --no-pub test/core/services/app_clock_test.dart; flutter analyze --no-pub"
```

---

### Task 4: Quick Entry Record Builder

**Files:**
- Create: `lib/features/home/services/quick_entry_record_builder.dart`
- Test: `test/features/home/services/quick_entry_record_builder_test.dart`

- [ ] **Step 1: Write builder tests**

Create `test/features/home/services/quick_entry_record_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/student.dart';
import 'package:moyun/core/models/structured_attendance_feedback.dart';
import 'package:moyun/features/home/services/quick_entry_record_builder.dart';

void main() {
  test('build preserves existing feedback and artwork during overwrite', () {
    final existing = Attendance(
      id: 'attendance-old',
      studentId: 'student-1',
      date: '2026-04-17',
      startTime: '18:00',
      endTime: '19:30',
      status: 'present',
      priceSnapshot: 180,
      feeAmount: 180,
      note: 'manual note',
      lessonFocusTags: const ['章法布局'],
      homePracticeNote: 'old practice',
      progressScores: const AttendanceProgressScores(strokeQuality: 4),
      artworkImagePath: 'artworks/old.png',
      createdAt: 11,
      updatedAt: 22,
    );

    final result = const QuickEntryRecordBuilder().build(
      request: QuickEntryRecordRequest(
        students: [
          Student(
            id: 'student-1',
            name: 'Alice',
            pricePerClass: 180,
            status: 'active',
            createdAt: 1,
            updatedAt: 1,
          ),
        ],
        conflictRecordsByStudentId: {'student-1': existing},
        date: '2026-04-18',
        startTime: '19:00',
        endTime: '20:00',
        status: 'late',
        lessonFocusTags: [],
        homePracticeNote: '',
        progressScores: null,
        nowMs: 99,
        idFactory: _FixedIdFactory('new-id').next,
      ),
    );

    expect(result.conflictIds, {'student-1': 'attendance-old'});
    expect(result.records, hasLength(1));
    final saved = result.records.single;
    expect(saved.id, 'attendance-old');
    expect(saved.note, 'manual note');
    expect(saved.lessonFocusTags, const ['章法布局']);
    expect(saved.homePracticeNote, 'old practice');
    expect(saved.progressScores?.strokeQuality, 4);
    expect(saved.artworkImagePath, 'artworks/old.png');
    expect(saved.createdAt, 11);
    expect(saved.updatedAt, 99);
    expect(saved.date, '2026-04-18');
    expect(saved.startTime, '19:00');
    expect(saved.endTime, '20:00');
    expect(saved.status, 'late');
    expect(saved.feeAmount, 180);
  });

  test('build rejects negative student price', () {
    expect(
      () => const QuickEntryRecordBuilder().build(
        request: QuickEntryRecordRequest(
          students: [
            Student(
              id: 'student-1',
              name: 'Alice',
              pricePerClass: -1,
              status: 'active',
              createdAt: 1,
              updatedAt: 1,
            ),
          ],
          conflictRecordsByStudentId: {},
          date: '2026-04-18',
          startTime: '19:00',
          endTime: '20:00',
          status: 'present',
          lessonFocusTags: [],
          homePracticeNote: '',
          progressScores: null,
          nowMs: 99,
          idFactory: _FixedIdFactory('new-id').next,
        ),
      ),
      throwsA(isA<QuickEntryInvalidPriceException>()),
    );
  });
}

class _FixedIdFactory {
  final String id;

  const _FixedIdFactory(this.id);

  String next() => id;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test --no-pub test/features/home/services/quick_entry_record_builder_test.dart
```

Expected: FAIL because the service does not exist.

- [ ] **Step 3: Implement builder**

Create `lib/features/home/services/quick_entry_record_builder.dart`:

```dart
import '../../../core/models/attendance.dart';
import '../../../core/models/student.dart';
import '../../../core/models/structured_attendance_feedback.dart';
import '../../../core/utils/fee_calculator.dart';
import '../../../shared/constants.dart';

typedef AttendanceIdFactory = String Function();

class QuickEntryInvalidPriceException implements Exception {
  final Student student;

  const QuickEntryInvalidPriceException(this.student);

  @override
  String toString() {
    return '${student.name} 的课时单价无效，请先编辑学生档案。';
  }
}

class QuickEntryRecordRequest {
  final List<Student> students;
  final Map<String, Attendance> conflictRecordsByStudentId;
  final String date;
  final String startTime;
  final String endTime;
  final String status;
  final List<String> lessonFocusTags;
  final String homePracticeNote;
  final AttendanceProgressScores? progressScores;
  final int nowMs;
  final AttendanceIdFactory idFactory;

  const QuickEntryRecordRequest({
    required this.students,
    required this.conflictRecordsByStudentId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.lessonFocusTags,
    required this.homePracticeNote,
    required this.progressScores,
    required this.nowMs,
    required this.idFactory,
  });
}

class QuickEntryRecordBuildResult {
  final List<Attendance> records;
  final Map<String, String> conflictIds;

  const QuickEntryRecordBuildResult({
    required this.records,
    required this.conflictIds,
  });
}

class QuickEntryRecordBuilder {
  const QuickEntryRecordBuilder();

  QuickEntryRecordBuildResult build({
    required QuickEntryRecordRequest request,
  }) {
    final statusEnum = AttendanceStatus.values.firstWhere(
      (item) => item.name == request.status,
    );
    final conflictIds = {
      for (final entry in request.conflictRecordsByStudentId.entries)
        entry.key: entry.value.id,
    };
    final records = <Attendance>[];

    for (final student in request.students) {
      if (student.pricePerClass < 0) {
        throw QuickEntryInvalidPriceException(student);
      }

      final price = student.pricePerClass;
      final fee = FeeCalculator.calcFee(statusEnum, price);
      final existingRecord = request.conflictRecordsByStudentId[student.id];
      final resolvedLessonFocusTags =
          existingRecord != null && request.lessonFocusTags.isEmpty
          ? existingRecord.lessonFocusTags
          : request.lessonFocusTags;
      final resolvedHomePracticeNote =
          existingRecord != null && request.homePracticeNote.isEmpty
          ? existingRecord.homePracticeNote
          : (request.homePracticeNote.isEmpty
                ? null
                : request.homePracticeNote);
      final resolvedProgressScores =
          existingRecord != null && request.progressScores == null
          ? existingRecord.progressScores
          : request.progressScores;

      records.add(
        existingRecord?.copyWith(
              date: request.date,
              startTime: request.startTime,
              endTime: request.endTime,
              status: request.status,
              priceSnapshot: price,
              feeAmount: fee,
              lessonFocusTags: resolvedLessonFocusTags,
              homePracticeNote: resolvedHomePracticeNote,
              progressScores: resolvedProgressScores,
              updatedAt: request.nowMs,
            ) ??
            Attendance(
              id: request.idFactory(),
              studentId: student.id,
              date: request.date,
              startTime: request.startTime,
              endTime: request.endTime,
              status: request.status,
              priceSnapshot: price,
              feeAmount: fee,
              lessonFocusTags: resolvedLessonFocusTags,
              homePracticeNote: resolvedHomePracticeNote,
              progressScores: resolvedProgressScores,
              createdAt: request.nowMs,
              updatedAt: request.nowMs,
            ),
      );
    }

    return QuickEntryRecordBuildResult(
      records: records,
      conflictIds: conflictIds,
    );
  }
}
```

- [ ] **Step 4: Run test**

Run:

```powershell
flutter test --no-pub test/features/home/services/quick_entry_record_builder_test.dart
flutter analyze --no-pub
```

Expected: both pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/home/services/quick_entry_record_builder.dart test/features/home/services/quick_entry_record_builder_test.dart
git commit -m "Extract quick entry record construction" -m "Moves quick-entry attendance record construction into a pure service with regression tests for overwrite preservation and price validation.`n`nConstraint: QuickEntrySheet behavior must remain unchanged.`nConfidence: high`nScope-risk: moderate`nTested: flutter test --no-pub test/features/home/services/quick_entry_record_builder_test.dart; flutter analyze --no-pub"
```

---

### Task 5: Quick Entry Screen Integration

**Files:**
- Modify: `lib/features/home/widgets/quick_entry_sheet.dart`
- Test: `test/features/home/widgets/quick_entry_sheet_test.dart`
- Depends on: Task 4

- [ ] **Step 1: Import builder**

Add:

```dart
import '../services/quick_entry_record_builder.dart';
```

- [ ] **Step 2: Replace record construction inside `_save`**

In `_save`, keep selection, conflict lookup, conflict dialog, persistence, invalidation, feedback, and navigation in the widget. Replace the invalid price loop and manual `records` construction with:

```dart
      final lessonFocusTags = _lessonFocusTags.toList(growable: false);
      final homePracticeNote = _homePracticeCtrl.text.trim();
      final progressScores = _buildProgressScores();

      final buildResult = const QuickEntryRecordBuilder().build(
        request: QuickEntryRecordRequest(
          students: selectedStudents.map((item) => item.student).toList(),
          conflictRecordsByStudentId: conflictRecords,
          date: _dateStr(),
          startTime: _startTime,
          endTime: _endTime,
          status: _status,
          lessonFocusTags: lessonFocusTags,
          homePracticeNote: homePracticeNote,
          progressScores: progressScores,
          nowMs: DateTime.now().millisecondsSinceEpoch,
          idFactory: () => const Uuid().v4(),
        ),
      );

      await _persistQuickEntryPreferences(selectedStudents);
      await dao.batchInsertWithConflictReplace(
        buildResult.records,
        buildResult.conflictIds,
      );
```

Add an exception branch before `FormatException`:

```dart
    } on QuickEntryInvalidPriceException catch (error) {
      final displayName =
          ref.read(studentDisplayNameMapProvider)[error.student.id] ??
          error.student.name;
      if (mounted) {
        AppToast.showError(context, '$displayName 的课时单价无效，请先编辑学生档案。');
      }
```

- [ ] **Step 3: Run existing widget tests**

Run:

```powershell
flutter test --no-pub test/features/home/widgets/quick_entry_sheet_test.dart
```

Expected: PASS. The existing conflict overwrite test must still prove feedback and artwork are preserved.

- [ ] **Step 4: Run lane regression**

Run:

```powershell
flutter test --no-pub test/features/home/widgets/quick_entry_sheet_test.dart test/features/home/services/quick_entry_record_builder_test.dart
flutter analyze --no-pub
```

Expected: both pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/home/widgets/quick_entry_sheet.dart
git commit -m "Delegate quick entry record building to service" -m "Keeps UI interaction in QuickEntrySheet while moving attendance record construction to the tested builder service.`n`nConstraint: Preserve existing quick-entry labels, conflict dialog, invalidation, and feedback behavior.`nConfidence: high`nScope-risk: moderate`nTested: flutter test --no-pub test/features/home/widgets/quick_entry_sheet_test.dart test/features/home/services/quick_entry_record_builder_test.dart; flutter analyze --no-pub"
```

---

### Task 6: Export Parent Snapshot Service

**Files:**
- Create: `lib/features/export/services/export_parent_snapshot_service.dart`
- Test: `test/features/export/services/export_parent_snapshot_service_test.dart`

- [ ] **Step 1: Write service test**

Create `test/features/export/services/export_parent_snapshot_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/utils/fee_calculator.dart';
import 'package:moyun/features/export/services/export_parent_snapshot_service.dart';

void main() {
  test('buildSnapshot exposes balance, progress, attention, and freshness', () {
    final snapshot = const ExportParentSnapshotService().buildSnapshot(
      records: [
        Attendance(
          id: 'a1',
          studentId: 's1',
          date: '2026-04-01',
          startTime: '09:00',
          endTime: '10:00',
          status: 'present',
          priceSnapshot: 180,
          feeAmount: 180,
          lessonFocusTags: ['控笔'],
          homePracticeNote: '每天练习横画',
          createdAt: 1,
          updatedAt: DateTime(2026, 4, 1, 12).millisecondsSinceEpoch,
        ),
      ],
      feeSummary: const StudentFeeSummary(
        totalReceivable: 180,
        totalReceived: 0,
        openingBalance: 0,
        periodNetChange: -180,
        balance: -180,
      ),
      pricePerClass: 180,
    );

    expect(snapshot.balanceLabel, '截至当前待缴 ¥-180.00');
    expect(snapshot.balanceState, LedgerBalanceState.debt);
    expect(snapshot.progressPoint, isNotEmpty);
    expect(snapshot.attentionPoint, isNotEmpty);
    expect(snapshot.dataFreshness, contains('2026-04-01'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test --no-pub test/features/export/services/export_parent_snapshot_service_test.dart
```

Expected: FAIL because the service does not exist.

- [ ] **Step 3: Implement service**

Create `lib/features/export/services/export_parent_snapshot_service.dart`:

```dart
import '../../../core/models/attendance.dart';
import '../../../core/services/student_growth_summary_service.dart';
import '../../../core/utils/fee_calculator.dart';

class ExportParentSnapshot {
  final String balanceLabel;
  final LedgerBalanceState balanceState;
  final String nextLessonLabel;
  final String progressPoint;
  final String attentionPoint;
  final String dataFreshness;

  const ExportParentSnapshot({
    required this.balanceLabel,
    required this.balanceState,
    required this.nextLessonLabel,
    required this.progressPoint,
    required this.attentionPoint,
    required this.dataFreshness,
  });
}

class ExportParentSnapshotService {
  const ExportParentSnapshotService();

  ExportParentSnapshot buildSnapshot({
    required List<Attendance> records,
    required StudentFeeSummary feeSummary,
    required double pricePerClass,
  }) {
    final summary = const StudentGrowthSummaryService().build(
      records: records,
    );
    final ledger = StudentLedgerView.fromSummary(
      feeSummary,
      pricePerClass: pricePerClass,
    );

    return ExportParentSnapshot(
      balanceLabel:
          '${ledger.currentBalanceLabel} ¥${feeSummary.balance.toStringAsFixed(2)}',
      balanceState: ledger.balanceState,
      nextLessonLabel: summary.nextLessonLabel,
      progressPoint: summary.progressPoint,
      attentionPoint: summary.attentionPoint,
      dataFreshness: summary.dataFreshness,
    );
  }
}
```

- [ ] **Step 4: Run service test**

Run:

```powershell
flutter test --no-pub test/features/export/services/export_parent_snapshot_service_test.dart
flutter analyze --no-pub
```

Expected: both pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/export/services/export_parent_snapshot_service.dart test/features/export/services/export_parent_snapshot_service_test.dart
git commit -m "Extract export parent snapshot assembly" -m "Moves parent snapshot calculation out of the export screen into a pure service with focused tests.`n`nConstraint: Snapshot text must continue to use the centralized ledger and growth summary logic.`nConfidence: high`nScope-risk: narrow`nTested: flutter test --no-pub test/features/export/services/export_parent_snapshot_service_test.dart; flutter analyze --no-pub"
```

---

### Task 7: Export Screen Integration And Temp Cleanup Extraction

**Files:**
- Create: `lib/features/export/services/export_temp_file_cleaner.dart`
- Modify: `lib/features/export/screens/export_config_screen.dart`
- Modify: `test/features/export/screens/export_config_screen_test.dart`
- Depends on: Task 6

- [ ] **Step 1: Extract temp file cleaner**

Create `lib/features/export/services/export_temp_file_cleaner.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:share_plus/share_plus.dart';

bool shouldTreatShareAsCompleted(ShareResultStatus status) {
  return status != ShareResultStatus.dismissed;
}

Future<void> deleteExportTempFile(String path) async {
  if (path.isEmpty) return;
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<void> cleanupExportTempFileForShare(
  String path,
  ShareResultStatus status, {
  Duration deferredDelay = const Duration(seconds: 3),
}) async {
  if (!shouldTreatShareAsCompleted(status)) {
    await deleteExportTempFile(path);
    return;
  }

  unawaited(
    Future<void>.delayed(deferredDelay, () => deleteExportTempFile(path)),
  );
}
```

- [ ] **Step 2: Import extracted services in export screen**

In `lib/features/export/screens/export_config_screen.dart`, add:

```dart
import '../services/export_parent_snapshot_service.dart';
import '../services/export_temp_file_cleaner.dart';
```

Replace private `_ParentSnapshot` with `ExportParentSnapshot`.

Replace `_snapshotBalanceColor(StudentLedgerView ledger)` with:

```dart
Color _snapshotBalanceColor(LedgerBalanceState state) {
  switch (state) {
    case LedgerBalanceState.debt:
      return kRed;
    case LedgerBalanceState.settled:
      return kInkSecondary;
    case LedgerBalanceState.surplus:
      return kGreen;
  }
}
```

Update `_ParentSnapshotCard` call sites so color is resolved in UI:

```dart
balanceColor: _snapshotBalanceColor(snapshot.balanceState),
```

Replace `_loadParentSnapshot` body with:

```dart
  Future<ExportParentSnapshot> _loadParentSnapshot(Student? student) async {
    final dataFuture = _loadData();
    final feeSummaryFuture = _loadFeeSummary();
    final resolvedStudent = student ?? await _loadStudent();
    final data = await dataFuture;
    final feeSummary = await feeSummaryFuture;

    return const ExportParentSnapshotService().buildSnapshot(
      records: data.records,
      feeSummary: feeSummary,
      pricePerClass: resolvedStudent?.pricePerClass ?? 0,
    );
  }
```

Keep top-level testing wrappers for compatibility:

```dart
@visibleForTesting
Future<void> deleteExportTempFileForTesting(String path) {
  return deleteExportTempFile(path);
}

@visibleForTesting
Future<void> cleanupExportTempFileForShareForTesting(
  String path,
  ShareResultStatus status, {
  Duration deferredDelay = const Duration(seconds: 3),
}) {
  return cleanupExportTempFileForShare(
    path,
    status,
    deferredDelay: deferredDelay,
  );
}

@visibleForTesting
bool shouldTreatShareAsCompletedForTesting(ShareResultStatus status) {
  return shouldTreatShareAsCompleted(status);
}
```

- [ ] **Step 3: Run export tests**

Run:

```powershell
flutter test --no-pub test/features/export/screens/export_config_screen_test.dart test/features/export/services/export_parent_snapshot_service_test.dart
flutter analyze --no-pub
```

Expected: both pass.

- [ ] **Step 4: Commit**

```powershell
git add lib/features/export/screens/export_config_screen.dart lib/features/export/services/export_temp_file_cleaner.dart test/features/export/screens/export_config_screen_test.dart
git commit -m "Slim export screen data helpers" -m "Moves parent snapshot calculation and temp file cleanup out of ExportConfigScreen while preserving existing test wrappers.`n`nConstraint: Existing export screen widget tests continue to import the screen-level testing helpers.`nConfidence: high`nScope-risk: moderate`nTested: flutter test --no-pub test/features/export/screens/export_config_screen_test.dart test/features/export/services/export_parent_snapshot_service_test.dart; flutter analyze --no-pub"
```

---

### Task 8: PDF Report Summary Service

**Files:**
- Create: `lib/core/services/pdf_report_summary_service.dart`
- Test: `test/core/services/pdf_report_summary_service_test.dart`

- [ ] **Step 1: Write report summary tests**

Create `test/core/services/pdf_report_summary_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/attendance.dart';
import 'package:moyun/core/models/payment.dart';
import 'package:moyun/core/services/pdf_report_summary_service.dart';
import 'package:moyun/core/utils/fee_calculator.dart';

void main() {
  test('build sorts records and resolves ledger from fee summary', () {
    final summary = const PdfReportSummaryService().build(
      records: [
        Attendance(
          id: 'b',
          studentId: 's1',
          date: '2026-04-02',
          startTime: '10:00',
          endTime: '11:00',
          status: 'present',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
        Attendance(
          id: 'a',
          studentId: 's1',
          date: '2026-04-01',
          startTime: '09:00',
          endTime: '10:30',
          status: 'late',
          priceSnapshot: 100,
          feeAmount: 100,
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      payments: [
        Payment(
          id: 'p1',
          studentId: 's1',
          amount: 50,
          paymentDate: '2026-04-03',
          createdAt: 1,
        ),
      ],
      pricePerClass: 100,
      feeSummary: const StudentFeeSummary(
        totalReceivable: 200,
        totalReceived: 50,
        openingBalance: 0,
        periodNetChange: -150,
        balance: -150,
      ),
      now: DateTime(2026, 4, 27),
    );

    expect(summary.sortedRecords.map((item) => item.id), ['a', 'b']);
    expect(summary.totalMinutes, 150);
    expect(summary.totalFee, 200);
    expect(summary.totalPaid, 50);
    expect(summary.ledger.balance, -150);
    expect(summary.feedbackRecords, isEmpty);
    expect(summary.growthSummary.dataFreshness, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test --no-pub test/core/services/pdf_report_summary_service_test.dart
```

Expected: FAIL because the service does not exist.

- [ ] **Step 3: Implement service**

Create `lib/core/services/pdf_report_summary_service.dart`:

```dart
import '../models/attendance.dart';
import '../models/payment.dart';
import 'student_growth_summary_service.dart';
import '../utils/fee_calculator.dart';

class PdfReportSummary {
  final List<Attendance> sortedRecords;
  final List<Payment> sortedPayments;
  final List<Attendance> feedbackRecords;
  final int totalMinutes;
  final double totalFee;
  final double totalPaid;
  final StudentLedgerView ledger;
  final StudentGrowthSummary growthSummary;

  const PdfReportSummary({
    required this.sortedRecords,
    required this.sortedPayments,
    required this.feedbackRecords,
    required this.totalMinutes,
    required this.totalFee,
    required this.totalPaid,
    required this.ledger,
    required this.growthSummary,
  });
}

class PdfReportSummaryService {
  const PdfReportSummaryService();

  PdfReportSummary build({
    required List<Attendance> records,
    required List<Payment> payments,
    required double pricePerClass,
    required DateTime now,
    StudentFeeSummary? feeSummary,
  }) {
    final sortedRecords = [...records]
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.startTime.compareTo(b.startTime);
      });
    final sortedPayments = [...payments]
      ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
    final feedbackRecords = sortedRecords
        .where(_hasStructuredFeedback)
        .toList(growable: false);
    final totalMinutes = sortedRecords.fold<int>(
      0,
      (sum, record) => sum + _durationMinutes(record.startTime, record.endTime),
    );
    final totalFee = sortedRecords.fold<double>(
      0,
      (sum, record) => sum + record.feeAmount,
    );
    final totalPaid = sortedPayments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final ledger = StudentLedgerView(
      balance: feeSummary?.balance ?? (totalPaid - totalFee),
      pricePerClass: pricePerClass,
      hasBalanceHistory: totalFee > 0 || totalPaid > 0,
    );
    final growthSummary = const StudentGrowthSummaryService().build(
      records: sortedRecords,
      now: now,
    );

    return PdfReportSummary(
      sortedRecords: sortedRecords,
      sortedPayments: sortedPayments,
      feedbackRecords: feedbackRecords,
      totalMinutes: totalMinutes,
      totalFee: totalFee,
      totalPaid: totalPaid,
      ledger: ledger,
      growthSummary: growthSummary,
    );
  }

  bool _hasStructuredFeedback(Attendance record) {
    return record.lessonFocusTags.isNotEmpty ||
        (record.homePracticeNote?.trim().isNotEmpty ?? false) ||
        record.progressScores != null ||
        (record.artworkImagePath?.trim().isNotEmpty ?? false);
  }

  int _durationMinutes(String startTime, String endTime) {
    final start = _minutesOfDay(startTime);
    final end = _minutesOfDay(endTime);
    return end > start ? end - start : 0;
  }

  int _minutesOfDay(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
```

- [ ] **Step 4: Run service test**

Run:

```powershell
flutter test --no-pub test/core/services/pdf_report_summary_service_test.dart
flutter analyze --no-pub
```

Expected: both pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/services/pdf_report_summary_service.dart test/core/services/pdf_report_summary_service_test.dart
git commit -m "Extract PDF report summary calculations" -m "Moves PDF report sorting, totals, ledger, and growth summary inputs into a focused service before slimming PdfGenerator.`n`nConstraint: Generated PDF layout remains unchanged in this task.`nConfidence: high`nScope-risk: narrow`nTested: flutter test --no-pub test/core/services/pdf_report_summary_service_test.dart; flutter analyze --no-pub"
```

---

### Task 9: PdfGenerator Integration

**Files:**
- Modify: `lib/core/utils/pdf_generator.dart`
- Test: `test/core/services/pdf_report_summary_service_test.dart`
- Depends on: Task 8

- [ ] **Step 1: Import summary service**

Add:

```dart
import '../services/pdf_report_summary_service.dart';
```

- [ ] **Step 2: Replace duplicated summary setup**

Inside `PdfGenerator.generate`, replace local `sortedRecords`, `sortedPayments`, `feedbackRecords`, `totalMinutes`, `totalFee`, `totalPaid`, `ledger`, and `growthSummary` construction with:

```dart
    final reportSummary = const PdfReportSummaryService().build(
      records: records,
      payments: payments,
      pricePerClass: student.pricePerClass,
      feeSummary: feeSummary,
      now: DateTime.now(),
    );
    final sortedRecords = reportSummary.sortedRecords;
    final sortedPayments = reportSummary.sortedPayments;
    final feedbackRecords = reportSummary.feedbackRecords;
    final totalMinutes = reportSummary.totalMinutes;
    final totalFee = reportSummary.totalFee;
    final totalPaid = reportSummary.totalPaid;
    final ledger = reportSummary.ledger;
    final growthSummary = reportSummary.growthSummary;
```

Keep all existing PDF widget builder functions and layout code in place.

- [ ] **Step 3: Remove now-unused private helpers if analyzer reports them unused**

Remove `_hasStructuredFeedback`, `_durationMinutes`, and `_minutesOfDay` from `PdfGenerator` only after `flutter analyze --no-pub` reports they are unused in that file.

- [ ] **Step 4: Run regression**

Run:

```powershell
flutter test --no-pub test/core/services/pdf_report_summary_service_test.dart
flutter analyze --no-pub
```

Expected: both pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/utils/pdf_generator.dart
git commit -m "Use report summary service in PDF generation" -m "PdfGenerator now delegates report totals and sorted data preparation to PdfReportSummaryService while keeping layout output stable.`n`nConstraint: No PDF visual redesign in this refactor.`nConfidence: medium`nScope-risk: moderate`nTested: flutter test --no-pub test/core/services/pdf_report_summary_service_test.dart; flutter analyze --no-pub"
```

---

### Task 10: Backup Helper Codec Split

**Files:**
- Create: `lib/core/services/backup/backup_file_naming.dart`
- Create: `lib/core/services/backup/backup_crypto_codec.dart`
- Create: `lib/core/services/backup/backup_bundle_codec.dart`
- Modify: `lib/core/utils/backup_helper.dart`
- Test: `test/core/utils/backup_helper_test.dart`
- Test: `test/core/services/backup/backup_file_naming_test.dart`
- Test: `test/core/services/backup/backup_crypto_codec_test.dart`
- Test: `test/core/services/backup/backup_bundle_codec_test.dart`

- [ ] **Step 1: Write backup file naming test**

Create `test/core/services/backup/backup_file_naming_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/services/backup/backup_file_naming.dart';

void main() {
  test('builds readable plain and encrypted backup names', () {
    final naming = const BackupFileNaming();
    final time = DateTime(2026, 4, 1, 9, 5, 7);

    expect(naming.buildPlainFileName(time), 'moyun_backup_2026-04-01_09-05-07.db');
    expect(
      naming.buildEncryptedFileName(time),
      'moyun_backup_2026-04-01_09-05-07.moyunbak',
    );
  });

  test('validates supported restore extensions', () {
    final naming = const BackupFileNaming();

    expect(naming.hasSupportedExtension('/tmp/a.db'), isTrue);
    expect(naming.hasSupportedExtension('/tmp/a.sqlite'), isTrue);
    expect(naming.hasSupportedExtension('/tmp/a.sqlite3'), isTrue);
    expect(naming.hasSupportedExtension('/tmp/a.moyunbak'), isTrue);
    expect(naming.hasSupportedExtension('/tmp/a.zip'), isFalse);
  });
}
```

- [ ] **Step 2: Implement file naming service**

Create `lib/core/services/backup/backup_file_naming.dart`:

```dart
import 'package:path/path.dart' as p;

class BackupFileNaming {
  static const encryptedBackupExtension = 'moyunbak';
  static const _backupFilePrefix = 'moyun_backup';

  const BackupFileNaming();

  String buildPlainFileName(DateTime at) {
    return '${_backupFilePrefix}_${_formatTimestamp(at)}.db';
  }

  String buildEncryptedFileName(DateTime at) {
    return '${_backupFilePrefix}_${_formatTimestamp(at)}.$encryptedBackupExtension';
  }

  bool hasSupportedExtension(String filePath) {
    final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');
    return extension == 'db' ||
        extension == 'sqlite' ||
        extension == 'sqlite3' ||
        extension == encryptedBackupExtension;
  }

  bool isEncryptedPath(String filePath) {
    final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');
    return extension == encryptedBackupExtension;
  }

  String _formatTimestamp(DateTime at) {
    final y = at.year.toString().padLeft(4, '0');
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    final h = at.hour.toString().padLeft(2, '0');
    final min = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    return '${y}-${m}-${d}_${h}-${min}-${s}';
  }
}
```

- [ ] **Step 3: Move crypto into service**

Create `lib/core/services/backup/backup_crypto_codec.dart` by moving the encryption envelope, passphrase validation, encrypt, and decrypt logic from `BackupHelper`. Keep public signatures:

```dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupCryptoCodec {
  static const minimumPassphraseLength = 8;
  static const _encryptedBackupFormat = 'moyun_encrypted_backup';
  static const _encryptedBackupVersion = 1;
  static const _pbkdf2Iterations = 120000;
  static const _kdfSaltLength = 16;
  static const _gcmNonceLength = 12;

  static final _cipher = AesGcm.with256bits();
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  );
  static final _random = Random.secure();

  const BackupCryptoCodec();

  String? validatePassphrase(String passphrase, {String? confirmation}) {
    final normalized = _normalizePassphrase(passphrase);
    if (normalized == null) {
      return '备份口令至少需要 $minimumPassphraseLength 个字符。';
    }
    if (confirmation != null && confirmation.trim() != normalized) {
      return '两次输入的口令不一致。';
    }
    return null;
  }

  Future<Uint8List> encrypt(List<int> bytes, {required String passphrase}) async {
    final validation = validatePassphrase(passphrase);
    if (validation != null) throw Exception(validation);

    final salt = _randomBytes(_kdfSaltLength);
    final nonce = _randomBytes(_gcmNonceLength);
    final secretKey = await _kdf.deriveKeyFromPassword(
      password: passphrase.trim(),
      nonce: salt,
    );
    final secretBox = await _cipher.encrypt(
      bytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return _EncryptedBackupEnvelope(
      salt: salt,
      nonce: secretBox.nonce,
      mac: secretBox.mac.bytes,
      cipherText: secretBox.cipherText,
    ).toBytes();
  }

  Future<Uint8List> decrypt(List<int> bytes, {required String passphrase}) async {
    final validation = validatePassphrase(passphrase);
    if (validation != null) throw Exception(validation);

    final envelope = _EncryptedBackupEnvelope.fromBytes(bytes);
    final secretKey = await _kdf.deriveKeyFromPassword(
      password: passphrase.trim(),
      nonce: envelope.salt,
    );

    try {
      final clearBytes = await _cipher.decrypt(
        SecretBox(
          envelope.cipherText,
          nonce: envelope.nonce,
          mac: Mac(envelope.mac),
        ),
        secretKey: secretKey,
      );
      return Uint8List.fromList(clearBytes);
    } on SecretBoxAuthenticationError {
      throw Exception('备份口令错误，或备份文件已损坏。');
    }
  }

  String? _normalizePassphrase(String passphrase) {
    final trimmed = passphrase.trim();
    return trimmed.length >= minimumPassphraseLength ? trimmed : null;
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }
}

class _EncryptedBackupEnvelope {
  final List<int> salt;
  final List<int> nonce;
  final List<int> mac;
  final List<int> cipherText;

  const _EncryptedBackupEnvelope({
    required this.salt,
    required this.nonce,
    required this.mac,
    required this.cipherText,
  });

  Uint8List toBytes() {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': BackupCryptoCodec._encryptedBackupFormat,
          'version': BackupCryptoCodec._encryptedBackupVersion,
          'algorithm': 'aes-256-gcm',
          'kdf': 'pbkdf2-hmac-sha256',
          'iterations': BackupCryptoCodec._pbkdf2Iterations,
          'salt': base64Encode(salt),
          'nonce': base64Encode(nonce),
          'mac': base64Encode(mac),
          'ciphertext': base64Encode(cipherText),
        }),
      ),
    );
  }

  factory _EncryptedBackupEnvelope.fromBytes(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      if (decoded['format'] != BackupCryptoCodec._encryptedBackupFormat ||
          decoded['version'] != BackupCryptoCodec._encryptedBackupVersion) {
        throw const FormatException();
      }
      return _EncryptedBackupEnvelope(
        salt: base64Decode(decoded['salt'] as String),
        nonce: base64Decode(decoded['nonce'] as String),
        mac: base64Decode(decoded['mac'] as String),
        cipherText: base64Decode(decoded['ciphertext'] as String),
      );
    } on FormatException {
      throw Exception('选择的文件不是有效的加密备份。');
    } on TypeError {
      throw Exception('选择的文件不是有效的加密备份。');
    }
  }
}
```

- [ ] **Step 4: Move bundle codec into service**

Create `lib/core/services/backup/backup_bundle_codec.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

class BackupBundle {
  final Uint8List databaseBytes;
  final Map<String, Uint8List> artworkFiles;
  final Map<String, String> sensitiveSettings;

  const BackupBundle({
    required this.databaseBytes,
    required this.artworkFiles,
    required this.sensitiveSettings,
  });
}

class BackupBundleCodec {
  static const _format = 'moyun_backup_bundle';
  static const _version = 1;

  const BackupBundleCodec();

  Uint8List encode({
    required List<int> databaseBytes,
    Map<String, List<int>> artworkFiles = const <String, List<int>>{},
    Map<String, String> sensitiveSettings = const <String, String>{},
  }) {
    final normalizedArtworkFiles = <String, String>{};
    for (final entry in artworkFiles.entries) {
      normalizedArtworkFiles[p.basename(entry.key)] = base64Encode(entry.value);
    }

    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': _format,
          'version': _version,
          'database': base64Encode(databaseBytes),
          'artwork_files': normalizedArtworkFiles,
          'sensitive_settings': sensitiveSettings,
        }),
      ),
    );
  }

  BackupBundle? tryDecode(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['format'] != _format || decoded['version'] != _version) {
        return null;
      }

      final rawArtworkFiles =
          decoded['artwork_files'] as Map<String, dynamic>? ?? const {};
      final rawSensitiveSettings =
          decoded['sensitive_settings'] as Map<String, dynamic>? ?? const {};
      final artworkFiles = <String, Uint8List>{};
      for (final entry in rawArtworkFiles.entries) {
        artworkFiles[p.basename(entry.key)] = Uint8List.fromList(
          base64Decode(entry.value as String),
        );
      }
      final sensitiveSettings = <String, String>{};
      for (final entry in rawSensitiveSettings.entries) {
        final key = entry.key.trim();
        final value = (entry.value as String).trim();
        if (key.isEmpty || value.isEmpty) continue;
        sensitiveSettings[key] = value;
      }

      return BackupBundle(
        databaseBytes: Uint8List.fromList(
          base64Decode(decoded['database'] as String),
        ),
        artworkFiles: artworkFiles,
        sensitiveSettings: sensitiveSettings,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
```

- [ ] **Step 5: Delegate from BackupHelper**

In `lib/core/utils/backup_helper.dart`, import the services:

```dart
import '../services/backup/backup_bundle_codec.dart';
import '../services/backup/backup_crypto_codec.dart';
import '../services/backup/backup_file_naming.dart';
```

Add static delegates:

```dart
  static const _fileNaming = BackupFileNaming();
  static const _cryptoCodec = BackupCryptoCodec();
  static const _bundleCodec = BackupBundleCodec();
```

Replace public helper bodies:

```dart
  static String buildBackupFileName([DateTime? at]) {
    return _fileNaming.buildPlainFileName(at ?? DateTime.now());
  }

  static String buildEncryptedBackupFileName([DateTime? at]) {
    return _fileNaming.buildEncryptedFileName(at ?? DateTime.now());
  }

  static bool hasSupportedBackupExtension(String filePath) {
    return _fileNaming.hasSupportedExtension(filePath);
  }

  static bool isEncryptedBackupPath(String filePath) {
    return _fileNaming.isEncryptedPath(filePath);
  }

  static String? validatePassphrase(String passphrase, {String? confirmation}) {
    return _cryptoCodec.validatePassphrase(
      passphrase,
      confirmation: confirmation,
    );
  }

  static Future<Uint8List> encryptBackupBytes(
    List<int> bytes, {
    required String passphrase,
  }) {
    return _cryptoCodec.encrypt(bytes, passphrase: passphrase);
  }

  static Future<Uint8List> decryptBackupBytes(
    List<int> bytes, {
    required String passphrase,
  }) {
    return _cryptoCodec.decrypt(bytes, passphrase: passphrase);
  }

  static Uint8List buildBackupBundleBytes({
    required List<int> databaseBytes,
    Map<String, List<int>> artworkFiles = const <String, List<int>>{},
    Map<String, String> sensitiveSettings = const <String, String>{},
  }) {
    return _bundleCodec.encode(
      databaseBytes: databaseBytes,
      artworkFiles: artworkFiles,
      sensitiveSettings: sensitiveSettings,
    );
  }
```

Keep `tryDecodeBackupBundleBytes` returning the current record type by mapping from `BackupBundle`.

- [ ] **Step 6: Run tests**

Run:

```powershell
flutter test --no-pub test/core/utils/backup_helper_test.dart
flutter test --no-pub test/core/services/backup/backup_file_naming_test.dart
flutter analyze --no-pub
```

Expected: pass.

- [ ] **Step 7: Commit**

```powershell
git add lib/core/services/backup lib/core/utils/backup_helper.dart test/core/services/backup test/core/utils/backup_helper_test.dart
git commit -m "Split backup helper codecs into focused services" -m "BackupHelper remains the public facade while filename, encryption, and bundle encoding responsibilities move into tested services.`n`nConstraint: Existing backup helper tests must continue to pass through the facade.`nConfidence: medium`nScope-risk: moderate`nTested: flutter test --no-pub test/core/utils/backup_helper_test.dart; flutter test --no-pub test/core/services/backup/backup_file_naming_test.dart; flutter analyze --no-pub"
```

---

### Task 11: Apply Clock To Providers

**Files:**
- Modify: `lib/core/providers/attendance_provider.dart`
- Modify: `lib/core/providers/home_workbench_provider.dart`
- Modify: `lib/core/providers/insight_provider.dart`
- Modify: `lib/core/providers/statistics_period_provider.dart`
- Test: `test/core/providers/statistics_period_provider_test.dart`
- Test: `test/core/providers/attendance_provider_test.dart`
- Depends on: Task 3

- [ ] **Step 1: Update providers to watch clock**

In each provider file, import:

```dart
import 'clock_provider.dart';
```

Use the clock where `DateTime.now()` controls provider output:

```dart
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return ref.watch(appClockProvider).now();
});
```

```dart
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = ref.watch(appClockProvider).now();
  return DateTime(now.year, now.month);
});
```

```dart
now: ref.read(appClockProvider).now(),
```

In `statistics_period_provider.dart`, replace direct calls:

```dart
final statisticsNowProvider = Provider<DateTime>((ref) {
  return ref.watch(appClockProvider).now();
});
```

Keep the existing stream provider if it is used for periodic refresh; only make range calculation read `statisticsNowProvider`.

- [ ] **Step 2: Add provider override test**

Extend `test/core/providers/statistics_period_provider_test.dart` with:

```dart
import 'package:moyun/core/providers/clock_provider.dart';
import 'package:moyun/core/services/app_clock.dart';
```

Add:

```dart
test('statisticsPeriodProvider uses injected app clock', () {
  final container = ProviderContainer(
    overrides: [
      appClockProvider.overrideWithValue(
        AppClock.fixed(DateTime(2026, 4, 27, 10)),
      ),
    ],
  );
  addTearDown(container.dispose);

  final range = container.read(statisticsPeriodProvider);

  expect(range.from, '2026-04-01');
  expect(range.to, '2026-04-30');
});
```

- [ ] **Step 3: Run provider tests**

Run:

```powershell
flutter test --no-pub test/core/providers/statistics_period_provider_test.dart test/core/providers/attendance_provider_test.dart
flutter analyze --no-pub
```

Expected: pass.

- [ ] **Step 4: Commit**

```powershell
git add lib/core/providers/attendance_provider.dart lib/core/providers/home_workbench_provider.dart lib/core/providers/insight_provider.dart lib/core/providers/statistics_period_provider.dart test/core/providers/statistics_period_provider_test.dart
git commit -m "Use injectable clock in time-sensitive providers" -m "Provider date ranges and workbench insights now read AppClock so tests can pin current time without global DateTime.now behavior.`n`nConstraint: Existing provider behavior must remain identical with the system clock.`nConfidence: medium`nScope-risk: moderate`nTested: flutter test --no-pub test/core/providers/statistics_period_provider_test.dart test/core/providers/attendance_provider_test.dart; flutter analyze --no-pub"
```

---

### Task 12: Extract Small UI Widgets From Large Screens

**Files:**
- Create: `lib/features/settings/widgets/settings_text_edit_sheet.dart`
- Create: `lib/features/students/widgets/student_detail_anchor_bar.dart`
- Modify: `lib/features/settings/screens/settings_screen.dart`
- Modify: `lib/features/students/screens/student_detail_screen.dart`
- Test: `test/features/settings/screens/settings_screen_test.dart`
- Test: `test/features/students/screens/student_detail_screen_test.dart`

- [ ] **Step 1: Extract settings text edit sheet**

Create `lib/features/settings/widgets/settings_text_edit_sheet.dart`:

```dart
import 'package:flutter/material.dart';

class SettingsTextEditSheet extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hintText;
  final int maxLines;
  final Future<void> Function(String value) onSave;

  const SettingsTextEditSheet({
    super.key,
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.maxLines,
    required this.onSave,
  });

  @override
  State<SettingsTextEditSheet> createState() => _SettingsTextEditSheetState();
}

class _SettingsTextEditSheetState extends State<SettingsTextEditSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_controller.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: widget.maxLines,
            decoration: InputDecoration(hintText: widget.hintText),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _handleSave,
              child: _saving
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('保存中...'),
                      ],
                    )
                  : const Text('保存修改'),
            ),
          ),
        ],
      ),
    );
  }
}
```

In `settings_screen.dart`, import the widget and replace `_TextEditSheet` usage:

```dart
builder: (_) => SettingsTextEditSheet(
  title: title,
  initialValue: current,
  hintText: hintText,
  maxLines: maxLines,
  onSave: onSave,
),
```

Remove private `_TextEditSheet` and `_TextEditSheetState` from the screen.

- [ ] **Step 2: Extract student detail anchor bar**

Create `lib/features/students/widgets/student_detail_anchor_bar.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../shared/theme.dart';

enum StudentDetailAnchor { finance, payments, attendance }

class StudentDetailAnchorBar extends StatelessWidget {
  final ValueChanged<StudentDetailAnchor> onSelect;

  const StudentDetailAnchorBar({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StudentDetailAnchorButton(
          label: '费用',
          icon: Icons.account_balance_wallet_outlined,
          onTap: () => onSelect(StudentDetailAnchor.finance),
        ),
        StudentDetailAnchorButton(
          label: '缴费',
          icon: Icons.payments_outlined,
          onTap: () => onSelect(StudentDetailAnchor.payments),
        ),
        StudentDetailAnchorButton(
          label: '出勤',
          icon: Icons.event_note_outlined,
          onTap: () => onSelect(StudentDetailAnchor.attendance),
        ),
      ],
    );
  }
}

class StudentDetailAnchorButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const StudentDetailAnchorButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: kPrimaryBlue),
      label: Text(label),
    );
  }
}
```

In `student_detail_screen.dart`, remove private `_StudentDetailAnchor`, `_StudentDetailAnchorBar`, and `_StudentDetailAnchorButton`. Import the extracted widget and update method signatures from `_StudentDetailAnchor` to `StudentDetailAnchor`.

- [ ] **Step 3: Run widget regressions**

Run:

```powershell
flutter test --no-pub test/features/settings/screens/settings_screen_test.dart test/features/students/screens/student_detail_screen_test.dart
flutter analyze --no-pub
```

Expected: pass. The settings save-disabled and student detail anchor button tests must still pass.

- [ ] **Step 4: Commit**

```powershell
git add lib/features/settings/widgets/settings_text_edit_sheet.dart lib/features/students/widgets/student_detail_anchor_bar.dart lib/features/settings/screens/settings_screen.dart lib/features/students/screens/student_detail_screen.dart
git commit -m "Extract reusable widgets from large screens" -m "Moves stable settings edit and student detail anchor widgets into focused files while keeping screen behavior unchanged.`n`nConstraint: This is a mechanical extraction, not a visual redesign.`nConfidence: medium`nScope-risk: moderate`nTested: flutter test --no-pub test/features/settings/screens/settings_screen_test.dart test/features/students/screens/student_detail_screen_test.dart; flutter analyze --no-pub"
```

---

### Task 13: Final Review And Release Gate

**Files:**
- Modify: `docs/iteration-roadmap.md`

- [ ] **Step 1: Run complete verification**

Run:

```powershell
dart format .
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug
```

Expected:

- `dart format .` completes without changed files after formatting is committed.
- `flutter analyze --no-pub` reports `No issues found`.
- `flutter test --no-pub` passes all tests.
- `flutter build apk --debug` produces a debug APK.

- [ ] **Step 2: Review code ownership and risk**

Run:

```powershell
git diff --stat
git diff --check
Get-ChildItem -Path lib,test -Recurse -Filter *.dart | ForEach-Object { $lines = (Get-Content -LiteralPath $_.FullName | Measure-Object -Line).Lines; [PSCustomObject]@{ Lines = $lines; Path = $_.FullName.Replace((Get-Location).Path + '\','') } } | Sort-Object Lines -Descending | Select-Object -First 20 | Format-Table -AutoSize
```

Expected:

- `git diff --check` prints no whitespace errors.
- The top large files should shrink or stop accumulating new logic.
- New files should be focused service/widget/test files.

- [ ] **Step 3: Update roadmap with actual completion evidence**

In `docs/iteration-roadmap.md`, add a section:

```md
## Optimization Pass Completed On 2026-04-27

Verification:
- `flutter analyze --no-pub` passed.
- `flutter test --no-pub` passed.
- `flutter build apk --debug` passed.

Completed improvements:
- Database documentation now has an automated drift guard.
- Time-sensitive provider behavior can be pinned through `AppClock`.
- Quick entry record construction is covered by a pure service test.
- Export parent snapshot calculation is covered by a pure service test.
- PDF report totals are covered outside the rendering class.
- Backup filename, crypto, and bundle behavior are split behind the existing facade.
- Settings and student detail screens have smaller extracted widgets.

Remaining risks:
- PDF visual output still needs manual inspection on a real generated report.
- Android backup and share flows still need one physical-device smoke test.
- Further screen decomposition should proceed only when touching the same screen for feature work.
```

- [ ] **Step 4: Final code review**

Review in this order:

```powershell
git diff -- docs
git diff -- lib/core
git diff -- lib/features/home
git diff -- lib/features/export
git diff -- lib/features/settings
git diff -- lib/features/students
git diff -- test
```

Check:

- No public labels changed unless tests were intentionally updated.
- No provider invalidation path was removed.
- No export or backup public helper was removed without a compatibility wrapper.
- No new dependency was added to `pubspec.yaml`.
- Tests prove behavior before and after each extraction.

- [ ] **Step 5: Commit**

```powershell
git add docs/iteration-roadmap.md
git commit -m "Record optimization verification evidence" -m "Updates the roadmap with completed optimization lanes, verification commands, and residual release risks.`n`nConstraint: Evidence must match commands run in this branch.`nConfidence: high`nScope-risk: narrow`nTested: dart format .; flutter analyze --no-pub; flutter test --no-pub; flutter build apk --debug"
```

---

## Self-Review

Spec coverage:

- Maintainability: Tasks 4, 5, 6, 7, 8, 9, 10, and 12 split large files behind pure services or focused widgets.
- Product experience: Tasks 4 through 9 preserve quick entry, export, parent snapshot, and PDF behavior while making future product changes safer.
- Performance confidence: Task 1 documents v6 indexes; Task 13 checks file sizes and build verification; provider clock work improves deterministic performance-related tests.
- Release quality: Tasks 1, 2, 11, and 13 add drift guards, remove test noise, and require full analyze/test/build verification.
- Parallel execution: Batch map provides independent lanes and dependencies.
- Code review: Every task has targeted tests, analyze, commit boundary, and final review checks.

Placeholder scan:

- No unresolved placeholder markers are used.
- Each code-creating step includes concrete code.
- Each test step includes exact commands and expected outcomes.

Type consistency:

- `AppClock`, `appClockProvider`, `QuickEntryRecordBuilder`, `ExportParentSnapshotService`, `PdfReportSummaryService`, and backup services are named consistently across tasks.
- UI integration tasks depend only on services introduced in earlier tasks.
