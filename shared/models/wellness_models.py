from sqlalchemy import Column, Integer, String, Text, DateTime, func
from sqlalchemy.dialects.postgresql import JSON
from .database import Base

class WellnessKnowledge(Base):
    __tablename__ = "wellness_knowledge"

    id = Column(Integer, primary_key=True, index=True)
    category = Column(String(20), nullable=False)        # 节气/季节/体质
    sub_category = Column(String(50))
    title = Column(String(200), nullable=False)
    content = Column(Text)
    recommended_foods = Column(JSON)
    avoid_foods = Column(JSON)
    applicable_constitutions = Column(JSON)
    season = Column(String(10))
    solar_term = Column(String(20))
    created_at = Column(DateTime, server_default=func.now())