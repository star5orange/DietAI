"""包装食品营养成分表 OCR 服务

针对人类预包装食品：
- 兼容"每 100g"与"每份"两种标注口径（统一换算为每 100g）
- 热量 kJ → kcal 换算（1 kJ ≈ 0.239 kcal）
- 额外提取 糖 / 膳食纤维 / 钠
- 非包装食品照片时返回 is_packaged_food=False，前端可引导改用餐食识别

视觉模型调用复用 shared/services/dashscope_vl_ocr.py
（含 API Key 获取与模型回退链，与宠物食品 OCR 共用同一实现）。
"""

import logging
import re

from shared.services.dashscope_vl_ocr import call_vl_json

logger = logging.getLogger("food_label_ocr_service")

# 人类预包装食品营养成分表解析 Prompt
_LABEL_OCR_PROMPT = (
    "请识别这张预包装食品的照片（包装正面或背面/侧面的营养成分表），提取以下内容并以JSON格式返回：\n"
    "{\n"
    '  "is_packaged_food": 布尔值，照片是否为预包装食品（有品牌、包装、配料表或营养成分表），\n'
    '  "brand": "品牌名称（如 伊利、康师傅、奥利奥等）",\n'
    '  "food_name": "产品名称（如 纯牛奶、老坛酸菜面、夹心饼干等）",\n'
    '  "serving_size_g": 每份克数（仅当包装按"每份"标注时返回，否则为null），\n'
    '  "calories_per_100g": 每100克能量数值，单位kcal（若包装标注为kJ请换算：1kJ≈0.239kcal；\n'
    "      若按每份标注请先根据每份克数换算成每100g），\n"
    '  "protein_per_100g": 每100克蛋白质克数，\n'
    '  "fat_per_100g": 每100克脂肪克数，\n'
    '  "carbs_per_100g": 每100克碳水化合物克数，\n'
    '  "sugar_per_100g": 每100克糖克数（无法识别则为null），\n'
    '  "fiber_per_100g": 每100克膳食纤维克数（无法识别则为null），\n'
    '  "sodium_per_100g": 每100克钠毫克数（无法识别则为null）\n'
    "}\n"
    "只返回JSON，不要其他内容。如果照片不是预包装食品（例如是一盘做好的菜肴、\n"
    '新鲜食材等），只返回 {"is_packaged_food": false}。\n'
    "如果某个字段无法识别，设为null。"
)


def _parse_label_local(reason: str = "") -> dict:
    """本地兜底：OCR 服务不可用时返回空结果提示手动输入

    reason 会写入 raw_text，前端可展示以便排查（额度耗尽/模型未开通等）。
    """

    return {
        "is_packaged_food": None,
        "brand": None,
        "food_name": None,
        "serving_size_g": None,
        "calories_per_100g": None,
        "protein_per_100g": None,
        "fat_per_100g": None,
        "carbs_per_100g": None,
        "sugar_per_100g": None,
        "fiber_per_100g": None,
        "sodium_per_100g": None,
        "raw_text": f"OCR服务不可用，请手动输入营养信息。{reason}".strip(),
    }


def _sanitize_label_result(result: dict) -> dict:
    """清洗模型返回：剔除未知键、数值字段转 float"""

    numeric_fields = (
        "serving_size_g",
        "calories_per_100g",
        "protein_per_100g",
        "fat_per_100g",
        "carbs_per_100g",
        "sugar_per_100g",
        "fiber_per_100g",
        "sodium_per_100g",
    )
    text_fields = ("brand", "food_name")

    cleaned = {"is_packaged_food": None}
    for field in text_fields:
        value = result.get(field)
        cleaned[field] = str(value).strip() if value else None

    for field in numeric_fields:
        value = result.get(field)
        if value is None:
            cleaned[field] = None
            continue
        try:
            # 兼容 "2300" / "2300mg" / "2,300" 之类的脏值
            text = str(value).replace(",", "").strip()
            match = re.search(r"-?\d+(\.\d+)?", text)
            cleaned[field] = float(match.group(0)) if match else None
        except (TypeError, ValueError):
            cleaned[field] = None

    is_packaged = result.get("is_packaged_food")
    if isinstance(is_packaged, bool):
        cleaned["is_packaged_food"] = is_packaged
    elif isinstance(is_packaged, str):
        # 兼容模型返回字符串 "true"/"false"/"是"/"否"
        normalized = is_packaged.strip().lower()
        if normalized in ("true", "yes", "1", "是"):
            cleaned["is_packaged_food"] = True
        elif normalized in ("false", "no", "0", "否"):
            cleaned["is_packaged_food"] = False
    return cleaned


def parse_food_label(image_base64: str) -> dict:
    """使用 DashScope OCR 解析人类预包装食品的营养成分表

    Args:
        image_base64: Base64 编码的包装食品照片（建议包装背面/侧面营养成分表清晰可见）

    Returns:
        dict: is_packaged_food / brand / food_name / serving_size_g /
              calories_per_100g(kcal) / protein_per_100g / fat_per_100g /
              carbs_per_100g / sugar_per_100g / fiber_per_100g /
              sodium_per_100g(mg) / raw_text
    """

    try:
        result = call_vl_json(
            image_base64,
            _LABEL_OCR_PROMPT,
            max_tokens=600,
            env_var="DIETAI_FOOD_LABEL_OCR_MODEL",
        )
    except RuntimeError as e:
        logger.error(f"包装食品 OCR 调用失败: {e}")
        return _parse_label_local(f"（{e}）")

    if result["data"] is None:
        return {"is_packaged_food": None, "raw_text": result["raw_text"]}

    cleaned = _sanitize_label_result(result["data"])
    cleaned["raw_text"] = result["raw_text"]
    cleaned["model"] = result["model"]
    return cleaned
