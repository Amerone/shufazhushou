# 技术选型说明

## 结论

`Flutter (Dart)` 适合作为本项目的 Android 离线优先技术底座。

## 选型理由

| 维度 | 说明 |
| --- | --- |
| 离线优先 | 核心数据保存在 SQLite，本地主链路无需网络 |
| 可选 AI 联网 | AI 功能通过用户配置的 `https://` 端点访问远端，和本地主流程解耦 |
| 开发效率 | Dart 语法清晰，Flutter 工程化成熟 |
| 生态完整 | PDF、Excel、图表、数据库、权限处理都有稳定依赖 |
| Android 聚焦 | 当前只需服务 Android，技术栈足够轻量 |

## 核心依赖

| 分类 | 依赖 | 作用 |
| --- | --- | --- |
| 数据库 | `sqflite` | SQLite 本地存储 |
| 路径 | `path` | 数据库与文件路径处理 |
| 状态管理 | `flutter_riverpod` | 全局状态与依赖注入 |
| 路由 | `go_router` | 页面路由与壳层导航 |
| 图表 | `fl_chart` | 收入趋势、排行、分布图 |
| 日历 | `table_calendar` | 出勤日历视图 |
| PDF | `pdf` / `printing` | PDF 生成与预览 |
| Excel | `excel` | Excel 导入导出 |
| 文件 | `path_provider` / `file_picker` / `share_plus` | 本地文件访问、选择、分享 |
| 权限 | `permission_handler` / `image_picker` | 媒体访问、拍照与选图 |

## 架构约束

- `features/` 负责按业务拆分页面与组件。
- `core/dao/` 负责数据库访问。
- `core/providers/` 负责依赖注入和状态组合。
- UI 不直接拼装数据库读写或远端请求。
- AI 能力作为可选扩展存在，不影响离线主链路。

## Android 配置

最低版本：Android 8.0（API 26）

Manifest 中涉及的权限：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="28"/>
<uses-permission
    android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

说明：

- `INTERNET` 仅用于可选 AI 能力和 Flutter 调试通信。
- Android 10+ 的导出与备份优先走 `MediaStore`。
- AI 端点仅允许 `https://`，避免和 Android 明文流量策略冲突。
