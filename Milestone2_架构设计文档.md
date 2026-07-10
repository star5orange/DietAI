# DietAI Milestone 2 架构设计文档

> **版本**: v1.0
> **创建日期**: 2026-07-08
> **基于文档**: Milestone 2 需求文档（PRD）
> **目的**: 为何丽（后端）、张正宏（前端+Agent）提供统一的接口规范、数据模型、模块边界依据

---

## 一、系统整体架构

### 1.1 分层架构视图

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DietAI Milestone 2                            │
├─────────────────────────────────────────────────────────────────────┤
│  前端层（Flutter App）                                               │
│  ├─ 页面层：7 新增页面 + 5 修改页面                                   │
│  ├─ 组件层：5 新增 Widget + 状态管理                                 │
│  ├─ 服务层：API 客户端 + 本地缓存                                    │
│  └─ 通知层：推送接收 + 本地提醒                                      │
├─────────────────────────────────────────────────────────────────────┤
│  后端层（FastAPI）                                                   │
│  ├─ API 层：16 新增接口 + 5 修改接口                                  │
│  ├─ 业务层：消费统计 / 虚拟宠物 / AI顾问 / 轻断食                    │
│  ├─ 数据层：PostgreSQL + Redis + MinIO                              │
│  └─ 外部层：DeepSeek API / qwen3.7-plus                             │
├─────────────────────────────────────────────────────────────────────┤
│  AI Agent 层                                                        │
│  ├─ Prompt 管理：advisor_style_prompt_manager                       │
│  ├─ 技能层：fasting_advisor_skill / pet_feedback_generator          │
│  ├─ Agent 层：chat_agent / enhanced_nutrition_agent                 │
│  └─ 合规层：免责声明注入 / 情感诱导拦截                               │
├─────────────────────────────────────────────────────────────────────┤
│  硬件层（ESP32-S3 + ESP32-CAM）                                      │
│  ├─ 主控 S3：宠物状态同步 / WiFi HTTP / 屏幕动画                     │
│  ├─ 摄像头 CAM：拍照 / 串口 JPEG 传输 / 帧差检测                     │
│  └─ 通信协议：轮询 / HTTP / 状态版本号                               │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 模块划分与依赖关系

```
                    ┌──────────────┐
                    │   用户入口    │
                    │  Flutter App │
                    └───────┬──────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ 消费统计模块  │   │ 虚拟宠物模块  │   │ AI顾问模块    │
│ cost_service  │   │ pet_service   │   │ advisor_mgr   │
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                   │                   │
        │           ┌───────┴───────┐           │
        │           │               │           │
        │           ▼               ▼           │
        │   ┌───────────────┐ ┌───────────────┐ │
        │   │ 硬件状态同步  │ │ AI Agent层   │ │
        │   │ device_sync  │ │ agent_layer  │ │
        │   └───────┬───────┘ └───────┬───────┘ │
        │           │                 │         │
        └─────┬─────┴─────────────────┴─────┬───┘
              │                             │
              ▼                             ▼
        ┌───────────────────────────────────────┐
        │         数据持久层                     │
        │  PostgreSQL / Redis / MinIO          │
        └───────────────────────────────────────┘
              │
              ▼
        ┌───────────────────────────────────────┐
        │         外部服务层                     │
        │  DeepSeek API / qwen3.7-plus          │
        └───────────────────────────────────────┘
```

### 1.3 技术选型说明

| 层级 | 技术栈 | 选型理由 |
|------|--------|---------|
| 前端 | Flutter 3.x + Dart | 已有基础框架，跨平台一致性，支持 Dark Mode |
| 状态管理 | Provider / Riverpod | 轻量级，适合当前规模，避免过度设计 |
| 图表 | fl_chart | 纯 Flutter 实现，性能好，支持动画 |
| 动画 | Lottie + Rive | 支持复杂宠物动画，JSON 资源体积小 |
| 后端 | FastAPI + Python 3.10 | 已有基础服务，异步支持，自动 OpenAPI 文档 |
| ORM | SQLAlchemy 2.0 | 支持异步，类型提示友好，迁移工具完善 |
| 数据库 | PostgreSQL 14 | 已部署，支持 JSONB（unlocked_skins），索引丰富 |
| 缓存 | Redis 7 | 已部署，用于高频查询缓存、限流 |
| 对象存储 | MinIO | 已部署，存储食物图片，S3 兼容 API |
| AI 接口 | DeepSeek API / qwen3.7-plus | 国内合规，性价比高，支持视觉模型 |
| 硬件通信 | HTTP 轮询（30s） | ESP32-S3 WiFi 支持良好，轮询实现简单可靠 |

---

## 二、数据模型设计

### 2.1 新增表 DDL

#### 2.1.1 food_records 表修改

```sql
-- 新增消费金额和来源标签字段
ALTER TABLE food_records 
ADD COLUMN cost DECIMAL(10, 2) NULL,
ADD COLUMN source_tag VARCHAR(20) NULL;

-- 添加约束
ALTER TABLE food_records 
ADD CONSTRAINT chk_cost_non_negative CHECK (cost >= 0),
ADD CONSTRAINT chk_cost_max CHECK (cost <= 99999.99);

-- 添加索引（用于消费统计聚合查询）
CREATE INDEX idx_food_records_user_date ON food_records(user_id, record_date);
CREATE INDEX idx_food_records_source_tag ON food_records(source_tag);
```

