# 仓库指南（Repository Guidelines）
## 项目结构与模块组织
- `lib/main.dart` 负责启动 Riverpod 和本地化初始化；`lib/app.dart` 管理路由与应用壳层
- `lib/core/` 存放数据与业务基础能力：`database/`、`dao/`、`models/`、`providers/`、`utils/`
- `lib/features/` 按功能组织 UI（`home`、`students`、`statistics`、`settings`、`export`），每个功能拆分为 `screens/` 与 `widgets/`
- `lib/shared/` 放跨功能复用内容，如主题、常量与公共组件
- `assets/` 存放资源文件（重点是 `assets/fonts/NotoSansSC-Regular.ttf`）
- `test/` 放自动化测试；`docs/` 放架构与数据库说明文档
- `build/` 与 `.dart_tool/` 为生成目录，不作为代码评审重点。
## 构建、测试与开发命令
- `flutter pub get`：安装或更新依赖
- `flutter run -d <device_id>`：在指定模拟器或真机运行应用
- `flutter analyze`（或 `dart analyze lib/`）：执行静态检查与 lint
- `flutter test`：运行 `test/` 下所有测试
- `flutter build apk --debug`：构建调试版 APK
- `flutter build apk --release`：构建发布版 APK
- `flutter clean && flutter pub get`：清理并重建依赖，用于排查本地构建异常。
## 代码风格与命名规范
- 遵循 `analysis_options.yaml` 中的 `flutter_lints`，提交前清理告警
- 使用 `dart format .` 统一格式（Dart 标准 2 空格缩进与尾逗号风格）
- 文件名使用 `snake_case`，并沿用后缀约定：`_screen.dart`、`_provider.dart`、`_dao.dart`
- UI 逻辑放在 `screens/widgets`，数据访问放在 `dao/provider`，避免职责混杂
- 若修改数据库表结构或迁移逻辑，需在同一 PR 更新 `docs/database-design.md`。
## 测试指南
- 使用 `flutter_test`，测试文件命名为 `*_test.dart` 并置于 `test/`
- 涉及 provider/DAO 行为变更或关键页面流程时，必须补充或更新测试
- 测试应保持可重复，避免直接依赖当前时间等不稳定输入（必要时注入或 mock）
- 提交 PR 前至少执行 `flutter test` 与 `flutter analyze`。
## 提交与 Pull Request 规范
- 当前工作区快照未包含 `.git` 历史，默认采用 Conventional Commits
- 推荐格式：`type(scope): summary`，例如 `feat(students): add import validation`
- PR 需包含：变更摘要、关联任务/Issue、测试结果；UI 变更需附截图
- 涉及 `lib/core/database/` 或 DAO 的修改，需在 PR 描述中明确数据模型/迁移影响。
## 安全与配置建议
- 保持离线优先原则，未经评审不要引入外部服务端点或敏感配置
- 不要提交本地备份、日志和构建产物（如 APK、`build/` 内容）。

