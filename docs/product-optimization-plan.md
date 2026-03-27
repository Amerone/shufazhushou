# 书法教育智能产品升级规划

## 初始化
您好，我是本项目的书法教育智能产品顾问，本次以中文输出，遵循“现状映射 -> 断点识别 -> 轻量干预 -> 洞察框架 -> 接口预留”的流程推进。基于项目当前已具备的学员档案、课时记录、多维统计、PDF/Excel 导出与本地设置能力，本规划目标是在保持离线优先与轻操作负担的前提下，让产品从“能用”进入“更懂教学、更会沟通、更利于续费”的阶段，这是一条值得持续打磨的正向路径。

## 项目现状判断
### 已有能力映射
| 模块 | 当前实现 | 典型使用时点 | 当前价值 |
| --- | --- | --- | --- |
| 首页 | 月历查看、`quick_entry_sheet` 三步记课、冲突覆盖确认 | 周一排课、每天课后记课 | 记录效率高，适合线下私教课堂批量签到 |
| 学生 | 学员档案、缴费记录、课次时间轴、单个学员报告导出 | 招生建档、课后跟进、续费前查看 | 基础档案闭环已形成 |
| 统计 | 指标卡、收入走势、贡献榜、状态分布、热力图、经营提醒 | 周复盘、月末对账 | 已具备数据看板雏形 |
| 导出 | PDF 预览/分享、Excel 导出、签名、水印、印章 | 家长反馈、财务留档、阶段汇报 | 已具备报告生成能力，但模板感不足 |
| 设置 | 教师信息、默认寄语、课堂模板、签名、印章、备份 | 日常维护、资料准备 | 支撑导出和本地数据安全 |

### 结合书法私教典型日程的效率断点
| 典型日程 | 现有承接 | 效率断点 | 机会判断 |
| --- | --- | --- | --- |
| 周一排课 | 课堂模板 + 快速记课 | 仅支持记录时段冲突，不支持未来排课冲突预检、补课推荐 | 应升级为 `schedule_conflict_guard` |
| 每日教学 | 出勤记录、备注 | 缺少对“笔势”“结体”“章法”等维度的结构化课堂反馈 | 应升级为 `teaching_feedback_struct` |
| 周五复盘 | 统计图表 + 经营提醒 | 统计有图无解释，提醒有规则无建议 | 应升级为 `insight_action_layer` |
| 月末对账 | 学生详情页余额 + PDF/Excel | 财务明细未区分课时费、材料费、优惠抵扣，追溯性一般 | 应升级为 `finance_trace_view` |
| 家长沟通 | 导出报告 + 默认寄语 | 家长 3 秒识别的信息仍不够聚焦，缺少“下次课”“余额提醒”“进步点”首屏摘要 | 应升级为 `parent_snapshot_header` |
| 续费转化 | 欠费提醒、试听转化提醒 | 只提醒问题，没有续费窗口和补救动作建议 | 应升级为 `renewal_opportunity_card` |

## 功能升级清单
### 高价值辅助功能
| 功能 | 目标 | 承接模块 | 轻量实现方案 | 优先级 |
| --- | --- | --- | --- | --- |
| `schedule_conflict_guard` | 在记课前减少冲突与重复沟通 | 首页、设置 | 基于 `class_templates`、`attendance`、教师偏好时段做预检；出现冲突时给出“覆盖”“改期”“推荐补课”三个动作 | P0 |
| `progress_timeline` | 让进步不止停留在备注文本 | 学生、导出 | 为每次课堂记录增加可选评估维度，自动生成学员进步轨迹和里程碑 | P0 |
| `balance_alert_center` | 提前触发续费沟通 | 学生、统计 | 新增余额预警规则：余额 `< 3.00` 课时或近 `14` 天预计耗尽时触发提醒 | P0 |
| `parent_snapshot_header` | 让家长 3 秒读懂报告重点 | 导出 | 在 PDF 首屏固定展示余额、下次课、进步点、待改进点、老师寄语摘要 | P1 |
| `saved_query_hub` | 降低老师重复筛选成本 | 学生、统计 | 支持保存 `{saved_query}`，例如“本月试听未转正”“近 30 天欠费学员” | P1 |

