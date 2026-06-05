# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Backend Development
```bash
# Install dependencies using uv
uv sync

# Start backend server (development)
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Database migrations
alembic upgrade head                    # Apply migrations
alembic revision --autogenerate -m "message"  # Create new migration

# Run tests
pytest                                  # Run all tests
pytest tests/test_auth.py              # Run specific test file
pytest --cov=. --cov-report=html      # Run with coverage report

# LangGraph CLI (for AI agent development)
langgraph dev --port 2024             # Start LangGraph development server
```

### Frontend Development (Flutter)
```bash
cd frontend_flutter
flutter pub get                        # Install dependencies
dart run build_runner build --delete-conflicting-outputs  # Run code generation
flutter run -d windows                # Run on Windows desktop
flutter run -d chrome                 # Run on web browser
flutter test                          # Run tests
```

### Docker & Infrastructure
```bash
docker-compose up -d postgres redis minio  # Start data services only
docker-compose up -d                       # Start all services
docker-compose logs -f dietai-backend      # View backend logs
```

## High-Level Architecture

### System Overview
DietAI is an AI-powered diet management system with three main components:

1. **LangGraph Agent System** (`agent/`)
   - Six graphs defined in `langgraph.json`:
     - `nutrition_agent` (`agent/nutrition_agent/agent.py`): `state_init` → `analyze_image` → `extract_nutrition` → `retrieve_nutrition_knowledge` → `generate_dependencies` → `generate_advice` → `format_response`
     - `enhanced_nutrition_agent` (`agent/enhanced_nutrition/enhanced_agent.py`): Enhanced version of nutrition analysis
     - `chat_agent` (`agent/chat_agent.py`): `initialize_chat` → `analyze_context` → `generate_response` → `format_chat_response`
     - `goal_tracking_agent` (`agent/goal_tracking/goal_agent.py`): Nutrition goal tracking and progress
     - `diet_deep_agent` (`agent/diet_deep_agent/deep_agent.py`): Deep Agents SDK-based autonomous agent with skills/subagents/tools, LLM: DashScope `qwen3.5-plus`
     - `test_agent` (`agent/test_agent.py`): Test graph for LangGraph service validation
   - RAG integration via ChromaDB vector store for nutrition knowledge retrieval
   - Configurable vision/analysis models via `agent/common_utils/configuration.py`
   - User memory system: MD file-based per-user workspaces at `agent/UserMemory/{user_id}/`

2. **FastAPI Backend** (`main.py`, `routers/`, `shared/`)
   - All routes prefixed with `/api` (e.g., `/api/auth`, `/api/foods`)
   - All routers in `routers/` directory: auth, user, food, health, chat, analysis_chat, goal, deep, saved_meals, exercise, water, reminder, notification, wellness
   - Models in `shared/models/`: `user_models.py`, `food_models.py`, `conversation_models.py`
   - Pydantic schemas in `shared/models/schemas/` package
   - Settings loaded from `.env.dev` with `DIETAI_` prefix

3. **Flutter Mobile App** (`frontend_flutter/`)
   - Riverpod for state management, Go Router for navigation
   - Dio for HTTP client, camera integration for food capture

### Core Data Flow
1. **Image Analysis**: Upload image → MinIO storage → LangGraph nutrition_agent → nutrition data extracted → stored in PostgreSQL with NutritionDetail
2. **Chat**: Message → chat_router/analysis_chat_router → LangGraph chat_agent → response with context
3. **Nutrition Knowledge**: Agent queries ChromaDB vector store (`agent/VectorStore/`) for relevant nutrition documents

### Key Integration Points
- **LangGraph Agent**: SDK client at `http://127.0.0.1:2024`, graphs: `nutrition_agent`, `enhanced_nutrition_agent`, `chat_agent`, `goal_tracking_agent`, `diet_deep_agent`, `test_agent`
- **MinIO**: Food images at `food_images/{user_id}/`, temporary URLs with expiration
- **Redis**: Caching for nutrition summaries and RAG query results
- **ChromaDB**: Vector store for nutrition knowledge RAG at `agent/VectorStore/`

### Environment Configuration
Settings in `shared/config/settings.py` use `DIETAI_` prefix:
- `DIETAI_DATABASE_URL`: PostgreSQL connection
- `DIETAI_REDIS_HOST/PORT/PASSWORD`: Redis config
- `DIETAI_MINIO_ENDPOINT/ACCESS_KEY/SECRET_KEY`: MinIO config
- `DIETAI_AI_SERVICE_URL`: LangGraph service URL (default: `http://127.0.0.1:2024`)

### Agent Model Configuration
When invoking agents via LangGraph SDK:
```python
config={
    "configurable": {
        "vision_model_provider": "openai",  # or "anthropic", "qwen"
        "vision_model": "gpt-4.1-nano-2025-04-14",
        "analysis_model_provider": "openai",
        "analysis_model": "o3-mini-2025-01-31"
    }
}
```

### Structured Output Types
Agent responses use Pydantic models in `agent/utils/structs.py` and `agent/nutrition_agent/utils/structs.py`:
- `NutritionAnalysis`: food_items, total_calories, macronutrients, vitamins_minerals, health_level
- `NutritionAdvice`: recommendations, dietary_tips, warnings, alternative_foods
- `AdviceDependencies`: nutrition_facts, health_guidelines, food_interactions
- `ChatResponse`: success, response_content, session_id, session_type, metadata, suggestions

### DietDeepAgent
- Built on `deepagents` SDK (LangChain Deep Agents), located at `agent/diet_deep_agent/`
- Structure: `deep_agent.py` (entry), `config.py`, `prompts.py`, `skills/`, `subagents/`, `tools/`, `memory/`
- API via `routers/deep_router.py` → `/api/deep/*`:
  - `POST /api/deep/chat` — Unified chat (text, SSE streaming)
  - `POST /api/deep/analyze` — Food image analysis (upload + SSE streaming)
  - `GET /api/deep/daily-status` — Today's nutrition status
  - `GET /api/deep/memory/{user_id}` — View user memory (debug)
- LLM: DashScope `qwen3.5-plus`
- Uses `create_diet_deep_agent()` factory, cached singleton in router
