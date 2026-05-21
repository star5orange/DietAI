# DietAI - 智能饮食健康管理系统

基于多模态 AI 的饮食健康管理系统。用户拍照上传食物图片，AI 自动识别食物种类、分析营养成分，并结合个人健康档案提供个性化饮食建议。

## 功能概览

- **AI 食物识别** - 上传食物图片，自动识别种类并分析卡路里、蛋白质、碳水、脂肪、维生素等营养成分
- **智能营养顾问** - 对话式 AI 助手，根据用户健康档案和饮食记录给出个性化饮食建议
- **饮食记录追踪** - 按餐次（早/午/晚/加餐）记录饮食，生成每日/每周/每月营养摄入统计
- **健康目标管理** - 支持减重、增肌、减脂等目标的设定与进度追踪
- **营养知识检索** - 基于 RAG 的营养知识库，为 AI 分析提供专业知识支撑

## 技术架构

```
┌──────────────────────────────────────────────────┐
│        Flutter 移动端 (Android / iOS / Web)       │
│           Riverpod + Go Router + Dio              │
└──────────────────────┬───────────────────────────┘
                       │  HTTP/SSE
                       ▼
┌──────────────────────────────────────────────────┐
│             FastAPI 后端 (:8000)                   │
│                                                    │
│  /api/auth    用户注册、登录、JWT 认证              │
│  /api/foods   食物记录 CRUD、图片上传、营养分析      │
│  /api/health  每日营养统计、健康评分                 │
│  /api/goals   健康目标设定与追踪                    │
│  /api/chat    AI 营养顾问对话                       │
└───────┬──────────┬──────────┬────────────────────┘
        │          │          │
        ▼          ▼          ▼
┌────────────┐ ┌────────┐ ┌────────────┐
│ PostgreSQL │ │ Redis  │ │   MinIO    │
│  (:5432)   │ │(:6379) │ │(:9000/9001)│
│  主数据库   │ │ 缓存   │ │ 图片存储   │
└────────────┘ └────────┘ └────────────┘
        │
        │  LangGraph SDK (HTTP)
        ▼
┌──────────────────────────────────────────────────┐
│          LangGraph Agent 服务 (:2024)             │
│                                                    │
│  nutrition_agent ─ 图片识别 → 营养提取 → 建议生成   │
│  chat_agent ─ 上下文分析 → 对话回复                 │
│  goal_tracking_agent ─ 目标追踪                    │
│                                                    │
│  ChromaDB (向量知识库)    LLM (OpenAI/通义千问)     │
└──────────────────────────────────────────────────┘
```

## 项目结构

