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
import '../widgets/home_screen_components.dart';
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

  int _teacherProfileReadyCount(Map<String, String> settings) {
    final teacherName = settings['teacher_name']?.trim() ?? '';
    final institutionName = settings['institution_name']?.trim() ?? '';
    return [
      teacherName.isNotEmpty && teacherName != kDefaultTeacherName,
      institutionName.isNotEmpty && institutionName != kDefaultInstitutionName,
    ].where((item) => item).length;
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
      useSafeArea: true,
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
      useSafeArea: true,
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
    final studentsLoadState = ref.watch(
      studentProvider.select(
        (value) => (isLoading: value.isLoading, hasError: value.hasError),
      ),
    );
    final studentSummary = ref.watch(studentRosterSummaryProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? const {};
    final today = DateTime.now();

    final studentCount = studentSummary.count;
    final hasStudents = studentSummary.hasStudents;
    final studentLoading = studentsLoadState.isLoading && !hasStudents;
    final studentLoadFailed = studentsLoadState.hasError && !hasStudents;
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
    final teacherProfileReadyCount = _teacherProfileReadyCount(settings);
    final recentSelectedIds = parseQuickEntryRecentStudentIds(
      settings,
    ).intersection(studentSummary.ids);
    final recentStartTime = settings[quickEntryDefaultStartTimeSettingKey]
        ?.trim();
    final recentEndTime = settings[quickEntryDefaultEndTimeSettingKey]?.trim();
    final recentStatus = settings[quickEntryDefaultStatusSettingKey]?.trim();
    final showQuickLaunchPanel =
        hasStudents && (recentSelectedIds.isNotEmpty || templates.isNotEmpty);
    final showInitialSetupBanner =
        !hasStudents && !studentLoading && !studentLoadFailed;
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
    final String? headerSubtitle = studentLoadFailed
        ? '学生档案暂时无法读取，请重试。'
        : studentLoading
        ? '正在读取本地学生档案。'
        : hasStudents
        ? null
        : '\u5148\u65b0\u589e\u6216\u5bfc\u5165\u5b66\u751f';

    final homeTheme = theme.copyWith(
      splashColor: kPrimaryBlue.withValues(alpha: 0.08),
      highlightColor: kPrimaryBlue.withValues(alpha: 0.04),
      hoverColor: kPrimaryBlue.withValues(alpha: 0.03),
    );
    final bottomSystemInset = MediaQuery.viewPaddingOf(context).bottom;
    const bottomNavigationReserve = 80.0;
    final fabBottomPadding = bottomSystemInset + bottomNavigationReserve;
    final scrollEndPadding = fabBottomPadding + 96;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Theme(
        data: homeTheme,
        child: InkWashBackground(
          child: Column(
            children: [
              PageHeader(
                title: studentLoading
                    ? '正在加载'
                    : hasStudents || studentLoadFailed
                    ? '\u4eca\u65e5\u5de5\u4f5c\u53f0'
                    : '\u5f00\u59cb\u4f7f\u7528',
                subtitle: headerSubtitle,
                trailing: HomeTodayAction(
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
                    final hasLoadedStudents =
                        ref.read(studentProvider).valueOrNull?.isNotEmpty ??
                        false;
                    await Future.wait([
                      ref.read(studentProvider.notifier).reload(),
                      if (hasLoadedStudents)
                        ref.read(attendanceProvider.notifier).reload(),
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
                              HomeFocusCard(
                                monthLabel: monthLabel,
                                dateLabel: dateLabel,
                                dayCount: dayCount,
                                monthCount: monthCount,
                                taskCount: pendingTaskCount,
                                studentCount: studentCount,
                                isToday: isToday,
                                hasStudents: hasStudents,
                                isLoading: studentLoading,
                                hasLoadError: studentLoadFailed,
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
                                onRetryStudents: () =>
                                    ref.invalidate(studentProvider),
                              ),
                              if (hasStudents && pendingTaskCount > 0) ...[
                                const SizedBox(height: 16),
                                const HomeWorkbenchPanel(),
                              ],
                              if (showQuickLaunchPanel) ...[
                                const SizedBox(height: 16),
                                HomeQuickLaunchPanel(
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
                                      HomeQuickLaunchTemplateShortcut(
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
                                HomeInitialSetupBanner(
                                  readyCount: teacherProfileReadyCount,
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
                      if (hasStudents) ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: KeyedSubtree(
                              key: _attendanceSectionKey,
                              child: HomeSectionTitleRow(
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
                            child: HomeSectionTitleRow(
                              title: '\u672c\u6708\u8bfe\u5386',
                              countText: '$monthCount \u6b21',
                              color: kPrimaryBlue,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            12,
                            20,
                            scrollEndPadding,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: AttendanceCalendar(),
                          ),
                        ),
                      ] else
                        SliverToBoxAdapter(
                          child: SizedBox(height: scrollEndPadding),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: studentLoading || studentLoadFailed
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: fabBottomPadding),
              child: hasStudents
                  ? HomeQuickEntryAction(onPressed: _openQuickEntrySheet)
                  : HomeSetupAction(onPressed: _openCreateStudent),
            ),
    );
  }
}
