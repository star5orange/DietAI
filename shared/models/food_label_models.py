"""成分表评价模型 - 购买前的包装食品成分对比与留存

用户把商品成分表照片发给 AI 助手，助手按「每 100g」结构化数值结合健康档案
（当前疾病 + 病程天数 + 过敏原 + 健康目标）做评价并给出购买建议。

设计要点：
- 一个商品一行；同一 session_id 串起一次采购对比（多商品并列），
  因此**不另建对比分组表**——会话本身就是对比容器。
- 数值来自 OCR（确定性），不是模型估算；未标注项为 NULL。
- verdict 为尽力而为字段（模型按约定输出末行），取不到为 NULL。
"""
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.sql import func

from .database import Base


class FoodLabelReview(Base):
    """一次成分表评价（一个商品一行）"""

    __tablename__ = "food_label_reviews"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # 对比容器：同一对话内的多次评价归为一组采购对比
    session_id = Column(
        Integer, ForeignKey("conversation_sessions.id", ondelete="SET NULL"), nullable=True
    )
    brand = Column(String(128), nullable=True, comment="品牌")
    food_name = Column(String(128), nullable=True, comment="产品名称")
    serving_size_g = Column(Float, nullable=True, comment="每份克数（包装按份标注时）")

    # 以下均为「每 100g」，与 shared/services/food_label_ocr_service.py 的口径一致
    calories_per_100g = Column(Float, nullable=True, comment="能量 kcal")
    protein_per_100g = Column(Float, nullable=True, comment="蛋白质 g")
    fat_per_100g = Column(Float, nullable=True, comment="脂肪 g")
    carbs_per_100g = Column(Float, nullable=True, comment="碳水化合物 g")
    sugar_per_100g = Column(Float, nullable=True, comment="糖 g")
    fiber_per_100g = Column(Float, nullable=True, comment="膳食纤维 g")
    sodium_per_100g = Column(Float, nullable=True, comment="钠 mg")

    is_packaged_food = Column(
        Boolean, nullable=False, default=True, comment="OCR 判定为预包装食品"
    )
    raw_text = Column(Text, nullable=True, comment="OCR 原始返回（排查用）")
    verdict = Column(
        String(16), nullable=True, comment="推荐购买|谨慎购买|不推荐购买（解析失败为 NULL）"
    )
    answer_text = Column(Text, nullable=True, comment="AI 的评价与购买建议原文")
    created_at = Column(DateTime, nullable=False, default=func.now())

    __table_args__ = (
        Index("idx_food_label_review_user", "user_id"),
        Index("idx_food_label_review_session", "session_id"),
    )