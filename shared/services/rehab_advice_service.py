"""康复建议：按疾病生成 AI 饮食/生活指导，并提供缓存失效判定。

设计要点：
- 建议与疾病 1:1，缓存在 `diseases.rehab_advice`（JSON 字符串），
  疾病被标记为「已痊愈」（is_current=False）后自然不再返回，无需清理。
- 失效判断用输入签名 `rehab_advice_sig` 而不是 `updated_at`：
  写入本列会触发 Disease.updated_at 的 onupdate 刷新，用它比较会导致反复重建。
- 签名刻意不含「病程天数」，避免每天重建一次；天数只在响应里实时计算展示。
"""
import hashlib
import json
import logging
from datetime import date
from typing import Any, Optional

logger = logging.getLogger(__name__)

# 结构化建议不需要长超时（体检解读那条链路用的是 120s）
ADVICE_TIMEOUT_SECONDS = 30.0
ADVICE_MODEL = "qwen-plus"
DASHSCOPE_ENDPOINT = (
    "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
)

# 模型没给出免责声明时的兜底（必须展示，避免越界成医疗建议）
DISCLAIMER_FALLBACK = (
    "本建议由 AI 生成，仅供参考，不构成医疗诊断或用药建议；"
    "具体康复方案请遵医嘱。"
)

_SEVERITY_LABELS = {1: "轻度", 2: "中度", 3: "重度"}


def compute_advice_sig(
    disease: Any,
    allergen_names: Optional[list[str]] = None,
    comorbidity_names: Optional[list[str]] = None,
) -> str:
    """计算生成输入签名。

    纳入疾病本身的属性 + 过敏原 + 并发疾病：
    用户新增过敏原或并发疾病变化后，建议需要重建
    （否则可能出现「建议吃虾皮补钙」这类致敏推荐）。
    刻意不纳入病程天数——那会导致每天重建一次。
    """
    diagnosed = getattr(disease, "diagnosed_date", None)
    parts = [
        (getattr(disease, "disease_name", None) or "").strip(),
        str(getattr(disease, "severity_level", None) or ""),
        diagnosed.isoformat() if diagnosed else "",
        (getattr(disease, "notes", None) or "").strip(),
        "、".join(sorted({n.strip() for n in (allergen_names or []) if n and n.strip()})),
        "、".join(sorted({n.strip() for n in (comorbidity_names or []) if n and n.strip()})),
    ]
    return hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()


def needs_regeneration(disease: Any, sig: str) -> bool:
    """结果为空或签名与生成时不一致时需要重建。"""
    if not getattr(disease, "rehab_advice", None):
        return True
    return (getattr(disease, "rehab_advice_sig", None) or "") != sig


def parse_stored_advice(disease: Any) -> Optional[dict]:
    """读取缓存中的建议，格式异常时返回 None（视同未生成）。"""
    raw = getattr(disease, "rehab_advice", None)
    if not raw:
        return None
    try:
        parsed = json.loads(raw)
    except (TypeError, ValueError):
        logger.warning("康复建议缓存不是合法 JSON，将重新生成")
        return None
    return parsed if isinstance(parsed, dict) else None


def elapsed_days(disease: Any) -> Optional[int]:
    """病程天数（实时计算，不参与失效判断）。"""
    diagnosed = getattr(disease, "diagnosed_date", None)
    if not diagnosed:
        return None
    return (date.today() - diagnosed).days