#### 2.1.2 user_profiles 表修改

```sql
-- 新增月度饮食预算字段
ALTER TABLE user_profiles 
ADD COLUMN monthly_food_budget DECIMAL(10, 2) DEFAULT 0;

-- 添加约束
ALTER TABLE user_profiles 
ADD CONSTRAINT chk_budget_non_negative CHECK (monthly_food_budget >= 0);
```

#### 2.1.3 virtual_pet_states 表（新增）

```sql
CREATE TABLE virtual_pet_states (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 状态字段
    mood VARCHAR(20) NOT NULL DEFAULT 'normal',
    -- ENUM: 'normal', 'happy', 'hungry', 'anxious', 'weak'
    
    level INTEGER NOT NULL DEFAULT 1,
    exp INTEGER NOT NULL DEFAULT 0,
    
    -- 外观字段
    current_skin VARCHAR(50) NOT NULL DEFAULT 'default',
    unlocked_skins JSONB NOT NULL DEFAULT '[]',
    -- 示例: ["default", "summer", "sporty"]
    
    -- 计算字段
    habit_score INTEGER NOT NULL DEFAULT 0,
    -- 每日达标累计分数
    
    -- 时间字段
    last_interact_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_feed_at TIMESTAMP NULL,
    last_play_at TIMESTAMP NULL,
    
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 索引
CREATE UNIQUE INDEX idx_pet_state_user ON virtual_pet_states(user_id);
CREATE INDEX idx_pet_state_mood ON virtual_pet_states(mood);
CREATE INDEX idx_pet_state_updated ON virtual_pet_states(updated_at);

-- 触发器：自动更新 updated_at
CREATE TRIGGER trigger_pet_state_updated_at
BEFORE UPDATE ON virtual_pet_states
FOR EACH ROW EXECUTE FUNCTION update_timestamp();
```

#### 2.1.4 pet_unlockables 表（新增）

```sql
CREATE TABLE pet_unlockables (
    id SERIAL PRIMARY KEY,
    
    unlock_type VARCHAR(20) NOT NULL,
    -- ENUM: 'skin', 'action', 'effect'
    
    unlock_key VARCHAR(50) NOT NULL UNIQUE,
    -- 示例: 'summer_skin', 'happy_spin', 'gold_sparkle'
    
    name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    
    -- 解锁条件
    required_level INTEGER NULL,
    required_streak INTEGER NULL,
    required_habit_score INTEGER NULL,
    
    -- 资源路径
    asset_url VARCHAR(255) NULL,
    -- Lottie JSON 文件路径
    
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 初始数据
INSERT INTO pet_unlockables (unlock_type, unlock_key, name, description, required_level, required_streak) VALUES
('skin', 'default', '默认外观', '可爱的基础宠物形象', 1, NULL),
('skin', 'summer', '夏日清凉', '夏日海滩风格外观', 3, NULL),
('skin', 'sporty', '运动活力', '运动装备外观', 5, NULL),
('action', 'happy_spin', '开心转圈', '达标后的开心转圈动作', NULL, 3),
('action', 'feed_eat', '进食动画', '喂食时的进食动作', NULL, NULL),
('effect', 'gold_sparkle', '金色光效', '升级时的金色闪光效果', 10, NULL);
```

#### 2.1.5 ai_advisor_settings 表（新增）

```sql
CREATE TABLE ai_advisor_settings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 风格设置
    advisor_style VARCHAR(30) NOT NULL DEFAULT 'nutritionist',
    -- ENUM: 'nutritionist', 'fitness_coach', 'tcm_healer', 'encouraging_friend'
    
    -- 专业偏向
    focus_goal VARCHAR(30) NULL,
    -- ENUM: 'fat_loss', 'muscle_gain', 'sugar_control', 'wellness', 'balanced'
    
    focus_nutrient VARCHAR(30) NULL,
    -- ENUM: 'calories', 'protein', 'carb', 'fat', 'micronutrient'
    
    -- 输出风格
    response_style VARCHAR(30) NOT NULL DEFAULT 'detailed',
    -- ENUM: 'concise', 'detailed', 'example_rich'
    
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 索引
CREATE UNIQUE INDEX idx_advisor_settings_user ON ai_advisor_settings(user_id);

-- 触发器
CREATE TRIGGER trigger_advisor_settings_updated_at
BEFORE UPDATE ON ai_advisor_settings
FOR EACH ROW EXECUTE FUNCTION update_timestamp();
```

#### 2.1.6 fasting_plans 表（新增）

