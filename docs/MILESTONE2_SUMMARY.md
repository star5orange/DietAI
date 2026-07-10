# DietAI Milestone 2 后端交付总结文档

> **版本**: v1.0
> **日期**: 2026-07-10
> **开发者**: 何丽
> **分支**: `backend`
> **数据库**: PostgreSQL 17（Windows 原生服务）

---

## 一、开发概览

Milestone 2 后端开发共完成 **8 个步骤**，涵盖四大核心功能模块：

| 模块 | 功能说明 | 新增接口数 |
|------|---------|-----------|
| **饮食消费记录与统计** | 消费金额/来源标签记录、多维度消费统计报表、预算管理 | 2 |
| **虚拟宠物联动养成** | 宠物状态模型、饮食/饮水达标联动、硬件状态同步、互动解锁 | 4 |
| **AI 健康顾问风格定制** | 4 种顾问风格选择、专业偏向/关注营养素/输出风格配置 | 2 |
| **轻断食科学引导** | 16:8 / 5:2 / 辟谷模式、禁忌筛查、每日打卡、复食指导 | 8 |

共新增 **16 个 API 接口**，加上修改的 5 个现有接口，系统总端点从 78 个增至 **94 个**。

---

## 二、数据库变更清单

### 2.1 新增表（5 张）

#### virtual_pet_states — 用户虚拟宠物状态

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | SERIAL PK | 主键 |
| `user_id` | INTEGER FK → users.id | 用户ID（唯一） |
| `mood` | VARCHAR(20) | 状态：normal / happy / hungry / anxious / weak |
| `level` | INTEGER | 宠物等级 |
| `exp` | INTEGER | 累计经验值 |
| `current_skin` | VARCHAR(50) | 当前皮肤 |
| `unlocked_skins` | JSONB | 已解锁皮肤列表 |
| `habit_score` | INTEGER | 习惯分数（0–100） |
| `version` | INTEGER | 状态版本号（硬件轮询用） |
| `last_interact_at` | TIMESTAMP | 最后互动时间 |
| `last_feed_at` | TIMESTAMP | 最后喂食时间 |
| `last_play_at` | TIMESTAMP | 最后玩耍时间 |
| `created_at` / `updated_at` | TIMESTAMP | 时间戳 |

#### pet_unlockables — 宠物可解锁内容定义

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | SERIAL PK | 主键 |
| `unlock_type` | VARCHAR(20) | 类型：skin / action / effect |
| `unlock_key` | VARCHAR(50) UNIQUE | 唯一标识键 |
| `name` | VARCHAR(100) | 名称 |
| `description` | TEXT | 描述 |
| `required_level` | INTEGER | 所需等级（可空） |
| `required_streak` | INTEGER | 所需连续达标天数（可空） |
| `required_habit_score` | INTEGER | 所需习惯分数（可空） |
| `asset_url` | VARCHAR(255) | 资源路径 |
| `is_active` | BOOLEAN | 是否启用 |

#### ai_advisor_settings — AI 顾问风格设置

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | SERIAL PK | 主键 |
| `user_id` | INTEGER FK → users.id | 用户ID（唯一） |
| `advisor_style` | VARCHAR(30) | nutritionist / fitness_coach / tcm_healer / encouraging_friend |
| `focus_goal` | VARCHAR(30) | fat_loss / muscle_gain / sugar_control / wellness / balanced |
| `focus_nutrient` | VARCHAR(30) | calories / protein / carb / fat / micronutrient |
| `response_style` | VARCHAR(30) | concise / detailed / example_rich |

#### fasting_plans — 轻断食/辟谷计划

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | SERIAL PK | 主键 |
| `user_id` | INTEGER FK → users.id | 用户ID |
| `plan_type` | VARCHAR(20) | 16_8 / 5_2 / basic_fasting |
| `target_weight` | DECIMAL(5,2) | 目标体重 |
| `start_date` | DATE | 开始日期 |
| `end_date` | DATE | 结束日期 |
| `status` | VARCHAR(20) | active / paused / stopped / completed |
| `eating_window_start` | TIME | 进食窗口开始 |
| `eating_window_end` | TIME | 进食窗口结束 |
| `disclaimer_accepted` | BOOLEAN | 是否接受免责声明 |
| `health_assessment` | JSONB | 健康评估数据 |

