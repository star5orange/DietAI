# DietAI Milestone 3 后端交付总结文档

> **版本**: v1.0
> **日期**: 2026-07-17
> **开发者**: 何丽
> **分支**: `backend`
> **需求覆盖率**: **25/25（100%）**
> **数据库**: PostgreSQL 17（Windows 原生服务，`127.0.0.1:5432`）

---

## 一、开发概览

Milestone 3 在 DietAI 现有"人的健康管理"基础上，新增**真实宠物健康管理**可选模块。用户可录入家中真实宠物（猫/狗等），通过智能硬件联动自动记录饮食、AI 分析营养摄入、生成专属卡通形象，实现"管好全家健康"的生态延伸。

### 五大功能模块

| 模块 | 功能说明 | 新增接口数 | 优先级 |
|------|---------|-----------|--------|
| **宠物档案管理** | 多宠物 CRUD、体重追踪/趋势图、疫苗/驱虫记录、到期提醒 | 13 | P0 |
| **硬件联动自动饮食记录** | target_type=pet 分支、喂食器/饮水机自动同步、每日营养汇总 | 3 | P0 |
| **宠物 AI 健康顾问** | 营养目标计算、7天趋势分析、AI 增强建议、换粮对比、健康评分 | 4 | P1 |
| **数据可视化（后端数据层）** | 饮食日报/周报、体重曲线、健康评分数据接口 | — | P1 |
| **AI 自定义宠物形象** | 通义万相图生图 → 4 情绪变体 → rembg 抠图 → MinIO → GIF | 4 | P0-P1 |

### 完成统计

| 指标 | 数值 |
|------|------|
| 需求功能点 | 25 项 |
| 已完成 | **25 项（100%）** |
| 新增数据库表 | 11 张（38 → 49） |
| 新增 API 端点 | 25 个（94 → 119） |
| 新增 Python 文件 | 12 个 |
| 修改现有文件 | 6 个 |
| 定时任务 | 2 个新增（共 8 个） |

---

## 二、数据库变更清单

### 2.1 新增表（9 张）

#### pet_profiles — 真实宠物档案

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | SERIAL PK | 主键 |
| `user_id` | INTEGER FK → users.id | 所属用户 |
| `name` | VARCHAR(50) | 宠物名 |
| `species` | VARCHAR(20) | cat / dog / other |
| `breed` | VARCHAR(100) | 品种（支持混血/其他手动输入） |
| `gender` | VARCHAR(10) | male / female |
| `birth_date` | DATE | 出生日期 |
| `is_neutered` | BOOLEAN | 是否绝育 |
| `avatar_url` | VARCHAR(500) | 头像 URL |
| `is_active` | BOOLEAN | 软删除标记 |

#### pet_weight_records — 宠物体重记录

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | SERIAL PK | 主键 |
| `pet_id` | INTEGER FK → pet_profiles.id | 关联宠物 |
| `weight` | DECIMAL(5,2) | 体重(kg) |
| `measured_at` | TIMESTAMP | 称重时间 |
| `notes` | TEXT | 备注 |

#### pet_vaccine_records — 疫苗记录

| 字段 | 类型 | 说明 |
|------|------|------|
| `vaccine_name` | VARCHAR(100) | 疫苗名称 |
| `vaccinated_at` | DATE | 接种日期 |
| `expiry_date` | DATE | 有效期 |
| `next_vaccination_date` | DATE | 下次接种日期（用于到期提醒） |

#### pet_deworming_records — 驱虫记录

| 字段 | 类型 | 说明 |
|------|------|------|
| `deworming_type` | VARCHAR(20) | internal（体内）/ external（体外） |
| `treated_at` | DATE | 驱虫日期 |
| `next_treatment_date` | DATE | 下次驱虫日期 |

#### pet_feeding_records — 宠物饮食记录

| 字段 | 类型 | 说明 |
|------|------|------|
| `food_name` | VARCHAR(200) | 食品名称 |
| `amount_grams` | DECIMAL(8,2) | 喂食克数 |
| `calories` | DECIMAL(8,2) | 热量(kcal) |
| `protein` / `fat` / `carbs` | DECIMAL(6,2) | 宏量营养素 |
| `record_time` | TIMESTAMP | 喂食时间 |
| `from_source` | VARCHAR(20) | hardware / manual |

