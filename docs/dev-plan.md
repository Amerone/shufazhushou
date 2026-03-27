# 开发计划文档

> 全程 AI 开发。每个任务为独立的 AI 执行单元，包含明确的输入、输出和验收标准。
> 任务按依赖顺序排列，同一阶段内无依赖的任务可并行执行。

---

## 阶段总览

| 阶段 | 名称 | 任务数 | 依赖 |
|------|------|--------|------|
| P0 | 项目骨架 | 5 | 无 |
| P1 | 数据层 | 6 | P0 |
| P2 | 学生模块 | 5 | P1 |
| P3 | 首页模块 | 5 | P1 |
| P4 | 统计模块 | 5 | P1 |
| P5 | 设置模块 | 4 | P1 |
| P6 | 导出模块 | 3 | P2, P3 |
| P7 | 集成收尾 | 2 | P2~P6 |

---

## P0 · 项目骨架

### P0-1 初始化 Flutter 项目

**目标：** 创建可运行的空白 Flutter 项目，配置所有依赖。

**输出文件：**
- `pubspec.yaml` — 含全部依赖（见 tech-stack.md）
- `lib/main.dart` — 入口，初始化 Riverpod
- `lib/app.dart` — MaterialApp + go_router 路由表（占位路由）
- `android/app/src/main/AndroidManifest.xml` — 权限声明

**验收：** `flutter run` 可启动，显示空白页面，无编译错误。

---

### P0-2 主题与常量

**目标：** 定义全局主题色、文字样式、间距常量。

**输出文件：**
- `lib/shared/theme.dart` — ThemeData，品牌色常量
- `lib/shared/constants.dart` — 出勤状态枚举、洞察类型枚举、字符串常量

**关键内容：**
```dart
// 出勤状态
enum AttendanceStatus { present, late, leave, absent, trial }

// 洞察类型
enum InsightType { debt, churn, peak, trial }

// 颜色
const kPrimaryBlue = Color(0xFF1565C0);
const kGreen = Color(0xFF2E7D32);
const kOrange = Color(0xFFE65100);
const kRed = Color(0xFFC62828);

// 业务常量
const kPeakThreshold = 3;        // 高峰提示阈值：周平均出勤人数
const kChurnDays = 21;           // 流失预警天数
const kBackupWarningDays = 7;    // 备份超期警告天数

// 出勤率公式（排除请假和试听）
// 出勤率 = (present + late) / (present + late + absent) × 100%
```

**验收：** 枚举和常量可在其他文件正常 import。

---

### P0-3 数据模型

**目标：** 创建所有数据模型类，支持 `fromMap` / `toMap` 序列化。

**输出文件：**
- `lib/core/models/student.dart`
- `lib/core/models/attendance.dart`
- `lib/core/models/payment.dart`
- `lib/core/models/class_template.dart`
- `lib/core/models/setting.dart`
- `lib/core/models/dismissed_insight.dart`

**每个模型必须包含：**
- 所有字段（对应 database-design.md）
- `factory Model.fromMap(Map<String, dynamic> map)`
- `Map<String, dynamic> toMap()`
- `copyWith(...)` 方法

**验收：** 所有模型可实例化，fromMap(toMap()) 往返一致。

---

### P0-4 数据库初始化

**目标：** 实现 SQLite 数据库的创建、版本管理。

**输出文件：**
- `lib/core/database/database_helper.dart`

**关键内容：**
- 单例模式
- `onOpen`：执行 `PRAGMA foreign_keys = ON`（必须，否则级联删除不生效）；**直接用 `db` 参数执行 SQL** 清理过期高峰提示忽略记录（不通过 DAO 单例，避免 `await database` 循环等待死锁）：`await db.delete('dismissed_insights', where: "insight_type = 'peak' AND dismissed_at < ?", whereArgs: [DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch])`
- `onCreate`：按顺序执行 database-design.md 中所有 CREATE TABLE + CREATE INDEX
- `onUpgrade`：预留空实现
- 暴露 `Future<Database> get database`

**验收：** App 启动后数据库文件存在，可用 DB Browser 打开验证表结构；删除学生后其出勤记录同步删除。

---

### P0-5 基础共享组件

**目标：** 创建所有页面依赖的基础 UI 组件，必须在 P2~P6 之前完成。

**输出文件：**
- `lib/shared/widgets/empty_state.dart` — 空状态组件（插画占位 + 文案 + 操作按钮）
- `lib/shared/utils/toast.dart` — 全局反馈工具

