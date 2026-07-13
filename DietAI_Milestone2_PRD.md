# DietAI — Milestone 2 需求文档（体验升级版）

> **版本**: v1.0  
> **更新日期**: 2026-07-07  
> **文档目的**: 明确 Milestone 2 体验升级需求、功能范围、验收标准与分工边界，为 APP 端、后端、AI Agent、硬件联动提供统一依据

---

## 一、文档概述

### 1.1 项目定位

DietAI 是一款面向追求趣味化健康管理的智能饮食健康移动应用。Milestone 1 已完成用户认证、饮食/饮水/运动记录、AI 饮食建议、养生推荐等基础能力。Milestone 2 在基础能力之上进行体验升级，让用户不仅能记录数据，还能直观查看消费开销、与虚拟形象互动、获得个性化 AI 健康建议，并在安全前提下尝试科学的轻断食管理。

### 1.2 Milestone 2 核心目标

完成移动端 APP 体验升级版本开发，实现以下四大核心功能：

1. **饮食消费记录与统计** — 在饮食记录中增加消费金额与来源标签，生成多维度消费统计报表
2. **虚拟形象联动养成** — 将 App 端已有的"宠物精灵"与硬件端宠物时钟打通联动，实现两端状态同步与互动反馈
3. **AI 健康顾问风格定制** — 在合规前提下，提供营养师、运动教练、中医养生师等专业顾问风格选择
4. **轻断食/辟谷科学引导** — 为减脂/养生用户提供科学的轻断食计划与辟谷引导流程

### 1.3 交付物与验收

| 项 | 内容 |
| --- | --- |
| 预期周期 | 10 天（暑假集中冲刺开发，可并行） |
| 核心交付物 | 1. 可运行移动端 APP 体验升级版本；2. 数据库变更文档、接口文档；3. 功能测试文档、虚拟形象联动测试记录 |
| 验收标准 | 四大核心功能正常使用，无严重 Bug，数据可正常保存，App 与硬件状态可同步，AI 输出符合合规要求 |

---

## 二、团队分工

| 角色 | 主责范围 | 协作范围 |
| --- | --- | --- |
| 胡馨（项目经理 / 统筹） | 需求评审、进度管控、文档同步、对接老师、架构设计文档输出 | 全模块测试、Bug 汇总分配、硬件联调 |
| 张正宏（前端 + Agent） | 移动端 APP 页面、UI 设计、交互逻辑、AI Agent prompt 模板与风格适配 | 配合前后端联调、UI 优化、虚拟形象动画 |
| 何丽（后端） | 数据库设计、接口开发、数据存储、虚拟形象状态服务、轻断食计划服务 | 配合前后端联调、数据同步、硬件协议对接 |

---

## 三、现有功能清单（Milestone 1 已交付）

> 以下为 Milestone 1 已交付并在 Milestone 2 中继续复用的核心能力。

### 3.1 用户与认证

| 功能 | 状态 | 前端 | 后端 | 说明 |
| --- | --- | --- | --- | --- |
| 注册/登录 | 已实现 | login_page, register_page | POST /auth/register, /auth/login | JWT 双 token 机制 |
| Token 刷新 | 已实现 | 自动 401 刷新 | POST /auth/refresh-token | access + refresh token |
| 用户资料管理 | 已实现 | profile_page, profile_edit_sheet | GET/PUT /users/profile | 姓名、性别、生日、身高体重等 |
| 健康目标管理 | 已实现 | health_goals_page, create_goal_modal | POST/GET/PUT /users/health-goals | 5 种目标类型：减脂/增肌/维持/减重/增重 |
| 体重记录 | 已实现 | weight_tracking_page, add_weight_modal | POST/GET /users/weight-records | 体重、体脂率、肌肉量、BMI 自动计算 |

### 3.2 饮食记录与分析

| 功能 | 状态 | 前端 | 后端/AI | 说明 |
| --- | --- | --- | --- | --- |
| 拍照记录饮食 | 已实现 | camera_page, food_analysis_page | POST /foods/records (SSE) | 拍照→AI 识别→营养分析流式推送 |
| 手动录入饮食 | 已实现 | food_record_modal | POST /foods/records/traditional | 文字描述录入，AI 自动计算营养素 |
| 食物营养详情 | 已实现 | nutrition_stats_card | GET /foods/records/{id} | 16 项营养素详情 |
| 每日营养汇总 | 已实现 | home_page 卡路里追踪器 | GET /foods/daily-summary/{date} | 总热量、蛋白质、脂肪、碳水、纤维、钠 |
| 营养趋势 | 已实现 | data_visualization_page | GET /foods/nutrition-trends | 按日/周/月展示趋势图表 |