#### pet_water_records — 宠物饮水记录

| 字段 | 类型 | 说明 |
|------|------|------|
| `amount_ml` | INTEGER | 饮水量(ml) |
| `record_time` | TIMESTAMP | 饮水时间 |
| `from_source` | VARCHAR(20) | hardware / manual |

#### pet_daily_summaries — 宠物每日营养汇总

| 字段 | 类型 | 说明 |
|------|------|------|
| `summary_date` | DATE | 汇总日期 |
| `total_calories` / `total_protein` / `total_fat` / `total_carbs` | DECIMAL | 当日合计 |
| `total_water_ml` | INTEGER | 当日饮水量 |
| `meal_count` | INTEGER | 当日餐数 |

#### pet_food_database — 宠物食品营养库

| 字段 | 类型 | 说明 |
|------|------|------|
| `food_name` | VARCHAR(200) | 食品名称 |
| `brand` | VARCHAR(100) | 品牌 |
| `category` | VARCHAR(20) | dry_food / wet_food / snack |
| `suitable_species` | VARCHAR(20) | cat / dog |
| `calories_per_100g` / `protein_per_100g` / `fat_per_100g` / `carbs_per_100g` | DECIMAL | 每100g营养 |

#### pet_avatars — AI 生成宠物形象

| 字段 | 类型 | 说明 |
|------|------|------|
| `pet_id` | INTEGER FK UNIQUE | 一宠一记录 |
| `status` | VARCHAR(20) | none / processing / done / failed |
| `error_message` | TEXT | 失败原因 |
| `base_image_url` | VARCHAR(500) | 基础形象 URL |
| `emotion_happy/normal/hungry/weak_url` | VARCHAR(500) | 4 种情绪变体 URL |
| `generation_seed` | INTEGER | 固定种子（pet_id × 10000） |
| `has_gif` | BOOLEAN | 是否已生成 GIF |
| `gif_url` | VARCHAR(500) | GIF URL |
| `prompt_used` | TEXT | 使用的 prompt |
| `ai_model` | VARCHAR(50) | 使用的 AI 模型 |

### 2.2 新增硬件表（2 张）

#### hardware_quick_buttons — 硬件快捷按钮

| 字段 | 说明 |
|------|------|
| `pet_id` | FK → pet_profiles.id（新增，支持宠物模式） |

#### offline_sync_log — 离线同步日志

| 字段 | 说明 |
|------|------|
| `target_type` | VARCHAR(20), default='human'（新增，区分 human/pet） |

### 2.3 修改现有表（3 张）

| 表名 | 变更 | 说明 |
|------|------|------|
| `virtual_pet_states` | 新增 `pet_name` VARCHAR(50)、`custom_messages` JSONB | 用户自定义桌宠名称和提示语 |
| `fasting_plans` | 新增 `fasting_days` JSONB | 断食日列表配置 |
| `fasting_checkins` | 新增 `is_fasting_day` BOOLEAN | 当天是否断食日 |

### 2.4 新增索引

| 表名 | 索引名 | 字段 |
|------|--------|------|
| `pet_profiles` | `idx_pet_profiles_user` | (user_id, is_active) |
| `pet_weight_records` | `idx_pet_weight_pet_time` | (pet_id, measured_at) |
| `pet_vaccine_records` | `idx_pet_vaccine_next_date` | (next_vaccination_date) |
| `pet_feeding_records` | `idx_pet_feeding_pet_time` | (pet_id, record_time) |
| `pet_water_records` | `idx_pet_water_pet_time` | (pet_id, record_time) |
| `pet_daily_summaries` | `idx_pet_daily_summary_date` | (pet_id, summary_date) UNIQUE |
| `pet_deworming_records` | `idx_pet_deworming_next` | (next_treatment_date) |
| `pet_food_database` | `idx_pet_food_db_species` | (suitable_species, category) |
| `hardware_quick_buttons` | `idx_hw_buttons_user` | (user_id, button_index) UNIQUE |
| `offline_sync_log` | `idx_offline_sync_user` | (user_id, synced_at) |
| `fasting_checkins` | `idx_fasting_checkin_fasting_day` | (plan_id, is_fasting_day) |