```sql
CREATE TABLE fasting_plans (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 计划类型
    plan_type VARCHAR(20) NOT NULL,
    -- ENUM: '16_8', '5_2', 'basic_fasting'
    
    -- 目标与周期
    target_weight DECIMAL(5, 2) NULL,
    start_date DATE NOT NULL,
    end_date DATE NULL,
    
    -- 状态
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    -- ENUM: 'active', 'paused', 'stopped', 'completed'
    
    -- 进食窗口
    eating_window_start TIME NOT NULL DEFAULT '08:00',
    eating_window_end TIME NOT NULL DEFAULT '16:00',
    
    -- 安全确认
    disclaimer_accepted BOOLEAN NOT NULL DEFAULT FALSE,
    disclaimer_accepted_at TIMESTAMP NULL,
    
    -- 禁忌筛查结果
    health_assessment JSONB NULL,
    -- 示例: {"bmi": 22.5, "has_diabetes": false, "is_pregnant": false}
    
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 索引
CREATE INDEX idx_fasting_plans_user ON fasting_plans(user_id);
CREATE INDEX idx_fasting_plans_status ON fasting_plans(status, user_id);
CREATE INDEX idx_fasting_plans_date ON fasting_plans(start_date, end_date);

-- 触发器
CREATE TRIGGER trigger_fasting_plans_updated_at
BEFORE UPDATE ON fasting_plans
FOR EACH ROW EXECUTE FUNCTION update_timestamp();
```

#### 2.1.7 fasting_checkins 表（新增）

```sql
CREATE TABLE fasting_checkins (
    id SERIAL PRIMARY KEY,
    plan_id INTEGER NOT NULL REFERENCES fasting_plans(id) ON DELETE CASCADE,
    
    -- 打卡日期
    checkin_date DATE NOT NULL,
    
    -- 身体数据
    weight DECIMAL(5, 2) NULL,
    feeling VARCHAR(30) NOT NULL DEFAULT 'normal',
    -- ENUM: 'good', 'normal', 'tired', 'uncomfortable'
    
    -- 完成情况
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- 不适症状（用于风险预警）
    discomfort JSONB NULL,
    -- 示例: {"dizziness": true, "low_sugar": false, "palpitation": false}
    
    -- 备注
    notes TEXT NULL,
    
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 索引
CREATE UNIQUE INDEX idx_fasting_checkin_plan_date ON fasting_checkins(plan_id, checkin_date);
CREATE INDEX idx_fasting_checkin_discomfort ON fasting_checkins(discomfort);
```

#### 2.1.8 reminders 表修改

```sql
-- 新增关联断食计划的字段
ALTER TABLE reminders 
ADD COLUMN fasting_plan_id INTEGER NULL REFERENCES fasting_plans(id) ON DELETE SET NULL;
```

### 2.2 索引策略总结

| 表名 | 索引 | 用途 |
|------|------|------|
| food_records | idx_food_records_user_date | 消费统计按用户+日期聚合 |
| food_records | idx_food_records_source_tag | 消费统计按来源分类 |
| virtual_pet_states | idx_pet_state_user | 用户宠物状态唯一查询 |
| virtual_pet_states | idx_pet_state_updated | 硬件轮询增量更新 |
| fasting_plans | idx_fasting_plans_status | 活动计划查询 |
| fasting_checkins | idx_fasting_checkin_plan_date | 打卡记录唯一性 |
| fasting_checkins | idx_fasting_checkin_discomfort | 不适症状预警查询 |

---

## 三、API 接口规范

### 3.1 消费统计模块

#### 3.1.1 GET /api/foods/cost-stats

**用途**: 获取本周/本月消费统计数据

**请求参数**:
```
Query:
  - period: string = 'week' | 'month'  # 统计周期
  - user_id: int (from JWT)            # 当前用户
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "period": "week",
    "total_cost": 156.80,
    "daily_avg": 22.40,
    "max_single": 35.00,
    "record_count": 14,
    "by_meal_time": {
      "breakfast": 28.50,
      "lunch": 65.30,
      "dinner": 48.00,
      "snack": 15.00
    },
    "by_source": {
      "canteen": 58.00,
      "delivery": 68.80,
      "home": 20.00,
      "restaurant": 10.00
    },
    "calorie_per_yuan": 28.5,
    "budget_remaining": 343.20
  }
}
```

**SQL 查询示意**:
```sql
SELECT 
  SUM(cost) as total_cost,
  COUNT(*) as record_count,
  MAX(cost) as max_single,
  AVG(cost) as daily_avg,
  JSONB_OBJECT_AGG(meal_time, SUM(cost)) as by_meal_time,
  JSONB_OBJECT_AGG(source_tag, SUM(cost)) as by_source
FROM food_records
WHERE user_id = ? AND record_date BETWEEN ? AND ?
GROUP BY meal_time, source_tag;
```

#### 3.1.2 GET /api/foods/cost-trend

**用途**: 获取近 7/30 天消费趋势

**请求参数**:
```
Query:
  - days: int = 7 | 30        # 天数
  - source_tag: string (可选) # 按来源筛选
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "trend": [
      {"date": "2026-07-01", "cost": 22.50, "records": 3},
      {"date": "2026-07-02", "cost": 18.00, "records": 2},
      {"date": "2026-07-03", "cost": 35.00, "records": 4},
      ...
    ],
    "total": 156.80,
    "avg": 22.40
  }
}
```

### 3.2 虚拟宠物模块

#### 3.2.1 GET /api/virtual-pet/status

**用途**: App 端获取用户宠物状态

**响应示例**:
```json
{
  "success": true,
  "data": {
    "mood": "happy",
    "level": 3,
    "exp": 150,
    "exp_to_next": 200,
    "current_skin": "default",
    "unlocked_skins": ["default", "summer"],
    "habit_score": 85,
    "last_interact_at": "2026-07-08T10:30:00Z",
    "streak_days": 5
  }
}
```

#### 3.2.2 GET /api/virtual-pet/status-for-device

