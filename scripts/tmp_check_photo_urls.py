"""临时脚本：查看体检报告 photo_url 实际内容"""
import sys, os, logging
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
logging.disable(logging.CRITICAL)

from shared.models.database import SessionLocal
from shared.models.exam_models import ExamReport

db = SessionLocal()
try:
    reports = db.query(ExamReport).order_by(ExamReport.id.desc()).limit(10).all()
    for r in reports:
        print(f"id={r.id} user={r.user_id} date={r.exam_date}")
        print(f"  photo_url={r.photo_url!r}")
        urls = r.photo_urls or []
        for u in urls:
            print(f"  photo_urls条目={u!r}")
finally:
    db.close()