---

## 三、新增 API 接口汇总

### 3.1 宠物档案管理（5 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| POST | `/api/pets` | 创建宠物档案（支持多只宠物） |
| GET | `/api/pets` | 获取当前用户的活跃宠物列表 |
| GET | `/api/pets/{id}` | 获取宠物详情 |
| PUT | `/api/pets/{id}` | 更新宠物信息 |
| DELETE | `/api/pets/{id}` | 软删除宠物（设置 is_active=false） |

### 3.2 宠物体重记录（4 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| POST | `/api/pets/{id}/weight-records` | 记录体重 |
| GET | `/api/pets/{id}/weight-records` | 查询体重历史记录 |
| GET | `/api/pets/{id}/weight-trend` | 体重趋势图数据（7/30/90天），含品种理想范围 |
| DELETE | `/api/pets/{id}/weight-records/{record_id}` | 删除体重记录 |

### 3.3 宠物疫苗与驱虫（4 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| POST | `/api/pets/{id}/vaccine-records` | 添加疫苗记录 |
| GET | `/api/pets/{id}/vaccine-records` | 查询疫苗记录列表 |
| POST | `/api/pets/{id}/deworming-records` | 添加驱虫记录（体内/体外） |
| GET | `/api/pets/{id}/deworming-records` | 查询驱虫记录列表 |

### 3.4 宠物饮食记录（4 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| POST | `/api/pets/{id}/feeding-records` | 手动记录宠物饮食（支持食品名称/克数/营养） |
| GET | `/api/pets/{id}/feeding-records` | 查询饮食记录（分页） |
| GET | `/api/pets/{id}/daily-summary/{date}` | 宠物每日营养汇总 |
| GET | `/api/pets/{id}/feeding-plan` | 获取推荐喂食计划（基于品种/年龄/体重） |

### 3.5 硬件联动扩展（3 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| POST | `/api/hardware/sync` | **修改**：新增 target_type=pet 分支，支持硬件投粮/放水自动记录 |
| GET | `/api/hardware/quick-buttons/{user_id}` | **扩展**：支持查询宠物专用快捷按钮 |
| GET | `/api/hardware/pet-feeding-plan/{pet_id}` | 硬件查询当日喂食计划 |

**硬件同步请求示例（宠物喂食）**：

```json
POST /api/hardware/sync
{
  "user_id": 1,
  "target_type": "pet",
  "records": [{
    "type": "feeding",
    "pet_id": 1,
    "food_name": "皇家猫粮",
    "amount_grams": 50,
    "calories": 210,
    "protein": 17.5,
    "timestamp": "2026-07-17T08:00:00"
  }]
}
```

### 3.6 宠物食品库（2 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| GET | `/api/pets/food-database` | 查询食品库（按 species、category 筛选） |
| GET | `/api/pets/food-database/search` | 关键词搜索食品 |

### 3.7 宠物 AI 健康建议（1 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| POST | `/api/pets/{id}/ai-advice` | 获取 AI 健康建议（基于 7 天真实数据 + 可选 AI 增强） |

**响应示例**：

```json
{
  "daily_targets": {"calories": 250, "protein_g": 20, "fat_g": 8.3},
  "ideal_weight_range": "4.3–5.8 kg",
  "nutrition_trend": {
    "avg_calories_pct": 85.2,
    "avg_protein_pct": 90.1,
    "trend_summary": "良好：近7天营养摄入基本达标，仍有优化空间。"
  },
  "weight_alert": null,
  "nutrition_tips": [
    "近7天热量摄入达标率 85.2%，基本达标，可适当调整。",
    "近7天蛋白质摄入达标率 90.1%，蛋白质摄入充足。"
  ],
  "disclaimer": "我是 AI 助手，以上建议仅供参考。宠物健康问题请咨询专业兽医..."
}
```

