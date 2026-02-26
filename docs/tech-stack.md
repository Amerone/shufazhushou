# 技术选型文档

## 结论

**Flutter (Dart)** — Android 离线 App

---

## 选型理由

| 维度 | 说明 |
|------|------|
| AI 开发友好 | Dart 语法清晰，AI 生成代码质量稳定，错误率低 |
| 离线优先 | SQLite 本地存储，无需网络 |
| 生态完整 | PDF、Excel、图表、数据库均有成熟 package |
| 性能 | 原生渲染，冷启动 < 2s 可达 |
| 单平台 | 仅需 Android，无跨平台负担 |

---

## 核心依赖

### 数据库
| Package | 用途 |
|---------|------|
| `sqflite: ^2.3.3` | SQLite 本地数据库 |
| `path: ^1.9.0` | 数据库文件路径 |

### 状态管理
| Package | 用途 |
|---------|------|
| `flutter_riverpod: ^2.5.1` | 全局状态管理，Provider 模式 |

### 导航
| Package | 用途 |
|---------|------|
| `go_router: ^14.2.0` | 声明式路由 |

### UI 组件
| Package | 用途 |
|---------|------|
| `table_calendar: ^3.1.2` | 首页月历组件 |
| `fl_chart: ^0.68.0` | 折线图、柱状图、环形图 |

### 字体
| 资源 | 用途 |
|------|------|
| `NotoSansSC-Regular.ttf` | PDF 中文字体（必须嵌入，否则中文显示为方块） |

在 `pubspec.yaml` 中声明：
```yaml
flutter:
  fonts:
    - family: NotoSansSC
      fonts:
        - asset: assets/fonts/NotoSansSC-Regular.ttf
  assets:
    - assets/fonts/
```

### 导出
| Package | 用途 |
|---------|------|
| `pdf: ^3.11.1` | 生成 PDF |
| `printing: ^5.13.1` | PDF 预览与分享 |
| `excel: ^4.0.6` | 生成 Excel |
| `share_plus: ^9.0.0` | 调用系统分享菜单 |

### 文件与权限
| Package | 用途 |
|---------|------|
| `path_provider: ^2.1.3` | 获取本地存储路径 |
| `permission_handler: ^11.3.1` | 运行时权限申请 |
| `image_picker: ^1.1.2` | 签名图片上传（相机/相册） |
| `file_picker: ^8.1.2` | Excel 批量导入学生 |

### 工具
| Package | 用途 |
|---------|------|
| `intl: ^0.19.0` | 日期格式化、中文本地化 |
| `uuid: ^4.4.2` | 生成唯一 ID |
| `restart_app: ^1.2.1` | 备份恢复后重启 App |

---

## 架构模式

```
lib/
├── main.dart
├── app.dart                  # 路由、主题配置
├── core/
│   ├── database/
│   │   ├── database_helper.dart   # SQLite 初始化、迁移
│   │   └── dao/                   # 各表的数据访问对象
│   │       ├── student_dao.dart
│   │       ├── attendance_dao.dart
│   │       ├── payment_dao.dart
│   │       ├── settings_dao.dart
│   │       └── dismissed_insight_dao.dart
│   ├── models/               # 数据模型 (fromMap/toMap)
│   │   ├── student.dart
│   │   ├── attendance.dart
│   │   ├── payment.dart
│   │   ├── class_template.dart
│   │   └── dismissed_insight.dart
│   ├── providers/            # Riverpod providers
│   └── utils/
│       ├── fee_calculator.dart    # 费用计算逻辑
│       └── backup_helper.dart     # 数据库备份/恢复
├── features/
│   ├── home/                 # 首页（出勤）
│   ├── students/             # 学生档案
│   ├── statistics/           # 数据统计
│   ├── settings/             # 我的设置
│   └── export/               # 导出配置页
└── shared/
    ├── widgets/              # 公共组件（empty_state, attendance_edit_sheet 等）
    ├── utils/                # toast.dart 等工具
    └── theme.dart            # 品牌色、字体
```

**分层规则：**
- `features/xxx/` 下各含 `screens/`、`widgets/`、`providers/`
- 业务逻辑在 Provider 中，UI 只调用 Provider
- 数据库操作只在 DAO 中，Provider 调用 DAO

---

## Android 配置

**最低版本：** Android 8.0 (API 26)
**目标版本：** Android 14 (API 34)

`AndroidManifest.xml` 权限声明：
```xml
<!-- Android 9 及以下使用，10+ 自动忽略 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="28"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

**Android 10+ 存储说明：**
- 写入 `Downloads/` 目录使用 `MediaStore.Downloads` API，无需额外权限
- `path_provider` 的 `getExternalStorageDirectory()` 在 Android 10+ 返回 App 私有目录，不可用于备份
- 备份/导出文件统一通过 `MediaStore` 写入公共 Downloads，代码示例在 P5-1 任务中提供

---

## 主题色规范

| 用途 | 颜色 |
|------|------|
| 主色（品牌蓝） | `#1565C0` |
| 辅助绿（全出勤） | `#2E7D32` |
| 辅助橙（警告） | `#E65100` |
| 辅助灰（禁用） | `#757575` |
| 余额负数（预存） | `#2E7D32` |
| 余额正数（欠费） | `#C62828` |
