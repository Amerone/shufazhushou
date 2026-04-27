# Project Optimization Execution Strategy

> Companion to `docs/superpowers/plans/2026-04-27-project-optimization.md`. This document does not replace the implementation plan; it defines how to run it safely in parallel with review and regression gates.

**Goal:** Execute the full optimization plan with parallel lanes while keeping behavior stable and regressions visible.

**Default Execution Mode:** Subagent-driven execution is preferred because the work naturally splits by ownership. Inline execution remains acceptable if only one engineer/session is available.

---

## Execution Lanes

### Lane A: Quality Baseline And Documentation

**Owned Tasks:** Task 1, Task 2, Task 13

**Purpose:** Make the project verifiable before refactors begin, then record completion evidence at the end.

**Write Scope:**
- `docs/database-design.md`
- `docs/iteration-roadmap.md`
- `test/docs/database_design_consistency_test.dart`
- `test/helpers/fake_settings_notifier.dart`
- `test/shared/widgets/attendance_edit_sheet_test.dart`

**Primary Checks:**
```powershell
flutter test --no-pub test/docs/database_design_consistency_test.dart
flutter test --no-pub test/shared/widgets/attendance_edit_sheet_test.dart
flutter analyze --no-pub
```

**Review Focus:**
- Docs match runtime facts.
- Test helper does not hide real app behavior.
- Final roadmap evidence matches commands actually run.

### Lane B: Time Determinism

**Owned Tasks:** Task 3, Task 11

**Purpose:** Replace scattered provider-level `DateTime.now()` dependencies with an injectable clock where it affects provider output.

**Write Scope:**
- `lib/core/services/app_clock.dart`
- `lib/core/providers/clock_provider.dart`
- `lib/core/providers/attendance_provider.dart`
- `lib/core/providers/home_workbench_provider.dart`
- `lib/core/providers/insight_provider.dart`
- `lib/core/providers/statistics_period_provider.dart`
- `test/core/services/app_clock_test.dart`
- `test/core/providers/statistics_period_provider_test.dart`
- `test/core/providers/attendance_provider_test.dart`

**Primary Checks:**
```powershell
flutter test --no-pub test/core/services/app_clock_test.dart
flutter test --no-pub test/core/providers/statistics_period_provider_test.dart test/core/providers/attendance_provider_test.dart
flutter analyze --no-pub
```

**Review Focus:**
- Do not inject clock into every UI timestamp in this pass.
- Only replace time reads that shape provider state or service decisions.
- Existing default behavior must still use current system time.

### Lane C: Home Quick Entry

**Owned Tasks:** Task 4, Task 5

**Purpose:** Pull attendance record construction out of the large quick-entry sheet while keeping UI behavior unchanged.

**Write Scope:**
- `lib/features/home/services/quick_entry_record_builder.dart`
- `lib/features/home/widgets/quick_entry_sheet.dart`
- `test/features/home/services/quick_entry_record_builder_test.dart`
- `test/features/home/widgets/quick_entry_sheet_test.dart`

**Primary Checks:**
```powershell
flutter test --no-pub test/features/home/services/quick_entry_record_builder_test.dart
flutter test --no-pub test/features/home/widgets/quick_entry_sheet_test.dart
flutter analyze --no-pub
```

**Review Focus:**
- Conflict overwrite must preserve existing feedback and artwork unless the new entry supplies replacements.
- Provider invalidation must still call `invalidateAfterAttendanceChange(ref)`.
- No route, button text, or semantics label should change.

### Lane D: Export And PDF

**Owned Tasks:** Task 6, Task 7, Task 8, Task 9

**Purpose:** Split export snapshot, temp-file cleanup, and PDF report calculations into focused services.

**Write Scope:**
- `lib/features/export/services/export_parent_snapshot_service.dart`
- `lib/features/export/services/export_temp_file_cleaner.dart`
- `lib/features/export/screens/export_config_screen.dart`
- `lib/core/services/pdf_report_summary_service.dart`
- `lib/core/utils/pdf_generator.dart`
- `test/features/export/services/export_parent_snapshot_service_test.dart`
- `test/features/export/screens/export_config_screen_test.dart`
- `test/core/services/pdf_report_summary_service_test.dart`

**Primary Checks:**
```powershell
flutter test --no-pub test/features/export/services/export_parent_snapshot_service_test.dart
flutter test --no-pub test/features/export/screens/export_config_screen_test.dart
flutter test --no-pub test/core/services/pdf_report_summary_service_test.dart
flutter analyze --no-pub
```

**Review Focus:**
- `ExportConfigScreen` should remain responsible for UI state and user actions only.
- Existing testing wrappers for temp-file cleanup must stay available unless all test imports are updated.
- `PdfGenerator` layout should not be redesigned in this lane.

### Lane E: Backup Decomposition

**Owned Tasks:** Task 10

**Purpose:** Keep `BackupHelper` as public facade while splitting naming, crypto, and bundle codec logic.

**Write Scope:**
- `lib/core/services/backup/backup_file_naming.dart`
- `lib/core/services/backup/backup_crypto_codec.dart`
- `lib/core/services/backup/backup_bundle_codec.dart`
- `lib/core/utils/backup_helper.dart`
- `test/core/services/backup/backup_file_naming_test.dart`
- `test/core/services/backup/backup_crypto_codec_test.dart`
- `test/core/services/backup/backup_bundle_codec_test.dart`
- `test/core/utils/backup_helper_test.dart`