### 3.8 AI 自定义宠物形象（4 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| POST | `/api/pets/{pet_id}/generate-avatar` | 触发 AI 生成（异步，返回 202 + task_id） |
| GET | `/api/pets/generation-tasks/{task_id}` | 查询生成任务状态与结果 |
| POST | `/api/pets/{pet_id}/regenerate-emotion` | 重新生成单个情绪变体（P1） |
| POST | `/api/pets/{pet_id}/upgrade-to-gif` | 4 帧微变体 → FFmpeg GIF 合成（P1） |

**生成 Pipeline**：

```
POST /generate-avatar (立即返回 202 + task_id)
  └─→ 后台线程:
      ① 通义万相 wan2.1-t2i-plus 生成基础卡通形象
      ② 并行生成 4 种情绪变体（seed = pet_id × 10000 + index）
      ③ rembg 抠图 → 透明背景 PNG
      ④ 上传 MinIO (pet_avatars/pet_{id}_{emotion}_{timestamp}.png)
      ⑤ 更新 pet_avatars 表 → status='done'
      失败 → status='failed' + error_message
      AI 不可用 → 自动降级为预设品种形象（8猫+1狗）
```

### 3.9 换粮建议（1 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| POST | `/api/pets/{id}/compare-foods` | 对比两份食品营养，生成 7 天渐进过渡方案 |

**响应示例**：

```json
{
  "comparison": {
    "current_food": {"name": "皇家室内成猫粮", "calories_per_100g": 380, "protein_per_100g": 34.0},
    "new_food": {"name": "渴望六种鱼猫粮", "calories_per_100g": 406, "protein_per_100g": 40.0},
    "differences": {"calories_change": 26.0, "calories_change_pct": 6.8, "protein_change": 6.0}
  },
  "transition_plan": [
    {"day": "1-2", "current_ratio": "75%", "new_ratio": "25%"},
    {"day": "3-4", "current_ratio": "50%", "new_ratio": "50%"},
    {"day": "5-6", "current_ratio": "25%", "new_ratio": "75%"},
    {"day": "7",   "current_ratio": "0%",  "new_ratio": "100%"}
  ],
  "warnings": ["换粮期间密切观察宠物粪便情况..."],
  "disclaimer": "换粮建议仅供参考。每只宠物体质不同..."
}
```

### 3.10 宠物健康评分（1 个接口）

| 方法 | 路径 | 功能说明 |
|------|------|---------|
| GET | `/api/pets/{id}/health-score` | 四维度综合评分 0-100 分 |

**评分维度**：

| 维度 | 满分 | 计算逻辑 |
|------|------|---------|
| 饮食达标率 | 40 | (热量达标率 + 蛋白质达标率) / 2 / 100 × 40 |
| 体重管理 | 30 | 理想范围=30，轻微偏离=20，明显偏离=10 |
| 疫苗状态 | 20 | 全部有效=20，部分到期=12，已过期=5 |
| 活跃度 | 10 | 近7天有饮食记录的天数 |

---

## 四、关键业务逻辑说明

### 4.1 硬件协议扩展（target_type=pet 分支）

```
POST /api/hardware/sync
  │
  ├─ target_type=human (默认)
  │   └─ sync_offline_records() → water/food records
  │
  └─ target_type=pet (M3 新增)
      ├─ type=feeding → sync_pet_feeding()
      │   ├─ 写入 pet_feeding_records
      │   └─ _upsert_pet_daily_summary() 更新每日汇总
      └─ type=water → sync_pet_water()
          ├─ 写入 pet_water_records
          └─ _upsert_pet_daily_summary() 更新每日汇总
```

两条分支完全独立，互不干扰。human 和 pet 记录写入不同的表。

### 4.2 宠物营养目标计算

```
每日热量 = 品种标准体重(kg)
         × 每公斤热量(kcal/kg)
         × 生命阶段系数 (幼年2.0 / 成年1.0 / 老年0.8)
         × 绝育调整 (0.85 if 已绝育)
         × 活动水平 (低0.8 / 中1.0 / 高1.2)

每日蛋白质(g) = 每日热量 × 蛋白质热量占比 / 4
  - 猫: 26% 热量来自蛋白质
  - 狗: 18%

每日脂肪(g) = 每日热量 × 30% / 9
```

