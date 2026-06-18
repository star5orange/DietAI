from sqlalchemy import Column, Integer, String, Float, Date, DateTime, Text, ForeignKey, func, Index, JSON
from .database import Base

class ExerciseRecord(Base):
    __tablename__ = "exercise_records"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    exercise_type = Column(String(50), nullable=False)
    exercise_name = Column(String(100), nullable=True)
    duration_minutes = Column(Integer, nullable=False)
    intensity = Column(Integer, nullable=False)          # 1=低, 2=中, 3=高
    calories_burned = Column(Float, nullable=False)
    record_date = Column(Date, nullable=False)
    notes = Column(Text)
    strength_detail = Column(JSON, nullable=True)  # 力量训练详情：{"muscle_groups":["胸","三头"],"sets":[{"exercise":"卧推","sets":4,"reps":12,"weight_kg":60}]}
    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        Index('idx_exercise_user_date', 'user_id', 'record_date'),
    )