### 现有模块对应优化
| 现有模块 | 建议升级点 | 说明 |
| --- | --- | --- |
| 首页 | 从“记课入口”升级为“今日教学工作台” | 增加今日冲突、待补课、待续费、待发送报告 4 类任务摘要 |
| 学生 | 从“档案详情”升级为“成长与续费工作台” | 强化阶段目标、进步轨迹、余额消耗趋势 |
| 统计 | 从“看板”升级为“洞察中心” | 每个图表上方增加一句话摘要，下方提供动作建议 |
| 导出 | 从“导出配置”升级为“沟通产物中心” | 加入模板、品牌水印、一键分享目标渠道预设 |
| 设置 | 从“系统设置”升级为“教学策略设置” | 新增提醒规则、评估维度权重、家长查看权限配置 |

## 断点到轻量干预
### 干预策略表
| 效率断点 | 干预方案 | 触发条件 | 输出结果 |
| --- | --- | --- | --- |
| 连续缺勤未被关注 | `absence_streak_tag` | 学员连续 `2` 次 `absent` 或 `leave` | 自动高亮学员并给出回访建议 |
| 试听后无转化动作 | `trial_followup_prompt` | 试听后 `7` 天内无正式出勤 | 生成跟进话术与推荐时段 |
| 老师重复查余额 | `balance_alert` | 余额 `< 3.00` 课时或余额 `< ¥300.00` | 首页、学生页、统计页同时显示提醒 |
| 月末临时做报告 | `report_ready_signal` | 学员本月有 `>= 2` 次正式课程 | 自动提示可一键生成家长版月报 |
| 课堂内容难复盘 | `lesson_focus_quick_tag` | 记录出勤时勾选课堂重点 | 汇入进步轨迹和报告摘要 |
| 手工判断补课时间 | `makeup_slot_recommendation` | 冲突、请假、缺勤发生后 | 推荐 `{recommended_slot}` 列表 |

### 干预优先级规则
1. `{fixed_schedule}` > `{teacher_preference}` > `{student_availability}`。
2. 先减少老师判断成本，再增加信息丰富度。
3. 所有自动建议必须带 `{calc_logic}` 与 `{data_freshness}`。
4. 所有提醒必须可忽略、可追溯、可恢复，不制造“提醒噪音”。
5. 单屏仅展示 5 个核心元素，多余信息折叠到“查看明细”。

## 统计洞察层规划
### 洞察分层
| 层级 | 输入 | 输出 | 约束 |
| --- | --- | --- | --- |
| `raw_record_layer` | `students`、`attendance`、`payments`、`settings` | 原始事实记录 | 不做结论，只做可信存储 |
| `metric_layer` | 原始记录聚合 | 课次、金额、出勤率、试听转化率、余额、活跃度 | 每个指标必须有 `{dimension}` 与 `{metric}` |
| `insight_layer` | 指标 + 时间范围 + 基准对比 | 可解释的经营或教学洞察 | 必须声明 `{time_range}`、`{benchmark}`、`{data_freshness}` |
| `action_layer` | 洞察结果 | 可点击动作，如“联系家长”“生成报告”“安排补课” | 一条洞察最多给 2 个动作 |

### 建议新增洞察主题
| 洞察主题 | 计算逻辑 | 数据时效 | 建议动作 |
| --- | --- | --- | --- |
| `attendance_risk_insight` | 最近 `{time_range}` 出勤率较 `{benchmark}` 下滑 `>= 20%` | 实时刷新 | 回访、补课建议 |
| `renewal_window_insight` | 余额可支撑课次 `< 3.00` 或预计 `14` 天内耗尽 | 每次记课/缴费后刷新 | 续费沟通、发送账单 |
| `progress_gain_insight` | `{stroke_quality}` 或 `{structure_accuracy}` 连续 `3` 次提升 | 每次记录后刷新 | 生成成长快照、鼓励家长陪练 |
| `practice_gap_insight` | 两次正式上课间隔 `> 10` 天 | 每日首次打开统计页刷新 | 提醒安排复习任务 |
| `trial_conversion_insight` | 试听后 `7` 天无正式课，或试听后 `14` 天成功转正 | 每日刷新 | 跟进话术、推荐首月课包 |