### 3.3 AI 对话与建议

| 功能 | 状态 | 前端 | 后端/AI | 说明 |
| --- | --- | --- | --- | --- |
| AI 聊天（SSE 流式） | 已实现 | chat_page, chat_sessions_page | POST /chat/send-message-stream | 多类型会话：营养咨询/健康评估/食物识别/运动建议/养生咨询 |
| 会话管理 | 已实现 | chat_sessions_page | GET/POST/DELETE /chat/sessions | 创建、查看、删除会话 |
| 会话上下文 | 已实现 | — | GET /chat/sessions/{id}/context | 加载用户资料、最近饮食、健康目标作为上下文 |
| 个性化饮食建议 | 已实现 | — | enhanced_nutrition_agent | 结合用户偏好、一周历史、过敏信息生成建议 |

### 3.4 喝水/运动/提醒

| 功能 | 状态 | 前端 | 后端 | 说明 |
| --- | --- | --- | --- | --- |
| 喝水记录 | 已实现 | water_intake_widget | POST/GET /api/water/records | 支持快速添加、自定义容量、进度环 |
| 运动记录 | 已实现 | exercise_record_page | POST/GET /api/exercises/records | 类型/时长/强度/热量消耗 |
| 提醒设置 | 已实现 | reminder_settings_page | CRUD /api/reminders | 喝水/吃饭提醒，本地通知 |
| 习惯连续天数 | 已实现 | habit_streak_badge | GET /health/habit-streak | 饮水+三餐连续达标天数 |

### 3.5 虚拟形象（Milestone 1 预留）

| 功能 | 状态 | 说明 |
| --- | --- | --- |
| 数据接口预留 | 已实现 | reminders 表预留 virtual_pet_status JSON 字段，habit_score 计算逻辑已落地 |
| App 端宠物入口 | 占位 | 首页或健康页预留宠物展示入口，Milestone 2 补全 |

### 3.6 基础设施

| 基础设施 | 状态 | 说明 |
| --- | --- | --- |
| PostgreSQL 数据库 | 已部署 | 存储用户、饮食、运动、喝水、提醒、会话等数据 |
| Redis 缓存 | 已部署 | 缓存高频查询，限流 |
| MinIO 对象存储 | 已部署 | 存储食物图片文件 |
| FastAPI 后端服务 | 已部署 | 以 systemd 服务运行，端口 8866，单 worker |
| ESP32-S3 宠物时钟 | 已联调 | 屏幕、WiFi、按钮、基础提醒展示 |
| ESP32-CAM 摄像头 | 已就绪 | 串口协议、JPEG 分片传输、动作检测已完成 |

---

## 四、Milestone 2 新增需求

> 基于现有功能，以下为 Milestone 2 需要新增或强化的功能，按四大核心功能拆解。

---

### 功能 1：饮食消费记录与统计

#### 1.1 需求背景

现有饮食记录已支持食物名称、图片、营养素、餐次等信息，但缺少消费金额维度。学生党、上班族、减脂用户均有查看饮食开销、优化预算的诉求。本期在饮食记录中增加消费金额与来源标签，并基于时间、餐次、来源等维度生成统计报表，让健康管理与消费管理结合。

#### 1.2 新增功能需求

##### 1.2.1 消费金额与来源记录

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 消费金额输入 | 记录饮食时可选填金额（元），支持整数/小数，允许为空 | 前端：food_record_modal；后端：food_records 表新增 cost 字段 | P0 |
| 消费来源标签 | 支持标记来源：食堂、外卖、自制、餐厅、零食、其他 | 前端：food_record_modal 来源选择器；后端：food_records 表新增 source_tag 字段 | P0 |
| 历史记录补录 | 已存在的饮食记录支持编辑补充金额和来源标签 | 前端：food_record_detail_page / food_record_modal；后端：PUT /foods/records/{id} | P1 |
| 金额校验 | 金额字段为非负数，最大值 99999.99，防止异常输入 | 后端：Pydantic 校验 + 数据库约束 | P1 |

##### 1.2.2 消费统计首页

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 总开销卡片 | 展示本周/本月总开销、日均开销、最贵单笔、记录笔数 | 前端：cost_statistics_page；后端：GET /foods/cost-stats | P0 |
| 分类对比 | 按餐次（早/午/晚/加餐）、来源（食堂/外卖/自制等）对比花费 | 前端：cost_statistics_page 饼图/柱状图；后端：GET /foods/cost-stats | P0 |
| 趋势图表 | 近 7 天/30 天饮食开销折线图，支持按来源筛选 | 前端：cost_trend_chart；后端：GET /foods/cost-trend | P0 |
| 与热量关联 | 展示"每元热量"指标，帮助用户评估饮食性价比 | 前端：cost_statistics_page；后端：GET /foods/cost-stats 计算 | P1 |

