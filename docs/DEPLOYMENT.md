# DietAI 后端部署文档

> 适用版本: Milestone 1+ | 最后更新: 2026-06-05

---

## 1. 环境要求

| 组件 | 版本要求 | 用途 |
|------|---------|------|
| Python | 3.12+ | 运行后端服务 |
| PostgreSQL | 15+ | 主数据库 |
| Redis | 7+ | 缓存 & 会话 |
| MinIO | latest | 对象存储（食物图片） |

**可选组件：**
- Nginx（生产环境反向代理）
- LangGraph Server (AI 功能，端口 2024)

---

## 2. 依赖安装

```bash
# 安装 uv（如未安装）
pip install uv

# 安装项目依赖
cd DietAI
uv sync

# 可选：安装压力测试工具
pip install locust
```

---

## 3. 数据库初始化

### 3.1 启动 PostgreSQL

```bash
# Docker 方式（推荐）
docker-compose up -d postgres redis minio

# 或手动启动本机 PostgreSQL
```

### 3.2 创建数据库

```sql
-- 连接 PostgreSQL 后执行
CREATE DATABASE dietai_db;
```

### 3.3 执行迁移

```bash
# 应用所有迁移到最新版本
alembic upgrade head

# 查看当前迁移状态
alembic current

# 查看迁移历史
alembic history
```

> **注意**: 第 1 周迁移（e6a322b5c6ba）创建 exercise_records、water_intake_records、reminders 等表。
> 第 4 周迁移（b4c3）添加性能优化索引。执行 `alembic upgrade head` 会自动应用两者。

---

## 4. 养生知识数据初始化

```bash
# 初始化 24 节气 + 四季 + 9 种体质饮食知识到 wellness_knowledge 表
python scripts/init_wellness_data.py
```

此脚本会插入约 40 条养生知识数据，供 `/api/wellness/tips` 和养生推荐接口使用。

---

## 5. 环境变量配置

复制模板文件并编辑：

```bash
cp .env.dev.example .env.dev
```

`.env.dev` 必需变量（`DIETAI_` 前缀）：

```bash
# ===== 数据库 =====
DIETAI_DATABASE_URL=postgresql://postgres:123456@localhost:5432/dietai_db

# ===== Redis =====
DIETAI_REDIS_HOST=localhost
DIETAI_REDIS_PORT=6379
DIETAI_REDIS_PASSWORD=          # 无密码则留空
DIETAI_REDIS_DB=5

# ===== MinIO 对象存储 =====
DIETAI_MINIO_ENDPOINT=localhost:9000
DIETAI_MINIO_ACCESS_KEY=minioadmin
DIETAI_MINIO_SECRET_KEY=minioadmin
DIETAI_MINIO_SECURE=false

# ===== JWT 安全（生产环境务必修改）=====
DIETAI_JWT_SECRET_KEY=<生成一个随机 64 字符密钥>
DIETAI_JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30

# ===== AI 服务（可选）=====
DIETAI_AI_SERVICE_ENABLED=false
DIETAI_AI_SERVICE_URL=http://127.0.0.1:2024

# ===== 调试 =====
DIETAI_DEBUG=false               # 生产环境必须为 false
DIETAI_LOG_LEVEL=INFO
```

> **安全提示**:
> - `DIETAI_JWT_SECRET_KEY` 生产环境必须使用强随机密钥
> - `DIETAI_DEBUG` 生产环境必须设为 `false`（否则错误信息可能泄露敏感细节）
> - 不要将 `.env.dev` 提交到 Git 仓库

---

## 6. 启动服务

### 6.1 开发模式

```bash
# 热重载模式（代码改动后自动重启）
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 或指定日志级别
uvicorn main:app --reload --host 0.0.0.0 --port 8000 --log-level debug
```

### 6.2 生产模式

```bash
# 使用 gunicorn + uvicorn workers（Linux）
gunicorn main:app \
  -w 4 \
  -k uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000 \
  --access-logfile logs/access.log \
  --error-logfile logs/error.log

# Windows 直接使用 uvicorn（不支持 gunicorn）
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1
```

### 6.3 Docker Compose（全栈）

```bash
# 启动所有服务（后端 + PostgreSQL + Redis + MinIO）
docker-compose up -d

# 仅启动数据服务
docker-compose up -d postgres redis minio

# 查看日志
docker-compose logs -f dietai-backend

# 停止
docker-compose down
```

### 6.4 AI 服务（LangGraph）

```bash
# 需要单独启动 LangGraph 开发服务器
langgraph dev --port 2024
```

---

## 7. 健康检查

### 7.1 API 健康检查

```bash
# 基础健康检查
curl http://localhost:8000/health

# 期望响应：
# {
#   "status": "healthy",
#   "database": "healthy",
#   "timestamp": "2026-06-05T...",
#   "version": "1.0.0"
# }
```

### 7.2 Swagger 文档

启动后访问：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### 7.3 验证步骤