**toast.dart 必须实现：**
```dart
static void showSuccess(BuildContext context, String msg)   // 绿色 SnackBar
static void showError(BuildContext context, String msg)     // 弹窗，含原因
static Future<bool> showConfirm(BuildContext context, String msg) // 二次确认，返回用户选择
```

**验收：** 可在任意页面调用，不依赖具体 feature 模块。

---

## P1 · 数据层

### P1-1 DAO — 学生

**目标：** 实现 students 表的全部数据操作。

**输出文件：** `lib/core/database/dao/student_dao.dart`

**必须实现的方法：**
```dart
Future<void> insert(Student student)
Future<void> update(Student student)
Future<void> delete(String id)
Future<Student?> getById(String id)
Future<List<Student>> getAll()
Future<List<Student>> search(String keyword)  // 按姓名或家长电话
Future<void> batchInsert(List<Student> students)
// 返回学生列表，附带最近出勤日期（子查询）
// StudentWithMeta 在本文件内定义：{ Student student, String? lastAttendanceDate }
Future<List<StudentWithMeta>> getStudentsWithLastAttendance()
```

---

### P1-2 DAO — 出勤

**输出文件：** `lib/core/database/dao/attendance_dao.dart`

**基础 CRUD：**
```dart
Future<void> insert(Attendance record)
Future<void> update(Attendance record)
Future<void> delete(String id)
Future<List<Attendance>> getByDate(String date)
Future<List<Attendance>> getByStudent(String studentId)
// 按学生+日期范围查询（from/to 可空，null 表示全量）
// SQL: WHERE student_id=? AND (? IS NULL OR date>=?) AND (? IS NULL OR date<=?)
Future<List<Attendance>> getByStudentAndDateRange(String studentId, String? from, String? to)
Future<List<Attendance>> getByDateRange(String from, String to)
Future<Attendance?> findConflict(String studentId, String date, String startTime, String endTime)
```

**统计聚合查询（P4 统计模块必需）：**
```dart
// 按月聚合应收金额（收入趋势图）
// 返回 List<{month: 'YYYY-MM', totalFee: double}>
Future<List<Map<String, dynamic>>> getMonthlyRevenue(String from, String to)

// 按学生聚合出勤节数和金额（贡献榜单）
// 返回 List<{studentId, studentName, attendanceCount, totalFee}>（JOIN students 表）
Future<List<Map<String, dynamic>>> getStudentContribution(String from, String to)

// 按星期+小时分组计数（时段热力图）
// 返回 List<{weekday: 1-7, hour: 0-23, count: int}>
Future<List<Map<String, dynamic>>> getTimeHeatmap(String from, String to)

// 按状态分组计数（状态分布环形图）
// 返回 List<{status: String, count: int}>
Future<List<Map<String, dynamic>>> getStatusDistribution(String from, String to)

// 按状态+日期范围筛选（状态分布点击扇区后的列表）
Future<List<Attendance>> getByDateRangeAndStatus(String from, String to, String status)

// 核心指标聚合（P4-1 指标卡片）
// 返回 {totalFee, presentCount, lateCount, absentCount, activeStudentCount}
Future<Map<String, dynamic>> getMetrics(String from, String to)
```

---

### P1-3 DAO — 缴费

**输出文件：**
- `lib/core/database/dao/payment_dao.dart`

**payment_dao 方法：**
```dart
Future<void> insert(Payment payment)
Future<void> delete(String id)
Future<List<Payment>> getByStudent(String studentId)
Future<double> getTotalByStudent(String studentId)
Future<double> getTotalByStudentAndDateRange(String studentId, String? from, String? to)
// 按月聚合实收（收入趋势图实收折线）
// 返回 List<{month: 'YYYY-MM', totalReceived: double}>
Future<List<Map<String, dynamic>>> getMonthlyReceived(String from, String to)
```

---

### P1-4 DAO — 模板 & 设置 & 洞察忽略

**输出文件：**
- `lib/core/database/dao/class_template_dao.dart`
- `lib/core/database/dao/settings_dao.dart`
- `lib/core/database/dao/dismissed_insight_dao.dart`

**class_template_dao 方法：**
```dart
Future<void> insert(ClassTemplate template)
Future<void> update(ClassTemplate template)
Future<void> delete(String id)
Future<List<ClassTemplate>> getAll()
```