##### 1.2.3 消费预算与提醒

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 月度预算设定 | 用户可设定每月饮食预算，首页展示剩余预算 | 前端：settings_page；后端：user_profiles 新增 monthly_food_budget | P1 |
| 预算预警 | 当月消费达到预算 80%/100% 时给出提醒 | 后端：每日汇总时计算；前端：首页提示 | P2 |

#### 1.3 验收标准

- [ ] 记录饮食时可输入金额和来源标签，金额校验正确
- [ ] 首页/统计页展示本周/本月消费总额、日均消费、最贵单笔
- [ ] 支持按餐次、来源筛选统计
- [ ] 近 7 天/30 天消费趋势图正常显示
- [ ] "每元热量"指标计算正确
- [ ] 历史记录可补充金额和来源标签

---

### 功能 2：虚拟形象联动养成

#### 2.1 需求背景

App 端已有"宠物精灵"概念，Milestone 1 已预留 habit_score 和虚拟形象相关数据字段。Milestone 2 将 App 端宠物精灵与硬件端 ESP32-S3 宠物时钟打通联动，核心目标是增加用户使用软件的粘性，让饮食记录过程更有趣味性。硬件作为 App 的扩展场景，核心体验仍以 App 为主体。

#### 2.2 新增功能需求

##### 2.2.1 宠物状态模型

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 宠物状态表 | 新增 virtual_pet_states 表：user_id, mood（正常/开心/饥饿/焦虑/虚弱）, level, exp, current_skin, unlocked_skins, last_interact_at, created_at | 后端：新建 pet_models.py, 迁移脚本 | P0 |
| 状态计算规则 | 根据当日饮食达标率、饮水达标率、连续达标天数计算 mood 和 exp | 后端：pet_service.py | P0 |
| 状态映射 | 正常/开心/饥饿/焦虑/虚弱五种状态，对应不同动画和提示语 | 前端：pet_animation_widget；后端：pet_service.py | P0 |
| 等级成长 | 累计经验值升级，每级解锁新外观或动作候选 | 后端：pet_service.py | P1 |

##### 2.2.2 App 端宠物展示

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 首页宠物入口 | 在首页展示 2D/伪 3D 宠物形象，点击可进入宠物详情页 | 前端：pet_home_page, pet_animation_widget | P0 |
| 宠物详情页 | 展示宠物当前状态、等级、经验、已解锁外观/动作、互动按钮 | 前端：pet_detail_page | P0 |
| 记录后即时反馈 | 用户完成饮食/饮水记录后，宠物弹出开心动画和正向反馈文案 | 前端：food_record_modal, water_intake_widget；后端：pet_service 触发 | P0 |
| 连续达标解锁 | 连续 3 天饮食/饮水达标解锁宠物新动作或装扮 | 后端：pet_service；前端：pet_detail_page 解锁提示 | P1 |

##### 2.2.3 硬件端联动

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 状态同步接口 | 硬件端通过轮询或 WebSocket 获取宠物状态（mood/level/skin） | 后端：新增 GET /api/virtual-pet/status-for-device；硬件：ESP32-S3 轮询 | P0 |
| 硬件表情映射 | ESP32-S3 根据 mood 展示对应表情/动画 | 硬件：dietai-firmware/src/main.cpp | P0 |
| 拍照互动联动 | 用户完成拍照识别并确认记录后，硬件端展示拍照成功动画 | 后端：记录确认后通知硬件；硬件：main.cpp | P1 |
| 喂食互动 | 用户点击"喂食"按钮，硬件端展示进食动画 | 前端：pet_detail_page；后端：POST /api/virtual-pet/feed；硬件：main.cpp | P2 |

##### 2.2.4 数据同步策略

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| App → 后端 | 用户记录饮食/饮水后，后端实时更新宠物状态 | 后端：food/water service 调用 pet_service | P0 |
| 后端 → 硬件 | 硬件每 30 秒轮询一次状态，或后端通过 MQTT/WebSocket 推送 | 后端/硬件 | P0 |
| 状态一致性 | 确保 App、后端、硬件三端状态最终一致 | 后端：pet_service 状态版本号；硬件：ACK 确认 | P1 |