品种数据来源于 `shared/config/pet_breeds.json`（8 猫 + 5 狗品种），未匹配品种使用物种默认值。

### 4.3 饮食趋势分析

- 查询近 7 天 `pet_daily_summaries` 数据
- 计算日均热量/蛋白质达标率
- **连续 3 天 < 70% 目标** → 识别为营养缺口
- 基于真实数据动态生成建议文案（非静态模板）
- 如果 `DASHSCOPE_API_KEY` 或 `DEEPSEEK_API_KEY` 已设置，调用 AI 增强建议

### 4.4 换粮 7 天渐进过渡方案

| 阶段 | 旧粮比例 | 新粮比例 | 重点 |
|------|---------|---------|------|
| Day 1-2 | 75% | 25% | 初步适应 |
| Day 3-4 | 50% | 50% | 观察粪便和精神状态 |
| Day 5-6 | 25% | 75% | 接近完全切换 |
| Day 7 | 0% | 100% | 完全切换，继续观察 |

自动检测并警告：
- 热量差异 > 20%
- 蛋白质明显降低（< 原食品 80%）
- 脂肪显著升高（> 原食品 150%）

### 4.5 健康评分四维度计算

| 维度 | 满分 | 数据来源 | 判定规则 |
|------|------|---------|---------|
| 饮食达标率 | 40 | pet_daily_summaries (7天) | (热量% + 蛋白质%) / 200 × 40 |
| 体重管理 | 30 | pet_weight_records + breed standard | 在理想范围 = 30，±15% = 20，>15% = 10 |
| 疫苗状态 | 20 | pet_vaccine_records | 全部有效 = 20，部分到期 = 12，已过期 = 5 |
| 活跃度 | 10 | pet_daily_summaries (7天) | 有记录天数（上限 10） |

### 4.6 定时任务

| 任务 | 执行时间 | 功能 |
|------|---------|------|
| `check_pet_vaccine_reminders` | 每天 08:00 | 检查疫苗/驱虫到期日期，提前 3 天创建提醒（写入 reminders 表） |
| `check_pet_weight_anomaly` | 每天 08:05 | 检查近两周体重变化 > 5%，生成预警通知 |

两个任务均通过 APScheduler 注册，复用现有 `reminders` 表推送提醒。

### 4.7 AI 形象生成 Pipeline

```
用户触发 POST /generate-avatar
  │
  ├─ 立即返回 202 + task_id
  └─ 后台线程执行:
      │
      ├─ ① 通义万相 wan2.1-t2i-plus
      │     prompt: "将这只宠物转换为Q版卡通形象..."
      │     seed: pet_id × 10000
      │     产出: 基础形象 PNG
      │
      ├─ ② 并行生成 4 种情绪变体
      │     seed = base_seed + emotion_index (1~4)
      │     产出: happy / normal / hungry / weak PNG
      │
      ├─ ③ rembg 抠图（每张）
      │     remove(img_bytes) → 透明背景 PNG
      │     失败 → 保留原始图片，不中断流程
      │
      ├─ ④ 上传 MinIO
      │     pet_avatars/pet_{id}_{emotion}_{timestamp}.png
      │     获取预签名 URL
      │
      └─ ⑤ 更新 pet_avatars 表
            status = 'done' / 'failed'
            写入各 emotion URL、seed、prompt
```

**兜底策略**：AI API 不可用时自动降级为预设品种形象（8 猫品种 + 默认狗），确保功能始终可用。

---

## 五、新增/修改文件清单

### 5.1 新建文件（12 个）

