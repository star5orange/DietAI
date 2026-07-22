"""模拟 FastAPI 调用 —— 完整测试 AI 养生推荐"""
import asyncio, sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from shared.models.database import SessionLocal
from shared.services.wellness_service import generate_ai_wellness_recommendation

async def test():
    db = SessionLocal()
    try:
        result = await generate_ai_wellness_recommendation(user_id=10, db=db)
        print(f'source: {result.get("source")}')
        tips = result.get('wellness_tips', [])
        print(f'tips count: {len(tips)}')
        for i, t in enumerate(tips):
            print(f'  [{i}] {t[:60]}...')
        print(f'ingredients: {result.get("recommended_ingredients")}')
        print(f'recipes: {len(result.get("recommended_recipes", []))}')
    except Exception as e:
        print(f'ERROR: {type(e).__name__}: {e}')
        import traceback
        traceback.print_exc()
    finally:
        db.close()

asyncio.run(test())