#### 2.3 验收标准

- [ ] App 首页展示宠物形象，状态与后端数据一致
- [ ] 记录饮食/饮水后宠物状态更新并展示反馈动画
- [ ] 宠物状态有五种 mood，状态计算规则正确
- [ ] 连续达标 3 天可解锁新动作/装扮
- [ ] 硬件端能获取并展示宠物状态
- [ ] 不连接硬件时，App 端宠物功能仍可独立使用

---

### 功能 3：AI 健康顾问风格定制

#### 3.1 需求背景

现有 AI 助手风格单一，Milestone 2 在合规前提下提供专业顾问风格选择，让用户自定义 AI 的输出风格和专业偏向。该功能定位为"AI 健康顾问风格 customization"，使用营养师、运动教练、中医养生师等专业人设，避免情感依赖诱导。

#### 3.2 新增功能需求

##### 3.2.1 顾问风格选择

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 风格预设 | 提供 4 种预设风格：营养师（均衡科普）、运动教练（严格激励）、中医养生师（温和调理）、鼓励型伙伴（亲切但不越界） | 前端：advisor_style_page；后端：ai_advisor_settings 表 | P0 |
| 专业偏向 | 用户可选择关注重点：减脂/增肌/控糖/养生/均衡饮食 | 后端：ai_advisor_settings 表；AI：prompt 注入 | P0 |
| 关注营养素 | 用户可选择关注：热量/蛋白质/碳水/脂肪/微量元素 | 后端：ai_advisor_settings 表；AI：prompt 注入 | P1 |
| 提醒方式 | 用户可选择输出风格：简洁直接/详细解释/举例说明 | 后端：ai_advisor_settings 表；AI：prompt 注入 | P1 |

##### 3.2.2 Prompt 模板管理

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 风格化系统提示词 | 每种风格对应独立 system prompt 模板，定义语气、用词、回答结构 | AI：advisor_style_prompts.py | P0 |
| 上下文注入 | AI 回答时注入用户选择的风格、专业偏向、关注重点 | AI：chat_agent, enhanced_nutrition_agent | P0 |
| 风格切换即时生效 | 用户切换风格后，下一条 AI 回答立即应用新风格 | 后端：ai_advisor_settings 实时读取；AI：每次请求注入 | P0 |

##### 3.2.3 合规控制

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 禁用情感人设 | 不提供恋人、偶像、乙游男主等强情感绑定选项 | 前端：选项过滤；后端：配置白名单 | P0 |
| 禁用诱导话术 | Prompt 中禁止出现"我会一直陪着你"、"主人"、"专属陪伴者"等诱导性表达 | AI：prompt 审核规则 | P0 |
| 免责声明 | 对话开头或涉及健康方案时，明确"我是 AI 健康顾问，建议仅供参考，不能替代医生诊断" | AI：所有风格 prompt 强制追加 | P0 |

#### 3.3 验收标准

- [ ] 支持选择至少 4 种顾问风格
- [ ] 选择风格后 AI 输出语气明显变化
- [ ] 专业偏向、关注重点、提醒方式可配置
- [ ] 对话开头显示 AI 身份免责声明
- [ ] 不提供恋人/偶像等人设选项
- [ ] 专业建议包含"请咨询医生"提示

---

### 功能 4：轻断食/辟谷科学引导

#### 4.1 需求背景

减脂/养生用户常有轻断食需求，但盲目断食存在健康风险。本期提供科学的 16:8、5:2 轻断食计划和循序渐进的辟谷引导流程，包含健康评估、监测、风险预警和复食指导，确保功能安全合规。

#### 4.2 新增功能需求

##### 4.2.1 断食模式选择

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 模式选择 | 支持 16:8 轻断食、5:2 轻断食、基础辟谷引导三种模式 | 前端：fasting_plan_page；后端：fasting_plans 表 | P0 |
| 计划生成 | 根据目标体重、周期、生活习惯生成每日饮食窗口建议 | 后端：fasting_service.py；AI：fasting_advisor | P0 |
| 计划编辑 | 用户可调整进食窗口、提醒时间、目标体重 | 前端：fasting_plan_page；后端：PUT /fasting/plans | P1 |

##### 4.2.2 健康评估与禁忌筛查

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 启用前评估 | 首次启用前收集 BMI、既往病史、饮食习惯，进行禁忌人群筛查 | 前端：fasting_assessment_page；后端：fasting_records 表 | P0 |
| 强制免责声明 | 首次启用前强制阅读免责声明并确认 | 前端：弹窗确认；后端：记录确认时间 | P0 |
| 禁忌人群拦截 | 孕妇、哺乳期、未成年人、糖尿病患者、进食障碍患者、BMI 过低者无法启用辟谷/高风险模式 | 后端：fasting_service 拦截逻辑 | P0 |