**settings_dao 方法：**
```dart
Future<String?> get(String key)
Future<void> set(String key, String value)
Future<Map<String, String>> getAll()
```

**dismissed_insight_dao 方法：**
```dart
Future<void> insert(DismissedInsight record)
Future<DismissedInsight?> find(String insightType, String? studentId)
Future<void> deleteByStudentAndType(String insightType, String? studentId)
Future<void> deleteExpired() // 按类型策略清理过期记录
```

---

### P1-5 费用计算器

**目标：** 封装所有费用计算逻辑，供 Provider 调用。

**输出文件：** `lib/core/utils/fee_calculator.dart`

**必须实现：**
```dart
// 费用汇总结果（在此文件内定义，无需单独模型文件）
class StudentFeeSummary {
  final double totalReceivable; // 总应收
  final double totalReceived;   // 总已收
  final double balance;         // 余额（正=欠费，负=预存）
}

// fee_summary_provider 的 family 参数封装类（在此文件内定义）
class FeeSummaryParams {
  final String studentId;
  final String? from; // null 表示全量
  final String? to;
  const FeeSummaryParams(this.studentId, {this.from, this.to});
  // 必须实现 == 和 hashCode 供 Riverpod family 缓存使用
}

// 计算单条出勤的费用
static double calcFee(AttendanceStatus status, double priceSnapshot)

// 计算学生汇总（from/to 为 null 表示全量）
static Future<StudentFeeSummary> calcSummary(
  String studentId,
  AttendanceDao attendanceDao,
  PaymentDao paymentDao, {
  String? from,
  String? to,
})
// 内部调用：
// attendanceDao.getByStudentAndDateRange → SUM(fee_amount)
// paymentDao.getTotalByStudentAndDateRange
// balance = totalReceived - totalReceivable（正=预存，负=欠费）
```

---

### P1-6 Riverpod Providers

**目标：** 创建全局数据 Provider，供所有 UI 层使用。

**输出文件：** `lib/core/providers/`
- `database_provider.dart` — DatabaseHelper 单例 Provider
- `student_provider.dart` — 学生列表、搜索状态
- `attendance_provider.dart` — **当月全量出勤记录**（供日历角标聚合）+ 选中日期的出勤列表 + 选中日期状态；月份切换时重新加载当月数据
- `fee_summary_provider.dart` — 学生费用汇总，参数为 `(studentId, from, to)` 三元组（使用 Riverpod `family` + 封装 `FeeSummaryParams` 类）
- `statistics_period_provider.dart` — 统计周期状态（周/月/年 + 当前时间范围），P4 所有组件共享此 provider
- `status_filter_provider.dart` — 状态分布筛选状态（`String? selectedStatus`），P4-3 环形图与列表共享
- `metrics_provider.dart` — 核心指标数据（调用 `attendanceDao.getMetrics`，监听 `statisticsPeriodProvider`）
- `revenue_provider.dart` — 收入趋势数据（调用 getMonthlyRevenue + getMonthlyReceived，**固定显示最近 12 个月**，不受 statisticsPeriodProvider 影响）
- `contribution_provider.dart` — 贡献榜单数据（调用 getStudentContribution，监听 statisticsPeriodProvider）
- `status_distribution_provider.dart` — 状态分布数据（调用 getStatusDistribution，监听 statisticsPeriodProvider）
- `heatmap_provider.dart` — 时段热力图数据（调用 getTimeHeatmap，监听 statisticsPeriodProvider）
- `insight_provider.dart` — 洞察列表计算（欠费/流失/高峰/试听转化）
- `settings_provider.dart` — 设置读写
- `class_template_provider.dart` — 课堂模板列表（P3-3 快速录入步骤 2 使用）

**规范：**
- 使用 `AsyncNotifierProvider` 处理异步数据
- 使用 `StateProvider` 处理简单 UI 状态（如选中日期）
- 统计类 provider 监听 `statistics_period_provider`，周期变化时自动刷新
- `statistics_period_provider` 暴露 `(String from, String to)` 供所有统计 provider 使用

---

## P2 · 学生模块

### P2-1 学生列表页

**输出文件：** `lib/features/students/screens/student_list_screen.dart`