### 移动端洞察卡结构
| 区块 | 内容 |
| --- | --- |
| 摘要 | 一句话结论，限制在 `24` 字内 |
| 明细 | 展示 `{time_range}`、`{benchmark}`、`{metric_value}`、`{data_freshness}` |
| 建议 | 1 到 2 个动作按钮，附带原因说明 |

### 洞察输出模板
```md
摘要：
{summary_text}

明细：
- 时间范围：{time_range}
- 学员标签：{student_tags}
- 对比基准：{benchmark}
- 指标结果：{metric_value}
- 计算逻辑：{calc_logic}
- 数据时效：{data_freshness}

建议：
- {action_1}
- {action_2}
```

### 数据洞察 Prompt 框架
```md
你是书法教学数据洞察助手，请基于以下输入输出适合移动端展示的洞察卡。

输入：
- 时间范围：{time_range}
- 学员标签：{student_tags}
- 对比基准：{benchmark}
- 统计维度：{dimension}
- 核心指标：{metric}
- 原始数据摘要：{raw_data_summary}
- 数据时效：{data_freshness}

要求：
- 必须输出“摘要 + 明细 + 建议”三段。
- 摘要不得使用“表现良好”“情况一般”这类模糊表述。
- 建议必须可执行，且优先减少老师操作负担。
- 如涉及书法专业判断，优先使用 `{stroke_quality}` `{structure_accuracy}` `{rhythm_consistency}` 等维度。
- 如涉及金额，统一保留 2 位小数。
- 如涉及时间，统一使用 `YYYY-MM-DD HH:mm`。
```

## 教学数据结构升级建议
### 建议新增或扩展字段
| 数据对象 | 字段 | 类型 | 用途 |
| --- | --- | --- | --- |
| `attendance` | `lesson_focus_tags` | TEXT/JSON | 记录本次课堂重点，如偏旁结构、控笔、章法 |
| `attendance` | `home_practice_note` | TEXT | 记录课后练习建议 |
| `attendance` | `progress_scores_json` | TEXT/JSON | 记录 `{stroke_quality}`、`{structure_accuracy}`、`{rhythm_consistency}` 等评分 |
| `payments` | `payment_category` | TEXT | 区分课时费、材料费、优惠抵扣 |
| `students` | `student_tags_json` | TEXT/JSON | 存储 `{skill_level}`、`{learning_pace}`、`{focus_area}` |
| `students` | `milestone_config_json` | TEXT/JSON | 自定义成长节点 |
| 通用 | `extension_json` | TEXT/JSON | 预留 AI 笔迹分析或第三方数据写入 |

### 书法专业评估维度建议
| 维度 | 适用说明 | 推荐权重提示 |
| --- | --- | --- |
| `{stroke_quality}` | 适合基础笔画训练与控笔稳定性观察 | 楷书高 |
| `{structure_accuracy}` | 适合观察结体与重心 | 楷书、隶书高 |
| `{rhythm_consistency}` | 适合观察节奏与连贯性 | 行书高 |
| `{ink_control}` | 适合观察墨色浓淡与提按 | 行书、隶书中 |
| `{chapter_layout}` | 适合作品布局与章法评估 | 创作课高 |

## PDF 与导出体验规划
### 报告模板策略
| `template_id` | 适用场景 | 首屏核心元素 |
| --- | --- | --- |
| `simple_monthly` | 日常月报 | 余额、下次课、进步点、待提升点、老师寄语 |
| `growth_portfolio` | 阶段成长档案 | 里程碑、课堂重点、作品点评、家长建议、费用概览 |
| `finance_statement` | 对账确认 | 期初余额、课时费、材料费、优惠抵扣、期末余额 |