##### 4.2.3 执行监测与提醒

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 进食窗口提醒 | 进食窗口开始/结束提醒、喝水提醒 | 后端：复用 reminder 模块；前端：fasting_timer_widget | P0 |
| 每日打卡 | 记录体重、体感、完成情况、是否出现不适 | 前端：fasting_checkin_page；后端：fasting_checkins 表 | P0 |
| 进度追踪 | 展示已完成天数、体重变化、达标率 | 前端：fasting_progress_page；后端：GET /fasting/progress | P1 |

##### 4.2.4 风险预警与复食指导

| 子功能 | 需求描述 | 涉及模块 | 优先级 |
| --- | --- | --- | --- |
| 风险预警 | 出现头晕、低血糖、心悸等症状时提示停止并就医 | 前端：fasting_checkin_page 不适选项；后端/AI：预警提示 | P0 |
| 复食指导 | 辟谷/断食结束后 3-7 天渐进复食方案 | AI：fasting_advisor；前端：fasting_refeed_page | P1 |
| 紧急停止 | 用户可随时停止计划，停止后进入复食指导或正常模式 | 前端：fasting_plan_page；后端：PUT /fasting/plans/{id}/stop | P1 |

#### 4.3 验收标准

- [ ] 支持 16:8、5:2 计划生成
- [ ] 启用前强制健康评估和免责声明
- [ ] 禁忌人群无法启用高风险模式
- [ ] 进食窗口开始/结束提醒正常推送
- [ ] 每日打卡可记录体重、体感、完成情况
- [ ] 出现不适症状时提示停止并就医
- [ ] 提供复食指导方案

---

## 五、数据库新增/修改需求

### 5.1 新增表

| 表名 | 核心字段 | 说明 |
| --- | --- | --- |
| virtual_pet_states | id, user_id(FK), mood(varchar), level(int), exp(int), current_skin(varchar), unlocked_skins(json), habit_score(int), last_interact_at(datetime), created_at | 用户虚拟宠物状态 |
| pet_unlockables | id, unlock_type(varchar:skin/action), unlock_key(varchar), name(varchar), description(text), required_level(int/NULL), required_streak(int/NULL), created_at | 宠物可解锁内容定义 |
| ai_advisor_settings | id, user_id(FK), advisor_style(varchar), focus_goal(varchar), focus_nutrient(varchar), response_style(varchar), created_at, updated_at | AI 顾问风格设置 |
| fasting_plans | id, user_id(FK), plan_type(varchar:16_8/5_2/basic_fasting), target_weight(decimal/NULL), start_date(date), end_date(date/NULL), status(varchar:active/paused/stopped/completed), eating_window(varchar), disclaimer_accepted(bool), created_at, updated_at | 轻断食/辟谷计划 |
| fasting_checkins | id, plan_id(FK), checkin_date(date), weight(decimal/NULL), feeling(varchar), completed(bool), discomfort(json/NULL), notes(text), created_at | 轻断食每日打卡 |

### 5.2 修改表

| 表名 | 修改 | 说明 |
| --- | --- | --- |
| food_records | 新增 cost(decimal(10,2), nullable), source_tag(varchar, nullable) | 记录饮食消费金额和来源 |
| user_profiles | 新增 monthly_food_budget(decimal(10,2), default=0) | 月度饮食预算 |
| reminders | 新增 fasting_plan_id(FK, nullable) | 关联断食计划提醒 |

### 5.3 已有表利用

| 表名 | 利用说明 |
| --- | --- |
| daily_nutrition_summaries | 用于计算宠物 mood、饮食达标率、消费统计 |
| water_intake_records | 用于计算饮水达标率和宠物 habit_score |
| conversation_sessions | AI 顾问风格设置影响 chat_agent 输出 |
| food_records | 新增 cost/source_tag 后用于消费统计 |

---

## 六、API 新增/修改需求

### 6.1 新增 API