**用途**: 硬件端轮询获取宠物状态（精简版）

**响应示例**:
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

**说明**: 
- `version` 字段用于硬件端判断是否需要刷新
- 硬件每 30 秒轮询一次，对比 version 决定是否重新渲染

#### 3.2.3 POST /api/virtual-pet/interact

**用途**: 用户与宠物互动

**请求体**:
```json
{
  "action": "feed" | "play" | "pet",
  "item_id": "apple" (可选)
}
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "mood": "happy",
    "exp_gained": 10,
    "feedback_text": "宠物很开心地吃掉了苹果！",
    "new_unlock": null
  }
}
```

#### 3.2.4 GET /api/virtual-pet/unlockables

**用途**: 获取可解锁内容列表

**响应示例**:
```json
{
  "success": true,
  "data": {
    "unlockables": [
      {
        "unlock_type": "skin",
        "unlock_key": "summer",
        "name": "夏日清凉",
        "description": "夏日海滩风格外观",
        "required_level": 3,
        "required_streak": null,
        "is_unlocked": false,
        "progress": {"current_level": 3, "target_level": 3}
      },
      {
        "unlock_type": "action",
        "unlock_key": "happy_spin",
        "name": "开心转圈",
        "required_streak": 3,
        "is_unlocked": true
      }
    ]
  }
}
```

### 3.3 AI 顾问设置模块

#### 3.3.1 GET /api/ai-advisor/settings

**用途**: 获取用户 AI 顾问风格设置

**响应示例**:
```json
{
  "success": true,
  "data": {
    "advisor_style": "nutritionist",
    "focus_goal": "fat_loss",
    "focus_nutrient": "calories",
    "response_style": "detailed"
  }
}
```

#### 3.3.2 PUT /api/ai-advisor/settings

**用途**: 更新用户 AI 顾问风格设置

**请求体**:
```json
{
  "advisor_style": "fitness_coach",
  "focus_goal": "muscle_gain",
  "focus_nutrient": "protein",
  "response_style": "concise"
}
```

**响应示例**:
```json
{
  "success": true,
  "message": "AI 顾问风格已更新，下次对话生效"
}
```

### 3.4 轻断食模块

#### 3.4.1 POST /api/fasting/plans

**用途**: 创建轻断食计划

**请求体**:
```json
{
  "plan_type": "16_8",
  "target_weight": 65.0,
  "start_date": "2026-07-10",
  "eating_window_start": "08:00",
  "eating_window_end": "16:00",
  "health_assessment": {
    "bmi": 22.5,
    "has_diabetes": false,
    "is_pregnant": false,
    "is_minor": false,
    "has_eating_disorder": false
  },
  "disclaimer_accepted": true
}
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "plan_id": 1,
    "plan_type": "16_8",
    "status": "active",
    "eating_window": "08:00-16:00",
    "estimated_duration": "30 days",
    "warnings": []
  }
}
```

**错误示例（禁忌人群）**:
```json
{
  "success": false,
  "error": "DISABLED_FOR_USER",
  "message": "您属于禁忌人群（BMI < 18.5），不建议启用辟谷模式，请选择其他减脂方式"
}
```

#### 3.4.2 GET /api/fasting/plans

**用途**: 获取用户断食计划列表

**请求参数**:
```
Query:
  - status: string (可选) = 'active' | 'completed' | 'stopped'
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "plans": [
      {
        "plan_id": 1,
        "plan_type": "16_8",
        "status": "active",
        "start_date": "2026-07-10",
        "days_elapsed": 3,
        "days_remaining": 27,
        "target_weight": 65.0,
        "current_weight": 66.5
      }
    ]
  }
}
```

#### 3.4.3 POST /api/fasting/checkins

**用途**: 每日打卡

**请求体**:
```json
{
  "plan_id": 1,
  "checkin_date": "2026-07-10",
  "weight": 66.2,
  "feeling": "good",
  "completed": true,
  "discomfort": {
    "dizziness": false,
    "low_sugar": false,
    "palpitation": false
  },
  "notes": "第一天感觉良好"
}
```

**响应示例（正常）**:
```json
{
  "success": true,
  "data": {
    "message": "打卡成功，继续保持！",
    "weight_change": -0.3,
    "days_completed": 3,
    "warning": null
  }
}
```

**响应示例（不适预警）**:
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

#### 3.4.4 GET /api/fasting/progress

**用途**: 获取计划进度

**响应示例**:
```json
{
  "success": true,
  "data": {
    "plan_id": 1,
    "days_elapsed": 5,
    "days_total": 30,
    "completion_rate": 16.7,
    "weight_start": 67.0,
    "weight_current": 66.0,
    "weight_change": -1.0,
    "feeling_avg": "good",
    "streak_days": 5,
    "chart": [
      {"date": "2026-07-10", "weight": 67.0},
      {"date": "2026-07-11", "weight": 66.8},
      {"date": "2026-07-12", "weight": 66.5},
      ...
    ]
  }
}
```

#### 3.4.5 GET /api/fasting/refeed-guide

**用途**: 获取复食指导方案