**Primary Checks:**
```powershell
flutter test --no-pub test/core/utils/backup_helper_test.dart
flutter test --no-pub test/core/services/backup/backup_file_naming_test.dart
flutter test --no-pub test/core/services/backup/backup_crypto_codec_test.dart
flutter test --no-pub test/core/services/backup/backup_bundle_codec_test.dart
flutter analyze --no-pub
```

**Review Focus:**
- Do not change encrypted backup format.
- Do not change passphrase validation messages unless tests explicitly assert the new text.
- Keep restore compatibility for plain `.db`, `.sqlite`, `.sqlite3`, and `.moyunbak`.

### Lane F: Screen Widget Extraction

**Owned Tasks:** Task 12

**Purpose:** Reduce screen file size by extracting stable widgets without changing product behavior.

**Write Scope:**
- `lib/features/settings/widgets/settings_text_edit_sheet.dart`
- `lib/features/students/widgets/student_detail_anchor_bar.dart`
- `lib/features/settings/screens/settings_screen.dart`
- `lib/features/students/screens/student_detail_screen.dart`
- `test/features/settings/screens/settings_screen_test.dart`
- `test/features/students/screens/student_detail_screen_test.dart`

**Primary Checks:**
```powershell
flutter test --no-pub test/features/settings/screens/settings_screen_test.dart
flutter test --no-pub test/features/students/screens/student_detail_screen_test.dart
flutter analyze --no-pub
```

**Review Focus:**
- This is mechanical extraction only.
- Keep labels, icons, button text, and disabled/saving states unchanged.
- Avoid introducing a new shared design abstraction.

---

## Merge Order

Use this order when integrating independently completed lanes:

1. Lane A baseline tasks: Task 1 and Task 2.
2. Lane B foundation: Task 3.
3. Lane C service task: Task 4.
4. Lane D service tasks: Task 6 and Task 8.
5. Lane E service extraction: Task 10.
6. Lane B provider integration: Task 11.
7. Lane C integration: Task 5.
8. Lane D integrations: Task 7 and Task 9.
9. Lane F mechanical widget extraction: Task 12.
10. Lane A final gate: Task 13.

If conflicts occur, prefer the branch with the smaller completed service extraction and reapply UI integration afterward.

---

## Review Protocol

Every task gets two review passes.

### Pass 1: Local Task Review

Check:
- Test added before implementation for behavior-bearing changes.
- New service has a single clear responsibility.
- Existing public functions remain available unless the plan explicitly removes them.
- No new dependencies in `pubspec.yaml`.
- No broad renames or unrelated formatting outside touched files.

Commands:
```powershell
git diff --check
flutter analyze --no-pub
```

### Pass 2: Lane Regression Review

Run the lane's targeted tests. Then inspect the affected diff:

```powershell
git diff -- lib
git diff -- test
```

Accept only if:
- Targeted tests pass.
- Analyzer passes.
- The diff matches the lane write scope.
- Behavior changes are either absent or explicitly covered by tests.

---

## Regression Matrix

| Risk | Guard |
| --- | --- |
| Database docs drift again | `test/docs/database_design_consistency_test.dart` |
| Widget tests touch real sqflite settings | `test/helpers/fake_settings_notifier.dart` |
| Quick-entry overwrite loses feedback or artwork | `test/features/home/services/quick_entry_record_builder_test.dart` and existing widget test |
| Export snapshot changes balance state text | `test/features/export/services/export_parent_snapshot_service_test.dart` |
| Export temp files leak or delete too early | `test/features/export/screens/export_config_screen_test.dart` |
| PDF report totals change silently | `test/core/services/pdf_report_summary_service_test.dart` |
| Backup compatibility breaks | `test/core/utils/backup_helper_test.dart` plus codec tests |
| Time-sensitive providers become non-deterministic | `test/core/services/app_clock_test.dart` and provider tests |
| Screen extraction changes user-visible controls | settings and student detail widget tests |

---

## Final Acceptance

The optimization pass is complete only after:

```powershell
dart format .
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug
```

Expected final state:
- All commands pass.
- `git diff --check` is clean.
- No new dependency added.
- Large files have either shrunk or stopped receiving new business logic.
- `docs/iteration-roadmap.md` records exact verification evidence.

Manual smoke tests still recommended after automated completion:
- Generate one PDF from a student with attendance and payments.
- Export one Excel report.
- Create one plain backup and one encrypted backup.
- Restore a backup on an Android device or emulator snapshot.
- Use quick entry with a conflict and choose “返回改时间” and “覆盖并保存”.

---

## Assignment Template

Use this template when dispatching each task:

```md
You are implementing Task <N> from:
docs/superpowers/plans/2026-04-27-project-optimization.md

Stay inside this write scope:
- <files>

Do not edit unrelated files. Do not change product behavior unless the task explicitly requires it.

Before coding:
- Read the task section.
- Read the current target files.
- Run the failing targeted test if the task asks for one.

After coding:
- Run the task's targeted tests.
- Run `flutter analyze --no-pub`.
- Report changed files, test results, and any residual risk.
```

---

## Stop Conditions

Pause the optimization pass if:
- A task requires a data migration beyond documentation/index alignment.
- A UI extraction changes visible behavior and the existing tests do not define the intended behavior.
- Backup restore compatibility is unclear after codec extraction.
- `flutter analyze --no-pub` fails in a way unrelated to the task's write scope.

In those cases, document the blocker in the task result and do not merge that lane until the blocker has a targeted test or an explicit design update.