| 模块 | 方法 | 路径 | 说明 |
| --- | --- | --- | --- |
| 消费统计 | GET | /api/foods/cost-stats | 本周/本月消费总额、日均、最贵单笔、分类对比 |
| 消费统计 | GET | /api/foods/cost-trend | 近 7/30 天消费趋势，支持按 source_tag 筛选 |
| 虚拟宠物 | GET | /api/virtual-pet/status | 获取当前用户宠物状态 |
| 虚拟宠物 | GET | /api/virtual-pet/status-for-device | 供硬件端轮询获取状态 |
| 虚拟宠物 | POST | /api/virtual-pet/interact | 用户与宠物互动（喂食/抚摸/玩耍） |
| 虚拟宠物 | GET | /api/virtual-pet/unlockables | 获取可解锁内容列表 |
| AI 顾问 | GET | /api/ai-advisor/settings | 获取用户顾问风格设置 |
| AI 顾问 | PUT | /api/ai-advisor/settings | 更新用户顾问风格设置 |
| 轻断食 | POST | /api/fasting/plans | 创建轻断食/辟谷计划 |
| 轻断食 | GET | /api/fasting/plans | 获取用户计划列表 |
| 轻断食 | PUT | /api/fasting/plans/{id} | 更新计划 |
| 轻断食 | PUT | /api/fasting/plans/{id}/stop | 停止计划 |
| 轻断食 | POST | /api/fasting/checkins | 每日打卡 |
| 轻断食 | GET | /api/fasting/checkins | 获取打卡记录 |
| 轻断食 | GET | /api/fasting/progress | 获取计划进度与体重变化 |
| 轻断食 | GET | /api/fasting/refeed-guide | 获取复食指导方案 |

### 6.2 修改 API

| 现有路径 | 修改内容 | 说明 |
| --- | --- | --- |
| POST /api/foods/records | 请求体增加 cost、source_tag 字段 | 支持记录消费金额和来源 |
| PUT /api/foods/records/{id} | 请求体增加 cost、source_tag 字段 | 支持补录金额和来源 |
| GET /api/foods/records | 返回体增加 cost、source_tag | 列表展示消费信息 |
| POST /chat/send-message-stream | 读取 ai_advisor_settings 注入风格上下文 | AI 回答应用用户选择的风格 |
| POST /analysis-chat/chat-with-analysis | 读取 ai_advisor_settings 注入风格上下文 | 分析讨论应用风格 |

---

## 七、前端新增/修改需求

### 7.1 新增页面

| 页面 | 文件名 | 说明 |
| --- | --- | --- |
| 消费统计页 | cost_statistics_page.dart | 本周/本月开销、分类对比、趋势图 |
| 宠物首页 | pet_home_page.dart | 宠物形象展示、状态、快速互动 |
| 宠物详情页 | pet_detail_page.dart | 等级、经验、已解锁外观/动作 |
| AI 顾问风格设置页 | advisor_style_page.dart | 选择风格、专业偏向、关注重点 |
| 轻断食计划页 | fasting_plan_page.dart | 创建/查看/编辑断食计划 |
| 轻断食打卡页 | fasting_checkin_page.dart | 每日体重、体感、完成情况、不适记录 |
| 轻断食复食指导页 | fasting_refeed_page.dart | 复食方案展示 |

### 7.2 新增组件/Widget

| 组件 | 文件名 | 说明 |
| --- | --- | --- |
| 消费趋势图 | cost_trend_chart.dart | 近 7/30 天消费折线图 |
| 宠物动画组件 | pet_animation_widget.dart | 2D/伪 3D 宠物形象与状态动画 |
| 风格选择器 | advisor_style_selector.dart | 风格卡片选择器 |
| 断食计时器 | fasting_timer_widget.dart | 进食窗口倒计时 |
| 预算进度卡片 | budget_progress_card.dart | 月度饮食预算剩余展示 |

### 7.3 修改页面

| 页面 | 修改内容 |
| --- | --- |
| home_page | 增加宠物入口、喝水/运动快捷入口、今日消费概览、月度预算卡片 |
| food_record_modal | 增加金额输入框、来源标签选择器 |
| chat_page | 增加 AI 顾问风格入口，对话顶部显示当前风格 |
| data_visualization_page | 增加消费统计 Tab |
| settings_page | 增加月度饮食预算、AI 顾问风格入口 |

### 7.4 新增依赖

| 包名 | 用途 |
| --- | --- |
| fl_chart | 消费趋势图、宠物成长曲线 |
| lottie | 宠物动画效果 |

---

## 八、AI Agent 新增/修改需求

### 8.1 新增 Agent / Skill

| 组件 | 说明 | 优先级 |
| --- | --- | --- |
| advisor_style_prompt_manager | 根据用户选择的风格、专业偏向、关注重点生成对应 system prompt | P0 |
| fasting_advisor_skill | 根据计划类型、用户目标、健康状况生成断食计划、打卡反馈、复食指导 | P0 |
| pet_feedback_generator | 根据用户当日饮食/饮水达标情况生成宠物反馈文案 | P1 |

