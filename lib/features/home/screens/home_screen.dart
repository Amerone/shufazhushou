import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/dao/student_dao.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/class_template_provider.dart';
import '../../../core/providers/home_workbench_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/constants.dart'
    show kDefaultInstitutionName, kDefaultTeacherName;
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';
import '../../students/widgets/student_action_launcher.dart';
import '../../students/widgets/student_picker_sheet.dart';
import '../widgets/attendance_calendar.dart';
import '../widgets/attendance_list.dart';
import '../widgets/home_workbench_panel.dart';
import '../widgets/quick_entry_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _attendanceSectionKey = GlobalKey();

  bool _isTeacherProfileReady(Map<String, String> settings) {
    final teacherName = settings['teacher_name']?.trim() ?? '';
    final institutionName = settings['institution_name']?.trim() ?? '';
    return (teacherName.isNotEmpty && teacherName != kDefaultTeacherName) ||
        (institutionName.isNotEmpty &&
            institutionName != kDefaultInstitutionName);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openQuickEntrySheet({
    Set<String> initialSelectedIds = const <String>{},
    String? initialStartTime,
    String? initialEndTime,
    String? initialStatus,
  }) async {
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickEntrySheet(
        initialSelectedIds: initialSelectedIds,
        initialStartTime: initialStartTime,
        initialEndTime: initialEndTime,
        initialStatus: initialStatus,
      ),
    );
  }

  Future<void> _openCreateStudent() async {
    await InteractionFeedback.pageTurn(context);
    if (!mounted) return;
    context.push('/students/create');
  }

  Future<void> _openImportStudents() async {
    await InteractionFeedback.pageTurn(context);
    if (!mounted) return;
    context.push('/students/import');
  }

  Future<void> _openPaymentEntry() async {
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    final selectedStudent = await showModalBottomSheet<StudentWithMeta>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const StudentPickerSheet(
        title: '\u9009\u62e9\u7f34\u8d39\u5b66\u751f',
        subtitle:
            '\u5148\u9009\u5b66\u751f\uff0c\u518d\u76f4\u63a5\u5f55\u5165\u672c\u6b21\u7f34\u8d39\u91d1\u989d\u3002',
        actionLabel: '\u8bb0\u5f55\u7f34\u8d39',
      ),
    );
    if (selectedStudent == null || !mounted) return;
    await showStudentPaymentSheet(
      context,
      studentId: selectedStudent.student.id,
      studentName: selectedStudent.student.name,
      pricePerClass: selectedStudent.student.pricePerClass,
    );
  }

  Future<void> _scrollToAttendanceSection() async {
    await InteractionFeedback.selection(context);
    if (!mounted) return;
    final targetContext = _attendanceSectionKey.currentContext;
    if (targetContext == null || !targetContext.mounted) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentSummary = ref.watch(studentRosterSummaryProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? const {};
    final today = DateTime.now();

    final studentCount = studentSummary.count;
    final hasStudents = studentSummary.hasStudents;
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final dayCount = hasStudents
        ? ref.watch(
            selectedDateAttendanceProvider.select(
              (value) => value.valueOrNull?.length ?? 0,
            ),
          )
        : 0;
    final monthCount = hasStudents
        ? ref.watch(
            attendanceProvider.select(
              (value) => value.valueOrNull?.length ?? 0,
            ),
          )
        : 0;
    final pendingTaskCount = hasStudents
        ? ref.watch(
            homeWorkbenchProvider.select(
              (value) => value.valueOrNull?.length ?? 0,
            ),
          )
        : 0;
    final templates = hasStudents
        ? ref.watch(classTemplateProvider).valueOrNull ?? const []
        : const [];
    final teacherReady = _isTeacherProfileReady(settings);
    final recentSelectedIds = parseQuickEntryRecentStudentIds(
      settings,
    ).intersection(studentSummary.ids);
    final recentStartTime = settings[quickEntryDefaultStartTimeSettingKey]
        ?.trim();
    final recentEndTime = settings[quickEntryDefaultEndTimeSettingKey]?.trim();
    final recentStatus = settings[quickEntryDefaultStatusSettingKey]?.trim();
    final showQuickLaunchPanel =
        hasStudents && (recentSelectedIds.isNotEmpty || templates.isNotEmpty);
    final showInitialSetupBanner = !hasStudents;
    final recentTimeLabel =
        isQuickEntryValidTimeValue(recentStartTime) &&
            isQuickEntryValidTimeValue(recentEndTime)
        ? '$recentStartTime-$recentEndTime'
        : null;

    final monthLabel = DateFormat(
      'yyyy\u5e74M\u6708',
      'zh_CN',
    ).format(selectedMonth);
    final dateLabel = DateFormat(
      'M\u6708d\u65e5 EEEE',
      'zh_CN',
    ).format(selectedDate);
    final isToday =
        selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
    final sectionTitle = isToday
        ? '\u4eca\u65e5\u51fa\u52e4\u540d\u5355'
        : '$dateLabel \u51fa\u52e4\u540d\u5355';
    final String? headerSubtitle = hasStudents
        ? null
        : '\u5148\u65b0\u589e\u6216\u5bfc\u5165\u5b66\u751f';

    final homeTheme = theme.copyWith(
      splashColor: kPrimaryBlue.withValues(alpha: 0.08),
      highlightColor: kPrimaryBlue.withValues(alpha: 0.04),
      hoverColor: kPrimaryBlue.withValues(alpha: 0.03),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Theme(
        data: homeTheme,
        child: InkWashBackground(
          child: Column(
            children: [
              PageHeader(
                title: hasStudents
                    ? '\u4eca\u65e5\u5de5\u4f5c\u53f0'
                    : '\u5f00\u59cb\u4f7f\u7528',
                subtitle: headerSubtitle,
                trailing: _TodayAction(
                  onPressed: () {
                    unawaited(InteractionFeedback.selection(context));
                    ref.read(selectedDateProvider.notifier).state = today;
                    ref.read(selectedMonthProvider.notifier).state = DateTime(
                      today.year,
                      today.month,
                    );
                  },
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: kSealRed,
                  edgeOffset: 20,
                  displacement: 28,
                  onRefresh: () async {
                    await Future.wait([
                      ref.read(attendanceProvider.notifier).reload(),
                      ref.read(studentProvider.notifier).reload(),
                    ]);
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _HomeFocusCard(
                                monthLabel: monthLabel,
                                dateLabel: dateLabel,
                                dayCount: dayCount,
                                monthCount: monthCount,
                                taskCount: pendingTaskCount,
                                studentCount: studentCount,
                                isToday: isToday,
                                hasStudents: hasStudents,
                                onQuickEntry: () => _openQuickEntrySheet(),
                                onOpenStudents: () async {
                                  await InteractionFeedback.pageTurn(context);
                                  if (!context.mounted) return;
                                  context.go('/students');
                                },
                                onOpenTodayAttendance:
                                    _scrollToAttendanceSection,
                                onOpenPaymentEntry: _openPaymentEntry,
                                onCreateStudent: _openCreateStudent,
                                onImportStudents: _openImportStudents,
                              ),
                              if (hasStudents && pendingTaskCount > 0) ...[
                                const SizedBox(height: 16),
                                const HomeWorkbenchPanel(),
                              ],
                              if (showQuickLaunchPanel) ...[
                                const SizedBox(height: 16),
                                _QuickLaunchPanel(
                                  recentGroupCount: recentSelectedIds.length,
                                  recentTimeLabel: recentTimeLabel,
                                  onOpenRecentGroup: recentSelectedIds.isEmpty
                                      ? null
                                      : () => _openQuickEntrySheet(
                                          initialSelectedIds: recentSelectedIds,
                                          initialStartTime:
                                              isQuickEntryValidTimeValue(
                                                recentStartTime,
                                              )
                                              ? recentStartTime
                                              : null,
                                          initialEndTime:
                                              isQuickEntryValidTimeValue(
                                                recentEndTime,
                                              )
                                              ? recentEndTime
                                              : null,
                                          initialStatus:
                                              quickEntryStatuses.any(
                                                (item) =>
                                                    item.$1 == recentStatus,
                                              )
                                              ? recentStatus
                                              : null,
                                        ),
                                  templateShortcuts: [
                                    for (final template in templates.take(3))
                                      _QuickLaunchTemplateShortcut(
                                        title: template.name,
                                        timeLabel:
                                            '${template.startTime}-${template.endTime}',
                                        onTap: () => _openQuickEntrySheet(
                                          initialStartTime: template.startTime,
                                          initialEndTime: template.endTime,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              if (showInitialSetupBanner) ...[
                                const SizedBox(height: 16),
                                _InitialSetupBanner(
                                  teacherReady: teacherReady,
                                  onOpenSetup: () async {
                                    await InteractionFeedback.pageTurn(context);
                                    if (!context.mounted) return;
                                    context.push('/setup');
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          hasStudents ? 28 : 24,
                          20,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: KeyedSubtree(
                            key: _attendanceSectionKey,
                            child: _SectionTitleRow(
                              title: sectionTitle,
                              countText: '$dayCount \u6761',
                              color: kSealRed,
                            ),
                          ),
                        ),
                      ),
                      const SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: GlassCard(
                            padding: EdgeInsets.fromLTRB(20, 16, 20, 18),
                            child: AttendanceList(),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _SectionTitleRow(
                            title: '\u672c\u6708\u8bfe\u5386',
                            countText: '$monthCount \u6b21',
                            color: kPrimaryBlue,
                          ),
                        ),
                      ),
                      const SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 120),
                        sliver: SliverToBoxAdapter(child: AttendanceCalendar()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 80,
        ),
        child: hasStudents
            ? _QuickEntryAction(onPressed: _openQuickEntrySheet)
            : _SetupAction(onPressed: _openCreateStudent),
      ),
    );
  }
}

class _HomeFocusCard extends StatelessWidget {
  final String monthLabel;
  final String dateLabel;
  final int dayCount;
  final int monthCount;
  final int taskCount;
  final int studentCount;
  final bool isToday;
  final bool hasStudents;
  final VoidCallback onQuickEntry;
  final VoidCallback onOpenStudents;
  final VoidCallback onOpenTodayAttendance;
  final VoidCallback onOpenPaymentEntry;
  final VoidCallback onCreateStudent;
  final VoidCallback onImportStudents;

  const _HomeFocusCard({
    required this.monthLabel,
    required this.dateLabel,
    required this.dayCount,
    required this.monthCount,
    required this.taskCount,
    required this.studentCount,
    required this.isToday,
    required this.hasStudents,
    required this.onQuickEntry,
    required this.onOpenStudents,
    required this.onOpenTodayAttendance,
    required this.onOpenPaymentEntry,
    required this.onCreateStudent,
    required this.onImportStudents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingCount = taskCount;
    final statusText = !hasStudents
        ? '\u5148\u5efa\u7acb\u5b66\u751f\u6863\u6848'
        : pendingCount > 0
        ? '\u5f85\u5904\u7406 $pendingCount \u9879'
        : '\u4eca\u65e5\u5df2\u8bb0 $dayCount \u8282\u8bfe';

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.66),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: kInkSecondary.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  monthLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kSealRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasStudents
                      ? (isToday
                            ? '\u4eca\u65e5\u4f18\u5148'
                            : '\u5f53\u524d\u65e5\u671f')
                      : '\u9996\u6b21\u5efa\u6863',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kSealRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasStudents
                ? dateLabel
                : '\u5148\u5efa\u7acb\u5b66\u751f\u6863\u6848',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HomeStatusPill(label: '今日出勤 $dayCount', color: kSealRed),
              _HomeStatusPill(label: '本月课次 $monthCount', color: kPrimaryBlue),
              _HomeStatusPill(
                label: hasStudents ? '学生总数 $studentCount' : statusText,
                color: kOrange,
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final primaryWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              final secondaryWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;

              if (!hasStudents) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: primaryWidth,
                      child: FilledButton.icon(
                        onPressed: onCreateStudent,
                        style: FilledButton.styleFrom(
                          backgroundColor: kSealRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('\u65b0\u589e\u5b66\u751f'),
                      ),
                    ),
                    SizedBox(
                      width: primaryWidth,
                      child: OutlinedButton.icon(
                        onPressed: onImportStudents,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('\u6279\u91cf\u5bfc\u5165'),
                      ),
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: compact ? constraints.maxWidth : primaryWidth,
                    child: FilledButton.icon(
                      onPressed: onQuickEntry,
                      style: FilledButton.styleFrom(
                        backgroundColor: kSealRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.brush_outlined),
                      label: const Text('\u7acb\u5373\u8bb0\u8bfe'),
                    ),
                  ),
                  SizedBox(
                    width: secondaryWidth,
                    child: FilledButton.tonalIcon(
                      onPressed: onOpenTodayAttendance,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(
                        isToday
                            ? '\u67e5\u770b\u4eca\u65e5\u51fa\u52e4'
                            : '\u67e5\u770b\u5f53\u5929\u51fa\u52e4',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: secondaryWidth,
                    child: OutlinedButton.icon(
                      onPressed: onCreateStudent,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('\u65b0\u589e\u5b66\u751f'),
                    ),
                  ),
                ],
              );
            },
          ),
          if (hasStudents) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenPaymentEntry,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('\u8bb0\u5f55\u7f34\u8d39'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenStudents,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.people_alt_outlined, size: 18),
                  label: const Text('\u5b66\u751f\u6863\u6848'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _HomeStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuickLaunchTemplateShortcut {
  final String title;
  final String timeLabel;
  final VoidCallback onTap;

  const _QuickLaunchTemplateShortcut({
    required this.title,
    required this.timeLabel,
    required this.onTap,
  });
}

class _QuickLaunchPanel extends StatelessWidget {
  final int recentGroupCount;
  final String? recentTimeLabel;
  final VoidCallback? onOpenRecentGroup;
  final List<_QuickLaunchTemplateShortcut> templateShortcuts;

  const _QuickLaunchPanel({
    required this.recentGroupCount,
    required this.recentTimeLabel,
    required this.onOpenRecentGroup,
    required this.templateShortcuts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '\u5e38\u7528\u8bb0\u8bfe\u6377\u5f84',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kSealRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '\u5c11\u8d70\u4e00\u6b65',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kSealRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (onOpenRecentGroup != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPrimaryBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kPrimaryBlue.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.history_outlined,
                      color: kPrimaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\u6309\u6700\u8fd1\u73ed\u7ea7\u8bb0\u8bfe',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: onOpenRecentGroup,
                    child: const Text('\u53bb\u8bb0\u8bfe'),
                  ),
                ],
              ),
            ),
          ],
          if (templateShortcuts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '\u6309\u5e38\u7528\u65f6\u6bb5\u6253\u5f00',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final itemWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final shortcut in templateShortcuts)
                      SizedBox(
                        width: itemWidth,
                        child: OutlinedButton(
                          onPressed: shortcut.onTap,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_outlined,
                                    size: 18,
                                    color: kPrimaryBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      shortcut.title,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  shortcut.timeLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: kPrimaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _InitialSetupBanner extends StatelessWidget {
  final bool teacherReady;
  final VoidCallback onOpenSetup;

  const _InitialSetupBanner({
    required this.teacherReady,
    required this.onOpenSetup,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readyCount = [teacherReady].where((item) => item).length;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '\u9996\u6b21\u4f7f\u7528\u5efa\u8bae\u5148\u5b8c\u6210\u5f15\u5bfc',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kPrimaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$readyCount/2 \u5df2\u5b8c\u6210',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onOpenSetup,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('\u67e5\u770b\u5f00\u8bfe\u5f15\u5bfc'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  final String title;
  final String countText;
  final Color color;

  const _SectionTitleRow({
    required this.title,
    required this.countText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.14)),
          ),
          child: Text(
            countText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayAction extends StatelessWidget {
  final VoidCallback onPressed;

  const _TodayAction({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryBlue,
        backgroundColor: Colors.white.withValues(alpha: 0.58),
        overlayColor: kSealRed.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: kInkSecondary.withValues(alpha: 0.18)),
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.today_outlined, size: 18),
      label: const Text('\u56de\u5230\u4eca\u5929'),
    );
  }
}

class _QuickEntryAction extends StatelessWidget {
  final VoidCallback onPressed;

  const _QuickEntryAction({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kSealRed.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'home-quick-entry',
        onPressed: onPressed,
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: kSealRed,
        foregroundColor: Colors.white,
        splashColor: Colors.white.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        icon: const Icon(Icons.brush_outlined),
        label: const Text(
          '\u7acb\u5373\u8bb0\u8bfe',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
      ),
    );
  }
}

class _SetupAction extends StatelessWidget {
  final VoidCallback onPressed;

  const _SetupAction({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'home-setup-entry',
      onPressed: onPressed,
      elevation: 0,
      highlightElevation: 0,
      backgroundColor: kPrimaryBlue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text(
        '\u65b0\u589e\u5b66\u751f',
        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
      ),
    );
  }
}
