"""康复建议纯函数单元测试（纯进程内，不需要后端 / LLM / 数据库）。

覆盖：
    - compute_advice_sig：同样输入稳定；对疾病名/严重程度/诊断日期/备注/
      过敏原/并发疾病敏感；**对病程天数不敏感**（否则会每天重建一次）
    - needs_regeneration：无缓存 / 签名一致 / 签名不一致三种分支
    - parse_stored_advice：合法 JSON / 非法 JSON / 空值
    - _normalize：缺 summary 判失败、免责声明兜底、列表字段清洗
    - elapsed_days：实时计算且不参与签名

运行：
    uv run pytest tests/test_rehab_advice.py -v
"""

import sys
from datetime import date, timedelta
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import pytest

from shared.services import rehab_advice_service as service
from shared.services.rehab_advice_service import (
    DISCLAIMER_FALLBACK,
    compute_advice_sig,
    elapsed_days,
    needs_regeneration,
    parse_stored_advice,
)


class _FakeDisease:
    """Disease 的最小替身，避免测试依赖数据库模型。"""

    def __init__(
        self,
        disease_name="骨折",
        severity_level=2,
        diagnosed_date=None,
        notes=None,
        rehab_advice=None,
        rehab_advice_sig=None,
    ):
        self.disease_name = disease_name
        self.severity_level = severity_level
        self.diagnosed_date = diagnosed_date
        self.notes = notes
        self.rehab_advice = rehab_advice
        self.rehab_advice_sig = rehab_advice_sig


class TestComputeAdviceSig:
    def test_同样输入得到相同签名(self):
        disease = _FakeDisease(diagnosed_date=date(2026, 9, 1), notes="手腕轻微骨折")
        assert compute_advice_sig(disease) == compute_advice_sig(disease)

    @pytest.mark.parametrize(
        "field, value",
        [
            ("disease_name", "高血压"),
            ("severity_level", 3),
            ("diagnosed_date", date(2026, 8, 1)),
            ("notes", "术后复查"),
        ],
    )
    def test_任一疾病属性变化都会改变签名(self, field, value):
        base = _FakeDisease(diagnosed_date=date(2026, 9, 1), notes="手腕轻微骨折")
        changed = _FakeDisease(diagnosed_date=date(2026, 9, 1), notes="手腕轻微骨折")
        setattr(changed, field, value)
        assert compute_advice_sig(base) != compute_advice_sig(changed)

    def test_过敏原变化会改变签名(self):
        disease = _FakeDisease()
        without = compute_advice_sig(disease, allergen_names=[])
        with_shrimp = compute_advice_sig(disease, allergen_names=["虾"])
        assert without != with_shrimp

    def test_过敏原顺序与重复不影响签名(self):
        disease = _FakeDisease()
        assert compute_advice_sig(
            disease, allergen_names=["虾", "花生", "花生"]
        ) == compute_advice_sig(disease, allergen_names=["花生", "虾"])

    def test_并发疾病变化会改变签名(self):
        disease = _FakeDisease()
        alone = compute_advice_sig(disease, comorbidity_names=[])
        with_diabetes = compute_advice_sig(disease, comorbidity_names=["糖尿病"])
        assert alone != with_diabetes

    def test_签名不随病程天数变化(self, monkeypatch):
        """这是「避免每天重建一次」的关键保证。"""
        disease = _FakeDisease(diagnosed_date=date.today() - timedelta(days=3))
        sig_before = compute_advice_sig(disease)
        days_before = elapsed_days(disease)

        class _LaterDate(date):
            @classmethod
            def today(cls):
                return date.today() + timedelta(days=30)

        monkeypatch.setattr(service, "date", _LaterDate)

        # 天数实时前进了，但签名必须保持不变
        assert elapsed_days(disease) == days_before + 30
        assert compute_advice_sig(disease) == sig_before


class TestNeedsRegeneration:
    def test_无缓存时需要生成(self):
        assert needs_regeneration(_FakeDisease(), "any-sig") is True

    def test_签名一致时复用缓存(self):
        disease = _FakeDisease(rehab_advice='{"summary": "ok"}', rehab_advice_sig="abc")
        assert needs_regeneration(disease, "abc") is False

    def test_签名不一致时重建(self):
        disease = _FakeDisease(rehab_advice='{"summary": "ok"}', rehab_advice_sig="abc")
        assert needs_regeneration(disease, "def") is True


class TestParseStoredAdvice:
    def test_合法JSON解析为字典(self):
        disease = _FakeDisease(rehab_advice='{"summary": "多补钙"}')
        assert parse_stored_advice(disease) == {"summary": "多补钙"}

    def test_非法JSON返回None(self):
        assert parse_stored_advice(_FakeDisease(rehab_advice="{不是json")) is None

    def test_空值返回None(self):
        assert parse_stored_advice(_FakeDisease()) is None


class TestNormalize:
    def test_缺summary判为失败(self):
        assert service._normalize({"diet_recommendations": ["喝牛奶"]}) is None

    def test_缺免责声明时用兜底文案(self):
        result = service._normalize({"summary": "注意补钙"})
        assert result["disclaimer"] == DISCLAIMER_FALLBACK

    def test_列表字段清洗空值与非法类型(self):
        result = service._normalize(
            {
                "summary": "注意补钙",
                "diet_recommendations": ["喝牛奶", "", "  "],
                "nutrient_focus": "钙",  # 非列表：应归一为空列表
                "avoid_recommendations": None,
            }
        )
        assert result["diet_recommendations"] == ["喝牛奶"]
        assert result["nutrient_focus"] == []
        assert result["avoid_recommendations"] == []

    def test_空复查提醒归一为None(self):
        result = service._normalize({"summary": "注意补钙", "followup_reminder": "  "})
        assert result["followup_reminder"] is None


class TestElapsedDays:
    def test_按诊断日期实时计算(self):
        disease = _FakeDisease(diagnosed_date=date.today() - timedelta(days=45))
        assert elapsed_days(disease) == 45

    def test_未记录诊断日期返回None(self):
        assert elapsed_days(_FakeDisease()) is None