```bash
# 1. 注册用户
curl -X POST http://localhost:8000/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"test","email":"test@test.com","password":"test123456"}'

# 2. 登录获取 Token
curl -X POST http://localhost:8000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"test","password":"test123456"}'

# 3. 使用 Token 调用 API（替换 <TOKEN>）
curl http://localhost:8000/api/exercises/records \
  -H 'Authorization: Bearer <TOKEN>'

# 4. 验证默认提醒已自动创建
curl http://localhost:8000/api/reminders/ \
  -H 'Authorization: Bearer <TOKEN>'
```

---

## 8. 应用索引优化

```bash
# 执行第 4 周索引迁移
alembic upgrade b4c3

# 验证索引是否生效（连接 PostgreSQL 执行）
psql -U postgres -d dietai_db
```

```sql
-- 查看表上的所有索引
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename IN (
  'exercise_records', 'water_intake_records', 'reminders', 'notification_responses'
)
ORDER BY tablename, indexname;

-- 验证索引被使用
EXPLAIN ANALYZE
SELECT * FROM exercise_records
WHERE user_id = 1 AND record_date = '2026-06-05';
-- 期望看到: Index Scan using idx_exercise_user_date

EXPLAIN ANALYZE
SELECT * FROM reminders
WHERE user_id = 1 AND reminder_type = 'water' AND is_enabled = true AND remind_time = '10:00:00';
-- 期望看到: Index Scan using idx_reminders_user_type_enabled
```

---

## 9. 常见问题排查

### 9.1 数据库连接失败

```
错误: connection refused (postgresql://...)
```

**解决：**
```bash
# 确认 PostgreSQL 已启动
docker-compose ps postgres
# 或
pg_isready -h localhost -p 5432

# 检查 .env.dev 中的 DIETAI_DATABASE_URL 是否正确
# Docker 内部使用服务名: postgresql://dietai:dietai123@postgres:5432/dietai_db
# 本机开发使用: postgresql://postgres:123456@localhost:5432/dietai_db
```

### 9.2 端口冲突

```
错误: [Errno 10048] address already in use
```

**解决：**
```bash
# Windows 查看端口占用
netstat -ano | findstr :8000
# 终止进程
taskkill /PID <PID> /F

# 或修改 .env.dev 中的 DIETAI_PORT
DIETAI_PORT=8001
```

### 9.3 AI 服务不可用

```
日志: Failed to connect to AI service at http://127.0.0.1:2024
```

**解决：**
- 确认 `DIETAI_AI_SERVICE_ENABLED=true`
- 确认 LangGraph 服务已启动: `langgraph dev --port 2024`
- 养生推荐接口会自动回退到数据库知识库，不影响基本功能

### 9.4 MinIO 图片上传失败

```
错误: Failed to upload to MinIO
```

**解决：**
```bash
# 确认 MinIO 已启动
docker-compose ps minio

# 检查 Bucket 是否存在（MinIO Console: http://localhost:9001）
# 用户: minioadmin / minioadmin
# 手动创建 bucket: dietai-bucket
```

### 9.5 Alembic 迁移冲突

```
错误: Multiple head revisions are present
```

**解决：**
```bash
# 查看当前状态
alembic heads
alembic branches

# 合并多个 head
alembic merge <head1> <head2> -m "merge heads"

# 或强制标记为最新
alembic stamp head
```

### 9.6 Redis 连接失败

```
日志: Error connecting to Redis
```

**解决：**
- 确认 Redis 已启动: `docker-compose ps redis`
- 检查 Redis 密码配置（如设置了密码）
- Redis 连接失败不影响核心 API，但缓存功能不可用

### 9.7 限流触发 429

```
响应: 429 Too Many Requests — "请求过于频繁，请稍后重试"
```

**说明：**
- 全局默认限制: 每 IP 每分钟 120 次读 / 30 次写
- 这是安全保护机制，正常使用不会触发
- 如需调整，修改 `shared/middleware/rate_limiter.py` 中的常量

---

## 10. 目录结构速查

```
DietAI/
├── main.py                  # FastAPI 入口
├── alembic/                 # 数据库迁移
│   └── versions/            # 迁移脚本
├── routers/                 # API 路由（14 个模块）
├── shared/
│   ├── config/              # 配置（Settings、Redis、MinIO）
│   ├── models/              # SQLAlchemy ORM + Pydantic Schema
│   ├── services/            # 业务逻辑服务层
│   ├── middleware/           # 中间件（限流等）
│   ├── tasks/               # 定时任务（APScheduler）
│   └── utils/               # 工具函数（Auth、营养计算）
├── agent/                   # AI Agent 代码
├── scripts/                 # 工具脚本
├── tests/                   # 测试代码
│   └── load_test/           # 压力测试
├── docker-compose.yml       # Docker 编排
├── Dockerfile               # 容器镜像
└── .env.dev                 # 环境变量配置
```
