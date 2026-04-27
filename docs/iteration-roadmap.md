# 墨韵迭代路线图

## 目标

基于 `docs/product-optimization-plan.md`，将当前产品从“可记录、可统计”推进到“可解释、可跟进、可转化”。

本路线图只保留当前代码库可直接执行的迭代项，避免泛化表述。

## 当前状态

### 本轮已完成

- 出勤记录已支持结构化课堂反馈：
  - `lesson_focus_tags`
  - `home_practice_note`
  - `progress_scores_json`
- 数据库已升级到 v6，并补齐兼容迁移与索引守卫。
- 洞察层已支持：
  - `debt`
  - `renewal`
  - `churn`
  - `peak`
  - `trial`
  - `progress`
- 统计卡片已展示：
  - 建议文案
  - 计算逻辑
  - 数据时效
- 已补的测试覆盖：
  - 结构化反馈模型
  - 洞察聚合逻辑
  - 忽略提醒策略
  - `InsightNotifier` 接线
  - 统计卡片跳转 / 忽略交互

### 本轮优化验收（2026-04-27）

- `flutter test --no-pub test/docs/database_design_consistency_test.dart` 已通过，数据库版本与索引文档漂移现在有自动守卫。
- `flutter test --no-pub test/shared/widgets/attendance_edit_sheet_test.dart` 已通过，相关 widget 测试已通过共享 `FakeSettingsNotifier` 隔离真实 settings 数据库访问。
- `flutter analyze --no-pub` 已通过，所有并行优化 lane 的符号与导入均已收敛。
- `flutter test --no-pub` 已通过，当前全量测试为 290 项。
- `flutter build apk --debug` 已通过，产物路径为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 已补齐优化执行计划文档：`docs/superpowers/plans/2026-04-27-project-optimization.md` 与 `docs/superpowers/plans/2026-04-27-project-optimization-execution-strategy.md`。
- 第二轮机械拆分已完成：
  - `quick_entry_sheet.dart` 抽出快速录课辅助组件。
  - `export_config_screen.dart` 抽出导出配置展示组件。
  - `settings_screen.dart` 抽出设置页 tile / banner 组件。
  - `student_detail_screen.dart` 抽出学生详情展示组件。
- 第三轮机械拆分已完成：
  - `home_screen.dart` 抽出首页工作台展示组件。
  - `backup_screen.dart` 抽出备份页展示组件。
- 第四轮保守拆分已完成：
  - `quick_entry_sheet.dart` 抽出冲突处理弹窗，主流程只负责准备冲突数据与消费处理结果。
  - `pdf_generator.dart` 抽出 PDF 文案格式化 helper，并补充格式化回归测试。
  - `export_config_screen.dart` 抽出导出概览面板，页面 `build` 方法进一步瘦身。
  - 代码审阅反馈已处理：PDF 总时长保留旧的部分异常时间解析语义；导出临时文件清理 helper 显式要求传入延迟策略。
- 第五轮保守拆分已完成：
  - `quick_entry_sheet.dart` 抽出时间选择、默认值提示、已选学员与确认摘要组件。
  - `export_config_screen.dart` 抽出日期范围、寄语与导出操作区块。
  - `student_import_screen.dart` 抽出导入说明、状态、指标、问题行与学生预览组件。
  - `pdf_generator.dart` 抽出 PDF 导出文件命名 helper，并补充文件名清洗与时间戳回归测试。
- 第六轮保守拆分已完成：
  - `quick_entry_sheet.dart` 抽出课堂反馈区块，父组件继续持有输入状态与保存流程。
  - `export_config_widgets.dart` 收敛为 barrel 文件，导出父级快照、概览、汇总与表单组件分文件维护。
  - `home_screen_components.dart` 收敛为 barrel 文件，首页重点卡、快捷入口与空状态组件分文件维护。
  - `backup_screen.dart` 抽出备份列表错误、风险提示、概览、操作与最近记录展示区块。
  - 第六轮只读代码审阅未发现回归；针对性 widget 测试、全量测试、静态分析、debug APK 构建均已通过。
- 第七轮保守拆分已完成：
  - `quick_entry_sheet.dart` 抽出 Step0 学员筛选、空状态、学员列表与底部操作组件，父组件继续持有筛选结果和保存流程。
  - `settings_screen.dart` 抽出教师资料、资料模板、导出沟通、提醒策略、沉浸反馈、AI 扩展、导入工具、开发者工具与关于应用区块。
  - `export_config_screen.dart` 抽出弹层头部与模板选择器，导出、分享、预览和设置持久化逻辑仍保留在页面内。
  - `pdf_generator.dart` 抽出 PDF 印章绘制 helper，并补充多种印章配置的 PDF 渲染 smoke test。
  - 第七轮代码审阅发现的测试过度绑定内部 widget 树问题已处理；目标测试、全量测试、静态分析、debug APK 构建与 diff 检查均已通过。