#### fasting_checkins — 断食每日打卡

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | SERIAL PK | 主键 |
| `plan_id` | INTEGER FK → fasting_plans.id | 计划ID |
| `checkin_date` | DATE | 打卡日期 |
| `weight` | DECIMAL(5,2) | 体重 |
| `feeling` | VARCHAR(30) | good / normal / tired / uncomfortable |
| `completed` | BOOLEAN | 是否完成当日计划 |
| `discomfort` | JSONB | 不适症状 |
| `notes` | TEXT | 备注 |

### 2.2 修改表（3 张）

| 表名 | 变更 | 说明 |
|------|------|------|
| `food_records` | 新增 `cost` DECIMAL(10,2)、`source_tag` VARCHAR(20) | 消费金额与来源标签，含 CHECK 约束（cost >= 0, cost <= 99999.99） |
| `user_profiles` | 新增 `monthly_food_budget` DECIMAL(10,2) | 月度饮食预算 |
| `reminders` | 新增 `fasting_plan_id` INTEGER FK | 关联断食计划提醒 |

### 2.3 新增索引

| 表 | 索引名 | 字段 | 类型 |
|----|--------|------|------|
| `food_records` | `idx_food_records_source_tag` | source_tag | 普通 |
| `virtual_pet_states` | `idx_pet_state_user` | user_id | UNIQUE |
| `virtual_pet_states` | `idx_pet_state_mood` | mood | 普通 |
| `virtual_pet_states` | `idx_pet_state_updated` | updated_at | 普通 |
| `ai_advisor_settings` | `idx_advisor_settings_user` | user_id | UNIQUE |
| `fasting_plans` | `idx_fasting_plans_user` | user_id | 普通 |
| `fasting_plans` | `idx_fasting_plans_status` | status, user_id | 复合 |
| `fasting_plans` | `idx_fasting_plans_date` | start_date, end_date | 复合 |
| `fasting_checkins` | `idx_fasting_checkin_plan_date` | plan_id, checkin_date | UNIQUE |
| `fasting_checkins` | `idx_fasting_checkin_discomfort` | discomfort | 普通 |

---

## 三、新增 API 接口汇总

### 3.1 消费统计模块（2 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| GET | `/api/foods/cost-stats` | 获取本周/本月消费统计（总额、日均、最贵单笔、餐次分类、来源分类、每元热量、预算剩余） |
| GET | `/api/foods/cost-trend` | 获取近 N 天消费趋势图数据（支持按 source_tag 筛选） |

**请求示例**：

```bash
# 本月消费统计
curl "http://127.0.0.1:8001/api/foods/cost-stats?period=month" \
  -H "Authorization: Bearer $TOKEN"

# 近 30 天消费趋势
curl "http://127.0.0.1:8001/api/foods/cost-trend?days=30" \
  -H "Authorization: Bearer $TOKEN"

# 按来源筛选
curl "http://127.0.0.1:8001/api/foods/cost-trend?days=7&source_tag=delivery" \
  -H "Authorization: Bearer $TOKEN"
```

**cost-stats 响应示例**：

```json
{
  "success": true,
  "data": {
    "period": "week",
    "total_cost": 156.80,
    "daily_avg": 22.40,
    "max_single": 35.00,
    "record_count": 14,
    "by_meal_time": { "breakfast": 28.50, "lunch": 65.30, "dinner": 48.00, "snack": 15.00 },
    "by_source": { "canteen": 58.00, "delivery": 68.80, "home": 20.00 },
    "calorie_per_yuan": 28.5,
    "budget_remaining": 343.20
  }
}
```

