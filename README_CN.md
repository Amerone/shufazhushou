# 书法私教助手

一款面向书法老师的离线 Android 应用，使用 Flutter 构建。管理学生考勤、费用收支，生成 PDF/Excel 报告。所有数据存储在本地 SQLite，无需联网。

## 功能特性

- **出勤日历** — 月历视图，日期角标颜色标识出勤情况（绿色=全勤、红色=有旷课、橙色=混合），点击日期查看/编辑记录
- **快速录入** — 三步操作：选学生（支持多选）-> 选时间段和状态 -> 确认提交，支持课堂模板一键选择时间
- **学生管理** — 完整的增删改查，支持搜索，支持从 Excel (.xlsx) 批量导入学生
- **费用追踪** — 根据出勤状态自动计算费用，记录缴费，按月查看学生余额（预存/欠费）
- **数据统计** — 收入趋势双折线图、贡献排行榜 TOP10、状态分布环形图、时段热力图、核心指标环比对比
- **智能洞察** — 自动检测欠费提醒、流失预警（21 天未出勤）、高峰时段提示、试听转化追踪
- **PDF 报告** — 4 页报告：封面、出勤明细、费用结算、寄语页，支持老师签名、水印、中文字体（思源黑体）
- **Excel 导出** — 出勤明细和费用汇总，旷课行标红、请假行标灰
- **数据备份** — 一键备份到下载目录（Android 10+ 使用 MediaStore API），支持从 .db 文件恢复
- **压角章** — 自定义印章文字、字体（小篆/缪篆/大篆）、布局、边框，用于启动页和 PDF 封面

## 截图

*即将补充*

## 技术栈

| 类别 | 技术方案 |
|------|---------|
| 框架 | Flutter (Dart) |
| 数据库 | SQLite (sqflite) |
| 状态管理 | Riverpod (AsyncNotifier) |
| 路由 | GoRouter (StatefulShellRoute) |
| 图表 | fl_chart |
| 日历 | table_calendar |
| PDF 生成 | pdf + printing |
| Excel 读写 | excel 包 |
| 文件分享 | share_plus |

## 项目架构

```
lib/
├── main.dart                  # 入口：Riverpod ProviderScope + 中文日期初始化
├── app.dart                   # MaterialApp.router + GoRouter 路由配置
├── core/
│   ├── database/
│   │   ├── database_helper.dart   # SQLite 单例，数据库迁移（v3）
│   │   └── dao/                   # 数据访问对象（每表一个）
│   ├── models/                    # 数据模型（fromMap/toMap/copyWith）
│   ├── providers/                 # Riverpod 全局 Provider
│   └── utils/                     # 费用计算、备份、PDF/Excel 生成
├── features/
│   ├── home/                      # 首页：出勤日历 + 快速录入
│   ├── students/                  # 学生：列表、详情、表单、导入
│   ├── statistics/                # 统计：指标、图表、洞察
│   ├── settings/                  # 设置：备份、模板、签名、压角章
│   └── export/                    # 导出：PDF/Excel 配置页
└── shared/
    ├── widgets/                   # 公共组件
    ├── utils/                     # Toast/弹窗工具
    └── theme.dart                 # 品牌色、Material 3 主题
```

**数据流向：** UI 界面 -> Riverpod Provider -> DAO 数据访问 -> SQLite 数据库

## 快速开始

### 环境要求

- Flutter SDK 3.11+
- Android SDK（最低 API 26 / Android 8.0）
- 已连接的 Android 设备或模拟器

### 构建运行

```bash
# 国内镜像（推荐）
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"

# 安装依赖
flutter pub get

# 连接设备并运行
flutter devices
flutter run -d <设备ID>

# 打包 Release APK
flutter build apk --release
```

### 输出文件

Release APK 路径：`build/app/outputs/flutter-apk/app-release.apk`

## 数据库设计

SQLite 数据库文件 `calligraphy_assistant.db`，当前版本 v3，共 6 张表：

| 表名 | 用途 |
|------|------|
| `students` | 学生档案（姓名、家长信息、单价、状态） |
| `attendance` | 出勤记录（含单价快照和计算费用） |
| `payments` | 缴费记录 |
| `class_templates` | 课堂时间模板 |
| `settings` | 键值对应用设置 |
| `dismissed_insights` | 已忽略的洞察提醒记录 |

所有 ID 使用 UUID。日期存储为 `YYYY-MM-DD` 字符串。外键启用 CASCADE 级联删除。

## 费用计算规则

| 出勤状态 | 是否计费 |
|---------|---------|
| 出勤 / 迟到 | 按 price_snapshot 计费 |
| 请假 / 旷课 / 试听 | 不计费（0 元） |

**余额** = 总已收 - 总应收（正数 = 预存，负数 = 欠费）

## 底部导航

| Tab | 页面 | 功能 |
|-----|------|------|
| 首页 | HomeScreen | 出勤日历 + 快速录入 |
| 学生 | StudentListScreen | 学生列表与管理 |
| 数据 | StatisticsScreen | 统计图表与洞察 |
| 我的 | SettingsScreen | 备份、模板、签名等设置 |

## 许可证

本项目基于 [Apache License 2.0](LICENSE) 开源。
