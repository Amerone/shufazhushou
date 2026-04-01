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
    show formatDate, kDefaultInstitutionName, kDefaultTeacherName;
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
        title: '选择缴费学生',
        subtitle: '先选学生，再直接录入本次缴费金额。',
        actionLabel: '记录缴费',
      ),
    );
    if (selectedStudent == null || !mounted) return;
    await showStudentPaymentSheet(
      context,
      studentId: selectedStudent.student.id,
      studentName: selectedStudent.student.name,
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
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final asyncRecords = ref.watch(attendanceProvider);
    final workbenchTasks = ref.watch(homeWorkbenchProvider);
    final asyncStudents = ref.watch(studentProvider);
    final templates = ref.watch(classTemplateProvider).valueOrNull ?? const [];
    final settings = ref.watch(settingsProvider).valueOrNull ?? const {};
    final today = DateTime.now();

    final dateStr = formatDate(selectedDate);
    final dayCount =
        asyncRecords.valueOrNull
            ?.where((record) => record.date == dateStr)
            .length ??
        0;
    final monthKey = DateFormat('yyyy-MM', 'zh_CN').format(selectedMonth);
    final monthCount =
        asyncRecords.valueOrNull
            ?.where((record) => record.date.startsWith(monthKey))
            .length ??
        0;
    final pendingTaskCount = workbenchTasks.valueOrNull?.length;
    final studentCount = asyncStudents.valueOrNull?.length ?? 0;
    final hasStudents = studentCount > 0;
    final teacherReady = _isTeacherProfileReady(settings);
    final studentIds = {
      for (final item in asyncStudents.valueOrNull ?? const <StudentWithMeta>[])
        item.student.id,
    };
    final recentSelectedIds = parseQuickEntryRecentStudentIds(
      settings,
    ).intersection(studentIds);
    final recentStartTime = settings[quickEntryDefaultStartTimeSettingKey]
        ?.trim();
    final recentEndTime = settings[quickEntryDefaultEndTimeSettingKey]?.trim();
    final recentStatus = settings[quickEntryDefaultStatusSettingKey]?.trim();
    final recentTimeLabel =
        isQuickEntryValidTimeValue(recentStartTime) &&
            isQuickEntryValidTimeValue(recentEndTime)
        ? '$recentStartTime-$recentEndTime'
        : null;

    final monthLabel = DateFormat('yyyy年M月', 'zh_CN').format(selectedMonth);
    final dateLabel = DateFormat('M月d日 EEEE', 'zh_CN').format(selectedDate);
    final isToday =
        selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
    final sectionTitle = isToday ? '今日出勤名单' : '$dateLabel 出勤名单';
    final headerSubtitle = !hasStudents
        ? '先建立学生档案，再开始记课、查出勤和记录缴费。'
        : isToday
        ? '先看今天谁已出勤，再继续记课或记录缴费。'
        : '$dateLabel 已选中，可继续核对当日出勤和课程记录。';

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
                title: hasStudents ? '今日工作台' : '开始使用',
                subtitle: headerSubtitle,
                trailing: _TodayAction(
                  onPressed: () {
                    unawaited(InteractionFeedback.selection(context));
                    ref.read(selectedDateProvider.notifier).state = today;
                    ref.read(selectedMonthProvider.notifier).state = DateTime(
                      today.year,
                      today.month,
                    );
                    ref.read(attendanceProvider.notifier).reload();
                  },
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: kSealRed,
                  edgeOffset: 20,
                  displacement: 28,
                  onRefresh: () async {
                    ref.read(attendanceProvider.notifier).reload();
                    await ref.read(studentProvider.notifier).reload();
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _HomeFocusCard(
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
                            onOpenTodayAttendance: _scrollToAttendanceSection,
                            onOpenPaymentEntry: _openPaymentEntry,
                            onCreateStudent: _openCreateStudent,
                            onImportStudents: _openImportStudents,
                          ),
                        ),
                      ),
                      if (hasStudents &&
                          (recentSelectedIds.isNotEmpty ||
                              templates.isNotEmpty))
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: _QuickLaunchPanel(
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
                                            (item) => item.$1 == recentStatus,
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
                          ),
                        ),
                      if (!hasStudents)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: _InitialSetupBanner(
                              teacherReady: teacherReady,
                              onOpenSetup: () async {
                                await InteractionFeedback.pageTurn(context);
                                if (!context.mounted) return;
                                context.push('/setup');
                              },
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          hasStudents ? 24 : 20,
                          20,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: KeyedSubtree(
                            key: _attendanceSectionKey,
                            child: _SectionTitleRow(
                              title: sectionTitle,
                              countText: '$dayCount 条',
                              color: kSealRed,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: GlassCard(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasStudents
                                      ? '按时间顺序查看和调整当日出勤记录'
                                      : '建好学生后，这里会直接显示当天谁出勤了。',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const AttendanceList(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (hasStudents)
                        const SliverPadding(
                          padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: HomeWorkbenchPanel(),
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
                          child: _SectionTitleRow(
                            title: '本月课历',
                            countText: '$monthCount 次',
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
  final int? taskCount;
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
    final pendingCount = taskCount ?? 0;
    final nextActionText = !hasStudents
        ? '下一步：先新增第一位学生，之后就能直接记课、查当天出勤和记录缴费。'
        : dayCount == 0
        ? '下一步：先记录今天第一节课，稍后这里会直接显示当天出勤名单。'
        : pendingCount > 0
        ? '下一步：先处理 $pendingCount 项待办，再继续查看今日出勤与缴费情况。'
        : '下一步：核对当天出勤后，可继续记录缴费或查看学生档案。';

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
                  hasStudents ? (isToday ? '今日优先' : '当前日期') : '首次建档',
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
            hasStudents ? dateLabel : '先建学生档案',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextActionText,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 3 : 2;
              final itemWidth =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '今日出勤',
                      value: '$dayCount',
                      hint: '当前日期',
                      color: kSealRed,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '本月课次',
                      value: '$monthCount',
                      hint: monthLabel,
                      color: kPrimaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '学生档案',
                      value: '$studentCount',
                      hint: hasStudents ? '当前总人数' : '先从 1 位开始',
                      color: kOrange,
                    ),
                  ),
                ],
              );
            },
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
                  : (constraints.maxWidth - 24) / 3;

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
                        label: const Text('新增学生'),
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
                        label: const Text('批量导入'),
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
                    width: primaryWidth,
                    child: FilledButton.icon(
                      onPressed: onQuickEntry,
                      style: FilledButton.styleFrom(
                        backgroundColor: kSealRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.brush_outlined),
                      label: const Text('立即记课'),
                    ),
                  ),
                  SizedBox(
                    width: secondaryWidth,
                    child: OutlinedButton.icon(
                      onPressed: onOpenTodayAttendance,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(isToday ? '查看今日出勤' : '查看当天出勤'),
                    ),
                  ),
                  SizedBox(
                    width: secondaryWidth,
                    child: OutlinedButton.icon(
                      onPressed: onOpenPaymentEntry,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('记录缴费'),
                    ),
                  ),
                  SizedBox(
                    width: secondaryWidth,
                    child: OutlinedButton.icon(
                      onPressed: onOpenStudents,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.people_alt_outlined),
                      label: const Text('学生档案'),
                    ),
                  ),
                ],
              );
            },
          ),
          if (hasStudents) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kInkSecondary.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: kPrimaryBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '下方课历可切换查询日期，查看任意一天谁出勤了。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: kPrimaryBlue,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
                  '常用记课捷径',
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
                  '少走一步',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kSealRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '直接按最近班级或常用时段开始记课，打开后仍可继续改人、改时间。',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
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
                          '按最近班级记课',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recentTimeLabel == null
                              ? '已预选最近同班的 $recentGroupCount 位学员。'
                              : '已预选最近同班的 $recentGroupCount 位学员，沿用 $recentTimeLabel。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: onOpenRecentGroup,
                    child: const Text('去记课'),
                  ),
                ],
              ),
            ),
          ],
          if (templateShortcuts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '按常用时段打开',
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
                  '首次使用建议先完成引导',
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
                  '$readyCount/2 已准备',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '先完善老师信息，再新增或导入学生，首页的记课和缴费入口就会顺手很多。',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SetupStatusChip(
                icon: Icons.edit_note_outlined,
                label: teacherReady ? '教师抬头已就绪' : '教师抬头待设置',
                color: teacherReady ? kGreen : kOrange,
              ),
              const _SetupStatusChip(
                icon: Icons.groups_2_outlined,
                label: '学生档案待建立',
                color: kSealRed,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onOpenSetup,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('查看开课引导'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SetupStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
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
      label: const Text('回到今天'),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: kInkSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'NotoSansSC',
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(hint, style: theme.textTheme.bodySmall),
        ],
      ),
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
          '立即记课',
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
        '新增学生',
        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
      ),
    );
  }
}