**功能：**
- 展示所有学生（姓名、单价、状态、最近出勤时间）
- 启动时调用 `getStudentsWithLastAttendance()` 加载完整列表到 `student_provider`
- 搜索在客户端对 `List<StudentWithMeta>` 过滤（按姓名或家长电话），无需额外 DB 查询
- 右上角"+"按钮 → 跳转 `/students/create`
- 右上角"导入"按钮 → 触发 Excel 导入流程
- 点击学生卡片 → 跳转 `/students/:id`
- 空状态：插画 + "暂无学生，去添加"

---

### P2-2 新增/编辑学生页

**输出文件：** `lib/features/students/screens/student_form_screen.dart`

**字段：** 姓名（必填）、家长姓名、家长电话、单价（必填）、状态
**逻辑：**
- 编辑模式：修改单价时弹窗红字提示"此修改仅对新记录生效"
- 删除学生：二次确认弹窗

---

### P2-3 学生详情页

**输出文件：** `lib/features/students/screens/student_detail_screen.dart`

**布局（参考 PRD 页面 2）：**
- 顶部信息卡片（姓名、家长、单价）
- 费用概览（**本月**应收/已收/余额，监听 `feeSummaryProvider(studentId, from: 月初, to: 月末)`，余额颜色区分）
- 功能按钮：[生成报告] [记录缴费]
- 出勤时间轴列表（"加载更多"按钮分页，每次 20 条）
- 点击出勤记录 → 打开 `AttendanceEditSheet`（P3-4）

---

### P2-4 缴费

**输出文件：**
- `lib/features/students/widgets/payment_bottom_sheet.dart` — 记录缴费弹窗

由 P2-3 的 [记录缴费] 按钮触发的**底部半屏弹窗**。

**缴费表单（payment_bottom_sheet）：** 金额（必填正数）、日期（默认今日）、备注

保存后按 invalidation 表刷新：缴费记录 → `feeSummaryProvider`、`revenue_provider`、`insight_provider`。

---

### P2-5 Excel 批量导入

**输出文件：** `lib/core/utils/excel_importer.dart`

**逻辑：**
1. 用 file_picker 选择 .xlsx 文件
2. 解析第一个 Sheet，**按第一行列名匹配**（不区分大小写空格）：`姓名`（必填）、`家长姓名`、`家长电话`、`单价`
3. 预览解析结果（总行数、跳过行数、错误原因列表）
4. 确认后批量写入 students 表
5. 同名学生（姓名完全相同）跳过并计入跳过数

**导入模板：** 在设置页提供"下载导入模板"按钮，生成含列名的空白 Excel 文件供老师填写。

---

## P3 · 首页模块

### P3-1 月历组件

**输出文件：** `lib/features/home/widgets/attendance_calendar.dart`

**基于 `table_calendar` 封装：**
- 有出勤记录的日期显示角标
- 角标颜色：有旷课=红，全出勤=绿，混合=橙
- 点击日期 → 更新选中日期 Provider
- 支持左右滑动切换月份

**数据源：** 从 attendance_provider 获取当月所有记录，按日期聚合角标状态

---

### P3-2 出勤列表

**输出文件：** `lib/features/home/widgets/attendance_list.dart`

**展示选中日期的出勤卡片：**
- 时间段、学生姓名、状态图标、备注摘要
- 点击卡片 → 打开 `AttendanceEditSheet`（P3-4，共享组件）
- 长按卡片 → 弹出删除确认

---

### P3-3 快速录入底部弹窗

**输出文件：** `lib/features/home/widgets/quick_entry_sheet.dart`

**三步流程：**
1. 选学生（列表 + 搜索框，支持多选）
2. 选时间（模板列表 + 自定义时间选择器）+ 选状态（5 个状态按钮）
3. 确认摘要页（显示所有选中学生的记录预览）

**多选学生规则：** 所有选中学生共用同一时间段和状态，批量生成记录（简化操作，符合"课堂"场景）。

**冲突检测：**
- 多选时逐一检查每个学生，汇总所有冲突学生名单，显示一次确认弹窗："以下学生此时间段已有记录：[名单]，是否全部覆盖？"
- 同日已有其他记录 → Toast 轻提示，不拦截

**新建记录字段赋值（重要）：**
- `price_snapshot` = 该学生当前 `price_per_class`
- `fee_amount` = `FeeCalculator.calcFee(status, priceSnapshot)`
- 保存后按 invalidation 表刷新相关 provider

---

### P3-4 出勤记录编辑弹窗

