from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, func, Index
from .database import Base

class WaterIntakeRecord(Base):
    __tablename__ = "water_intake_records"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    amount_ml = Column(Integer, nullable=False)
    record_time = Column(DateTime, nullable=False)
    drink_type = Column(String(20))                     # 水/茶/咖啡/果汁等
    # 代记录人ID（NULL=本人记录，有值=代记录人ID）
    recorded_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        Index('idx_water_user_time', 'user_id', 'record_time'),
    )