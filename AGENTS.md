# DietAI — Agent Working Guide

## Project Directory Structure

```
DietAI/
├── main.py                     → FastAPI entry, middleware, all routers at /api/*
├── vector_init.py              → One-time ChromaDB vector store init
├── agent/                      → AI Agent core (LangGraph)
│   ├── agent.py                → Top-level agent entry
│   ├── chat_agent.py           → chat_agent graph entry
│   ├── test_agent.py           → test_agent graph
│   ├── common_utils/           → Shared utilities (image, model, rag, redis, configuration)
│   ├── diet_deep_agent/        → Deep Agents SDK agent (qwen3.5-plus)
│   │   ├── deep_agent.py
│   │   ├── prompts.py
│   │   ├── config.py
│   │   ├── memory/             → md_checkpointer, md_store, backend, namespaces
│   │   ├── skills/             → conversation, diet_planning, health_assessment, etc.
│   │   ├── subagents/          → definitions
│   │   └── tools/              → food_analysis, goal_tracking, memory_tools, etc.
│   ├── enhanced_nutrition/     → enhanced_nutrition_agent
│   ├── goal_tracking/          → goal_tracking_agent
│   ├── memory/                 → memory_manager, schemas, sync_service, markdown_renderer
│   ├── nutrition_agent/        → nutrition_agent graph entry
│   │   ├── agent.py
│   │   └── utils/              → nodes, states, structs, tools, prompts
│   ├── utils/                  → Shared agent utils (nodes, states, structs, tools, prompts, chat_nodes, chat_states)
│   ├── UserMemory/             → Per-user memory files (gitignored)
│   └── VectorStore/            → ChromaDB persistence (gitignored)
├── routers/                    → All API route handlers (unified)
│   ├── auth_router.py          → /api/auth
│   ├── user_router.py          → /api/users
│   ├── food_router.py          → /api/foods
│   ├── health_router.py        → /api/health
│   ├── chat_router.py          → /api/chat (AI conversation)
│   ├── analysis_chat_router.py → /api/analysis-chat
│   ├── goal_router.py          → /api/goals
│   ├── deep_router.py          → /api/deep (DietDeepAgent)
│   ├── saved_meals_router.py   → /api/saved-meals
│   ├── exercise_router.py      → /api/exercises
│   ├── water_router.py         → /api/water
│   ├── reminder_router.py      → /api/reminders
│   ├── notification_router.py  → /api/notifications
│   └── wellness_router.py      → /api/wellness
├── shared/                     → Backend shared code
│   ├── config/                 → settings.py (DIETAI_ env prefix), redis_config, minio_config
│   ├── models/                 → SQLAlchemy models + Pydantic schemas
│   │   ├── database.py         → engine, SessionLocal, get_db
│   │   ├── schemas/            → Pydantic schemas (base, user, food, chat, health, agent, exercise, water, etc.)
│   │   ├── user_models.py
│   │   ├── food_models.py
│   │   ├── conversation_models.py
│   │   ├── saved_meal_models.py
│   │   ├── exercise_models.py
│   │   ├── water_models.py
│   │   ├── reminder_models.py
│   │   ├── notification_models.py
│   │   └── wellness_models.py
│   ├── services/               → Business logic services
│   ├── tasks/                  → Background scheduler, memory_events
│   └── utils/                  → auth, model, nutrition_calc
├── alembic/                    → Database migrations
├── scripts/                    → Utility scripts
│   ├── init_wellness_data.py
│   └── bats/                   → Windows service start scripts
├── docs/                       → Project documentation
│   └── 需求文档/               → Requirements docs
├── frontend_flutter/           → Flutter mobile app
│   └── lib/
│       ├── main.dart
│       ├── core/               → cache, constants, router, services, themes, utils
│       ├── features/           → Feature modules (auth, camera, chat, health, history, home, onboarding, pet, profile, saved_meals)
│       ├── services/           → Shared API services (food, chat, exercise, health, etc.)
│       └── shared/             → Shared models, widgets, pages
├── AGENTS.md                   → This file
├── CLAUDE.md                   → Claude Code guide
├── .env.example                → Environment variable template
├── docker-compose.yml
├── Dockerfile
└── alembic.ini
```

## Environment & Config

- Config loads from `.env.dev` (not `.env`) via `pydantic-settings` with `DIETAI_` prefix (`shared/config/settings.py`).
- `.env` is gitignored; `.env.example` documents available vars. Copy `.env.example` → `.env.dev` for local dev.
- Default credentials in `settings.py` are local dev values (Redis password `123456`, MinIO `admin/admin123456` on port `9090`). Docker Compose uses different defaults (`minioadmin/minioadmin` on port `9000`).

## Required Services

Backend requires 3 external services running before `uvicorn`:

| Service | Default Port | Purpose |
|---------|-------------|---------|
| PostgreSQL | 5432 | Primary database |
| Redis | 6379 | Cache for nutrition summaries & RAG results |
| MinIO | 9000 (API) / 9001 (Console) | Food image storage |

Start locally: `docker-compose up -d postgres redis minio`
Windows local services: `scripts/bats/minio_start.bat`, `scripts/bats/postgresql_start.bat`

LangGraph dev server must run separately: `langgraph dev --port 2024`

## Run Commands

```bash
# Backend
uv sync                                           # install deps (uses uv, not pip)
uvicorn main:app --reload --host 0.0.0.0 --port 8000  # dev server

# LangGraph agent service
langgraph dev --port 2024

# Vector store initialization (one-time, before first agent use)
python vector_init.py

# Flutter frontend
cd frontend_flutter
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # codegen before run
flutter run -d windows   # or -d chrome
```

## LangGraph Graphs (defined in langgraph.json)

| Graph Name | Entry File | Flow |
|------------|-------------|------|
| `nutrition_agent` | `agent/nutrition_agent/agent.py:graph` | state_init → analyze_image → extract_nutrition → retrieve_knowledge → generate_deps → generate_advice → format_response |
| `enhanced_nutrition_agent` | `agent/enhanced_nutrition/enhanced_agent.py` | Enhanced nutrition analysis |
| `chat_agent` | `agent/chat_agent.py:chat_graph` | initialize_chat → analyze_context → generate_response → format_response |
| `goal_tracking_agent` | `agent/goal_tracking/goal_agent.py` | Nutrition goals |
| `diet_deep_agent` | `agent/diet_deep_agent/deep_agent.py:agent` | Deep Agents SDK, DashScope qwen3.5-plus |
| `test_agent` | `agent/test_agent.py:test_graph` | Validation test graph |

Agent model config passed via LangGraph SDK: `{"configurable": {"vision_model_provider": "openai", "vision_model": "gpt-4.1-nano-2025-04-14", "analysis_model_provider": "openai", "analysis_model": "o3-mini-2025-01-31"}}`

## Shared Models Import Convention

Pydantic schemas live in `shared/models/schemas/` package. Import as `from shared.models.schemas.xxx import ...`. Database models go in `user_models.py`, `food_models.py`, `conversation_models.py`, `saved_meal_models.py`, etc. Register new models in `shared/models/__init__.py`.

## Test Infrastructure

No `tests/` directory or `pytest.ini` configured. Tests listed in `pyproject.toml` deps (`pytest`, `pytest-asyncio`, `pytest-cov`) but no test suite exists yet.
