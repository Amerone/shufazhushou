import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/attendance.dart';
import '../../../core/models/handwriting_analysis_result.dart';
import '../../../core/providers/ai_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/invalidation_helper.dart';
import '../../../core/providers/student_provider.dart';
import '../../../core/services/ai_analysis_note_codec.dart';
import '../../../core/services/attendance_artwork_storage_service.dart';
import '../../../core/services/handwriting_analysis_service.dart';
import '../../../shared/constants.dart';
import '../../../shared/utils/toast.dart';
import 'attendance_ai_analysis_sheet.dart';

Future<void> launchAttendanceArtworkAnalysis(
  BuildContext context,
  WidgetRef ref, {
  required Attendance record,
  required String studentName,
  VoidCallback? onStarted,
  VoidCallback? onFinished,
  Future<void> Function()? onAttendanceSaved,
}) async {
  final service = ref.read(handwritingAnalysisServiceProvider);
  if (service == null) {
    AppToast.showError(context, '请先在设置中完成 AI 配置。');
    return;
  }

  final imageSource = await _pickArtworkImageSource(context);
  if (imageSource == null || !context.mounted) return;

  final image = await ImagePicker().pickImage(source: imageSource);
  if (image == null || !context.mounted) return;

  onStarted?.call();

  try {
    final result = await service.analyze(
      HandwritingAnalysisInput(
        imageSource: image.path,
        studentName: studentName,
      ),
    );
    await _saveArtworkImage(
      ref,
      record,
      image.path,
      onAttendanceSaved: onAttendanceSaved,
    );
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AttendanceAiAnalysisSheet(
        result: result,
        onApplySuggestion: () async {
          final nextPracticeNote = _buildPracticeSuggestionText(result);
          final applied = await _applyPracticeSuggestion(
            context,
            ref,
            record,
            nextPracticeNote,
            analysisResult: result,
            onAttendanceSaved: onAttendanceSaved,
          );
          if (applied && sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
        },
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    AppToast.showError(context, '图片分析失败，请稍后重试。');
  } finally {
    onFinished?.call();
  }
}

Future<ImageSource?> _pickArtworkImageSource(BuildContext context) async {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          color: Theme.of(sheetContext).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '上传课堂作品',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '可直接拍照，或从相册选择已有作品图片进行 AI 分析。',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('拍照分析'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('从相册选择'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _saveArtworkImage(
  WidgetRef ref,
  Attendance record,
  String imagePath, {
  Future<void> Function()? onAttendanceSaved,
}) async {
  final attendanceDao = ref.read(attendanceDaoProvider);
  final latestRecord = await attendanceDao.getById(record.id);
  if (latestRecord == null) {
    throw StateError('Attendance not found for artwork save');
  }

  final storedImagePath = await const AttendanceArtworkStorageService()
      .replaceArtwork(
        attendanceId: latestRecord.id,
        sourceImagePath: imagePath,
        previousImagePath: latestRecord.artworkImagePath,
      );

  await attendanceDao.update(
    latestRecord.copyWith(
      artworkImagePath: storedImagePath,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  invalidateAfterAttendanceChange(ref);
  if (onAttendanceSaved != null) {
    await onAttendanceSaved();
  }
}

Future<bool> _applyPracticeSuggestion(
  BuildContext context,
  WidgetRef ref,
  Attendance record,
  String suggestion, {
  HandwritingAnalysisResult? analysisResult,
  Future<void> Function()? onAttendanceSaved,
}) async {
  final normalizedSuggestion = suggestion.trim();
  if (normalizedSuggestion.isEmpty) {
    AppToast.showError(context, 'AI 未返回可写入的练习建议。');
    return false;
  }

  try {
    final attendanceDao = ref.read(attendanceDaoProvider);
    final latestRecord = await attendanceDao.getById(record.id);
    if (latestRecord == null) {
      if (context.mounted) {
        AppToast.showError(context, '未找到对应的出勤记录，无法更新练习建议。');
      }
      return false;
    }

    final oldNote = latestRecord.homePracticeNote?.trim() ?? '';
    final stamp = formatDate(DateTime.now());
    final mergedNote = oldNote.isEmpty
        ? normalizedSuggestion
        : '$oldNote\n\nAI 建议记录于 $stamp：\n$normalizedSuggestion';

    final updated = latestRecord.copyWith(
      homePracticeNote: mergedNote,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await attendanceDao.update(updated);
    if (analysisResult != null) {
      await _saveHandwritingAnalysisToStudentNote(
        ref,
        latestRecord,
        analysisResult,
      );
    }

    invalidateAfterAttendanceChange(ref);
    if (onAttendanceSaved != null) {
      await onAttendanceSaved();
    }

    if (!context.mounted) return true;
    AppToast.showSuccess(
      context,
      analysisResult == null ? '课后练习建议已更新。' : '课后练习建议已更新，并已纳入学生 AI 洞察。',
    );
    return true;
  } catch (_) {
    if (context.mounted) {
      AppToast.showError(
        context,
        analysisResult == null ? '更新课后练习建议失败，请稍后重试。' : '保存课后建议或作品分析失败，请稍后重试。',
      );
    }
    return false;
  }
}

Future<void> _saveHandwritingAnalysisToStudentNote(
  WidgetRef ref,
  Attendance record,
  HandwritingAnalysisResult result,
) async {
  final studentDao = ref.read(studentDaoProvider);
  final currentStudent = await studentDao.getById(record.studentId);
  if (currentStudent == null) {
    throw StateError('Student not found for handwriting analysis save');
  }

  final noteContent = _buildHandwritingAnalysisNoteContent(record, result);
  final latestContent = AiAnalysisNoteCodec.latestContent(
    currentStudent.note,
    type: 'handwriting',
  );
  if (latestContent?.trim() == noteContent) {
    return;
  }

  final mergedNote = AiAnalysisNoteCodec.appendHandwritingAnalysis(
    existingNote: currentStudent.note,
    analysisText: noteContent,
    analyzedAt: DateTime.now(),
  );

  await studentDao.update(
    currentStudent.copyWith(
      note: mergedNote,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  await ref.read(studentProvider.notifier).reload();
}

String _buildHandwritingAnalysisNoteContent(
  Attendance record,
  HandwritingAnalysisResult result,
) {
  final lines = <String>[
    '课堂日期：${record.date} ${record.startTime}-${record.endTime}',
  ];

  if (result.summary.trim().isNotEmpty) {
    lines.add('总体概览：${result.summary.trim()}');
  }
  if (result.strokeObservation.trim().isNotEmpty) {
    lines.add('笔画观察：${result.strokeObservation.trim()}');
  }
  if (result.structureObservation.trim().isNotEmpty) {
    lines.add('结构观察：${result.structureObservation.trim()}');
  }
  if (result.layoutObservation.trim().isNotEmpty) {
    lines.add('章法观察：${result.layoutObservation.trim()}');
  }
  if (result.practiceSuggestions.isNotEmpty) {
    lines.add('练习建议：');
    for (var i = 0; i < result.practiceSuggestions.length; i++) {
      lines.add('${i + 1}. ${result.practiceSuggestions[i]}');
    }
  }

  return lines.join('\n');
}

String _buildPracticeSuggestionText(HandwritingAnalysisResult result) {
  final suggestions = result.practiceSuggestions
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (suggestions.isNotEmpty) {
    return suggestions
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');
  }

  final fallbackParts = <String>[
    result.summary.trim(),
    result.strokeObservation.trim(),
    result.structureObservation.trim(),
    result.layoutObservation.trim(),
  ].where((item) => item.isNotEmpty);

  return fallbackParts.join('\n');
}
