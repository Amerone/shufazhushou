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
                practiceSuggestions: ['保持起收笔节奏', '继续检查中宫'],
                focusTags: ['结构', '章法'],
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
}