### 3.2 虚拟宠物模块（4 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| GET | `/api/virtual-pet/status` | 获取 App 端宠物完整状态（mood、level、exp、皮肤、习惯分数、连续天数） |
| GET | `/api/virtual-pet/status-for-device` | 硬件端轮询获取精简状态（带版本号，用于 30 秒轮询判断刷新） |
| POST | `/api/virtual-pet/interact` | 用户与宠物互动（feed / play / pet），返回经验值和反馈文案 |
| GET | `/api/virtual-pet/unlockables` | 获取全部可解锁内容列表及用户当前进度 |

**请求示例**：

```bash
# 获取宠物状态
curl http://127.0.0.1:8001/api/virtual-pet/status \
  -H "Authorization: Bearer $TOKEN"

# 硬件端轮询状态
curl http://127.0.0.1:8001/api/virtual-pet/status-for-device \
  -H "Authorization: Bearer $TOKEN"

# 喂食互动
curl -X POST http://127.0.0.1:8001/api/virtual-pet/interact \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"action": "feed", "item_id": "apple"}'

# 可解锁内容
curl http://127.0.0.1:8001/api/virtual-pet/unlockables \
  -H "Authorization: Bearer $TOKEN"
```

**status-for-device 响应示例（硬件轮询用）**：

```json
{
  "success": true,
  "data": {
    "mood": "happy",
    "level": 3,
    "skin": "default",
    "version": 15,
    "has_new_unlock": false
  }
}
```

### 3.3 AI 顾问设置模块（2 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| GET | `/api/ai-advisor/settings` | 获取用户 AI 顾问风格设置（首次自动创建默认值） |
| PUT | `/api/ai-advisor/settings` | 更新顾问风格、关注目标、关注营养素、输出风格（仅传需修改字段） |

**请求示例**：

```bash
# 获取设置
curl http://127.0.0.1:8001/api/ai-advisor/settings \
  -H "Authorization: Bearer $TOKEN"

# 更新设置
curl -X PUT http://127.0.0.1:8001/api/ai-advisor/settings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "advisor_style": "fitness_coach",
    "focus_goal": "muscle_gain",
    "focus_nutrient": "protein",
    "response_style": "concise"
  }'
```

**合法值白名单**：

| 字段 | 可选值 |
|------|--------|
| `advisor_style` | `nutritionist`, `fitness_coach`, `tcm_healer`, `encouraging_friend` |
| `focus_goal` | `fat_loss`, `muscle_gain`, `sugar_control`, `wellness`, `balanced` |
| `focus_nutrient` | `calories`, `protein`, `carb`, `fat`, `micronutrient` |
| `response_style` | `concise`, `detailed`, `example_rich` |

### 3.4 轻断食模块（8 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| POST | `/api/fasting/plans` | 创建轻断食计划（含健康评估 + 禁忌筛查 + 免责声明） |
| GET | `/api/fasting/plans` | 获取用户计划列表（支持按状态筛选） |
| PUT | `/api/fasting/plans/{plan_id}` | 更新计划（目标体重、进食窗口、结束日期） |
| PUT | `/api/fasting/plans/{plan_id}/stop` | 停止计划（状态变为 stopped） |
| POST | `/api/fasting/checkins` | 每日打卡（体重、体感、完成情况、不适症状） |
| GET | `/api/fasting/checkins` | 获取打卡记录列表 |
| GET | `/api/fasting/progress` | 获取进度（完成率、体重变化趋势、连续天数） |
| GET | `/api/fasting/refeed-guide` | 获取复食指导方案（按 plan_type 返回分阶段建议） |

**请求示例**：

```bash
# 创建计划
curl -X POST http://127.0.0.1:8001/api/fasting/plans \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "plan_type": "16_8",
    "target_weight": 65.0,
    "start_date": "2026-07-10",
    "eating_window_start": "08:00",
    "eating_window_end": "16:00",
    "disclaimer_accepted": true,
    "health_assessment": {
      "bmi": 22.5,
      "has_diabetes": false,
      "is_pregnant": false,
      "is_breastfeeding": false,
      "is_minor": false,
      "has_eating_disorder": false
    }
  }'

# 每日打卡
curl -X POST http://127.0.0.1:8001/api/fasting/checkins \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "plan_id": 1,
    "checkin_date": "2026-07-10",
    "weight": 66.2,
    "feeling": "good",
    "completed": true,
    "discomfort": { "dizziness": false, "low_sugar": false, "palpitation": false },
    "notes": "第一天感觉良好"
  }'

# 查看进度
curl "http://127.0.0.1:8001/api/fasting/progress?plan_id=1" \
  -H "Authorization: Bearer $TOKEN"

# 复食指导
curl "http://127.0.0.1:8001/api/fasting/refeed-guide?plan_id=1" \
  -H "Authorization: Bearer $TOKEN"
```