**目标：** 提供统一的出勤记录编辑组件，供首页（P3-2）和学生详情页（P2-3）共用。

**输出文件：** `lib/shared/widgets/attendance_edit_sheet.dart`

**功能：**
- 接收现有 `Attendance` 对象作为初始值
- 可修改：状态（5 个状态按钮）、日期、开始/结束时间、备注
- 保存时重新计算 `fee_amount`（调用 `FeeCalculator.calcFee`）
- 删除按钮（二次确认）

**验收：** 修改旷课→出勤后，该学生总应收正确增加对应金额。

---

### P3-5 首页主屏

**输出文件：** `lib/features/home/screens/home_screen.dart`

**组合 P3-1、P3-2、P3-3（P3-4 编辑弹窗由 P3-2 调用）：**
- 顶部栏：月份标题 + "今日"快捷按钮
- 日历组件（占屏幕约 40%）
- 列表标题（显示选中日期 + 记录数）
- 出勤列表（可滚动）
- 右下角 FAB（点击展开 P3-3）

---

## P4 · 统计模块

### P4-1 核心指标卡片

**输出文件：** `lib/features/statistics/widgets/metrics_grid.dart`

**4 个指标：**
- 收入：选定周期内 `SUM(attendance.fee_amount)`
- 出勤节数：选定周期内 `status IN ('present','late')` 的记录数
- 活跃人数：选定周期内有至少一条出勤记录（任意状态）的不重复学生数
- 出勤率：`(present + late) / (present + late + absent) × 100%`（排除请假和试听）

**支持周期切换：** 周 / 月 / 年（Segmented Button）

**环比计算：** 与上一个同等周期对比（上周/上月/上年），显示 ↑↓ 箭头 + 百分比，正增长绿色，负增长红色，无数据显示"—"

---

### P4-2 收入趋势图

**输出文件：** `lib/features/statistics/widgets/revenue_chart.dart`

**基于 fl_chart LineChart：**
- 双折线：应收（蓝，数据来自 `attendanceDao.getMonthlyRevenue`）vs 实收（绿，数据来自 `paymentDao.getMonthlyReceived`）
- X 轴=月份，Y 轴=金额
- 长按显示具体数值 tooltip
- 点击图例可隐藏/显示系列

---

### P4-3 贡献榜单 & 状态分布

**输出文件：**
- `lib/features/statistics/widgets/contribution_chart.dart` — 横向柱状图 TOP10
- `lib/features/statistics/widgets/status_pie_chart.dart` — 环形图
- `lib/features/statistics/widgets/status_filtered_list.dart` — 状态筛选出勤列表

**贡献榜单：**
- 支持切换维度（按节数/按金额）
- 点击条目 → 跳转学生详情

**状态分布：**
- 5 种状态颜色区分
- 点击扇区 → 更新 `statusFilterProvider`，`StatusFilteredList` 响应筛选显示对应出勤记录
- 再次点击同一扇区 → 取消筛选

**StatusFilteredList：** 展示当前周期内被筛选状态的出勤记录（学生名、日期、时间）。数据来自 `getByDateRangeAndStatus`，学生姓名通过 `student_provider` 中的 `List<StudentWithMeta>` 做 id→name 映射（内存查找，无需额外 DB 查询）。无数据时显示空状态组件

---

### P4-4 时段热力图

**输出文件：** `lib/features/statistics/widgets/time_heatmap.dart`

**自定义绘制（fl_chart 不直接支持热力图）：**
- 行 = 小时（6:00-22:00），列 = 星期一到日
- 颜色深浅代表出勤人数（品牌蓝，透明度渐变）
- 点击格子显示具体人数 tooltip

---

### P4-5 智能洞察 & 统计主屏

**输出文件：**
- `lib/features/statistics/widgets/insight_list.dart`
- `lib/features/statistics/screens/statistics_screen.dart`

**洞察列表：**
- 欠费提醒、流失预警、高峰提示、试听转化
- 每条洞察有"处理"按钮（跳转）和"忽略"按钮
- 忽略后写入 dismissed_insights 表

**忽略重置规则：**
- 欠费提醒：该学生余额变为 ≤ 0 后，dismissed 记录自动失效（下次欠费重新触发）
- 流失预警：该学生有新出勤记录后，dismissed 记录自动失效
- 试听转化：该学生有正式出勤后，dismissed 记录自动失效
- 高峰提示：每周重置一次（dismissed_at 距今 > 7 天自动失效）