### 导出体验升级点
1. 在导出前支持选择 `{template_id}`、`{brand_watermark}`、`{share_target}`。
2. PDF 首页固定展示 `余额 / 下次课 / 进步点 / 待提升点 / 数据截止说明` 5 项。
3. 支持“老师版”“家长版”两套字段可见性，避免过量暴露经营数据。
4. 分享链路增加“保存本地”“微信转发预备文案”“导出图片摘要页”。
5. 生成进度文案可保留书法文化气质，但不影响效率，例如“正在整理本月笔墨轨迹”。

### 财务展示规范
| 项目 | 展示规则 |
| --- | --- |
| 课时费 | 由正式出勤和迟到计费产生 |
| 材料费 | 单独列项，不与课时费混算 |
| 优惠抵扣 | 作为负向金额列示，支持备注来源 |
| 余额 | `总已收 - 总应收`，保留 `2` 位小数 |
| 数据截止 | 固定展示 `数据截止至 {data_freshness}` |

## 老师-家长-学员三方视角
### 权限与展示逻辑
| 视角 | 可见信息 | 不建议展示 |
| --- | --- | --- |
| 老师 | 全量档案、全部出勤、财务明细、洞察建议、内部标签 | 无 |
| 家长 | 学员出勤摘要、余额、下次课、进步点、课后建议、阶段报告 | 其他学员对比、内部经营提醒、敏感标签 |
| 学员 | 成长里程碑、作品点评、课堂目标、勋章式反馈 | 余额、家长联系方式、内部续费提醒 |

### 权限控制字段
| 字段 | 说明 |
| --- | --- |
| `{share_permission}` | 控制是否允许查看全量报告、余额、费用明细 |
| `{report_audience}` | 区分 `teacher`、`parent`、`student` 输出风格 |
| `{sensitive_mask}` | 控制手机号、内部备注等敏感字段脱敏 |

## 扩展接口定义
### 领域接口建议
```ts
type InsightRequest = {
  time_range: string;
  student_tags: string[];
  benchmark: string;
  dimension: 'student' | 'date' | 'course_type';
  metric: 'attendance_rate' | 'balance' | 'progress_gain' | 'trial_conversion';
  data_freshness: string;
};

type InsightResponse = {
  summary: string;
  details: {
    metric_value: string;
    calc_logic: string;
    benchmark: string;
    data_freshness: string;
  };
  suggestions: string[];
};

type HandwritingAnalysisPayload = {
  student_id: string;
  work_id: string;
  script_type: 'kaishu' | 'xingshu' | 'lishu' | 'zhuanshu';
  image_uri: string;
  extension_json?: Record<string, unknown>;
};

type CourseRecommendationPayload = {
  student_id: string;
  skill_level: string;
  focus_area: string[];
  recent_progress_scores: Record<string, number>;
  balance_lessons: number;
};
```

### REST 风格接口预留
| 接口 | 方法 | 说明 |
| --- | --- | --- |
| `/api/v1/insights/generate` | `POST` | 生成统计洞察卡 |
| `/api/v1/reports/render` | `POST` | 根据 `{template_id}` 输出报告 |
| `/api/v1/handwriting/analyze` | `POST` | 接入 AI 笔迹分析 |
| `/api/v1/courses/recommend` | `POST` | 基于阶段表现推荐课程 |
| `/api/v1/share-permissions/{student_id}` | `PUT` | 维护家长查看权限 |

### 本地优先兼容策略
1. 先在本地领域层定义 `service_contract`，避免 UI 直接耦合远端接口。
2. 远端能力接入后，通过适配器实现 `local_first + remote_enhanced` 模式。
3. 所有 AI 扩展结果都写入 `{extension_json}`，保证离线主流程不受影响。

## 分阶段路线图
### Phase 1
| 目标 | 交付 |
| --- | --- |
| 降低日常操作负担 | `schedule_conflict_guard`、`balance_alert_center`、一句话洞察、导出模板选择 |
| 强化可追溯性 | 财务分类、数据截止说明、洞察计算逻辑展示 |

