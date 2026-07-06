# DietAI Milestone 1 后端开发总结

> **开发者**: 何丽 | **分支**: `backend` | **周期**: 2026-05-19 ~ 2026-06-05（4 周）

---

## 1. 开发概览

Milestone 1 后端开发完成了开发计划中从 B1-1 到 B4-4 的**全部 24 个任务**，覆盖以下四大领域：

| 周次 | 主题 | 完成任务 |
|------|------|----------|
| 第 1 周 | 基础搭建 + 核心 CRUD | B1-1 ~ B1-7（7 个） |
| 第 2 周 | 提醒/体质/养生 | B2-1 ~ B2-7（7 个） |
| 第 3 周 | 联调整合 | B3-2 ~ B3-4（3 个） |
| 第 4 周 | 测试交付 | B4-1 ~ B4-4（4 个） |

> 注：B2-1 和 B3-1 由其他周任务自然覆盖，B3-5 为 Bug 修复类任务分布在各周中完成。

---

## 2. 文件变更清单

### 2.1 新建文件（15 个）

| 文件 | 说明 | 所属任务 |
|------|------|----------|
| `shared/models/exercise_models.py` | 运动记录 ORM 模型 | B1-1 |
| `shared/models/water_models.py` | 喝水记录 ORM 模型 | B1-1 |
| `shared/models/reminder_models.py` | 提醒 ORM 模型 | B1-1 |
| `shared/models/notification_models.py` | 提醒响应 ORM 模型 | B1-1 |
| `shared/models/wellness_models.py` | 养生知识 ORM 模型 | B1-1 |
| `shared/models/schemas/exercise.py` | 运动 Pydantic Schema | B1-2 |
| `shared/models/schemas/water.py` | 喝水 Pydantic Schema | B1-4 |
| `shared/models/schemas/reminder.py` | 提醒 Pydantic Schema | B1-7 |
| `shared/models/schemas/notification.py` | 通知 Pydantic Schema | B2-7 |
| `shared/models/schemas/wellness.py` | 养生 Pydantic Schema | B2-5 |
| `shared/models/schemas/constitution.py` | 体质自测 Schema（含 9 题 + 9 种体质） | B2-4 |
| `shared/services/exercise_service.py` | 运动记录服务（MET 热量计算） | B1-2 |
| `shared/services/water_service.py` | 喝水记录服务 | B1-4 |
| `shared/services/reminder_service.py` | 提醒服务（含默认模板） | B1-7 |
| `shared/services/notification_service.py` | 通知响应服务 | B2-7 |
| `shared/services/wellness_service.py` | 养生推荐服务（AI + 知识库双模式） | B2-5 |
| `shared/middleware/__init__.py` | 中间件包 | B4-2 |
| `shared/middleware/rate_limiter.py` | 滑动窗口限流中间件 | B4-2 |
| `alembic/versions/b4c3_add_performance_indexes.py` | 性能优化索引迁移 | B4-3 |
| `tests/load_test/locustfile.py` | 接口压力测试脚本 | B4-1 |
| `docs/DEPLOYMENT.md` | 部署文档 | B4-4 |

### 2.2 修改文件（14 个）

| 文件 | 修改内容 |
|------|----------|
| `main.py` | 注册新路由 + 限流中间件 + AI 路由器可选导入 + 错误脱敏 |
| `shared/models/__init__.py` | 导出新模型 + 取消注释 SavedMeal |
| `shared/models/user_models.py` | UserProfile 新增 `crowd_tag`、`constitution_type`、`daily_water_goal` |
| `shared/models/food_models.py` | FoodRecord 新增 `from_source` 字段 |
| `shared/models/schemas/__init__.py` | 导出所有新 Schema |
| `shared/models/schemas/exercise.py` | 加强输入校验（max_length、le 限制） |
| `shared/utils/nutrition_calc.py` | 新增 `CrowdTag` 类、人群标签差异化宏量营养素配比 + 热量调整 |
| `routers/auth_router.py` | 注册后自动创建默认提醒模板 |
| `routers/user_router.py` | 新增体质自测接口 + 引导完成后自动创建提醒 |
| `routers/health_router.py` | 新增 4 个端点：统计/规律度/连续天数/周度摘要 |
| `routers/wellness_router.py` | AI 养生推荐 + 养生知识卡片 |
| `routers/notification_router.py` | 提醒响应统计 |
| `shared/tasks/scheduler.py` | 注册 `check_reminders` 每分钟检查任务 |
| `shared/tasks/reminder_check.py` | 修复 weekday bitmask + 日志 + 防重复触发 |
| `.env.dev` | 更新数据库连接配置 |