**高峰提示计算：** 基于最近 4 周数据，按时段统计周平均出勤人数，超过 `kPeakThreshold`（= 3）的时段触发提示。

实现方式：insight_provider 计算洞察时，对每条结果检查 dismissed_insights 表中是否存在有效的忽略记录，有则过滤掉。

**统计主屏：** 组合 P4-1 ~ P4-4，顶部 Segmented Button 更新 `statisticsPeriodProvider`，所有子组件监听该 provider 自动刷新；`statusFilterProvider` 在周期切换时重置为 null

---

## P5 · 设置模块

### P5-1 数据备份与恢复

**输出文件：**
- `lib/core/utils/backup_helper.dart` — 备份/恢复工具类
- `lib/features/settings/screens/backup_screen.dart` — 备份页面 UI

**backup_helper.dart 备份（Android 10+ 使用 MediaStore API）：**
1. Android 9-：申请 WRITE_EXTERNAL_STORAGE 权限，直接写文件
2. Android 10+：通过 `MediaStore.Downloads` 插入文件，无需额外权限
3. 复制 SQLite 文件，文件名 `backup_YYYYMMDD_HHmmss.db`
4. 更新 `settings.last_backup_at`
5. Toast 提示"备份成功，文件已保存至下载目录"

**backup_helper.dart 恢复：**
1. file_picker 选择 .db 文件
2. 二次确认"恢复将覆盖当前所有数据，此操作不可撤销"
3. 关闭数据库连接，覆盖文件
4. 调用 `Restart.restartApp()`（来自 `restart_app` 包）重启 App

**backup_screen.dart UI：**
- 显示上次备份时间
- [立即备份] 按钮
- [从文件恢复] 按钮
- 超期警告提示（距今 > `kBackupWarningDays` 天时显示橙色提示条）

---

### P5-2 课堂模板管理

**输出文件：** `lib/features/settings/screens/template_screen.dart`

**功能：** 模板列表、新增（名称+起止时间）、编辑、删除（二次确认）

---

### P5-3 签名管理

**输出文件：** `lib/features/settings/screens/signature_screen.dart`

**功能：**
- 展示当前签名图片预览
- 按钮：拍照上传 / 相册选择
- 图片保存到 App 私有目录，路径写入 `settings.signature_path`
- 删除签名（二次确认）

---

### P5-4 设置主页

**输出文件：** `lib/features/settings/screens/settings_screen.dart`

**列表项：**
- 老师姓名（文本输入）
- 数据备份（含超期警告角标）→ 跳转备份页
- 课堂模板 → 跳转模板页
- 签名管理 → 跳转签名页
- 导出默认设置（水印开关、默认寄语）
- 下载导入模板 → 生成含列名的空白 Excel 文件（`姓名/家长姓名/家长电话/单价`），通过 MediaStore 保存到 Downloads
- 关于（版本号）

---

## P6 · 导出模块

### P6-1 PDF 生成

**输出文件：** `lib/core/utils/pdf_generator.dart`

**中文字体（必须）：**
- 将 `NotoSansSC-Regular.ttf` 放入 `assets/fonts/`
- 加载方式：
```dart
final fontData = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
final ttf = pw.Font.ttf(fontData);
// 所有 pw.TextStyle 必须指定 font: ttf
```

**输入参数：** 学生、时间范围、寄语文本、是否启用水印

**PDF 结构（4页）：**
1. 封面：学生姓名、时间范围、老师签名图
2. 出勤明细表：日期、时间、状态、费用
3. 费用结算：应收、调整、已收、余额
4. 寄语页（若有寄语）

**水印：** 斜铺文字"仅供 [学生名] 家长核对"，透明度 15%

**签名处理：** 读取 `settings.signature_path`；若路径为空或文件不存在，PDF 中隐藏签名区域（不显示空白框）

---

### P6-2 Excel 导出

**输出文件：** `lib/core/utils/excel_exporter.dart`

**输入参数：** 学生、时间范围

**Sheet 结构：**
- Sheet1"出勤明细"：日期、时间、状态、单价快照、费用
- Sheet2"费用汇总"：应收、调整明细、缴费明细、余额
- 条件格式：旷课行标红，请假行标灰

---

### P6-3 导出配置页

**输出文件：** `lib/features/export/screens/export_config_screen.dart`

**触发方式：** `showModalBottomSheet`，从学生详情页 [生成报告] 按钮调用