**不适症状预警响应示例**：

```json
{
  "success": true,
  "data": {
    "message": "打卡已记录",
    "warning": {
      "level": "high",
      "symptoms": ["dizziness", "low_sugar"],
      "advice": "请立即停止断食并咨询医生，您的身体出现了明显不适反应"
    }
  }
}
```

---

## 四、修改的现有接口

### 4.1 food_records 接口变更

| 接口 | 变更内容 |
|------|---------|
| `POST /api/foods/records/traditional` | 请求体新增 `cost`（金额）和 `source_tag`（来源标签）可选字段 |
| `PUT /api/foods/records/{id}` | 支持编辑更新 `cost` 和 `source_tag` |
| `GET /api/foods/records` | 返回体每条记录增加 `cost` 和 `source_tag` 字段 |
| `GET /api/foods/records/{id}` | 详情返回增加 `cost` 和 `source_tag` 字段 |
| `POST /api/foods/records/confirm/{record_id}` | 确认返回增加 `cost` 和 `source_tag` 字段 |

**Pydantic Schema 变更**（`shared/models/schemas/food.py`）：

- `FoodRecordCreate`：新增 `cost: Optional[float]`（ge=0, le=99999.99）、`source_tag: Optional[str]`（max_length=20）
- `FoodRecordResponse`：新增 `cost: Optional[float]`、`source_tag: Optional[str]`

### 4.2 宠物状态联动触发

饮食记录和饮水记录创建后会自动触发宠物状态更新。修改位置：

| 文件 | 触发点 | 说明 |
|------|--------|------|
| `routers/food_router.py` | `create_food_record_traditional()` 提交后 | 调用 `update_pet_status_on_record()` |
| `routers/food_router.py` | `add_nutrition_detail()` 提交后 | 营养详情添加后触发 |
| `shared/services/water_service.py` | `create_water_record()` 提交后 | 饮水记录创建后触发 |

联动流程：

```
用户记录饮食/饮水
  → food_router / water_service 完成记录创建
  → 调用 pet_service.update_pet_status_on_record()
  → 重新计算当日饮食达标率 + 饮水达标率
  → 更新宠物 mood / exp / habit_score
  → 检查升级 + 解锁
  → version 递增（硬件下次轮询时刷新）
```

---

## 五、新增/修改文件清单

### 5.1 新建文件

| 文件路径 | 类型 | 说明 |
|----------|------|------|
| `.env.dev` | 配置 | 开发环境配置（DEBUG=true, DB URL, Redis, MinIO） |
| `shared/models/pet_models.py` | Model | VirtualPetState + PetUnlockable ORM 模型 |
| `shared/models/advisor_models.py` | Model | AiAdvisorSettings ORM 模型 |
| `shared/models/fasting_models.py` | Model | FastingPlan + FastingCheckin ORM 模型 |
| `shared/services/cost_service.py` | Service | 消费统计业务逻辑（本周/本月聚合、趋势、每元热量、预算剩余） |
| `shared/services/pet_service.py` | Service | 宠物状态管理（创建/更新/互动/解锁/硬件状态） |
| `shared/services/advisor_service.py` | Service | AI 顾问设置读写 + 默认值创建 |
| `shared/services/fasting_service.py` | Service | 断食计划管理（禁忌筛查/计划CRUD/打卡/进度/复食指导） |
| `routers/cost_router.py` | Router | 消费统计接口（prefix="/foods"） |
| `routers/pet_router.py` | Router | 虚拟宠物接口（prefix="/virtual-pet"） |
| `routers/advisor_router.py` | Router | AI 顾问设置接口（prefix="/ai-advisor"） |
| `routers/fasting_router.py` | Router | 轻断食接口（prefix="/fasting"） |
| `scripts/init_pet_unlockables.py` | Script | 宠物可解锁内容种子数据脚本（支持 --reset） |
| `alembic/versions/0da986e876fe_milestone2_new_tables_and_fields.py` | Migration | Milestone 2 完整数据库迁移脚本（含 up/down） |