```
DietAI/
├── main.py                       # FastAPI 应用入口
├── langgraph.json                # LangGraph Agent 图定义（注册了 4 个 Agent）
├── pyproject.toml                # Python 依赖（uv 管理）
├── docker-compose.yml            # Docker 服务编排
├── Dockerfile                    # 后端容器镜像
├── .env.example                  # 环境变量模板
│
├── agents/                       # --- LangGraph AI Agent ---
│   ├── nutrition_agent/
│   │   ├── agent.py              # 核心: nutrition_agent 图定义
│   │   └── utils/                # nutrition_agent 节点/状态/提示词/结构体
│   │       ├── nodes.py          #   nutrition_agent 各节点实现
│   │       ├── states.py         #   nutrition_agent 状态定义
│   │       ├── prompts.py        #   所有提示词模板
│   │       └── sturcts.py        #   响应结构体 (NutritionAnalysis 等)
│   ├── chat_agent/
│   │   ├── chat_agent.py         # 核心: chat_agent 图定义
│   │   ├── utils/                # chat_agent 节点/状态/提示词
│   │   │   ├── chat_nodes.py     #   chat_agent 各节点实现
│   │   │   └── chat_states.py    #   chat_agent 状态定义
│   │   ├── enhanced_nutrition/   # 增强营养分析 Agent
│   │   ├── goal_tracking/        # 目标追踪 Agent
│   │   ├── diet_deep_agent/      # Deep Agents SDK Agent
│   │   └── memory/              # 用户记忆管理（长期偏好记录）
│   ├── common_utils/             # 公共工具: 图片处理、模型调用、RAG 检索、Redis、配置
│   │   └── configuration.py      #   模型配置 (provider/model 切换)
│   └── VectorStore/              # ChromaDB 持久化数据（营养知识向量库）
│
├── routers/                      # --- FastAPI 路由 ---
│   ├── auth_router.py            # POST /api/auth/register, /api/auth/login
│   ├── user_router.py            # GET/PUT /api/users/profile
│   ├── food_router.py            # POST /api/foods (SSE 流式分析), GET /api/foods
│   ├── health_router.py          # GET /api/health/nutrition/summary
│   ├── goal_router.py            # /api/goals CRUD
│   ├── chat_router.py            # POST /api/chat/message
│   └── analysis_chat_router.py   # 分析结果页内的追问对话
│
├── shared/                       # --- 共享模块 ---
│   ├── config/
│   │   ├── settings.py           # 全局配置 (Pydantic Settings, DIETAI_ 前缀)
│   │   ├── redis_config.py       # Redis 连接管理 + CacheService
│   │   └── minio_config.py       # MinIO 连接管理 + 文件上传下载
│   ├── models/
│   │   ├── user_models.py        # User, UserProfile, UserHealthGoal, UserAllergy...
│   │   ├── food_models.py        # FoodRecord, NutritionDetail, DailyNutritionSummary
│   │   ├── conversation_models.py# ConversationSession, ConversationMessage
│   │   ├── schemas.py            # Pydantic 请求/响应 Schema
│   │   └── database.py           # SQLAlchemy engine + session
│   ├── services/                 # Agent 编排服务
│   ├── tasks/                    # 后台定时任务
│   └── utils/
│       ├── auth.py               # JWT 生成/验证、密码哈希
│       └── nutrition_calc.py     # 营养计算工具
│
├── frontend_flutter/             # --- Flutter 前端 ---
│   ├── lib/                      # Dart 源码
│   ├── pubspec.yaml              # Flutter 依赖
│   └── ...
│
├── infrastructure/
│   └── docker/init.sql           # PostgreSQL 初始化 SQL（建表 + 测试数据）
│
├── bats/                         # Windows 本地启动脚本
│   ├── postgresql_start.bat      # 启动本地 PostgreSQL
│   └── minio_start.bat           # 启动本地 MinIO
│
└── vector_init.py                # 向量知识库初始化脚本（读取文档 → ChromaDB）
```

## 环境搭建

> 本节指导你从零搭建完整的开发环境。如果已安装某项工具可跳过对应步骤。

### 前置工具安装

#### 1. Python 3.12

项目指定 Python 3.12（见 `.python-version`）。

