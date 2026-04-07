import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/dao/student_dao.dart';
import '../../../core/providers/attendance_provider.dart';
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
    final hasStudents = (asyncStudents.valueOrNull?.length ?? 0) > 0;
    final teacherReady = _isTeacherProfileReady(settings);

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
                            dateLabel: dateLabel,
                            dayCount: dayCount,
                            monthCount: monthCount,
                            isToday: isToday,
                            hasStudents: hasStudents,
                            onQuickEntry: () => _openQuickEntrySheet(),
                            onOpenTodayAttendance: _scrollToAttendanceSection,
                            onOpenPaymentEntry: _openPaymentEntry,
                            onCreateStudent: _openCreateStudent,
                            onImportStudents: _openImportStudents,
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
                      if (hasStudents && (pendingTaskCount ?? 0) > 0)
                        const SliverPadding(
                          padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: HomeWorkbenchPanel(),
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
  final String dateLabel;
  final int dayCount;
  final int monthCount;
  final bool isToday;
  final bool hasStudents;
  final VoidCallback onQuickEntry;
  final VoidCallback onOpenTodayAttendance;
  final VoidCallback onOpenPaymentEntry;
  final VoidCallback onCreateStudent;
  final VoidCallback onImportStudents;

  const _HomeFocusCard({
    required this.dateLabel,
    required this.dayCount,
    required this.monthCount,
    required this.isToday,
    required this.hasStudents,
    required this.onQuickEntry,
    required this.onOpenTodayAttendance,
    required this.onOpenPaymentEntry,
    required this.onCreateStudent,
    required this.onImportStudents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasStudents
                          ? (isToday ? '今天' : dateLabel)
                          : '先建学生档案',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hasStudents) ...[
                      const SizedBox(height: 4),
                      Text(
                        '今日 $dayCount 人出勤，本月共 $monthCount 次',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: kInkSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasStudents)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCreateStudent,
                    style: FilledButton.styleFrom(
                      backgroundColor: kSealRed,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('新增学生'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
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
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final secondaryWidth =
                    (constraints.maxWidth - 12) / 2;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: onQuickEntry,
                      style: FilledButton.styleFrom(
                        backgroundColor: kSealRed,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: const Icon(Icons.brush_outlined),
                      label: const Text('立即记课'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: secondaryWidth,
                          child: OutlinedButton.icon(
                            onPressed: onOpenTodayAttendance,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text('查看出勤'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: secondaryWidth,
                          child: OutlinedButton.icon(
                            onPressed: onOpenPaymentEntry,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('记录缴费'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
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
