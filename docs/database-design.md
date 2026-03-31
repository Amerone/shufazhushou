# 数据库设计文档

## 概览

- 引擎：SQLite（通过 sqflite）
- 数据库文件名：`moyun.db`（兼容迁移旧文件 `calligraphy_assistant.db`）
- 当前版本：`4`

---

## 表结构

### 1. students（学生档案）

```sql
CREATE TABLE students (
  id          TEXT PRIMARY KEY,          -- UUID
  name        TEXT NOT NULL,             -- 学生姓名
  parent_name TEXT,                      -- 家长姓名
  parent_phone TEXT,                     -- 家长电话
  price_per_class REAL NOT NULL DEFAULT 0, -- 当前单价（元/节）
  status      TEXT NOT NULL DEFAULT 'active', -- active | suspended
  note        TEXT,                      -- 学生长期备注
  created_at  INTEGER NOT NULL,          -- Unix 毫秒时间戳
  updated_at  INTEGER NOT NULL
);
```

**说明：**
- `price_per_class` 仅为"当前单价"，修改不影响历史出勤记录
- `status`: `active`=在读，`suspended`=休学
- `note` 用于保存长期跟进备注，不替代单次课堂反馈

---

### 2. attendance（出勤记录）

```sql
CREATE TABLE attendance (
  id             TEXT PRIMARY KEY,       -- UUID
  student_id     TEXT NOT NULL,          -- FK → students.id
  date           TEXT NOT NULL,          -- 日期 YYYY-MM-DD
  start_time     TEXT NOT NULL,          -- 开始时间 HH:mm
  end_time       TEXT NOT NULL,          -- 结束时间 HH:mm
  status         TEXT NOT NULL,          -- present | late | leave | absent | trial
  price_snapshot REAL NOT NULL DEFAULT 0, -- 记录时的单价快照
  fee_amount     REAL NOT NULL DEFAULT 0, -- 本条记录产生的费用
  note           TEXT,                   -- 备注（如"横画进步"）
  lesson_focus_tags TEXT,                -- 课堂重点标签 JSON 数组
  home_practice_note TEXT,               -- 课后练习建议
  progress_scores_json TEXT,             -- 结构化进步评分 JSON
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
);

CREATE INDEX idx_attendance_student_date ON attendance(student_id, date);
CREATE INDEX idx_attendance_date ON attendance(date);
```

**计费规则（fee_amount 赋值逻辑）：**

| status | fee_amount |
|--------|-----------|
| present | price_snapshot × 1 |
| late | price_snapshot × 1 |
| leave | 0 |
| absent | 0 |
| trial | 0 |

**说明：**
- `price_snapshot` 在录入时从 `students.price_per_class` 复制，此后独立存储
- 修改出勤状态时重新计算该条 `fee_amount`，不影响其他记录
- `lesson_focus_tags` 保存结构化课堂重点，例如 `["控笔","结构"]`
- `home_practice_note` 保存课后练习建议，供家长沟通和导出使用
- `progress_scores_json` 保存结构化评分，当前支持 `stroke_quality`、`structure_accuracy`、`rhythm_consistency`

---

### 3. payments（缴费记录）

```sql
CREATE TABLE payments (
  id           TEXT PRIMARY KEY,         -- UUID
  student_id   TEXT NOT NULL,            -- FK → students.id
  amount       REAL NOT NULL,            -- 缴费金额（必须为正数）
  payment_date TEXT NOT NULL,            -- 缴费日期 YYYY-MM-DD
  note         TEXT,                     -- 备注（如"微信转账"）
  created_at   INTEGER NOT NULL,
  FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
);

CREATE INDEX idx_payments_student ON payments(student_id);
```

---

---

### 4. class_templates（课堂时间模板）

```sql
CREATE TABLE class_templates (
  id         TEXT PRIMARY KEY,           -- UUID
  name       TEXT NOT NULL,              -- 模板名称（如"下午班"）
  start_time TEXT NOT NULL,              -- HH:mm
  end_time   TEXT NOT NULL,              -- HH:mm
  created_at INTEGER NOT NULL
);
```

---

### 5. settings（应用设置）

```sql
CREATE TABLE settings (
  key        TEXT PRIMARY KEY,           -- 设置键
  value      TEXT,                       -- 设置值（JSON 字符串或纯文本）
  updated_at INTEGER NOT NULL
);
```

**预定义 key 列表：**

| key | 类型 | 说明 |
|-----|------|------|
| `signature_path` | String | 签名图片本地路径 |
| `default_watermark_enabled` | bool | 导出 PDF 默认是否启用水印 |
| `default_message_template` | String | 默认寄语模板文本 |
| `last_backup_at` | int | 上次备份的 Unix 毫秒时间戳 |
| `teacher_name` | String | 老师姓名（用于 PDF 签名区） |
| `qwen_api_key` | String | Qwen / DashScope API Key |
| `qwen_base_url` | String | Qwen 请求端点 |
| `qwen_model` | String | Qwen 模型标识，默认预置为 `qwen3-vl-plus` |
| `qwen_system_prompt` | String | 默认视觉分析系统提示词 |