### 5.2 修改文件

| 文件路径 | 改动内容 |
|----------|---------|
| `shared/config/settings.py` | ① JWT 密钥：开发环境自动生成随机密钥，不再强制报错退出；② 默认 DB URL 改为 `127.0.0.1`（避免 IPv6 编码问题） |
| `alembic/env.py` | 支持同时读取 `.env.dev` 和 `.env` 文件中的数据库 URL |
| `main.py` | ① 导入新模型（pet_models, advisor_models, fasting_models）；② 注册 4 个新路由（cost_router, pet_router, advisor_router, fasting_router） |
| `routers/auth_router.py` | 用户注册时自动创建：① 虚拟宠物初始状态 ② AI 顾问默认设置 |
| `routers/food_router.py` | ① 创建/更新/查询接口支持 cost、source_tag 字段；② 记录创建后触发宠物状态更新 |
| `shared/services/water_service.py` | 饮水记录创建后触发宠物状态更新 |
| `shared/models/food_models.py` | FoodRecord 新增 cost（Numeric）和 source_tag（String）字段 + idx_food_records_source_tag 索引 |
| `shared/models/user_models.py` | UserProfile 新增 monthly_food_budget（Numeric）字段 |
| `shared/models/reminder_models.py` | Reminder 新增 fasting_plan_id（FK → fasting_plans.id）字段 |
| `shared/models/schemas/food.py` | FoodRecordCreate / FoodRecordResponse 新增 cost、source_tag |

---

## 六、关键业务逻辑说明

### 6.1 宠物状态计算规则

**Mood（五种状态）判定逻辑**：

| 条件 | Mood |
|------|------|
| 饮食达标率 ≥ 90% **且** 饮水达标率 ≥ 90% | `happy`（开心） |
| 饮食达标率 ≥ 60% **且** 饮水达标率 ≥ 60% | `normal`（正常） |
| 饮食达标率 < 30% **且** 饮水达标率 < 30% | `weak`（虚弱） |
| 饮水达标率 < 50% | `anxious`（焦虑） |
| 饮食达标率 < 60% | `hungry`（饥饿） |
| 其他 | `normal`（正常） |

- **饮食达标率** = 当日三餐（早/午/晚）记录完成的餐次数 / 3
- **饮水达标率** = 当日实际饮水(ml) / 用户饮水目标(ml)，上限 1.0

**经验值（EXP）计算**：

| 行为 | 经验值 |
|------|--------|
| 每次饮食记录 | +10 |
| 当日饮水 100% 达标 | +20 |
| 连续达标 ≥ 3 天 | +15/天 |
| 互动-喂食 | +5 |
| 互动-玩耍 | +3 |
| 互动-抚摸 | +1 |

**等级阈值**：Lv1=0, Lv2=50, Lv3=120, Lv4=220, Lv5=350, Lv6=520, Lv7=750, Lv8=1050, Lv9=1400, Lv10=1850，之后每级 +200。

**Habit Score**：`min(100, (饮食达标率 + 饮水达标率) / 2 × 100)`，即 0–100 分。

### 6.2 宠物状态版本号机制

用于硬件端（ESP32-S3）每 30 秒轮询时判断是否需要刷新屏幕：

- `version` 字段在每次状态变更时自动递增
- 硬件端缓存上一次的 `version` 值，仅当不一致时才重新渲染
- `GET /api/virtual-pet/status-for-device` 返回精简版状态（mood, level, skin, version）