### Phase 2
| 目标 | 交付 |
| --- | --- |
| 提升教学价值表达 | `progress_timeline`、课堂重点标签、阶段成长报告 |
| 提升家长沟通效率 | `parent_snapshot_header`、分享权限、快捷沟通文案 |

### Phase 3
| 目标 | 交付 |
| --- | --- |
| 预留 AI 增强能力 | 笔迹分析接口、课程推荐接口、统一扩展字段 |
| 打通长期经营能力 | 续费预测、补课推荐、学员成长里程碑体系 |

## 五维建议体系
### 可操作性
1. 为首页增加 `{quick_mark}` 长按学员名直接完成签到、扣费、补记备注。
2. 在统计页加入 `{time_compare}` 切换，支持“本周 vs 上周”“本月 vs 上月”。
3. 为导出入口增加 `{template_id}` 预设，默认记忆上一次选择。
4. 为余额提醒建立 `{balance_alert}` 规则中心，支持 `¥300.00` 与 `3.00` 课时双阈值。
5. 为高频筛选建立 `{saved_query}` 快捷入口，减少老师重复点击。

### 逻辑性
1. 明确采用“原始记录 -> 聚合指标 -> 洞察建议”的三层数据管道。
2. 所有统计卡都必须带 `{dimension}` 与 `{metric}`，避免同名指标歧义。
3. 对“最近情况”“近期表现”类查询，统一走时间范围澄清链。
4. 洞察卡必须固定展示 `{calc_logic}` 与 `{data_freshness}`，提高可信度。
5. 排课冲突判断统一遵循 `{fixed_schedule}` > `{teacher_preference}` > `{student_availability}`。

### 专业性
1. 在点评和报告中内置 `{stroke_quality}`、`{structure_accuracy}`、`{rhythm_consistency}` 评估维度。
2. 进步结论必须引用具体案例，如“见 {lesson_date} 课堂记录”。
3. 按书体切换权重，楷书重 `{structure_accuracy}`，行书重 `{rhythm_consistency}`。
4. 财务明细必须区分课时费、材料费、优惠抵扣，符合家长认知。
5. 学员标签建议采用 `{skill_level}`、`{learning_pace}`、`{focus_area}` 三类核心标签。

### 扩展性
1. 为核心对象预留 `{extension_json}`，接住 AI 与第三方能力结果。
2. 为成长轨迹提供 `{milestone_config}`，支持“掌握永字八法”等自定义节点。
3. 为统计导出定义 `{export_schema}`，便于后续接 BI 或小程序。
4. 在洞察 Prompt 中预留 `{ai_assistant_mode}`，兼容“简洁回复 / 深度分析”。
5. 为家长侧建立 `{share_permission}` 粒度控制，避免一次性开放所有数据。

### 体验感
1. 每个统计分区前置一句话洞察，降低老师读图成本。
2. 在操作成功反馈中保留克制的书法意象动效，不增加等待负担。
3. 学员列表增加 `{pin_important}`，置顶高频学员或待续费学员。
4. PDF 生成过程展示简短文化化进度文案，缓解等待焦虑。
5. 夜间使用场景可预留 `{theme_mode: 'ink_dark'}`，但需保持信息对比清晰。

## 建议的研发落点
### 文档与数据层
1. 先更新 `docs/database-design.md`，补齐新增字段与追溯规则。
2. 在 `lib/core/models/` 中为结构化评估与权限字段预留对象。
3. 在 `lib/core/providers/insight_provider.dart` 上方新增洞察聚合服务层，避免规则堆叠在 Provider 内。

### 页面与交互层
1. 首页优先增加“今日待办摘要”与冲突预警，不先做复杂课表。
2. 学生详情页优先增加成长轨迹和续费机会卡。
3. 导出页优先增加模板选择与家长版首屏摘要。

### 验收标准
1. 老师在 3 次点击内完成“查看提醒 -> 处理问题 -> 发出报告”。
2. 家长在 3 秒内识别“余额 / 下次课 / 进步点”。
3. 任一洞察都能追溯到原始记录、计算逻辑和数据截止时间。
