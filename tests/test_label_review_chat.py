"""成分表评价（对话发图）纯函数单元测试（纯进程内，不需要后端 / LLM / 数据库）。

覆盖：
    - _build_label_review_text：三种 OCR 结果的注入文本（预包装食品 / 非预包装 / OCR 失败）
    - _extract_verdict：末行机器可读结论的解析与缺失兜底
    - _save_label_review：字段映射、verdict 落库、异常不抛出
    - _resolve_deep_chat_params：JSON body 里的 image_base64 可选透传

运行：
    uv run pytest tests/test_label_review_chat.py -v
"""

import asyncio
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import pytest
from starlette.requests import Request

from routers import deep_router
from routers.deep_router import (
    _LABEL_REVIEW_DEFAULT_ASK,
    _build_label_review_text,
    _extract_verdict,
    _resolve_deep_chat_params,
    _save_label_review,
)

_PACKAGED_LABEL = {
    "is_packaged_food": True,
    "brand": "伊利",
    "food_name": "中老年高钙奶粉",
    "serving_size_g": 25.0,
    "calories_per_100g": 470.0,
    "protein_per_100g": 22.5,
    "fat_per_100g": 15.0,
    "carbs_per_100g": 55.0,
    "sugar_per_100g": None,
    "fiber_per_100g": None,
    "sodium_per_100g": 320.0,
    "raw_text": "{...}",
}


def _make_json_request(payload: dict) -> Request:
    body = json.dumps(payload).encode("utf-8")
    scope = {
        "type": "http",
        "method": "POST",
        "headers": [(b"content-type", b"application/json")],
    }

    async def receive():
        return {"type": "http.request", "body": body, "more_body": False}

    return Request(scope, receive)


class TestBuildLabelReviewText:
    def test_预包装食品注入结构化数值(self):
        text = _build_label_review_text("外婆骨折，这个能买吗", _PACKAGED_LABEL)
        for keyword in (
            "伊利",
            "中老年高钙奶粉",
            "470 kcal",
            "22.5 g",
            "320 mg",
            "外婆骨折，这个能买吗",
            "成分表评价与购买建议",
        ):
            assert keyword in text, keyword

    def test_未标注项渲染为未标注而非null(self):
        text = _build_label_review_text("", _PACKAGED_LABEL)
        assert "null" not in text
        assert "糖：未标注" in text
        assert "膳食纤维：未标注" in text

    def test_空诉求用默认问法(self):
        text = _build_label_review_text("", _PACKAGED_LABEL)
        assert _LABEL_REVIEW_DEFAULT_ASK in text

    def test_非预包装食品不出数值(self):
        text = _build_label_review_text("", {"is_packaged_food": False})
        assert "不是预包装食品" in text
        assert "470" not in text
        assert "kcal" not in text

    def test_ocr失败提示重拍且不编造(self):
        text = _build_label_review_text(
            "", {"is_packaged_food": None, "raw_text": "OCR服务不可用"}
        )
        assert "未能识别" in text
        assert "OCR服务不可用" in text
        assert "严禁编造" in text


class TestExtractVerdict:
    @pytest.mark.parametrize(
        "verdict", ["推荐购买", "谨慎购买", "不推荐购买"]
    )
    def test_解析三种结论(self, verdict):
        assert _extract_verdict(f"总结一下。\n【购买建议】{verdict}") == verdict

    def test_缺失结论返回None(self):
        assert _extract_verdict("这款奶粉蛋白质还可以。") is None
        assert _extract_verdict("") is None

    def test_不在可选集合内的措辞不解析(self):
        assert _extract_verdict("【购买建议】可以买") is None


class _RecorderReview:
    """FoodLabelReview 的最小替身：只记录构造入参，避免测试依赖数据库。"""

    captured: dict = {}

    def __init__(self, **kwargs):
        type(self).captured = kwargs


class _FakeSession:
    def __init__(self):
        self.added = []
        self.committed = False
        self.rolled_back = False

    def add(self, obj):
        self.added.append(obj)

    def commit(self):
        self.committed = True

    def rollback(self):
        self.rolled_back = True


@pytest.fixture
def recorder(monkeypatch):
    from shared.models import food_label_models as models

    _RecorderReview.captured = {}
    monkeypatch.setattr(models, "FoodLabelReview", _RecorderReview)
    return _RecorderReview


class TestSaveLabelReview:
    def test_字段映射与落库(self, recorder):
        db = _FakeSession()
        _save_label_review(
            db,
            user_id=7,
            session_id=42,
            label=_PACKAGED_LABEL,
            answer_text="整体适合康复期。\n【购买建议】推荐购买",
        )

        assert db.committed is True
        assert db.rolled_back is False
        assert len(db.added) == 1

        captured = recorder.captured
        assert captured["user_id"] == 7
        assert captured["session_id"] == 42
        assert captured["brand"] == "伊利"
        assert captured["food_name"] == "中老年高钙奶粉"
        assert captured["calories_per_100g"] == 470.0
        assert captured["protein_per_100g"] == 22.5
        assert captured["sodium_per_100g"] == 320.0
        assert captured["sugar_per_100g"] is None
        assert captured["is_packaged_food"] is True
        assert captured["verdict"] == "推荐购买"

    def test_无结论时verdict为None(self, recorder):
        db = _FakeSession()
        _save_label_review(
            db, user_id=7, session_id=None, label=_PACKAGED_LABEL, answer_text="还行"
        )
        assert recorder.captured["verdict"] is None

    def test_超长品牌名被截断(self, recorder):
        db = _FakeSession()
        label = dict(_PACKAGED_LABEL, brand="伊" * 300)
        _save_label_review(
            db, user_id=7, session_id=None, label=label, answer_text=""
        )
        assert len(recorder.captured["brand"]) == 128

    def test_落库异常不抛出(self, recorder, monkeypatch):
        db = _FakeSession()

        def _boom(self):
            raise RuntimeError("db down")

        monkeypatch.setattr(_FakeSession, "commit", _boom)
        _save_label_review(
            db, user_id=7, session_id=None, label=_PACKAGED_LABEL, answer_text=""
        )
        assert db.rolled_back is True


class TestResolveImageParam:
    def test_json_body带图透传(self):
        request = _make_json_request(
            {"message": "看看这个", "image_base64": "  QUJD  ", "session_type": 1}
        )
        message, session_id, session_type, channel, image = asyncio.run(
            _resolve_deep_chat_params(request, "", None)
        )
        assert message == "看看这个"
        assert session_type == "1"
        assert channel == "app"
        assert image == "QUJD"

    def test_json_body无图返回None(self):
        request = _make_json_request({"message": "你好"})
        _, _, _, _, image = asyncio.run(
            _resolve_deep_chat_params(request, "", None)
        )
        assert image is None

    def test_空字符串图视为无图(self):
        request = _make_json_request({"message": "你好", "image_base64": "   "})
        _, _, _, _, image = asyncio.run(
            _resolve_deep_chat_params(request, "", None)
        )
        assert image is None

    def test_文件头docstring已订正(self):
        """文件头注释曾是过期的「文字+图片」，订正后不应再出现该措辞"""
        assert "统一对话入口（文字+图片）" not in (deep_router.__doc__ or "")