```cpp
// ESP32-S3 伪代码
int last_version = 0;
void loop() {
    if (millis() - last_poll > 30000) {
        PetStatus status = httpGET("/api/virtual-pet/status-for-device");
        if (status.version != last_version) {
            updateDisplay(status.mood, status.skin);
            last_version = status.version;
        }
    }
}
```

### 6.3 轻断食禁忌筛查逻辑

创建断食计划时，系统根据 `health_assessment` 数据进行禁忌筛查：

| 条件 | 拦截效果 |
|------|---------|
| `is_pregnant = true` | 所有模式被拦截 |
| `is_breastfeeding = true` | 所有模式被拦截 |
| `is_minor = true` | 所有模式被拦截 |
| `has_diabetes = true` | 所有模式被拦截 |
| `has_eating_disorder = true` | 所有模式被拦截 |
| `bmi < 18.5` | 所有模式被拦截 |

- 被拦截的用户仅 `basic_fasting`（辟谷）模式会**直接拒绝创建**
- 其他模式（16:8、5:2）仍可创建，但会在 `warnings` 字段中列出禁忌原因供用户知晓

```json
// 禁忌人群响应示例
{
  "success": false,
  "error": "DISABLED_FOR_USER",
  "message": "您属于禁忌人群（BMI 过低（<18.5），不建议启用断食模式），不建议启用辟谷模式，请选择其他减脂方式"
}
```

### 6.4 轻断食打卡不适症状预警

打卡时系统检查 `discomfort` 字段中的症状标记：

| 严重症状 | 预警等级 | 提示内容 |
|---------|---------|---------|
| `dizziness`（头晕）| **high** | 请立即停止断食并咨询医生 |
| `low_sugar`（低血糖）| **high** | 请立即停止断食并咨询医生 |
| `palpitation`（心悸）| **high** | 请立即停止断食并咨询医生 |
| 其他不适 | **medium** | 请注意观察，如持续或加重请咨询医生 |

### 6.5 复食指导生成方式

当前采用**基于规则的静态模板**方案，根据 `plan_type` 返回对应的分阶段复食建议：

| 计划类型 | 复食周期 | 阶段 |
|---------|---------|------|
| `16_8` | 7 天 | 清淡饮食（1-2天）→ 渐进恢复（3-5天）→ 正常恢复（6-7天） |
| `5_2` | 5 天 | 低热量过渡（1-2天）→ 正常恢复（3-5天） |
| `basic_fasting` | 7 天 | 流质/半流质（1-2天）→ 软食渐进（3-5天）→ 清淡恢复（6-7天） |

> **预留扩展**：模板结构已预留 `ai_suggestion` 字段，后续可接入 AI Agent（`fasting_advisor_skill`）生成个性化复食方案。

---

## 七、数据初始化说明

### 7.1 宠物可解锁内容种子数据

已在数据库迁移脚本中自动插入，共 **10 条**记录：

| unlock_key | unlock_type | name | 解锁条件 |
|------------|-------------|------|---------|
| `default` | skin | 默认外观 | Lv1 |
| `summer` | skin | 夏日清凉 | Lv3 |
| `sporty` | skin | 运动活力 | Lv5 |
| `winter` | skin | 冬日暖阳 | Lv8 |
| `festival` | skin | 节日盛装 | Lv12 + habit_score=85 |
| `happy_spin` | action | 开心转圈 | 连续达标 3 天 |
| `feed_eat` | action | 进食动画 | 无门槛 |
| `level_up` | action | 升级庆祝 | Lv2 |
| `water_great` | action | 饮水达人 | 连续达标 7 天 |
| `gold_sparkle` | effect | 金色光效 | Lv10 |

**手动运行种子数据更新**：

```bash
# 增量插入（跳过已存在的）
uv run python scripts/init_pet_unlockables.py

# 清空后重新插入
uv run python scripts/init_pet_unlockables.py --reset
```

### 7.2 用户注册时自动初始化

用户注册时（`POST /api/auth/register`），系统自动创建：

1. **虚拟宠物状态** — mood=normal, level=1, exp=0, skin=default
2. **AI 顾问默认设置** — advisor_style=nutritionist, focus_goal=balanced, response_style=detailed
3. **默认提醒模板** —（Milestone 1 已有，保持不变）

