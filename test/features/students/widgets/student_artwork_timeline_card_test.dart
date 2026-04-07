import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyun/core/models/student_artwork_timeline_entry.dart';
import 'package:moyun/features/students/widgets/student_artwork_timeline_card.dart';
import 'package:moyun/shared/theme.dart';

void main() {
  testWidgets('renders artwork timeline entries with progress and practice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: StudentArtworkTimelineCard(
            entries: [
              StudentArtworkTimelineEntry(
                createdAt: DateTime(2026, 3, 30, 21, 0),
                lessonDate: '2026-03-30',
                lessonTimeRange: '18:00-19:30',
                summary: '结构更稳，字形收得更集中',
                strokeObservation: '起收笔更利落',
                structureObservation: '左右留白更均衡',
                layoutObservation: '整行节奏更顺',
                practiceSuggestions: const ['保持起收笔节奏', '继续检查中宫'],
                focusTags: const ['结构', '章法'],
                progressLabel: '较上次更稳',
                scoreSummary: '笔画 3.8 / 结构 4.1',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('作品成长时间线'), findsOneWidget);
    expect(find.text('2026-03-30 18:00-19:30'), findsOneWidget);
    expect(find.text('较上次更稳'), findsOneWidget);
    expect(find.textContaining('保持起收笔节奏'), findsOneWidget);
  });

  testWidgets('can expand timeline to view older artwork entries', (
    tester,
  ) async {
    final entries = List.generate(
      7,
      (index) => StudentArtworkTimelineEntry(
        createdAt: DateTime(2026, 3, 30 - index, 21, 0),
        lessonDate: '2026-03-${(30 - index).toString().padLeft(2, '0')}',
        lessonTimeRange: '18:00-19:30',
        summary: '第 ${index + 1} 次作品总结',
        strokeObservation: '',
        structureObservation: '',
        layoutObservation: '',
        practiceSuggestions: const [],
        focusTags: const [],
        progressLabel: index == 0 ? '较上次更稳' : '与上次接近',
        scoreSummary: '',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: StudentArtworkTimelineCard(entries: entries),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('展开更多'), findsOneWidget);
    expect(find.text('2026-03-24 18:00-19:30'), findsNothing);

    await tester.ensureVisible(find.text('展开更多'));
    await tester.tap(find.text('展开更多'));
    await tester.pumpAndSettle();

    expect(find.text('2026-03-24 18:00-19:30'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);
  });
}