**请求参数**:
```
Query:
  - plan_id: int
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "plan_type": "16_8",
    "refeed_duration": "7 days",
    "phases": [
      {
        "day": "1-2",
        "description": "清淡饮食阶段",
        "foods": ["粥", "蒸蔬菜", "清淡汤品"],
        "avoid": ["油炸", "辛辣", "高蛋白"]
      },
      {
        "day": "3-5",
        "description": "渐进恢复阶段",
        "foods": ["全谷物", "瘦肉", "豆制品"],
        "avoid": ["暴饮暴食"]
      },
      {
        "day": "6-7",
        "description": "正常饮食恢复",
        "tips": "逐步恢复到正常饮食结构，保持健康习惯"
      }
    ],
    "disclaimer": "复食期间如出现不适，请立即咨询医生"
  }
}
```

### 3.5 修改接口

#### 3.5.1 POST /api/foods/records（修改）

**新增请求字段**:
```json
{
  "food_name": "红烧肉",
  "meal_time": "lunch",
  "description": "食堂午餐",
  "calories": 350,
  "protein": 15,
  "carb": 20,
  "fat": 18,
  
  // 新增字段
  "cost": 12.50,
  "source_tag": "canteen"
}
```

#### 3.5.2 POST /chat/send-message-stream（修改）

**新增上下文注入逻辑**:
```python
async def send_message_stream(message: str, session_id: int, user_id: int):
    # 读取 AI 顾问设置
    settings = await get_advisor_settings(user_id)
    
    # 注入风格化 system prompt
    system_prompt = build_style_prompt(
        advisor_style=settings.advisor_style,
        focus_goal=settings.focus_goal,
        focus_nutrient=settings.focus_nutrient,
        response_style=settings.response_style
    )
    
    # 强制追加合规免责声明
    system_prompt += "\n\n【重要】我是 AI 健康顾问，建议仅供参考，不能替代医生诊断。"
    
    # 调用 chat_agent
    response = await chat_agent.chat(
        message=message,
        system_prompt=system_prompt,
        session_id=session_id,
        user_id=user_id
    )
    
    return response
```

---

## 四、前端组件架构

### 4.1 页面路由设计

```
/ (home)
├─ /cost-stats          # 消费统计页
├─ /pet                 # 宠物首页
│   └─ /pet/detail      # 宠物详情页
├─ /advisor-style       # AI 顾问风格设置页
├─ /fasting             # 轻断食首页
│   ├─ /fasting/create  # 创建计划页
│   ├─ /fasting/detail/:id  # 计划详情页
│   ├─ /fasting/checkin # 打卡页
│   └─ /fasting/refeed  # 复食指导页
└─ /settings
    ├─ /settings/budget # 月度预算设置
    └─ /settings/advisor # AI 顾问风格（快捷入口）
```

### 4.2 新增页面组件树

#### cost_statistics_page.dart

```
CostStatisticsPage
├─ AppBar (标题 + 周期切换按钮)
├─ TotalCostCard
│   ├─ TotalAmountText
│   ├─ DailyAvgText
│   └─ MaxSingleText
├─ CategoryPieChart (by_meal_time / by_source)
├─ CostTrendChart (fl_chart LineChart)
├─ CaloriePerYuanCard
└─ BudgetRemainingCard (条件渲染)
```

#### pet_home_page.dart

```
PetHomePage
├─ PetAnimationWidget (Lottie + 状态映射)
│   ├─ MoodIndicator (mood -> 动画选择)
│   └─ LevelBadge
├─ QuickActionButtons
│   ├─ FeedButton
│   ├─ PlayButton
│   └─ PetButton
├─ StreakBadge (连续达标天数)
└─ NavigateToDetailButton
```

#### pet_detail_page.dart

```
PetDetailPage
├─ LargePetAnimationWidget
├─ StatusPanel
│   ├─ MoodText
│   ├─ LevelProgress (exp / exp_to_next)
│   └─ HabitScoreText
├─ UnlockablesList
│   └─ UnlockableCard (每个可解锁项)
│       ├─ PreviewImage
│       ├─ NameText
│       ├─ ProgressIndicator
│       └─ UnlockButton (条件渲染)
└─ InteractPanel
    ├─ FeedButton + ItemSelector
    ├─ PlayButton
    └─ PetButton
```

#### advisor_style_page.dart

```
AdvisorStylePage
├─ StyleSelector (4 种风格卡片)
│   ├─ NutritionistCard
│   ├─ FitnessCoachCard
│   ├─ TCMHealerCard
│   └─ EncouragingFriendCard
├─ FocusGoalSelector (5 种目标)
├─ FocusNutrientSelector (5 种营养素)
├─ ResponseStyleSelector (3 种输出风格)
└─ SaveButton
```

#### fasting_plan_page.dart

```
FastingPlanPage
├─ ActivePlanCard (如有活动计划)
│   ├─ PlanTypeText
│   ├─ ProgressIndicator
│   └─ NavigateToDetailButton
├─ CreatePlanButton (无活动计划时)
└─ HistoryPlansList (已完成/已停止)
```

#### fasting_checkin_page.dart

```
FastingCheckinPage
├─ DateSelector
├─ WeightInput
├─ FeelingSelector (good / normal / tired / uncomfortable)
├─ DiscomfortCheckboxList
│   ├─ DizzinessCheckbox
│   ├─ LowSugarCheckbox
│   └─ PalpitationCheckbox
├─ NotesInput
└─ SubmitButton
```

### 4.3 状态管理方案

使用 **Provider** 管理全局状态：

