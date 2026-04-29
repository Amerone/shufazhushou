import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/utils/interaction_feedback.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';

class InitialSetupScreen extends ConsumerWidget {
  const InitialSetupScreen({super.key});

  bool _isTeacherProfileReady(Map<String, String> settings) {
    final teacherName = settings['teacher_name']?.trim() ?? '';
    final institutionName = settings['institution_name']?.trim() ?? '';
    return (teacherName.isNotEmpty && teacherName != kDefaultTeacherName) ||
        (institutionName.isNotEmpty &&
            institutionName != kDefaultInstitutionName);
  }

  Future<void> _openRoute(
    BuildContext context,
    String route, {
    bool replace = false,
  }) async {
    await InteractionFeedback.pageTurn(context);
    if (!context.mounted) return;
    if (replace) {
      context.go(route);
      return;
    }
    context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull ?? const {};
    final asyncStudents = ref.watch(studentProvider);
    final studentCount = asyncStudents.valueOrNull?.length ?? 0;
    final hasStudents = studentCount > 0;
    final teacherReady = _isTeacherProfileReady(settings);
    final readyCount = [
      teacherReady,
      hasStudents,
      hasStudents,
    ].where((item) => item).length;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: '开课前先准备好',
              subtitle: '教师、学生、首页入口。',
              trailing: hasStudents
                  ? TextButton.icon(
                      onPressed: () => _openRoute(context, '/', replace: true),
                      icon: const Icon(Icons.arrow_forward_outlined, size: 18),
                      label: const Text('进入首页'),
                    )
                  : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                children: [
                  GlassCard(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 360;
                            final titleBlock = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '今天先完成这 3 步',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '完成后即可记课、查出勤、记缴费。',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            );
                            final icon = Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: kPrimaryBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.auto_stories_outlined,
                                color: kPrimaryBlue,
                              ),
                            );

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  icon,
                                  const SizedBox(height: 10),
                                  titleBlock,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                icon,
                                const SizedBox(width: 10),
                                Expanded(child: titleBlock),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.54),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: kInkSecondary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SetupMetric(
                                  label: '进度',
                                  value: '$readyCount/3',
                                  color: kSealRed,
                                ),
                              ),
                              Expanded(
                                child: _SetupMetric(
                                  label: '学生',
                                  value: '$studentCount',
                                  color: kPrimaryBlue,
                                ),
                              ),
                              Expanded(
                                child: _SetupMetric(
                                  label: '保存',
                                  value: '本机',
                                  color: kGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SetupStepCard(
                    indexLabel: '第一步',
                    title: '设置教师抬头与机构名',
                    description: teacherReady ? '首页和报告会沿用当前抬头。' : '用于首页和导出报告。',
                    statusLabel: teacherReady ? '已就绪' : '待设置',
                    statusColor: teacherReady ? kGreen : kOrange,
                    icon: Icons.edit_note_outlined,
                    accentColor: kPrimaryBlue,
                    actionLabel: teacherReady ? '继续调整' : '去设置',
                    onTap: () => _openRoute(context, '/settings'),
                  ),
                  const SizedBox(height: 12),
                  _SetupStepCard(
                    indexLabel: '第二步',
                    title: '建立首批学生档案',
                    description: hasStudents
                        ? '已有 $studentCount 位学生。'
                        : '新增学生，或批量导入 Excel。',
                    statusLabel: hasStudents ? '已完成' : '待完成',
                    statusColor: hasStudents ? kGreen : kSealRed,
                    icon: Icons.groups_2_outlined,
                    accentColor: kSealRed,
                    primaryActionLabel: '新增学生',
                    onPrimaryTap: () => _openRoute(context, '/students/create'),
                    secondaryActionLabel: '批量导入',
                    onSecondaryTap: () =>
                        _openRoute(context, '/students/import'),
                  ),
                  const SizedBox(height: 12),
                  _SetupStepCard(
                    indexLabel: '第三步',
                    title: '回到首页开始记课',
                    description: hasStudents ? '首页第一屏可直接操作。' : '先准备学生档案。',
                    statusLabel: hasStudents ? '可以开始' : '等待学生',
                    statusColor: hasStudents ? kGreen : kInkSecondary,
                    icon: Icons.dashboard_customize_outlined,
                    accentColor: kGreen,
                    actionLabel: '进入首页',
                    onTap: hasStudents
                        ? () => _openRoute(context, '/', replace: true)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SetupMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SetupStepCard extends StatelessWidget {
  final String indexLabel;
  final String title;
  final String description;
  final String statusLabel;
  final Color statusColor;
  final IconData icon;
  final Color accentColor;
  final String? actionLabel;
  final VoidCallback? onTap;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryTap;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryTap;

  const _SetupStepCard({
    required this.indexLabel,
    required this.title,
    required this.description,
    required this.statusLabel,
    required this.statusColor,
    required this.icon,
    required this.accentColor,
    this.actionLabel,
    this.onTap,
    this.primaryActionLabel,
    this.onPrimaryTap,
    this.secondaryActionLabel,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDualActions =
        primaryActionLabel != null &&
        onPrimaryTap != null &&
        secondaryActionLabel != null &&
        onSecondaryTap != null;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      indexLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          if (hasDualActions)
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final itemWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: FilledButton.icon(
                        onPressed: onPrimaryTap,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(primaryActionLabel!),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: OutlinedButton.icon(
                        onPressed: onSecondaryTap,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(secondaryActionLabel!),
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_outlined, size: 18),
                label: Text(actionLabel ?? '继续'),
              ),
            ),
        ],
      ),
    );
  }
}