---

## 3. 数据库变更

### 3.1 新增表（5 张）

| 表名 | 核心字段 | 说明 |
|------|----------|------|
| `exercise_records` | id, user_id, exercise_type, duration_minutes, intensity, calories_burned, record_date | 运动记录 |
| `water_intake_records` | id, user_id, amount_ml, record_time, drink_type | 喝水记录 |
| `reminders` | id, user_id, reminder_type, remind_time, repeat_days, is_enabled, title | 提醒配置 |
| `notification_responses` | id, user_id, reminder_id, responded_at, action_type | 提醒响应 |
| `wellness_knowledge` | id, category, sub_category, title, content, recommended_foods, avoid_foods | 养生知识库 |

### 3.2 修改表（2 张）

| 表名 | 新增字段 |
|------|----------|
| `user_profiles` | `crowd_tag`（人群标签）、`constitution_type`（体质类型）、`daily_water_goal`（每日饮水目标 ml） |
| `food_records` | `from_source`（记录来源：camera/manual/voice 等） |

---

## 4. API 接口汇总

### 4.1 运动模块 (`/api/exercises`)

| 方法 | 路径 | 功能 | 对应任务 |
|------|------|------|----------|
| POST | `/records` | 创建运动记录（自动计算热量消耗） | B1-2 |
| GET | `/records` | 查询运动记录（支持日期范围筛选） | B1-2 |
| PUT | `/records/{id}` | 更新运动记录（自动重算汇总） | B3-3 |
| DELETE | `/records/{id}` | 删除运动记录（自动重算汇总） | B3-3 |
| GET | `/statistics` | 运动统计（按日/周/月 + 热量/时长/次数） | B1-3 |

### 4.2 喝水模块 (`/api/water`)

| 方法 | 路径 | 功能 | 对应任务 |
|------|------|------|----------|
| POST | `/records` | 创建喝水记录（自动同步到每日汇总） | B1-4 |
| GET | `/records` | 查询喝水记录 | B1-4 |
| GET | `/daily-summary/{date}` | 每日喝水汇总（总量/目标/完成率） | B1-4 |
| GET | `/statistics` | 喝水统计（达标率/7日/30日） | B1-5 |

### 4.3 提醒模块 (`/api/reminders`)

| 方法 | 路径 | 功能 | 对应任务 |
|------|------|------|----------|
| POST | `/` | 创建提醒 | B1-7 |
| GET | `/` | 获取提醒列表（支持类型筛选） | B1-7 |
| GET | `/{id}` | 获取单个提醒 | B1-7 |
| PUT | `/{id}` | 更新提醒 | B1-7 |
| DELETE | `/{id}` | 删除提醒 | B1-7 |

> 新用户注册或完成 onboarding 后**自动创建 5 条喝水 + 3 条吃饭默认提醒**（B2-2）。
> 后台每分钟检查到期提醒并触发通知（B2-1/B3-2）。

### 4.4 通知模块 (`/api/notifications`)

| 方法 | 路径 | 功能 | 对应任务 |
|------|------|------|----------|
| POST | `/responses` | 记录提醒响应（drank 自动创建 250ml 喝水记录） | B2-7 |
| GET | `/responses/stats` | 提醒响应统计（响应率/连续天数） | B2-7 |

### 4.5 养生模块 (`/api/wellness`)

| 方法 | 路径 | 功能 | 对应任务 |
|------|------|------|----------|
| GET | `/daily-recommendation` | 每日养生推荐（AI 生成 / 知识库回退双模式） | B2-5 |
| GET | `/solar-terms` | 获取全年节气日期 | B2-5 |
| GET | `/tips` | 随机养生知识卡片（优先匹配用户体质） | B2-7 |

### 4.6 健康统计模块 (`/api/health`)