| 文件路径 | 类型 | 说明 |
|----------|------|------|
| `shared/models/schemas/real_pet.py` | Schema | 宠物档案/体重/疫苗/驱虫/饮食/饮水/AI建议/形象生成的 Pydantic Schema |
| `shared/services/real_pet_service.py` | Service | 宠物 CRUD + 体重/疫苗/驱虫/饮食/食品库/换粮/健康评分/AI 建议（~630 行） |
| `shared/services/pet_avatar_service.py` | Service | AI 形象生成 Pipeline：通义万相 + rembg + MinIO（~340 行） |
| `shared/services/pet_nutrition_calc.py` | Service | 营养目标计算 + 每周趋势分析 + 达标检查（~230 行） |
| `routers/real_pet_router.py` | Router | 宠物管理路由（~300 行，22+ 端点） |
| `routers/pet_avatar_router.py` | Router | AI 形象生成路由（4 端点） |
| `shared/tasks/pet_tasks.py` | Task | 疫苗/驱虫到期提醒 + 体重异常检测定时任务 |
| `shared/config/pet_breeds.json` | Config | 8 猫 + 5 狗品种标准体重/热量配置 |
| `scripts/init_pet_food_database.py` | Script | 宠物食品库种子数据（12 条猫粮/狗粮/零食） |
| `alembic/versions/7ef153f14795_milestone3_all_tables.py` | Migration | M3 全部数据库变更（11 张表 + 修改 3 张表 + 索引） |
| `alembic/versions/5f8e13bbb3c1_add_status_and_error_message_to_pet_.py` | Migration | PetAvatar 添加 status + error_message |

### 5.2 修改文件（6 个）

| 文件路径 | 改动内容 |
|----------|---------|
| `shared/models/pet_models.py` | 新增 11 个 ORM 模型（PetProfile ~ PetAvatar + HardwareQuickButton + OfflineSyncLog）；VirtualPetState 新增 pet_name/custom_messages |
| `shared/models/fasting_models.py` | FastingPlan 新增 fasting_days；FastingCheckin 新增 is_fasting_day |
| `routers/hardware_router.py` | 新增 pet 分支路由：sync pet records、pet-feeding-plan |
| `shared/services/hardware_service.py` | 新增 sync_pet_feeding()、sync_pet_water()、get_pet_quick_buttons()、get_pet_feeding_plan_for_hardware() |
| `shared/tasks/scheduler.py` | 注册 check_pet_vaccine_reminders + check_pet_weight_anomaly 定时任务 |
| `main.py` | 注册 real_pet_router + pet_avatar_router；导入新模型 |
| `shared/config/settings.py` | jwt_private_key / jwt_public_key 属性增加 FileNotFoundError 容错 |
| `pyproject.toml` | 新增 rembg 依赖 |

---

## 六、部署与启动说明

### 6.1 数据库迁移

```bash
# 在项目根目录执行
uv run alembic upgrade head
```

迁移文件（按执行顺序）：
1. `0da986e876fe` — M2 基础
2. `7ef153f14795` — M3 全部 11 张新表 + 索引 + 修改 3 张表
3. `5f8e13bbb3c1` — PetAvatar 添加 status + error_message

### 6.2 种子数据初始化

```bash
# 宠物食品库（12 条常见猫粮/狗粮/零食）
uv run python scripts/init_pet_food_database.py
```

### 6.3 环境变量

| 变量 | 必需 | 说明 |
|------|------|------|
| `DIETAI_DEBUG` | 开发 | 设为 `true`（已在 `.env.dev` 中配置） |
| `DASHSCOPE_API_KEY` | 可选 | 通义万相 API Key；未设置时 AI 形象生成自动降级为预设品种 |
| `DEEPSEEK_API_KEY` | 可选 | AI 健康建议增强；未设置时使用规则引擎兜底 |

### 6.4 依赖安装

```bash
uv sync                          # 安装全部依赖（含 rembg）
# rembg 首次运行会自动下载 U-Net 模型（~170MB）
```

### 6.5 启动服务

```bash
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
# Swagger: http://127.0.0.1:8000/docs
```

---

## 七、验证与测试

### 7.1 前提：获取 Token

```bash
# 注册
curl -X POST http://127.0.0.1:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test_m3","email":"m3@dietai.dev","password":"Test123456"}'

# 登录并保存 Token
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test_m3","password":"Test123456"}' \
  | python -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])")
```

### 7.2 宠物档案 CRUD