### 8.2 修改 Agent

| Agent | 修改内容 | 优先级 |
| --- | --- | --- |
| chat_agent | 接收 advisor_style 参数，注入对应 system prompt；所有风格强制追加合规免责声明 | P0 |
| enhanced_nutrition_agent | 在生成建议时读取 ai_advisor_settings，调整语气、关注重点、输出结构 | P0 |
| goal_tracking_agent | 增加轻断食目标计算，评估断食期间热量摄入是否符合计划 | P1 |
| diet_deep_agent | 支持养生/断食相关咨询，调用 fasting_advisor_skill | P1 |

### 8.3 Prompt 优化

| Agent / Skill | Prompt 优化内容 | 优先级 |
| --- | --- | --- |
| advisor_style_prompt_manager | 营养师风格：科普均衡、数据清晰；运动教练风格：严格激励、强调执行；中医养生师风格：温和调理、引用传统养生概念；鼓励型伙伴风格：亲切正向、不越界 | P0 |
| chat_agent | 所有风格 prompt 强制追加："我是 AI 健康顾问，建议仅供参考，不能替代医生诊断"；禁止情感诱导表达 | P0 |
| fasting_advisor_skill | 辟谷/断食方案 prompt 中必须包含禁忌人群提示、不适停止提示、复食指导 | P0 |
| pet_feedback_generator | 根据达标情况生成 5 种 mood 对应的正向/提醒文案 | P1 |

---

## 九、非功能需求

### 9.1 性能需求

| 指标 | 要求 | 说明 |
| --- | --- | --- |
| 接口响应时间 | 普通 CRUD < 500ms，消费统计 < 1s，AI 分析 < 10s（流式） | 后端需优化聚合查询 |
| App 操作流畅度 | 页面切换 < 300ms，图表渲染 < 1s，宠物动画 60fps | 使用缓存和懒加载 |
| 数据持久化 | 本地缓存 + 服务端存储 | 前端 CacheManager + PostgreSQL |

### 9.2 兼容性需求

| 项 | 要求 |
| --- | --- |
| 目标平台 | 移动端 APP（Android 8.0+、iOS 13.0+） |
| 屏幕适配 | 主流手机屏幕尺寸（6.0"-6.7"） |
| 深色模式 | 已支持 Light/Dark 主题 |
| 硬件兼容 | 支持不连接硬件时钟独立使用 App；连接时通过 WiFi/HTTP 同步 |

### 9.3 安全需求

| 项 | 要求 |
| --- | --- |
| 数据加密 | JWT 令牌加密传输，密码 bcrypt 加密存储（已实现） |
| 接口防护 | 全接口 Bearer Token 认证（已实现） |
| 敏感数据 | 体重/健康/消费数据仅用户本人可见 |
| 断食安全 | 禁忌人群拦截、免责声明、不适预警不可关闭 |

### 9.4 可观测性

| 项 | 要求 |
| --- | --- |
| 日志 | 关键操作日志（登录、AI 调用、错误）已通过中间件记录 |
| 监控 | 健康检查端点 GET /health 已实现 |
| 错误追踪 | 全局异常处理器已实现 |

---

## 十、开发里程碑与进度要求

### 第一阶段（Day 1-2）：需求确认与接口设计

| 模块 | 任务 | 产出 |
| --- | --- | --- |
| 统筹 | PRD 最终确认、输出架构设计文档、接口规范、数据模型 | 架构设计文档 v1 |
| 后端 | 数据库表设计、新增 API 骨架、定时任务框架 | 新增 5 张表 DDL、15+ API 骨架路由 |
| 前端 | 完成新增页面 UI 设计、搭建页面框架 | 消费统计、宠物、AI 风格、断食页面 wireframe |

### 第二阶段（Day 3-8）：核心功能开发

| 阶段 | APP 端 | 后端 | AI Agent |
| --- | --- | --- | --- |
| Day 3-4 | 消费统计 UI、饮食记录金额/来源输入 | 饮食消费统计 API、虚拟形象状态 API | advisor_style_prompt_manager |
| Day 5-6 | 虚拟形象联动 UI、AI 风格选择页 | AI 顾问设置 API、虚拟形象状态计算 | 风格 prompt 模板、合规规则 |
| Day 7-8 | 轻断食计划/打卡 UI、宠物动画优化 | 轻断食计划/打卡 API、复食指导接口 | fasting_advisor_skill |

### 第三阶段（Day 9-10）：联调与验收