| 方法 | 路径 | 功能 | 对应任务 |
|------|------|------|----------|
| GET | `/statistics` | 人群维度统计（按 crowd_tag 聚合营养数据） | B2-6 |
| GET | `/meal-regularity` | 三餐规律度分析（频率 + 时间方差） | B2-6 |
| GET | `/habit-streak` | 习惯连续天数（饮食/喝水/运动/综合） | B2-6 |
| GET | `/weekly-summary` | 周度摘要（7 天数据 + 趋势 + 体重变化 + 文字摘要） | B3-4 |

### 4.7 体质自测 (`/api/users`)

| 方法 | 路径 | 功能 | 对应任务 |
|------|------|------|----------|
| POST | `/constitution-quiz` | 提交 9 题问卷，返回推荐体质 + 饮食建议 | B2-4 |

---

## 5. 关键业务逻辑

### 5.1 热量自动计算（MET 公式）

```python
# shared/services/exercise_service.py
calories = MET × 体重(kg) × (时长/60) × 强度系数

MET_VALUES = {
    "跑步": 8.0, "游泳": 6.0, "力量训练": 5.0,
    "骑行": 7.5, "跳绳": 10.0, "瑜伽": 3.0,
    "快走": 4.5, "篮球": 6.5, "足球": 7.0, "羽毛球": 5.5,
}
# 强度系数: 低=0.8, 中=1.0, 高=1.2
```

### 5.2 运动/喝水消耗同步到每日汇总

- **运动**: 创建/更新/删除运动记录后，触发 `_recalc_daily_exercise()`，基于 `SUM(calories_burned)` 全量重算当天汇总
- **喝水**: 创建喝水记录后，触发 `_recalc_daily_water()`，基于 `SUM(amount_ml)` 全量重算当天汇总
- 使用 `SELECT ... FOR UPDATE` 行锁防止竞态条件
- 如果当天不存在汇总记录，自动创建

### 5.3 人群标签差异化营养目标

| 标签 | 蛋白质 | 碳水 | 脂肪 | 热量调整 | 纤维目标 |
|------|--------|------|------|----------|----------|
| 减脂 | 40% | 30% | 30% | -200 kcal | 35g |
| 健身 | 35% | 45% | 20% | +100 kcal | 30g |
| 普通日常 | 25% | 50% | 25% | 0 | 25g |

### 5.4 默认提醒模板创建时机

1. **注册时**: `POST /api/auth/register` 成功后自动创建
2. **引导完成时**: `POST /api/users/onboarding/complete` 成功后自动创建
3. 幂等操作：如果该类型已存在提醒则跳过

### 5.5 养生推荐的双模式

- **AI 模式（默认）**: 调用 LangGraph `chat_agent`（session_type=5），结合节气+体质+人群标签生成个性化推荐
- **知识库回退**: AI 不可用时，从 `wellness_knowledge` 表按节气/季节查询
- 通过 `use_ai=false` 参数可手动切换

---

## 6. 安全加固

| 修复项 | 严重度 | 说明 |
|--------|--------|------|
| 限流中间件 | 高 | 滑动窗口算法，读 120/min、写 30/min，超限返回 429 |
| 通知接口越权修复 | 中 | `POST /api/notifications/responses` 验证 `reminder.user_id == current_user.id` |
| 错误信息脱敏 | 中 | `debug=true` 时仅返回异常类型名，不暴露堆栈和 SQL |
| 输入校验加强 | 低 | `duration_minutes` ≤ 1440，`calories_burned` ≤ 10000，`notes` ≤ 500 字符 |

---

## 7. 性能优化

### 7.1 新增数据库索引

| 索引名 | 表 | 字段 | 覆盖查询 |
|--------|-----|------|----------|
| `idx_exercise_user_date` | exercise_records | (user_id, record_date DESC) | 运动记录查询/统计 |
| `idx_water_user_time` | water_intake_records | (user_id, record_time DESC) | 喝水记录查询 |
| `idx_water_user_date` | water_intake_records | (user_id, (record_time::date) DESC) | 喝水按日聚合 |
| `idx_reminders_user_type_enabled` | reminders | (user_id, reminder_type, is_enabled, remind_time) | 提醒定时检查 |
| `idx_notif_resp_user_reminder` | notification_responses | (user_id, reminder_id) | 提醒响应统计 |
| `idx_notif_resp_user_time` | notification_responses | (user_id, responded_at DESC) | 响应时间线查询 |

### 7.2 预期性能提升