**布局（参考 PRD 页面 4，半屏弹窗）：**
1. 时间范围选择器（默认当月）
2. 寄语输入框（0/200 字）
3. 签名预览（读取设置页图片）
4. 水印开关（默认开，关闭时二次确认）
5. 底部：[预览 PDF] [生成 PDF 并分享] [导出 Excel]

**PDF 分享：** 调用 `share_plus`，同时通过 MediaStore 保存副本到 `Downloads/书法助手导出/`（Android 10+ 用 MediaStore，Android 9- 直接写文件，与 P5-1 保持一致）

**Excel 导出：** 调用 `ExcelExporter`（P6-2），同样通过 MediaStore 保存，Toast 提示"已保存至下载目录"

---

## P7 · 集成收尾

### P7-1 底部导航 & 路由整合

**输出文件：** 更新 `lib/app.dart`

**底部 Tab：** 首页 / 学生 / 数据 / 我的
**路由表（go_router）：**

| 路径 | 页面 |
|------|------|
| `/` | HomeScreen |
| `/students` | StudentListScreen |
| `/students/create` | StudentFormScreen（新增）|
| `/students/:id` | StudentDetailScreen |
| `/students/:id/edit` | StudentFormScreen（编辑）|
| `/statistics` | StatisticsScreen |
| `/settings` | SettingsScreen |
| `/settings/templates` | TemplateScreen |
| `/settings/signature` | SignatureScreen |
| `/settings/backup` | BackupScreen |

**注意：** `/students/create` 必须在 `/students/:id` 之前注册，避免 go_router 将 "create" 匹配为 id 参数。导出配置页（P6-3）以 `showModalBottomSheet` 方式调用，不注册为独立路由。

---

### P7-2 端到端测试 & 性能验收

**验收清单：**

| 指标 | 标准 | 验证方法 |
|------|------|---------|
| 冷启动 | < 2 秒 | 录屏计时 |
| 页面切换 | < 0.5 秒 | 肉眼观察 |
| 5000 条记录 | 无卡顿 | 脚本批量插入后操作 |
| 备份/恢复 | 数据完整 | 备份后手动删除数据库文件（或卸载重装），再恢复并对比记录数 |
| PDF 生成 | 内容正确 | 人工核对 |
| Excel 导入 | 50 行无误 | 准备测试文件 |

**测试数据脚本：** `scripts/seed_test_data.dart` — 插入 20 名学生 × 250 条出勤记录

---

## 执行顺序建议

```
P0-1 → P0-2 → P0-3 → P0-4 → P0-5
                                ↓
              P1-1 ~ P1-4（可并行）→ P1-5 → P1-6
                                              ↓
        P2（P2-1~P2-5）    P3（P3-1~P3-5）    P4（P4-1~P4-5）    P5（P5-1~P5-4）
        以上四组可并行
                                              ↓
                            P6-1, P6-2（可并行）→ P6-3
                                              ↓
                                    P7-1 → P7-2
```

---

## AI 开发注意事项

1. **每次执行一个任务**，提供任务编号和本文档作为上下文
2. **先读后写**：修改已有文件前必须先读取
3. **引用规范**：模型字段名、枚举值、颜色常量严格使用本文档定义
4. **不超范围**：每个任务只创建/修改该任务列出的文件
5. **数据库变更**：任何表结构变更必须同步更新 `database-design.md` 和版本号

6. **数据变更后必须刷新 Provider（重要）：**

| 操作 | 必须 invalidate 的 provider |
|------|---------------------------|
| 新增/编辑学生 | `student_provider` |
| 删除学生（级联删除出勤/缴费/调整） | `student_provider`、`attendance_provider`、`feeSummaryProvider(受影响学生)`、`metrics_provider`、`revenue_provider`、`contribution_provider`、`status_distribution_provider`、`heatmap_provider`、`insight_provider` |
| 批量导入学生 | `student_provider` |
| 新增/编辑/删除出勤记录 | `attendance_provider`、`feeSummaryProvider(受影响学生)`、`metrics_provider`、`revenue_provider`、`contribution_provider`、`status_distribution_provider`、`heatmap_provider`、`insight_provider` |
| 新增/删除缴费记录 | `feeSummaryProvider(受影响学生)`、`revenue_provider`、`insight_provider` |
| 修改设置 | `settings_provider` |
| 忽略洞察 | `insight_provider` |