- 第八轮保守拆分已完成：
  - `quick_entry_sheet_components.dart` 收敛为 barrel 文件，并拆出 common、Step0、Step1 三组快速录入组件。
  - `export_form_widgets.dart` 收敛为 barrel 文件，并拆出弹层头部/模板、日期范围、寄语、选项与操作面板组件。
  - `backup_screen_widgets.dart` 收敛为 barrel 文件，并拆出备份状态、操作、记录与公共组件。
  - 代码审阅发现的备份中文文案迁移损坏已修复；复审确认无残留乱码、无漏导出或循环导入。
  - 第八轮目标测试、全量测试、静态分析、debug APK 构建与 diff 检查均已通过。

### 当前仍存在的边界

- 大型页面与服务仍只是完成阶段性瘦身，`pdf_generator.dart` 约 1096 行，仍需要后续继续拆分 PDF 页面组装；`quick_entry_sheet.dart` 已降至约 818 行，配套组件已拆为 3-379 行的小文件。
- `export_config_screen.dart` 约 682 行、`settings_screen.dart` 约 561 行、`student_detail_screen.dart` 约 780 行，状态与操作流仍可继续拆出控制器/表单区块。
- `backup_screen.dart` 已瘦身至约 465 行，`export_config_widgets.dart`、`export_form_widgets.dart`、`home_screen_components.dart`、`quick_entry_sheet_components.dart` 与 `backup_screen_widgets.dart` 已变成 barrel 文件；后续重点应从机械拆分转向提炼页面状态模型和操作服务。
- PDF 导出、备份恢复、系统分享等平台能力已通过单元/组件测试与 debug 构建，但尚未做真机手工冒烟。
- `flutter build apk --debug` 提示 34 个依赖存在可升级版本，本轮为降低风险未升级依赖。
- `progress` 洞察目前只约束为“最近 3 次有效评分”，尚未引入“最近 N 天”窗口
- `dismissed insight` 的保留期已显式化，但尚未暴露到设置页

## 迭代拆分

## Iteration 1

### 目标

完成 P0 能力的稳定化，降低误报、噪音和维护成本。

### 待办

- 为 `progress` 洞察增加可配置时间窗：
  - 例如“最近 30 天内的最近 3 次有效评分”
- 为 `dismissed insight` 增加设置化策略：
  - 默认保留期
  - 是否允许自动恢复
- 统一洞察卡片的长文案折叠规则：
  - `suggestion`
  - `calcLogic`
- 补轻量验证脚本或最小化测试命令清单，替代全量 `flutter test`

### 验收标准

- 无“零历史学生”续费误报
- 无“陈旧进步”持续提示
- 洞察忽略行为可预期、可恢复

## Iteration 2

### 目标

把首页从“记录入口”升级到“教学工作台”。

### 待办

- `schedule_conflict_guard`
  - 未来排课冲突预检
  - 冲突时给出覆盖 / 改期 / 推荐补课动作
- `balance_alert_center`
  - 首页聚合待续费学员
- `trial_followup_prompt`
  - 试听后跟进提醒
- `absence_streak_tag`
  - 连续请假 / 缺勤高亮

### 验收标准

- 首页能直接看到今日待处理事项
- 至少 3 类提醒可从首页直达处理页

## Iteration 3

### 目标

把学生页升级为“成长与续费工作台”。

### 待办

- 进步轨迹展示：
  - 最近评分趋势
  - 课堂重点标签汇总
- 余额消耗趋势
- 续费窗口说明
- 家长沟通摘要：
  - 本阶段进步点
  - 待改进点
  - 课后练习建议

### 验收标准

- 单个学生页可直接支撑“复盘 + 沟通 + 续费”三类动作

## Iteration 4

### 目标

把导出模块升级为“家长沟通产物中心”。

### 待办

- `parent_snapshot_header`
- 月报模板分层：
  - 家长版
  - 教师版
- 导出首屏固定摘要：
  - 余额
  - 下次课
  - 进步点
  - 待改进点
  - 数据截止时间

### 验收标准

- 家长版 PDF 首屏 3 秒可读懂重点

## 推荐执行顺序

1. 先完成 Iteration 1，继续压缩误报和测试盲区。
2. 再做 Iteration 2，把提醒从“能看到”变成“能处理”。
3. 然后做 Iteration 3，把学生页做成日常主工作台。
4. 最后做 Iteration 4，沉淀对家长沟通产物。

## 不建议现在做的事

- 引入远程服务或 AI 接口
- 扩大全量测试链路
- 大规模 UI 重构

当前阶段更重要的是先把离线主链路、洞察逻辑和操作闭环做稳。