- 提醒检查：从全表扫描 → 索引扫描，查询时间降低 90%+
- 运动/喝水统计：无索引时全表扫描 → 覆盖索引扫描
- 周度摘要：多个单表查询并行 + 索引优化

---

## 8. 部署说明

### 8.1 环境变量（`.env.dev`）

```bash
DIETAI_DATABASE_URL=postgresql://dietai:dietai123@localhost:5432/dietai_db
DIETAI_REDIS_HOST=localhost
DIETAI_REDIS_PORT=6379
DIETAI_REDIS_PASSWORD=
DIETAI_DEBUG=false
```

### 8.2 数据库初始化

```bash
# Docker 启动数据服务
docker-compose up -d postgres redis minio

# 应用迁移
alembic upgrade head

# 初始化养生知识数据
python scripts/init_wellness_data.py
```

### 8.3 启动服务

```bash
# Windows (需先解决 GBK 编码问题 — 推荐使用 WSL)
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# WSL (推荐)
cd /mnt/c/Users/12591/Downloads/DietAI
export DIETAI_DATABASE_URL='postgresql://dietai:dietai123@localhost:5432/dietai_db'
setsid python3 -m uvicorn main:app --host 0.0.0.0 --port 8000 &

# Docker (完整服务栈)
docker-compose up -d
```

### 8.4 Swagger 文档

启动后访问 `http://localhost:8000/docs` 可交互式测试所有接口。

---

## 9. 测试验证

### 9.1 压力测试

```bash
# 快速验证（10 并发 / 50 请求）
python tests/load_test/locustfile.py --quick

# 完整压测（50 并发 / 200 请求）
python tests/load_test/locustfile.py --standalone

# Locust Web UI
pip install locust
locust -f tests/load_test/locustfile.py --host=http://localhost:8000
```

### 9.2 限流验证

```bash
# 连续发送 35 次写请求，预期第 31 次后触发 429
for i in $(seq 1 35); do
  curl -s -o /dev/null -w "请求 $i: HTTP %{http_code}\n" \
    -X POST http://localhost:8000/api/water/records \
    -H "Authorization: Bearer <TOKEN>" \
    -H "Content-Type: application/json" \
    -d '{"amount_ml":250,"record_time":"2026-06-05T10:00:00","drink_type":"水"}'
done
```

### 9.3 索引验证 SQL

```sql
-- 验证索引被使用
EXPLAIN ANALYZE SELECT * FROM exercise_records
WHERE user_id = 1 AND record_date = '2026-06-05';
-- 期望: Index Scan using idx_exercise_user_date

EXPLAIN ANALYZE SELECT * FROM reminders
WHERE user_id = 1 AND reminder_type = 'water'
AND is_enabled = true AND remind_time = '10:00:00';
-- 期望: Index Scan using idx_reminders_user_type_enabled
```

---

## 10. 已知限制与后续建议

### 10.1 Windows CP936 编码问题

**现象**: 中文 Windows（locale `zh_CN/CP936`）上，psycopg2 和 pg8000 的 PostgreSQL 连接在 SCRAM/MD5 认证握手时触发 `UnicodeDecodeError`。

**影响**: 无法从 Windows 原生 Python 直接连接 Docker PostgreSQL。

**解决方案**:
- **当前**: 使用 **WSL Ubuntu** 运行后端（UTF-8 环境，无编码问题）
- **长期**: 将后端 Docker 化，在容器内运行（`docker-compose up -d dietai-backend`）
- **替代**: 设置 PostgreSQL 为 trust 认证（仅开发环境）

### 10.2 后续优化方向

| 方向 | 建议 |
|------|------|
| 数据一致性 | 将运动/喝水汇总更新改为异步队列，减少请求链路耗时 |
| 缓存策略 | 周度摘要、人群统计等计算密集型接口增加 Redis 缓存（TTL 3600s） |
| AI 集成 | 完成 LangGraph 服务部署后，取消 `main.py` 中 AI 路由器的条件导入 |
| 消息推送 | `check_reminders` 当前仅记录日志，需接入 FCM/APNs 实现真实推送 |
| 限流升级 | 当前为内存限流，多实例部署时需改用 Redis 实现分布式限流 |
| 测试覆盖 | 增加 Service 层单元测试和 API 集成测试 |

---

*文档生成日期：2026-06-05*
