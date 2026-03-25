import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/dao/student_dao.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/student_provider.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ink_wash_background.dart';
import '../../../shared/widgets/page_header.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncStudents = ref.watch(studentProvider);

        return Scaffold(
      backgroundColor: Colors.transparent,
      body: InkWashBackground(
        child: Column(
          children: [
            PageHeader(
              title: asyncStudents.whenOrNull(
                    data: (list) => '学生 (${list.length})',
                  ) ??
                  '学生',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.upload_file),
                    tooltip: '导入',
                    onPressed: () => context.push('/students/import'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '新增',
                    onPressed: () => context.push('/students/create'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '搜索姓名或家长电话',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: kSealRed,
                onRefresh: () async {
                  ref.read(studentProvider.notifier).reload();
                },
                child: asyncStudents.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('加载失败: $e')),
                  data: (list) {
                    final filtered = _query.isEmpty
                        ? list
                        : list.where((m) {
                            final s = m.student;
                            return s.name.contains(_query) ||
                                (s.parentPhone?.contains(_query) ?? false);
                          }).toList();

                    if (filtered.isEmpty) {
                      return ListView(
                        children: [
                          _query.isNotEmpty
                              ? const EmptyState(message: '无搜索结果')
                              : EmptyState(
                                  message: '暂无学生，去添加',
                                  actionLabel: '添加学生',
                                  onAction: () => context.push('/students/create'),
                                ),
                        ],
                      );
                    }

                    final displayNames = buildDisplayNameMap(
                        filtered.map((m) => m.student).toList());
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _StudentCard(filtered[i], displayNames),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentWithMeta meta;
  final Map<String, String> displayNames;
  const _StudentCard(this.meta, this.displayNames);

  @override
  Widget build(BuildContext context) {
    final s = meta.student;
    final theme = Theme.of(context);
    final isSuspended = s.status != 'active';
    return Opacity(
      opacity: isSuspended ? 0.55 : 1.0,
      child: ListTile(
        leading: isSuspended
            ? const Icon(Icons.pause_circle_outline, color: Colors.grey)
            : null,
        title: Text(displayNames[s.id] ?? s.name),
        subtitle: Text(isSuspended
            ? '¥${s.pricePerClass.toStringAsFixed(0)}/节  休学'
            : '¥${s.pricePerClass.toStringAsFixed(0)}/节  在读'),
        trailing: meta.lastAttendanceDate != null
            ? Text(
                meta.lastAttendanceDate!,
                style: theme.textTheme.bodySmall,
              )
            : null,
        onTap: () => context.push('/students/${s.id}'),
      ),
    );
  }
}