---

## 八、部署与启动说明

### 8.1 环境变量配置变更

| 变更项 | 说明 |
|--------|------|
| JWT 密钥 | 开发环境（`DIETAI_DEBUG=true`）不再强制要求设置 `DIETAI_JWT_SECRET_KEY`，会自动生成随机密钥。**生产环境必须显式设置**。 |
| 数据库 URL | 默认使用 `127.0.0.1`（IPv4）而非 `localhost`，避免 IPv6 编码问题。 |
| `.env.dev` | 新增开发环境配置文件，包含 `DIETAI_DEBUG=true`。 |

### 8.2 数据库迁移

```bash
# 在项目根目录执行

# 查看当前迁移状态
uv run alembic current

# 执行迁移到最新版本
uv run alembic upgrade head

# 如需回滚
uv run alembic downgrade -1
```

### 8.3 启动开发服务器

```bash
# 安装依赖
uv sync

# 启动服务（端口 8001，如果 8000 被占用）
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8001

# Swagger 文档访问
# http://127.0.0.1:8001/docs
```

---

## 九、验证与测试

### 9.1 接口可用性验证

应用启动后访问 `/openapi.json` 确认 94 个端点全部注册。以下为各新增接口的 curl 测试命令（需先登录获取 Token）：

```bash
# ===== 前提：获取 Token =====
# 注册
curl -X POST http://127.0.0.1:8001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test_m2","email":"test_m2@dietai.dev","password":"Test123456"}'

# 登录（保存返回的 access_token）
TOKEN=$(curl -s -X POST http://127.0.0.1:8001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test_m2","password":"Test123456"}' \
  | python -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])")

# ===== 消费统计模块 =====
# 1. 创建带消费金额的饮食记录
curl -X POST http://127.0.0.1:8001/api/foods/records/traditional \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"record_date":"2026-07-10","meal_type":2,"food_name":"测试午餐","cost":12.50,"source_tag":"canteen"}'

# 2. 本周消费统计
curl "http://127.0.0.1:8001/api/foods/cost-stats?period=week" \
  -H "Authorization: Bearer $TOKEN"

# 3. 消费趋势
curl "http://127.0.0.1:8001/api/foods/cost-trend?days=7" \
  -H "Authorization: Bearer $TOKEN"

# ===== 虚拟宠物模块 =====
# 4. 宠物状态（注册后自动创建）
curl http://127.0.0.1:8001/api/virtual-pet/status \
  -H "Authorization: Bearer $TOKEN"

# 5. 硬件端状态
curl http://127.0.0.1:8001/api/virtual-pet/status-for-device \
  -H "Authorization: Bearer $TOKEN"

# 6. 互动
curl -X POST http://127.0.0.1:8001/api/virtual-pet/interact \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"action":"feed"}'

# 7. 可解锁内容
curl http://127.0.0.1:8001/api/virtual-pet/unlockables \
  -H "Authorization: Bearer $TOKEN"

# ===== AI 顾问模块 =====
# 8. 获取设置（注册后自动创建默认值）
curl http://127.0.0.1:8001/api/ai-advisor/settings \
  -H "Authorization: Bearer $TOKEN"

# 9. 更新设置
curl -X PUT http://127.0.0.1:8001/api/ai-advisor/settings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"advisor_style":"fitness_coach","focus_goal":"muscle_gain"}'

# ===== 轻断食模块 =====
# 10. 创建计划
curl -X POST http://127.0.0.1:8001/api/fasting/plans \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "plan_type":"16_8",
    "start_date":"2026-07-10",
    "target_weight":65.0,
    "disclaimer_accepted":true,
    "health_assessment":{"bmi":22.5,"has_diabetes":false,"is_pregnant":false,"is_minor":false,"has_eating_disorder":false}
  }'

# 11. 获取计划列表
curl "http://127.0.0.1:8001/api/fasting/plans?status=active" \
  -H "Authorization: Bearer $TOKEN"

# 12. 每日打卡
curl -X POST http://127.0.0.1:8001/api/fasting/checkins \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"plan_id":1,"checkin_date":"2026-07-10","weight":66.2,"feeling":"good","completed":true}'

# 13. 打卡记录
curl "http://127.0.0.1:8001/api/fasting/checkins?plan_id=1" \
  -H "Authorization: Bearer $TOKEN"

# 14. 进度查询
curl "http://127.0.0.1:8001/api/fasting/progress?plan_id=1" \
  -H "Authorization: Bearer $TOKEN"

# 15. 复食指导
curl "http://127.0.0.1:8001/api/fasting/refeed-guide?plan_id=1" \
  -H "Authorization: Bearer $TOKEN"

# 16. 停止计划
curl -X PUT "http://127.0.0.1:8001/api/fasting/plans/1/stop" \
  -H "Authorization: Bearer $TOKEN"
```