```dart
// 全局 Provider
MultiProvider(
  providers: [
    Provider<PetService>(create: (_) => PetService()),
    Provider<AdvisorService>(create: (_) => AdvisorService()),
    Provider<FastingService>(create: (_) => FastingService()),
    Provider<CostService>(create: (_) => CostService()),
    
    ChangeNotifierProvider<PetState>(create: (_) => PetState()),
    ChangeNotifierProvider<AdvisorState>(create: (_) => AdvisorState()),
    ChangeNotifierProvider<FastingState>(create: (_) => FastingState()),
  ],
  child: MyApp(),
)

// PetState 示例
class PetState extends ChangeNotifier {
  String mood = 'normal';
  int level = 1;
  int exp = 0;
  String currentSkin = 'default';
  
  Future<void> fetchStatus() async {
    final response = await petService.getStatus();
    mood = response.mood;
    level = response.level;
    exp = response.exp;
    notifyListeners();
  }
  
  Future<void> interact(String action) async {
    final response = await petService.interact(action);
    exp += response.expGained;
    mood = response.mood;
    notifyListeners();
  }
}
```

### 4.4 本地缓存策略

```dart
// 使用 CacheManager 缓存高频数据
class CacheManager {
  static final PetStatusCache = _cache<PetStatus>(
    key: 'pet_status',
    duration: Duration(minutes: 5),
  );
  
  static final AdvisorSettingsCache = _cache<AdvisorSettings>(
    key: 'advisor_settings',
    duration: Duration(hours: 1),
  );
  
  static final CostStatsCache = _cache<CostStats>(
    key: 'cost_stats_week',
    duration: Duration(hours: 6),
  );
}
```

---

## 五、AI Agent 架构

### 5.1 Agent 层次划分

```
┌─────────────────────────────────────────────────────────────┐
│                      AI Agent Layer                          │
├─────────────────────────────────────────────────────────────┤
│  Prompt Manager Layer                                        │
│  └───────────────────────────────────────────────────────┐ │
│  │ advisor_style_prompt_manager                          │ │
│  │ - 生成风格化 system prompt                            │ │
│  │ - 注入合规免责声明                                     │ │
│  │ - 过滤情感诱导表达                                     │ │
│  └───────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Skill Layer                                                 │
│  └───────────────────────────────────────────────────────┐ │
│  │ fasting_advisor_skill                                 │ │
│  │ - 生成断食计划                                         │ │
│  │ - 打卡反馈                                             │ │
│  │ - 复食指导                                             │ │
│  │ - 禁忌人群提示                                         │ │
│  │                                                        │ │
│  │ pet_feedback_generator                                │ │
│  │ - 生成宠物反馈文案                                     │ │
│  │ - 根据达标情况生成 mood 对应提示                       │ │
│  └───────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Agent Layer                                                 │
│  └───────────────────────────────────────────────────────┐ │
│  │ chat_agent                                            │ │
│  │ - 接收用户对话                                         │ │
│  │ - 应用风格化 prompt                                    │ │
│  │ - 调用技能层                                           │ │
│  │                                                        │ │
│  │ enhanced_nutrition_agent                              │ │
│  │ - 个性化饮食建议                                       │ │
│  │ - 结合用户设置调整输出                                 │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Prompt 模板设计

#### advisor_style_prompt_manager.py

```python
ADVISOR_PROMPTS = {
    'nutritionist': """
你是一位专业的营养师，擅长科学分析食物营养成分，为用户提供均衡饮食建议。

**回答风格**：
- 以数据为依据，列出具体营养数值
- 强调营养均衡，不偏激推荐单一饮食
- 语气专业但不生硬，像一位温和的指导老师

**禁止行为**：
- 不使用"我会一直陪着你"、"主人"等情感诱导表达
- 不以恋人、偶像身份说话
""",
    
    'fitness_coach': """
你是一位严格的健身教练，专注于减脂和增肌目标，强调执行力。

**回答风格**：
- 直接指出问题，不留情面但不是侮辱
- 强调热量控制和运动配合
- 用激励性语言，但不越界

**禁止行为**：
- 不使用"我会一直陪着你"、"主人"等情感诱导表达
""",
    
    'tcm_healer': """
你是一位中医养生师，擅长根据体质给出温和的饮食调理建议。

**回答风格**：
- 引用传统养生概念（如"脾胃调理"、"气血平衡"）
- 建议循序渐进，不激进
- 语气温和，像一位有经验的老医生

**禁止行为**：
- 不使用"我会一直陪着你"、"主人"等情感诱导表达
""",
    
    'encouraging_friend': """
你是一位鼓励型健康伙伴，像朋友一样给出建议，亲切但不越界。

**回答风格**：
- 语气轻松，使用日常用语
- 给出正向鼓励，但不回避问题
- 不以恋人、偶像身份说话

**禁止行为**：
- 不使用"我会一直陪着你"、"主人"等情感诱导表达
"""
}

MANDATORY_DISCLAIMER = """
【重要提醒】我是 AI 健康顾问，所有建议仅供参考，不能替代医生诊断。
如涉及具体健康方案，请结合个人身体状况，必要时咨询专业医生。
"""

