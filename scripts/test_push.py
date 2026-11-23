"""测试推送功能 -- 手动触发健康报告和宠物提醒"""
import sys
import os

# 确保项目根目录在 sys.path 中
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from shared.tasks.health_report_tasks import send_weekly_health_report, send_monthly_health_report
from shared.tasks.pet_tasks import check_pet_vaccine_reminders

if __name__ == "__main__":
    print("=" * 60)
    print("测试 1: 宠物疫苗/驱虫推送")
    print("=" * 60)
    check_pet_vaccine_reminders()

    print()
    print("=" * 60)
    print("测试 2: 周报推送")
    print("=" * 60)
    send_weekly_health_report()

    print()
    print("=" * 60)
    print("测试 3: 月报推送")
    print("=" * 60)
    send_monthly_health_report()

    print()
    print("全部测试完成，检查日志和手机通知。")