```bash
# 创建宠物
curl -X POST http://127.0.0.1:8000/api/pets \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"小橘","species":"cat","breed":"橘猫","gender":"male","birth_date":"2024-03-15","is_neutered":true}'

# 宠物列表
curl http://127.0.0.1:8000/api/pets -H "Authorization: Bearer $TOKEN"

# 宠物详情
curl http://127.0.0.1:8000/api/pets/1 -H "Authorization: Bearer $TOKEN"

# 更新宠物
curl -X PUT http://127.0.0.1:8000/api/pets/1 \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"大橘"}'

# 软删除
curl -X DELETE http://127.0.0.1:8000/api/pets/1 -H "Authorization: Bearer $TOKEN"
```

### 7.3 体重、疫苗、驱虫

```bash
# 记录体重
curl -X POST http://127.0.0.1:8000/api/pets/1/weight-records \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"weight":5.2,"notes":"今日称重"}'

# 体重趋势
curl "http://127.0.0.1:8000/api/pets/1/weight-trend?days=30" -H "Authorization: Bearer $TOKEN"

# 添加疫苗
curl -X POST http://127.0.0.1:8000/api/pets/1/vaccine-records \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"vaccine_name":"猫三联","vaccinated_at":"2026-01-15","next_vaccination_date":"2027-01-15"}'

# 添加驱虫
curl -X POST http://127.0.0.1:8000/api/pets/1/deworming-records \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"deworming_type":"internal","treated_at":"2026-06-01","next_treatment_date":"2026-09-01"}'
```

### 7.4 饮食记录

```bash
# 手动记录饮食
curl -X POST http://127.0.0.1:8000/api/pets/1/feeding-records \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"food_name":"皇家猫粮","amount_grams":50,"calories":190,"protein":17}'

# 每日汇总
curl http://127.0.0.1:8000/api/pets/1/daily-summary/2026-07-17 -H "Authorization: Bearer $TOKEN"

# 喂食计划
curl http://127.0.0.1:8000/api/pets/1/feeding-plan -H "Authorization: Bearer $TOKEN"
```

### 7.5 硬件联动

```bash
# 硬件投粮
curl -X POST http://127.0.0.1:8000/api/hardware/sync \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"user_id":1,"target_type":"pet","records":[{"type":"feeding","pet_id":1,"food_name":"皇家猫粮","amount_grams":50,"calories":190,"protein":17,"timestamp":"2026-07-17T08:00:00"}]}'

# 硬件放水
curl -X POST http://127.0.0.1:8000/api/hardware/sync \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"user_id":1,"target_type":"pet","records":[{"type":"water","pet_id":1,"amount_ml":150,"timestamp":"2026-07-17T08:00:00"}]}'

# 硬件查询喂食计划
curl http://127.0.0.1:8000/api/hardware/pet-feeding-plan/1 -H "Authorization: Bearer $TOKEN"
```

### 7.6 AI 建议 & 换粮 & 健康评分

```bash
# AI 健康建议
curl -X POST http://127.0.0.1:8000/api/pets/1/ai-advice \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" -d '{}'

# 换粮对比
curl -X POST http://127.0.0.1:8000/api/pets/1/compare-foods \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"current_food_id":1,"new_food_id":5}'

# 健康评分
curl http://127.0.0.1:8000/api/pets/1/health-score -H "Authorization: Bearer $TOKEN"
```

### 7.7 AI 宠物形象

```bash
# 生成形象
curl -X POST http://127.0.0.1:8000/api/pets/1/generate-avatar \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"mode":"description","description":"橘猫，白手套，绿眼睛"}'

# 查询任务状态
curl http://127.0.0.1:8000/api/pets/generation-tasks/gen_1_1712345678 \
  -H "Authorization: Bearer $TOKEN"

# 重新生成情绪
curl -X POST http://127.0.0.1:8000/api/pets/1/regenerate-emotion \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"emotion":"happy"}'

# 升级为 GIF
curl -X POST http://127.0.0.1:8000/api/pets/1/upgrade-to-gif \
  -H "Authorization: Bearer $TOKEN"
```

### 7.8 食品库