def build_style_prompt(advisor_style: str, focus_goal: str = None, 
                        focus_nutrient: str = None, response_style: str = 'detailed') -> str:
    prompt = ADVISOR_PROMPTS[advisor_style]
    
    # 注入关注重点
    if focus_goal:
        prompt += f"\n**用户当前目标**: {focus_goal}\n请围绕此目标给出建议。"
    
    if focus_nutrient:
        prompt += f"\n**用户关注营养素**: {focus_nutrient}\n请在回答中重点分析此营养素。"
    
    # 注入输出风格
    if response_style == 'concise':
        prompt += "\n**输出要求**: 回答简洁直接，控制在 100 字以内。"
    elif response_style == 'example_rich':
        prompt += "\n**输出要求**: 回答详细，包含具体食物示例和做法。"
    
    # 强制追加免责声明
    prompt += MANDATORY_DISCLAIMER
    
    return prompt
```

#### fasting_advisor_skill.py

```python
FASTING_SKILL_PROMPT = """
你是一位专业的轻断食指导专家，负责为用户生成科学的断食计划和复食指导。

**核心要求**：
1. 计划生成时必须包含禁忌人群筛查
2. 每次建议必须附带"如出现不适请立即停止并咨询医生"
3. 复食指导必须循序渐进，不建议立即恢复正常饮食

**禁忌人群**：
- 孕妇、哺乳期女性
- 未成年人（<18岁）
- 糖尿病患者
- 进食障碍患者
- BMI < 18.5 的用户

**断食模式说明**：
- 16:8: 每天 16 小时禁食，8 小时进食窗口
- 5:2: 每周 5 天正常饮食，2 天低热量（500-600 kcal）
- basic_fasting: 循序渐进的基础辟谷引导

**输出格式**（JSON）：
{
  "plan": {
    "eating_window": "08:00-16:00",
    "daily_calorie_target": 1500,
    "meal_suggestions": ["高蛋白早餐", "蔬菜为主午餐", "清淡晚餐"]
  },
  "warnings": ["请确保饮水充足", "如出现头晕请立即停止"],
  "disclaimer": "本建议仅供参考，不能替代医生诊断"
}
"""

def generate_fasting_plan(plan_type: str, target_weight: float, 
                           health_assessment: dict) -> dict:
    # 禁忌人群筛查
    if health_assessment.get('bmi') < 18.5:
        return {
            "success": False,
            "error": "BMI 过低，不建议断食"
        }
    
    # 调用 AI 生成计划
    response = call_ai_api(
        system_prompt=FASTING_SKILL_PROMPT,
        user_message=f"生成 {plan_type} 计划，目标体重 {target_weight}kg"
    )
    
    return response
```

#### pet_feedback_generator.py

```python
PET_FEEDBACK_TEMPLATES = {
    'happy': [
        "太棒了！你今天的饮食很健康，宠物开心地转圈圈！",
        "完美达标！宠物为你感到骄傲，继续加油！",
        "你的坚持让宠物活力满满，它很喜欢你的努力！"
    ],
    'normal': [
        "今天的饮食还不错，宠物状态正常，继续保持！",
        "宠物看起来心情平稳，明天可以做得更好哦！"
    ],
    'hungry': [
        "宠物有点饿了，记得按时吃饭哦！",
        "你的宠物在提醒你：别忘记今天的三餐！"
    ],
    'anxious': [
        "宠物有点焦虑，可能是你今天吃得不太规律，明天调整一下吧！",
        "宠物期待你更稳定的饮食习惯，它会很支持你的！"
    ],
    'weak': [
        "宠物看起来有点虚弱，可能是营养不够，记得补充蛋白质哦！",
        "宠物需要你的照顾，今天的营养摄入可以再丰富一些！"
    ]
}

def generate_feedback(mood: str, streak_days: int, unlocked: bool) -> str:
    templates = PET_FEEDBACK_TEMPLATES[mood]
    feedback = random.choice(templates)
    
    if unlocked:
        feedback += "\n🎉 你解锁了新装扮！快去看看吧！"
    
    if streak_days >= 7:
        feedback += f"\n连续达标 {streak_days} 天，太厉害了！"
    
    return feedback
```

### 5.3 合规拦截规则

```python
# 情感诱导关键词拦截
EMOTIONAL_INDUCING_KEYWORDS = [
    "我会一直陪着你",
    "我是你的专属",
    "主人",
    "亲爱的",
    "宝贝",
    "我最爱的人",
    "只属于你"
]

def check_compliance(response_text: str) -> dict:
    for keyword in EMOTIONAL_INDUCING_KEYWORDS:
        if keyword in response_text:
            return {
                "compliant": False,
                "violated_keyword": keyword,
                "action": "请修改回答，移除情感诱导表达"
            }
    
    return {"compliant": True}
```

---

## 六、硬件联动架构

### 6.1 状态同步机制

```
┌──────────────┐                    ┌──────────────┐
│  Flutter App │                    │   后端 API   │
│              │                    │              │
│  用户操作    │ POST /interact ──►│ 更新状态     │
│  饮食记录    │ POST /foods ─────►│ 计算 habit   │
│              │                    │ 更新 mood    │
│              │                    │              │
│              │ GET /status ◄─────│ 返回最新状态 │
└──────────────┘                    └───────┬──────┘
                                            │
                                            │ HTTP
                                            │
                                    ┌───────▼──────┐
                                    │  ESP32-S3    │
                                    │  (主控)      │
                                    │              │
                                    │ GET /status  │
                                    │ 每 30s 轮询  │
                                    │              │
                                    │ version !=?  │
                                    │ 刷新屏幕     │
                                    └──────────────┘