- Windows: 从 [python.org](https://www.python.org/downloads/) 下载安装，安装时勾选 "Add to PATH"
- macOS: `brew install python@3.12`
- 验证: `python --version` 应输出 `3.12.x`

#### 2. uv (Python 包管理器)

项目使用 [uv](https://docs.astral.sh/uv/) 管理 Python 依赖，替代 pip/poetry。

```bash
# Windows (PowerShell)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# macOS / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# 验证
uv --version
```

#### 3. Docker Desktop

用于运行 PostgreSQL、Redis、MinIO 三个基础设施服务。

- Windows / macOS: 从 [docker.com](https://www.docker.com/products/docker-desktop/) 下载安装 Docker Desktop
- 安装后确保 Docker 正在运行: `docker --version && docker compose version`

> 如果你不想用 Docker，也可以本地安装这三个服务（见下方"不使用 Docker"章节）。

#### 4. Flutter 3.x (前端开发者需要)

仅负责前端开发的同学需要安装。

- 安装指南: [flutter.dev/docs/get-started/install](https://docs.flutter.dev/get-started/install)
- 验证: `flutter doctor`

#### 5. AI 模型 API Key

至少需要一个 LLM 服务的 API Key，用于食物识别和营养分析：

| 提供商 | 环境变量 | 获取地址 | 说明 |
|--------|----------|----------|------|
| OpenAI (推荐) | `OPENAI_API_KEY` | [platform.openai.com](https://platform.openai.com/api-keys) | 支持 GPT-4 Vision 图片识别 |
| 阿里通义千问 | `DASHSCOPE_API_KEY` | [dashscope.console.aliyun.com](https://dashscope.console.aliyun.com/) | 支持 qwen-vl 视觉模型 |
| Anthropic | `ANTHROPIC_API_KEY` | [console.anthropic.com](https://console.anthropic.com/) | Claude 系列模型 |

### 快速启动（5 步）

#### Step 1: 克隆项目

```bash
git clone https://github.com/beihaizzz/DietAI.git
cd DietAI
```

#### Step 2: 配置环境变量

```bash
# 复制模板（.env 供 LangGraph Agent 使用）
cp .env.example .env
```

编辑 `.env`，填入你的 API Key：

```bash
# 至少填一个
OPENAI_API_KEY=sk-your-key-here
# DASHSCOPE_API_KEY=your-key-here
# ANTHROPIC_API_KEY=your-key-here
```

后端服务读取 `.env.dev` 文件，环境变量前缀为 `DIETAI_`。**所有配置项都有默认值**（见 `shared/config/settings.py`），如果你使用 Docker 启动基础设施且端口未冲突，无需创建 `.env.dev`。

如需覆盖默认值（比如数据库密码不同），创建 `.env.dev`：

```bash
# 数据库（默认: postgresql://postgres:123456@localhost:5432/dietai_db）
DIETAI_DATABASE_URL=postgresql://postgres:yourpass@localhost:5432/dietai_db

# Redis（默认: localhost:6379, 密码 123456, db 5）
DIETAI_REDIS_HOST=localhost
DIETAI_REDIS_PASSWORD=123456

# MinIO（默认: localhost:9090, admin/admin123456）
DIETAI_MINIO_ENDPOINT=localhost:9090
DIETAI_MINIO_ACCESS_KEY=admin
DIETAI_MINIO_SECRET_KEY=admin123456

# Agent 服务地址（默认: http://127.0.0.1:2024）
DIETAI_AI_SERVICE_URL=http://127.0.0.1:2024
```

#### Step 3: 启动基础设施

```bash
# 启动 PostgreSQL + Redis + MinIO
docker compose up -d postgres redis minio

# 确认三个容器都是 running 状态
docker compose ps
```

容器启动后，PostgreSQL 会自动执行 `infrastructure/docker/init.sql` 完成建表和测试数据初始化。

> Docker 方式的默认账号：
> - PostgreSQL: `dietai` / `dietai123`，数据库 `dietai_db`，端口 `5432`
> - Redis: 无密码，端口 `6379`
> - MinIO: `minioadmin` / `minioadmin`，API 端口 `9000`，控制台 `9001`
>
> 注意：Docker 中的 PostgreSQL/Redis 配置与后端 `settings.py` 中的默认值不完全一致（Docker 用 `dietai/dietai123`，settings 默认 `postgres/123456`）。如果用 Docker，请创建 `.env.dev` 并设置：
> ```
> DIETAI_DATABASE_URL=postgresql://dietai:dietai123@localhost:5432/dietai_db
> DIETAI_REDIS_PASSWORD=
> ```

#### Step 4: 启动后端 + Agent

打开两个终端：

**终端 1 - FastAPI 后端：**
```bash
# 安装依赖（首次）
uv sync

# 启动后端（--reload 开启热重载）
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**终端 2 - LangGraph Agent 服务：**
```bash
uv run langgraph dev --port 2024
```

#### Step 5: 验证

```bash
# 后端健康检查
curl http://localhost:8000/health
# 期望返回: {"status":"healthy","database":"healthy",...}
```

- Swagger API 文档: http://localhost:8000/docs
- ReDoc 文档: http://localhost:8000/redoc
- MinIO 控制台: http://localhost:9001 (`minioadmin` / `minioadmin`)

### 不使用 Docker（本地安装服务）

如果不使用 Docker，需要自行安装以下服务：

**PostgreSQL 15+**
- 下载: [postgresql.org/download](https://www.postgresql.org/download/)
- 安装后创建数据库: `createdb dietai_db`
- 手动执行建表脚本: `psql -d dietai_db -f infrastructure/docker/init.sql`
- 项目中也提供了 Windows 启动脚本: `bats/postgresql_start.bat`（需修改路径）

**Redis 7+**
- Windows: 从 [github.com/tporadowski/redis/releases](https://github.com/tporadowski/redis/releases) 下载
- macOS: `brew install redis && brew services start redis`
- 默认端口 6379

**MinIO**
- 下载: [min.io/download](https://min.io/download)
- 启动: `minio server /path/to/data --console-address ":9001"`
- 项目中提供了 Windows 启动脚本: `bats/minio_start.bat`（需修改路径）

确保在 `.env.dev` 中将各服务的地址、端口、密码配置正确。

## 开发指引

### 后端开发流程

1. **启动依赖服务** - `docker compose up -d postgres redis minio`
2. **启动后端** - `uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000`
3. **修改代码** - `--reload` 会自动重启
4. **查看 API 文档** - http://localhost:8000/docs 可直接在页面测试接口

#### 添加新接口

1. 在 `routers/` 下创建或修改路由文件
2. 在 `shared/models/` 中定义数据模型（SQLAlchemy ORM）
3. 在 `shared/models/schemas.py` 中定义请求/响应 Schema（Pydantic）
4. 在 `main.py` 中注册路由: `app.include_router(your_router, prefix="/api", tags=["标签"])`
5. 生成数据库迁移: `uv run alembic revision --autogenerate -m "add xxx table"`
6. 执行迁移: `uv run alembic upgrade head`

#### 数据库模型关系

```
users ──1:1── user_profiles          用户基本信息 + 详细档案
  │──1:N── user_health_goals         健康目标
  │──1:N── user_diseases             疾病信息
  │──1:N── user_allergies            过敏信息
  │──1:1── user_preferences          偏好设置
  │──1:N── food_records ──1:1── nutrition_details   食物记录 + 营养详情
  │──1:N── daily_nutrition_summary   每日营养汇总
  │──1:N── weight_records            体重记录
  │──1:N── conversation_sessions ──1:N── conversation_messages  对话
  └──1:N── user_memory_contexts      AI 长期记忆
```

### Agent 开发流程

1. **启动 Agent** - `uv run langgraph dev --port 2024`
2. **访问 LangGraph Studio** - Agent 启动后会打印 Studio 地址，可在浏览器中可视化调试图的执行过程
3. **修改 Agent** - 修改 `agents/` 下的代码后 Agent 服务会自动重载

#### Agent 工作流 (nutrition_agent)

```
state_init → analyze_image → extract_nutrition → retrieve_nutrition_knowledge
    → generate_dependencies → generate_advice → format_response
```

每个节点对应 `agents/nutrition_agent/utils/nodes.py` 中的一个函数。状态定义在 `agents/nutrition_agent/utils/states.py`，提示词在 `agents/nutrition_agent/utils/prompts.py`。

#### 切换 AI 模型

模型配置在 `agents/common_utils/configuration.py` 中，默认使用通义千问。可通过调用时传入 `configurable` 参数切换：

```python
# 通过 LangGraph SDK 调用时指定模型
config = {
    "configurable": {
        "vision_model_provider": "openai",   # openai / qwen
        "vision_model": "gpt-4o",
        "analysis_model_provider": "openai",
        "analysis_model": "gpt-4o"
    }
}
```

也可通过环境变量全局覆盖：`VISION_MODEL_PROVIDER=openai`

#### 更新向量知识库

营养知识库存储在 `agents/VectorStore/`（已提交到仓库）。如需更新：

1. 编辑 `docs/Knowledge/nutrition_knowledge.txt`（本地 docs 目录不会提交）
2. 运行 `uv run python vector_init.py` 重新生成向量数据
3. 需要 `OPENAI_API_KEY`（使用 OpenAI Embeddings）

### 前端开发流程

1. **安装依赖** - `cd frontend_flutter && flutter pub get`
2. **代码生成** - `dart run build_runner build --delete-conflicting-outputs`
3. **启动应用** - `flutter run -d chrome`（Web）或 `flutter run -d windows`（桌面）
4. **配置后端地址** - 编辑 `frontend_flutter/lib/config/` 中的 API 地址，默认 `http://localhost:8000/api`

### 全部服务端口汇总

| 服务 | 端口 | 说明 |
|------|------|------|
| FastAPI 后端 | 8000 | REST API + Swagger 文档 |
| LangGraph Agent | 2024 | AI Agent 服务 + Studio |
| PostgreSQL | 5432 | 关系型数据库 |
| Redis | 6379 | 缓存（db 5） |
| MinIO API | 9000 | 对象存储 S3 兼容 API |
| MinIO Console | 9001 | 对象存储 Web 管理界面 |

## 常用命令速查

```bash
# ---- 后端 ----
uv sync                                                        # 安装/更新依赖
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000   # 启动开发服务器
uv run alembic revision --autogenerate -m "描述"                # 生成迁移
uv run alembic upgrade head                                     # 执行迁移
uv run alembic downgrade -1                                     # 回滚一次迁移
uv run pytest                                                   # 运行测试
uv run pytest --cov=. --cov-report=html                        # 测试 + 覆盖率报告

# ---- Agent ----
uv run langgraph dev --port 2024                                # 启动 Agent 服务
uv run python vector_init.py                                    # 重建向量知识库

# ---- 前端 ----
cd frontend_flutter
flutter pub get                                                 # 安装依赖
dart run build_runner build --delete-conflicting-outputs        # 代码生成
flutter run -d chrome                                           # 运行 (Web)
flutter run -d windows                                          # 运行 (Windows)
flutter test                                                    # 测试

# ---- Docker ----
docker compose up -d postgres redis minio                       # 启动基础设施
docker compose ps                                               # 查看状态
docker compose logs -f postgres                                 # 查看日志
docker compose down                                             # 停止
docker compose down -v                                          # 停止并删除数据卷
```

## 常见问题

**Q: `uv sync` 失败？**

确认 Python 版本为 3.12。运行 `python --version` 检查。如果系统有多个 Python 版本，uv 会自动根据 `.python-version` 文件选择。

**Q: 后端启动报数据库连接错误？**

1. 确认 PostgreSQL 容器在运行: `docker compose ps postgres`
2. 确认 `.env.dev` 中的 `DIETAI_DATABASE_URL` 与实际数据库账号一致
3. Docker 默认用户是 `dietai/dietai123`，非 Docker 默认是 `postgres/123456`

**Q: AI 分析功能不可用？**

1. 确认 LangGraph Agent 服务已启动: `curl http://localhost:2024`
2. 确认 `.env` 中填写了有效的 API Key
3. 确认网络能访问对应的 AI 服务（需能访问 api.openai.com 或 dashscope.aliyuncs.com）

**Q: MinIO 图片上传失败？**

1. 访问 http://localhost:9001 检查 MinIO 控制台是否正常
2. 确认 `.env.dev` 中的 MinIO endpoint/key 配置正确
3. Docker 默认 `minioadmin/minioadmin`，端口 9000；settings.py 默认 `admin/admin123456`，端口 9090 - 请确保一致

**Q: Redis 连接失败？**

确认 Redis 服务运行中且密码配置一致。Docker 方式无密码，settings.py 默认密码 `123456`。

## 许可证

本项目仅供学习与比赛评审使用，未经授权不得用于商业用途。