```bash
# 查询猫粮
curl "http://127.0.0.1:8000/api/pets/food-database?species=cat&category=dry_food" \
  -H "Authorization: Bearer $TOKEN"

# 搜索
curl "http://127.0.0.1:8000/api/pets/food-database/search?keyword=皇家" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 八、注意事项与后续建议

### 8.1 Agent 层待开发项（张正宏 — 前端/Agent 职责）

以下工作属于 AI Agent 层，后端已提供完整的数据接口支持：

| 工作项 | 依赖的后端接口 |
|--------|---------------|
| `pet_nutrition_skill` — 基于品种/年龄计算营养目标 | `pet_nutrition_calc.py` 模块 |
| `pet_health_advice_skill` — 基于饮食历史生成健康建议 | `POST /api/pets/{id}/ai-advice` |
| `pet_weight_alert_skill` — 体重异常预警文案生成 | `GET /api/pets/{id}/weight-trend` |
| `diet_deep_agent` pet_health Skills | 各 pet API |
| `chat_agent` session_type=6 宠物健康咨询 | chat_router 扩展 |

### 8.2 前端待开发项（张正宏 — 前端职责）

| 工作项 | 说明 |
|--------|------|
| 宠物品种选择器 | 复用 `pet_breeds.json` + `GET /api/pets/food-database?species=cat` |
| 伪动画组件 | 呼吸缩放、眨眼、微旋转、情绪切换淡入淡出 |
| 宠物饮食日报/周报页面 | 复用 `fl_chart`，数据源切换至 pet API |
| my_pet_page.dart 改造 | 新增「真实宠物」Tab |

### 8.3 后续优化建议

1. **AI 形象 WebSocket 推送**：当前用轮询查询生成状态，可改为 WebSocket 实时推送进度
2. **宠物品种数据扩展**：`pet_breeds.json` 可持续补充更多品种和精准数据
3. **拍照 OCR 录入食品**：`POST /api/pets/food-database/ocr` 接口，解析宠物食品包装营养成分表
4. **AI 对话 session_type=6**：chat_agent 增加宠物健康咨询 session，后端需在 chat_router 添加路由
5. **硬件固件对接测试**：`POST /api/hardware/sync` 的 pet 分支需与 ESP32 喂食器实物联调
6. **MinIO 预设形象图片**：8 种猫品种 + 默认狗的预设 PNG 需上传至 MinIO（当前为占位 URL）

---

## 附录 A：统一错误码

| 错误码 | HTTP 状态码 | 说明 |
|--------|------------|------|
| `AUTH_FAILED` | 401 | 认证失败 |
| `INVALID_PARAM` | 400 | 参数校验失败 |
| `NOT_FOUND` | 404 | 资源不存在（宠物/记录/食品） |
| `FORBIDDEN` | 403 | 权限不足 |
| `DISABLED_FOR_USER` | 400 | 用户不可用此功能 |

## 附录 B：文件结构总览

```
DietAI/
├── shared/
│   ├── models/
│   │   ├── pet_models.py          ← M3: 11 新模型（+ M2 保留）
│   │   ├── fasting_models.py      ← 修改: + fast_days, + is_fasting_day
│   │   └── schemas/
│   │       └── real_pet.py        ← M3: 全部 Schema
│   ├── services/
│   │   ├── real_pet_service.py    ← M3: 核心业务逻辑
│   │   ├── pet_nutrition_calc.py  ← M3: 营养计算
│   │   ├── pet_avatar_service.py  ← M3: AI 形象生成
│   │   └── hardware_service.py    ← 修改: + pet 同步函数
│   ├── tasks/
│   │   ├── pet_tasks.py           ← M3: 定时任务
│   │   └── scheduler.py           ← 修改: 注册 pet 任务
│   └── config/
│       └── pet_breeds.json        ← M3: 品种数据
├── routers/
│   ├── real_pet_router.py         ← M3: 宠物管理 API
│   ├── pet_avatar_router.py       ← M3: AI 形象 API
│   └── hardware_router.py         ← 修改: + pet 端点
├── scripts/
│   └── init_pet_food_database.py  ← M3: 食品库种子
├── alembic/versions/
│   ├── 7ef153f14795_*.py          ← M3: 全量迁移
│   └── 5f8e13bbb3c1_*.py          ← M3: PetAvatar 补充字段
└── main.py                        ← 修改: 注册新路由
```

---

**文档结束**
