from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey, func, Index
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

    # V6 多成员归属（PRD §5.2，全部可空；空 = 归属 user_id 本人，历史数据不回填）
    member_id = Column(Integer, ForeignKey("family_members.id"), nullable=True,
                       comment="归属成员ID，空=账号本人")
    attributed_by = Column(String(16), nullable=True,
                           comment="归属依据: device_bind/voice_name/screen/default/manual/reconcile（开放集合）")
    attribution_confidence = Column(Float, nullable=True, comment="归属置信度 0-1")
    device_id = Column(String(64), nullable=True, comment="来源设备（device_key）")
    client_uuid = Column(String(36), nullable=True, comment="客户端幂等键，断网补传去重依据（A3）")

    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        Index('idx_water_user_time', 'user_id', 'record_time'),
        Index('idx_water_records_member', 'member_id'),
        Index('uq_water_records_client_uuid', 'client_uuid', unique=True),
    )