| 模块 | 任务 |
| --- | --- |
| 全组 | 全功能测试、Bug 修复、性能优化 |
| APP 端 | 兼容性测试、UI 细节打磨、宠物动画走查 |
| 后端 | 接口联调、数据一致性验证、断食安全逻辑复核 |
| AI | 风格输出质量验证、断食建议合规性检查 |
| 统筹 | 验收测试、文档更新、硬件联调、Milestone 2 交付评审 |

---

## 十一、风险与应对

| 风险 | 影响 | 应对措施 |
| --- | --- | --- |
| 服务器内存不足 | AI 功能响应慢或宕机 | 限制并发、优化 PostgreSQL/Redis、必要时升级配置 |
| AI 合规审查不通过 | 功能需返工 | 严格按合规要求设计，避免情感诱导 |
| 辟谷功能安全争议 | 产品下架风险 | 强化免责声明、禁忌筛查、不适预警 |
| 硬件联调时间不可控 | 虚拟形象同步延迟 | App 端先做独立宠物功能，硬件同步作为扩展 |
| 消费统计聚合查询慢 | 统计页加载慢 | 增加数据库索引、预计算日报表、分页查询 |

---

## 十二、附录

### 附录 A：Milestone 2 新增 API 清单

| # | 方法 | 路径 | 说明 |
| --- | --- | --- | --- |
| 1 | GET | /api/foods/cost-stats | 消费统计（本周/本月/分类对比） |
| 2 | GET | /api/foods/cost-trend | 消费趋势（近 7/30 天） |
| 3 | GET | /api/virtual-pet/status | 获取宠物状态 |
| 4 | GET | /api/virtual-pet/status-for-device | 硬件端获取宠物状态 |
| 5 | POST | /api/virtual-pet/interact | 宠物互动 |
| 6 | GET | /api/virtual-pet/unlockables | 可解锁内容 |
| 7 | GET | /api/ai-advisor/settings | 获取 AI 顾问设置 |
| 8 | PUT | /api/ai-advisor/settings | 更新 AI 顾问设置 |
| 9 | POST | /api/fasting/plans | 创建断食计划 |
| 10 | GET | /api/fasting/plans | 获取断食计划列表 |
| 11 | PUT | /api/fasting/plans/{id} | 更新断食计划 |
| 12 | PUT | /api/fasting/plans/{id}/stop | 停止断食计划 |
| 13 | POST | /api/fasting/checkins | 断食打卡 |
| 14 | GET | /api/fasting/checkins | 获取打卡记录 |
| 15 | GET | /api/fasting/progress | 获取断食进度 |
| 16 | GET | /api/fasting/refeed-guide | 获取复食指导 |

### 附录 B：Milestone 2 新增/修改数据模型清单

| # | 表名 | 类型 | 说明 |
| --- | --- | --- | --- |
| 1 | food_records | 修改 | 新增 cost、source_tag 字段 |
| 2 | user_profiles | 修改 | 新增 monthly_food_budget 字段 |
| 3 | reminders | 修改 | 新增 fasting_plan_id 字段 |
| 4 | virtual_pet_states | 新增 | 用户虚拟宠物状态 |
| 5 | pet_unlockables | 新增 | 宠物可解锁内容定义 |
| 6 | ai_advisor_settings | 新增 | AI 顾问风格设置 |
| 7 | fasting_plans | 新增 | 断食计划 |
| 8 | fasting_checkins | 新增 | 断食每日打卡 |

### 附录 C：Milestone 2 AI Agent 能力矩阵

| 能力 | advisor_style_prompt_manager | fasting_advisor_skill | pet_feedback_generator | chat_agent | enhanced_nutrition_agent |
| --- | --- | --- | --- | --- | --- |
| 顾问风格切换 | 生成 | — | — | 应用 | 应用 |
| 专业偏向注入 | 生成 | — | — | 应用 | 应用 |
| 合规免责声明 | 生成 | — | — | 应用 | 应用 |
| 断食计划生成 | — | 生成 | — | 调用 | — |
| 复食指导 | — | 生成 | — | 调用 | — |
| 断食安全预警 | — | 生成 | — | 调用 | — |
| 宠物反馈文案 | — | — | 生成 | — | — |

### 附录 D：相关文档

- [DietAI 后端 API 文档](http://8.130.208.166:8866/docs)
- [Milestone 1 需求文档](../milestone1/Milestone1_需求文档.md)
- [硬件规划文档](../hardware/智能宠物时钟硬件规划.md)
- [Milestone 2 路线图原文](milestone2路线图规划.md)