### 9.2 关键功能验证方法

**宠物状态更新**：

1. 创建几条饮食记录 → 调用 `GET /api/virtual-pet/status` 确认 mood/exp 变化
2. 创建饮水记录 → 确认 habit_score 更新
3. 多次达标后 → 确认 version 递增、unlockables 解锁

**断食禁忌拦截**：

```bash
# 使用禁忌人群参数尝试创建（应被拦截）
curl -X POST http://127.0.0.1:8001/api/fasting/plans \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "plan_type":"basic_fasting",
    "start_date":"2026-07-10",
    "disclaimer_accepted":true,
    "health_assessment":{"bmi":17.0,"is_pregnant":false}
  }'
# 预期返回 400: "您属于禁忌人群（BMI 过低...），不建议启用辟谷模式"
```

**打卡不适预警**：

```bash
curl -X POST http://127.0.0.1:8001/api/fasting/checkins \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "plan_id":1,
    "checkin_date":"2026-07-10",
    "feeling":"uncomfortable",
    "discomfort":{"dizziness":true,"low_sugar":false,"palpitation":false}
  }'
# 预期返回 warning.level = "high"
```

---

## 十、附录

### A. 统一错误码

所有接口使用统一的错误码格式：

| 错误码 | HTTP 状态码 | 说明 |
|--------|------------|------|
| `AUTH_FAILED` | 401 | 认证失败 |
| `INVALID_PARAM` | 400 | 参数校验失败 |
| `NOT_FOUND` | 404 | 资源不存在 |
| `FORBIDDEN` | 403 | 权限不足 |
| `DISABLED_FOR_USER` | 400 | 用户不可用此功能（如禁忌人群） |

### B. 未完成的 Agent 侧工作

以下工作属于张正宏（前端+Agent）的职责范围，后端已预留接口和数据支持：

| 工作项 | 依赖的后端接口 |
|--------|---------------|
| `advisor_style_prompt_manager` — 根据用户设置生成风格化 system prompt | `GET /api/ai-advisor/settings` |
| `fasting_advisor_skill` — AI 生成断食计划和复食建议 | `POST /api/fasting/plans`（health_assessment 字段） |
| `pet_feedback_generator` — 根据达标情况生成宠物反馈文案 | `GET /api/virtual-pet/status` |
| chat_agent 注入风格化 prompt | `GET /api/ai-advisor/settings` |
| enhanced_nutrition_agent 读取用户设置调整输出 | `GET /api/ai-advisor/settings` |

### C. 后续优化建议

1. **消费统计缓存** — 高频查询的 cost-stats 可接入 Redis 缓存（参考已有 nutrition:daily 缓存模式）
2. **宠物状态 WebSocket** — 当前硬件使用 HTTP 轮询（30s），后续可升级为 WebSocket 推送
3. **复食指导 AI 化** — 当前使用静态模板，可接入 `fasting_advisor_skill` 生成个性化方案
4. **断食提醒** — `reminders` 表已添加 `fasting_plan_id` 关联，后续可在 reminder_service 中实现进食窗口自动提醒
5. **消费预算预警** — `user_profiles.monthly_food_budget` 已就绪，后续可添加定时任务检测 80%/100% 阈值并推送通知

---

**文档结束**
