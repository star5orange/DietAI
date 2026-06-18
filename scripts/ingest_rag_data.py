"""
RAG 知识库数据入库脚本

将食物营养、节气养生、特殊人群饮食建议三类数据写入 ChromaDB 向量库，
每条数据附带 metadata 标签，支持后续 metadata filtering 精准检索。

用法:
    cd DietAI
    python scripts/ingest_rag_data.py [--type food|solar|diet|all] [--clear]
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import argparse
from dotenv import load_dotenv
load_dotenv(".env", override=True)

from langchain_chroma import Chroma
from langchain_openai import OpenAIEmbeddings
from langchain_core.documents import Document

from shared.config.settings import settings
from scripts.rag_data.food_nutrition import (
    GRAINS, VEGETABLES, FRUITS, MEATS, SEAFOOD, DAIRY_EGGS,
    LEGUMES, NUTS_SEEDS, ALL_FOODS
)
from scripts.rag_data.solar_term_nutrition import ALL_SOLAR_TERMS
from scripts.rag_data.special_diet import ALL_SPECIAL_DIETS


def _split_tags(tag_string: str) -> list[str]:
    """将逗号分隔的标签字符串拆分为列表"""
    return [t.strip() for t in tag_string.split(",") if t.strip()]


def _build_tag_metadata(tag_string: str, prefix: str) -> dict:
    """将标签字符串转为布尔型 metadata 字段，如 crowd_减脂=True

    ChromaDB 的 $contains 对中文不支持，改用布尔字段 + $eq 匹配
    """
    result = {}
    for tag in _split_tags(tag_string):
        result[f"{prefix}_{tag}"] = True
    return result


def build_food_documents() -> list[Document]:
    """将食物营养数据转为 LangChain Document 列表"""
    documents = []
    for item in ALL_FOODS:
        name, category, calories, protein, fat, carb, fiber, nature, nutrients, constitution, crowd, season, desc = item
        page_content = (
            f"食物名称: {name}\n"
            f"分类: {category}\n"
            f"热量: {calories}kcal/100g\n"
            f"蛋白质: {protein}g\n"
            f"脂肪: {fat}g\n"
            f"碳水化合物: {carb}g\n"
            f"膳食纤维: {fiber}g\n"
            f"性味: {nature}\n"
            f"关键营养素: {nutrients}\n"
            f"适用体质: {constitution}\n"
            f"适用人群: {crowd}\n"
            f"适用季节: {season}\n"
            f"简介: {desc}"
        )
        metadata = {
            "data_type": "food_nutrition",
            "name": name,
            "category": category,
            "calories": calories,
            "protein": protein,
            "fat": fat,
            "carb": carb,
            "fiber": fiber,
            "nature": nature,
        }
        # 拆分多值标签为布尔字段
        metadata.update(_build_tag_metadata(constitution, "constitution"))
        metadata.update(_build_tag_metadata(crowd, "crowd"))
        metadata.update(_build_tag_metadata(season, "season"))
        documents.append(Document(page_content=page_content, metadata=metadata))
    return documents


def build_solar_term_documents() -> list[Document]:
    """将节气养生数据转为 LangChain Document 列表"""
    documents = []
    for item in ALL_SOLAR_TERMS:
        (term, season, time_range, climate, principle,
         rec_foods, avoid_foods, tea, key_points,
         constitution, tips, recipe) = item
        page_content = (
            f"节气: {term}\n"
            f"季节: {season}\n"
            f"公历时间: {time_range}\n"
            f"气候特点: {climate}\n"
            f"养生原则: {principle}\n"
            f"推荐食物: {', '.join(rec_foods)}\n"
            f"忌食: {', '.join(avoid_foods)}\n"
            f"推荐茶饮: {tea}\n"
            f"养生要点: {key_points}\n"
            f"适用体质: {constitution}\n"
            f"特别提示: {tips}\n"
            f"经典食疗方: {recipe}"
        )
        metadata = {
            "data_type": "solar_term",
            "term": term,
            "season": season,
        }
        metadata.update(_build_tag_metadata(constitution, "constitution"))
        metadata.update(_build_tag_metadata(season, "season"))
        documents.append(Document(page_content=page_content, metadata=metadata))
    return documents


def build_special_diet_documents() -> list[Document]:
    """将特殊人群饮食建议转为 LangChain Document 列表"""
    documents = []
    for item in ALL_SPECIAL_DIETS:
        (group, subgroup, constitution, goal, calories,
         macro_ratio, rec_foods, avoid_foods, principles,
         meal_plan, notes, myths) = item
        carb_pct, protein_pct, fat_pct = macro_ratio
        page_content = (
            f"人群类别: {group}\n"
            f"子类别: {subgroup}\n"
            f"适用体质: {constitution}\n"
            f"核心目标: {goal}\n"
            f"每日热量建议: {calories}\n"
            f"宏量营养素比例: 碳水{carb_pct}% 蛋白质{protein_pct}% 脂肪{fat_pct}%\n"
            f"推荐食物: {', '.join(rec_foods)}\n"
            f"忌食/少食: {', '.join(avoid_foods)}\n"
            f"饮食原则: {principles}\n"
            f"一日食谱示例: {meal_plan}\n"
            f"特别注意事项: {notes}\n"
            f"常见误区: {myths}"
        )
        metadata = {
            "data_type": "special_diet",
            "group": group,
            "subgroup": subgroup,
            "goal": goal,
            "carb_pct": carb_pct,
            "protein_pct": protein_pct,
            "fat_pct": fat_pct,
        }
        metadata.update(_build_tag_metadata(constitution, "constitution"))
        metadata.update(_build_tag_metadata(group, "crowd"))
        documents.append(Document(page_content=page_content, metadata=metadata))
    return documents


def get_vector_store() -> Chroma:
    """获取 ChromaDB 向量存储实例，优先使用 DashScope 兼容接口"""
    dashscope_api_key = os.getenv("DASHSCOPE_API_KEY", "")
    openai_api_key = os.getenv("OPENAI_API_KEY", "")

    if dashscope_api_key and not openai_api_key:
        # 使用 DashScope 兼容 OpenAI 接口
        embeddings = OpenAIEmbeddings(
            model="text-embedding-v3",
            base_url="https://dashscope.aliyuncs.com/compatible-mode/v1",
            api_key=dashscope_api_key,
            check_embedding_ctx_length=False,
            chunk_size=10,  # DashScope batch size 限制为 10
        )
        print("使用 DashScope Embeddings (text-embedding-v3)")
    elif openai_api_key:
        embeddings = OpenAIEmbeddings()
        print("使用 OpenAI Embeddings")
    else:
        print("错误: 未配置 OPENAI_API_KEY 或 DASHSCOPE_API_KEY")
        print("请在 .env 文件中配置 API Key 后重试")
        sys.exit(1)

    vector_store = Chroma(
        collection_name=settings.VECTOR_COLLECTION_NAME,
        embedding_function=embeddings,
        persist_directory=settings.VECTOR_STORE_PATH,
    )
    return vector_store


def clear_collection(vector_store: Chroma):
    """清空向量库中的所有数据"""
    try:
        # 获取已有文档数量
        collection = vector_store._collection
        count = collection.count()
        if count > 0:
            # 获取所有文档 ID 然后删除
            all_ids = collection.get()["ids"]
            if all_ids:
                collection.delete(ids=all_ids)
                print(f"已清空向量库，删除 {len(all_ids)} 条数据")
        else:
            print("向量库为空，无需清空")
    except Exception as e:
        print(f"清空向量库时出错: {e}")


def ingest_data(data_type: str = "all", clear: bool = False):
    """执行数据入库"""
    vector_store = get_vector_store()

    if clear:
        clear_collection(vector_store)

    # 构建文档
    all_documents = []
    if data_type in ("food", "all"):
        food_docs = build_food_documents()
        all_documents.extend(food_docs)
        print(f"食物营养数据: {len(food_docs)} 条")

    if data_type in ("solar", "all"):
        solar_docs = build_solar_term_documents()
        all_documents.extend(solar_docs)
        print(f"节气养生数据: {len(solar_docs)} 条")

    if data_type in ("diet", "all"):
        diet_docs = build_special_diet_documents()
        all_documents.extend(diet_docs)
        print(f"特殊人群饮食数据: {len(diet_docs)} 条")

    if not all_documents:
        print("没有数据需要入库")
        return

    # 批量入库
    print(f"正在入库 {len(all_documents)} 条数据到 ChromaDB...")
    try:
        # 分批入库，每批100条，避免内存溢出
        batch_size = 100
        for i in range(0, len(all_documents), batch_size):
            batch = all_documents[i:i + batch_size]
            vector_store.add_documents(batch)
            print(f"  已入库 {min(i + batch_size, len(all_documents))}/{len(all_documents)}")

        # 验证
        collection = vector_store._collection
        total = collection.count()
        print(f"\n入库完成！向量库中共有 {total} 条数据")

        # 重建运行时向量存储实例，清除缓存
        try:
            from agent.common_utils.rag_utils import rebuild_vector_store
            rebuild_vector_store()
            print("已清除 RAG 缓存并重建向量存储实例")
        except Exception as e:
            print(f"清除 RAG 缓存时出错(非致命): {e}")

        # 简单检索验证
        print("\n--- 检索验证 ---")
        test_queries = [
            ("适合减脂的低热量食物", {"$and": [{"data_type": "food_nutrition"}, {"crowd_减脂": True}]}),
            ("夏至养生", {"$and": [{"data_type": "solar_term"}, {"term": "夏至"}]}),
            ("孕妇饮食建议", {"$and": [{"data_type": "special_diet"}, {"group": "孕妇"}]}),
        ]
        for query, filter_meta in test_queries:
            try:
                results = vector_store.similarity_search(query, k=2, filter=filter_meta)
                print(f"\n查询: {query}")
                print(f"  过滤条件: {filter_meta}")
                for doc in results:
                    first_line = doc.page_content.split("\n")[0]
                    print(f"  -> {first_line}")
            except Exception as e:
                print(f"\n查询: {query}")
                print(f"  过滤检索失败(可能ChromaDB版本不支持此过滤语法): {e}")
                # 退回无过滤检索
                results = vector_store.similarity_search(query, k=2)
                print(f"  无过滤检索结果:")
                for doc in results:
                    first_line = doc.page_content.split("\n")[0]
                    print(f"  -> {first_line}")

    except Exception as e:
        print(f"入库失败: {e}")
        raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="RAG 知识库数据入库")
    parser.add_argument(
        "--type",
        choices=["food", "solar", "diet", "all"],
        default="all",
        help="入库数据类型: food=食物营养, solar=节气养生, diet=特殊人群, all=全部"
    )
    parser.add_argument(
        "--clear",
        action="store_true",
        help="入库前清空向量库"
    )
    args = parser.parse_args()
    ingest_data(args.type, args.clear)