def _build_prompt(disease: Any, health_context: str) -> str:
    severity = _SEVERITY_LABELS.get(getattr(disease, "severity_level", None), "未标注")
    days = elapsed_days(disease)
    if days is not None:
        course = f"诊断于 {disease.diagnosed_date.isoformat()}，已 {days} 天"
    else:
        course = "诊断日期未记录"

    notes = (getattr(disease, "notes", None) or "").strip()

    return (
        "你是一名临床营养师，请为正在患病的用户给出康复期的饮食与生活建议。\n\n"
        f"疾病：{disease.disease_name}\n"
        f"严重程度：{severity}\n"
        f"病程：{course}\n"
        + (f"补充说明：{notes}\n" if notes else "")
        + (health_context or "")
        + "\n\n要求：\n"
        "1. 只给饮食与生活方式建议，禁止做诊断、禁止推荐具体药物或剂量；\n"
        "2. 必须避开用户的所有过敏原，绝不能推荐含过敏原的食物；\n"
        "3. 结合病程天数判断所处阶段（如骨折早期消肿、中期骨痂形成、"
        "后期功能恢复的营养侧重各不相同），并兼顾用户的其他当前患病；\n"
        "4. 全部使用简体中文，每条建议不超过 30 字；\n"
        "5. 只输出 JSON（不要 markdown 代码块），格式：\n"
        '{"summary": "一句话总览", "diet_recommendations": ["宜…"], '
        '"avoid_recommendations": ["忌…"], "nutrient_focus": ["钙", "维生素D"], '
        '"recovery_notes": ["注意事项…"], "followup_reminder": "复查提醒，没有则为 null", '
        '"disclaimer": "免责声明"}'
    )


def _normalize(parsed: dict) -> Optional[dict]:
    """字段归一化，保证与 RehabAdviceItem 契约一致。"""
    summary = parsed.get("summary")
    if not isinstance(summary, str) or not summary.strip():
        return None

    def _str_list(value: Any) -> list[str]:
        if not isinstance(value, list):
            return []
        return [str(x).strip() for x in value if str(x).strip()]

    followup = parsed.get("followup_reminder")
    disclaimer = parsed.get("disclaimer")

    return {
        "summary": summary.strip(),
        "diet_recommendations": _str_list(parsed.get("diet_recommendations")),
        "avoid_recommendations": _str_list(parsed.get("avoid_recommendations")),
        "nutrient_focus": _str_list(parsed.get("nutrient_focus")),
        "recovery_notes": _str_list(parsed.get("recovery_notes")),
        "followup_reminder": followup.strip() if isinstance(followup, str) and followup.strip() else None,
        "disclaimer": (
            disclaimer.strip()
            if isinstance(disclaimer, str) and disclaimer.strip()
            else DISCLAIMER_FALLBACK
        ),
    }


async def generate_rehab_advice(disease: Any, health_context: str = "") -> Optional[dict]:
    """调用 DashScope qwen-plus 生成康复建议。失败返回 None（不抛异常）。"""
    try:
        from shared.config.settings import get_settings

        settings = get_settings()
        if not settings.dashscope_api_key:
            logger.warning("未配置 dashscope_api_key，跳过康复建议生成")
            return None

        import httpx

        prompt = _build_prompt(disease, health_context)
        async with httpx.AsyncClient(
            timeout=ADVICE_TIMEOUT_SECONDS, trust_env=False
        ) as client:
            response = await client.post(
                DASHSCOPE_ENDPOINT,
                headers={
                    "Authorization": f"Bearer {settings.dashscope_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": ADVICE_MODEL,
                    "input": {"messages": [{"role": "user", "content": prompt}]},
                    "parameters": {"result_format": "message"},
                },
            )
            if response.status_code != 200:
                logger.error(
                    f"康复建议模型调用失败: {response.status_code} - {response.text[:200]}"
                )
                return None
            result = response.json()
            content_text = (
                result.get("output", {})
                .get("choices", [{}])[0]
                .get("message", {})
                .get("content", "")
            )
            start, end = content_text.find("{"), content_text.rfind("}") + 1
            if start < 0 or end <= start:
                logger.warning(f"康复建议返回内容不是 JSON: {content_text[:200]}")
                return None
            normalized = _normalize(json.loads(content_text[start:end]))
            if normalized is None:
                logger.warning(f"康复建议缺少 summary: {content_text[:200]}")
                return None
            logger.info(
                f"康复建议生成成功: {disease.disease_name} "
                f"({len(normalized['diet_recommendations'])} 条饮食建议)"
            )
            return normalized
    except Exception as e:
        logger.warning(f"康复建议生成异常: {e}")
        return None