```

### 6.2 状态版本号机制

**后端返回**:
```json
{
  "mood": "happy",
  "level": 3,
  "skin": "default",
  "version": 15  // 每次状态变更时 +1
}
```

**ESP32-S3 逻辑**:
```cpp
int last_version = 0;

void loop() {
  if (millis() - last_poll > 30000) {  // 30秒轮询
    String response = httpGET("/api/virtual-pet/status-for-device");
    PetStatus status = parsePetStatus(response);
    
    if (status.version != last_version) {
      updatePetDisplay(status.mood, status.skin);
      last_version = status.version;
    }
    
    last_poll = millis();
  }
}
```

### 6.3 宠物动画资源映射

| mood | Lottie 文件 | 说明 |
|------|-------------|------|
| normal | `pet_normal.json` | 平静站立，偶尔眨眼 |
| happy | `pet_happy.json` | 开心转圈，跳跃 |
| hungry | `pet_hungry.json` | 摸肚子，眼神期待 |
| anxious | `pet_anxious.json` | 轻微摇头，不安 |
| weak | `pet_weak.json` | 慢动作，低头 |

---

## 七、模块边界与协作规范

### 7.1 何丽（后端）职责边界

| 模块 | 职责 | 不涉及 |
|------|------|--------|
| 数据库 | 表设计、迁移脚本、索引优化 | 前端状态管理 |
| API | 接口实现、请求响应定义 | UI 组件 |
| 业务逻辑 | 状态计算、合规检查、聚合查询 | Prompt 模板 |
| 硬件协议 | status-for-device 端点 | ESP32-S3 固件 |

### 7.2 张正宏（前端+Agent）职责边界

| 模块 | 职责 | 不涉及 |
|------|------|--------|
| 前端页面 | UI 设计、组件实现、状态管理 | 数据库表 |
| API 调用 | 前端 HTTP 客户端、缓存 | 接口实现 |
| AI Agent | Prompt 模板、技能层、合规规则 | 数据库查询 |
| 宠物动画 | Lottie 资源、动画触发 | 状态计算公式 |

### 7.3 胡馨（统筹）职责边界

| 模块 | 职责 | 不涉及 |
|------|------|--------|
| 架构设计 | 模块划分、接口定义、数据模型 | 具体代码实现 |
| 文档同步 | PRD、架构文档、测试文档 | UI 设计 |
| 测试 | 验收测试、Bug 汇总、联调协调 | 单元测试编写 |
| 硬件联调 | 状态同步测试、协议验证 | ESP32 固件编写 |

### 7.4 接口对接约定

1. **接口文档先行**: 何丽先输出 OpenAPI schema，张正宏按文档对接
2. **Mock 数据**: 后端未完成时，前端使用 mock.json 开发
3. **错误码统一**: 所有接口使用统一错误码格式（见附录）
4. **日志规范**: 关键操作记录 user_id、action、timestamp

---

## 八、附录

### 附录 A：统一错误码定义

| 错误码 | 说明 | 示例 |
|--------|------|------|
| SUCCESS | 成功 | {"success": true} |
| AUTH_FAILED | 认证失败 | {"success": false, "error": "AUTH_FAILED"} |
| INVALID_PARAM | 参数错误 | {"success": false, "error": "INVALID_PARAM", "field": "cost"} |
| NOT_FOUND | 资源不存在 | {"success": false, "error": "NOT_FOUND", "resource": "plan"} |
| FORBIDDEN | 权限不足 | {"success": false, "error": "FORBIDDEN"} |
| DISABLED_FOR_USER | 用户不可用此功能 | {"success": false, "error": "DISABLED_FOR_USER", "reason": "禁忌人群"} |
| COMPLIANCE_VIOLATION | 合规违规 | {"success": false, "error": "COMPLIANCE_VIOLATION"} |

### 附录 B：开发顺序建议

| 优先级 | 何丽（后端） | 张正宏（前端+Agent） |
|--------|-------------|---------------------|
| P0 | 数据库表 DDL + 迁移 | 页面 wireframe + mock 数据 |
| P0 | 消费统计 API | 消费统计 UI |
| P0 | 虚拟宠物 API | 宠物动画组件 |
| P0 | AI 顾问设置 API | advisor_style_prompt_manager |
| P0 | 轻断食 API | fasting_advisor_skill |
| P1 | 预算预警逻辑 | 宠物详情页 |
| P1 | 复食指导接口 | 断食打卡页 |
| P2 | 硬件同步优化 | 宠物动画优化 |

### 附录 C：技术栈版本确认

| 技术 | 版本 | 状态 |
|------|------|------|
| Flutter | 3.22+ | 已安装 |
| Dart | 3.4+ | 已安装 |
| FastAPI | 0.111+ | 已部署 |
| PostgreSQL | 14+ | 已部署 |
| Redis | 7+ | 已部署 |
| MinIO | RELEASE.2024+ | 已部署 |
| DeepSeek API | v1 | 待配置 |
| ESP32-S3 | ESP-IDF 5.2+ | 已烧录 |
| ESP32-CAM | Arduino 2.0.14+ | 已烧录 |

---

**文档结束**