---

### 6. dismissed_insights（已忽略的洞察提醒）

```sql
CREATE TABLE dismissed_insights (
  id           TEXT PRIMARY KEY,         -- UUID
  insight_type TEXT NOT NULL,            -- debt | renewal | churn | peak | trial | progress
  student_id   TEXT,                     -- 关联学生（可为空，如高峰提示）
  dismissed_at INTEGER NOT NULL
);
```

**说明：** 用于"忽略"按钮，避免已处理的洞察反复出现。

当前建议的忽略有效期策略：
- `debt`、`renewal`：`3` 天后恢复
- `churn`、`peak`、`trial`：`7` 天后恢复
- `progress`：`14` 天后恢复

---

## 核心计算公式

```
-- 某学生某周期内：
总应收 = SUM(attendance.fee_amount WHERE student_id=? AND date BETWEEN ? AND ?)

总已收 = SUM(payments.amount WHERE student_id=? AND payment_date BETWEEN ? AND ?)

余额   = 总已收 - 总应收
-- 余额 > 0 → 预存（绿色）
-- 余额 < 0 → 欠费（红色）
-- 余额 = 0 → 已结清
```

**注意：** 费用汇总默认不限时间范围（全量），时间筛选仅用于统计页展示。学生详情页"本月"概览使用当月范围。

---

## 洞察触发查询

```sql
-- 欠费提醒：余额 < 0 的学生
SELECT student_id,
       COALESCE(pay.total,0) - SUM(fee_amount) AS balance
FROM attendance
LEFT JOIN (...payments aggregated...) pay USING(student_id)
GROUP BY student_id
HAVING balance < 0;

-- 流失预警：最近出勤时间超过 21 天
SELECT id, name FROM students
WHERE status = 'active'
  AND (
    SELECT MAX(date) FROM attendance
    WHERE student_id = students.id AND status IN ('present','late')
  ) < date('now', '-21 days');

-- 试听转化：有试听记录但无正式出勤
SELECT DISTINCT student_id FROM attendance WHERE status = 'trial'
EXCEPT
SELECT DISTINCT student_id FROM attendance WHERE status IN ('present','late');
```

---

## 数据库初始化与迁移

```dart
// database_helper.dart 关键逻辑
static const int _version = 4;
static const String _dbName = 'moyun.db';

Future<Database> _initDB() async {
  final path = join(await getDatabasesPath(), _dbName);
  return openDatabase(
    path,
    version: _version,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onOpen: (db) async {
      // 必须启用外键约束，否则 ON DELETE CASCADE 不生效
      await db.execute('PRAGMA foreign_keys = ON');
    },
  );
}

Future _onCreate(Database db, int version) async {
  // 按顺序执行上述所有 CREATE TABLE 语句
}

Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 4) {
    await _addColumnIfMissing(db, 'attendance', 'lesson_focus_tags TEXT');
    await _addColumnIfMissing(db, 'attendance', 'home_practice_note TEXT');
    await _addColumnIfMissing(db, 'attendance', 'progress_scores_json TEXT');
  }
}
```

### v4 迁移补充

- `students.note` 在 v2 引入，当前也建议通过列存在检查做幂等升级
- `dismissed_insights` 在 v3 引入，用于忽略已处理洞察
- `attendance.lesson_focus_tags`：课堂重点标签 JSON 数组
- `attendance.home_practice_note`：课后练习建议
- `attendance.progress_scores_json`：结构化进步评分 JSON
- 升级过程使用 `PRAGMA table_info` 检查列是否存在，避免重复升级时报错

---

## 备份策略

- 备份 = 直接复制 SQLite 数据库文件到 `Downloads/墨韵备份/` 目录
- 文件名格式：`backup_YYYYMMDD_HHmmss.db`
- 恢复 = 用户选择备份文件，覆盖当前数据库文件后重启 App
- 超过 7 天未备份：读取 `settings.last_backup_at`，在设置页显示橙色警告

---

## Runtime Naming Update

- Active SQLite file name: `moyun.db`
- Legacy SQLite file name: `calligraphy_assistant.db`
- Active temporary backup directory: `moyun_backups`
- Legacy temporary backup directory: `calligraphy_assistant_backups`

### Compatibility

At runtime the app now prefers `moyun.db`.
If only the legacy database file exists, `DatabaseHelper.resolveDatabasePath()` migrates the old database and its sidecar files (`-wal`, `-shm`, `-journal`) to the new name before opening it.

`BackupHelper` now reads the active database path via `DatabaseHelper.resolveDatabasePath()` and also migrates the legacy temporary backup directory to `moyun_backups` when needed.
