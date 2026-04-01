# 墨韵

一款面向书法老师的离线优先 Android 应用，使用 Flutter 构建。学生、出勤、费用、导出与备份数据默认保存在本地 SQLite。可选 AI 分析功能需要联网，并且只会向用户配置的 `https://` 端点发送数据。

## 功能特性

- **出勤日历**：按月查看出勤状态，支持按天快速编辑记录。
- **快捷录入**：三步完成出勤登记，支持课程时间模板。
- **学生管理**：增删改查、搜索、Excel 批量导入。
- **费用追踪**：自动计费、缴费记录、预存与欠费余额统计。
- **统计看板**：收入趋势、排行、分布图、热力图与经营洞察。
- **智能提醒**：欠费风险、流失风险、高峰时段与转化机会提醒。
- **可选 AI 分析**：笔迹分析和经营分析能力可在用户确认后调用自定义 `https://` 端点。
- **PDF 导出**：支持签名、水印与中文字体。
- **Excel 导出**：支持出勤明细和费用汇总。
- **数据备份**：本地数据库备份与恢复。

## 技术栈

| 类别 | 方案 |
| --- | --- |
| 框架 | Flutter (Dart) |
| 数据库 | SQLite / `sqflite` |
| 状态管理 | Riverpod |
| 路由 | GoRouter |
| 图表 | `fl_chart` |
| 日历 | `table_calendar` |
| PDF | `pdf` + `printing` |
| Excel | `excel` |
| 分享 | `share_plus` |

## 目录结构

```text
lib/
├─ main.dart
├─ app.dart
├─ core/
│  ├─ database/
│  ├─ dao/
│  ├─ models/
│  ├─ providers/
│  └─ utils/
├─ features/
│  ├─ home/
│  ├─ students/
│  ├─ statistics/
│  ├─ settings/
│  └─ export/
└─ shared/
   ├─ widgets/
   ├─ utils/
   └─ theme.dart
```

数据流：UI -> Riverpod Provider -> DAO/Service -> SQLite。

## 常用命令

```bash
flutter pub get
flutter run -d <device_id>
flutter analyze
flutter test
flutter build apk --release
```

## 联网说明

- 出勤、费用、统计、导出、备份等主流程默认离线可用。
- 不配置 AI API Key 时，不会发起 AI 远端请求。
- 使用 AI 分析时，应用会在用户确认后，把图片、提示词和必要的学员信息发送到配置的 `https://` 端点。

## 数据库

主数据库文件：`moyun.db`。

核心表：

- `students`
- `attendance`
- `payments`
- `class_templates`
- `settings`
- `dismissed_insights`

## 许可证

基于 [Apache License 2.0](LICENSE) 开源。
