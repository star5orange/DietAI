"""
体检提醒定时任务

实现体检报告相关的自动提醒：
1. 年度体检提醒：距上次体检 ≥ 11 个月，每月 1 次
2. 复查提醒：体检异常后，到期前 2 周、1 周、3 天、当天提醒
3. 未上传提醒：用户年龄 > 50 且从未上传体检报告，每周 1 次
4. 家人体检提醒：家人的体检到期/复查到期，同步推送给家人
"""

import logging
from datetime import datetime, date, timedelta
from typing import List, Optional

from sqlalchemy.orm import Session
from sqlalchemy import and_, or_

logger = logging.getLogger(__name__)


async def check_annual_exam_reminders():
    """
    年度体检提醒：距上次体检 ≥ 11 个月
    
    每月 1 号执行一次，检查所有活跃用户：
    - 如果距上次体检 ≥ 11 个月，发送提醒
    - 同时通知所有家人
    """
    from shared.models.database import SessionLocal
    from shared.models.user_models import User
    from shared.models.exam_models import ExamReport
    from shared.models.social_models import UserRelationship
    from shared.services.push_service import send_push_to_user
    
    logger.info("[年度体检提醒] 开始检查")
    
    db = SessionLocal()
    try:
        # 查询最近 7 天活跃的用户
        cutoff_date = datetime.now() - timedelta(days=7)
        active_users = db.query(User).filter(User.last_login >= cutoff_date).all()
        
        reminder_count = 0
        
        for user in active_users:
            try:
                # 获取用户最新的体检报告
                latest_report = db.query(ExamReport).filter(
                    ExamReport.user_id == user.id
                ).order_by(ExamReport.exam_date.desc()).first()
                
                if not latest_report:
                    # 从未上传过体检报告，跳过（由未上传提醒处理）
                    continue
                
                # 计算距上次体检的月数
                exam_date = latest_report.exam_date
                today = date.today()
                
                # 简单计算月数差
                months_diff = (today.year - exam_date.year) * 12 + (today.month - exam_date.month)
                
                # 如果 ≥ 11 个月，发送提醒
                if months_diff >= 11:
                    # 发送给用户本人
                    await send_push_to_user(
                        db=db,
                        user_id=user.id,
                        title="年度体检提醒",
                        body=f"距上次体检已 {months_diff} 个月，建议安排今年体检",
                        data={
                            "type": "annual_exam_reminder",
                            "months_since_exam": months_diff,
                            "last_exam_date": exam_date.isoformat()
                        },
                        reminder_type="annual_exam"
                    )
                    
                    # 通知所有家人
                    family_relations = db.query(UserRelationship).filter(
                        or_(
                            UserRelationship.user_id == user.id,
                            UserRelationship.related_user_id == user.id
                        ),
                        UserRelationship.relationship_type == "family",
                        UserRelationship.status == "accepted"
                    ).all()
                    
                    for rel in family_relations:
                        family_member_id = rel.related_user_id if rel.user_id == user.id else rel.user_id
                        await send_push_to_user(
                            db=db,
                            user_id=family_member_id,
                            title="家人年度体检提醒",
                            body=f"您的家人距上次体检已 {months_diff} 个月，建议提醒 TA 安排体检",
                            data={
                                "type": "family_annual_exam_reminder",
                                "family_member_id": user.id,
                                "months_since_exam": months_diff
                            },
                            reminder_type="annual_exam"
                        )
                    
                    reminder_count += 1
                    logger.info(f"[年度体检提醒] user_id={user.id}, 距上次体检 {months_diff} 个月")
                    
            except Exception as e:
                logger.error(f"[年度体检提醒] 处理用户 {user.id} 失败: {e}")
        
        logger.info(f"[年度体检提醒] 检查完成，发送 {reminder_count} 条提醒")
        
    except Exception as e:
        logger.error(f"[年度体检提醒] 任务执行失败: {e}")
    finally:
        db.close()


async def check_followup_exam_reminders():
    """
    复查提醒：体检异常后，到期前 2 周、1 周、3 天、当天提醒
    
    每天执行一次，检查所有异常指标的复查日期：
    - 从 ExamMetric 中读取 is_abnormal=True 的指标
    - 根据 AI 建议的复查周期（存储在 compared_to_last 或 doctor_advice 中）
    - 在到期前 2 周、1 周、3 天、当天发送提醒
    """
    from shared.models.database import SessionLocal
    from shared.models.exam_models import ExamReport, ExamMetric
    from shared.models.social_models import UserRelationship
    from shared.services.push_service import send_push_to_user
    
    logger.info("[复查提醒] 开始检查")
    
    db = SessionLocal()
    try:
        today = date.today()
        
        # 查询所有有异常指标的报告
        abnormal_reports = db.query(ExamReport).filter(
            ExamReport.abnormal_count > 0
        ).all()
        
        reminder_count = 0
        
        for report in abnormal_reports:
            try:
                # 获取异常指标
                abnormal_metrics = db.query(ExamMetric).filter(
                    ExamMetric.report_id == report.id,
                    ExamMetric.is_abnormal == True
                ).all()
                
                if not abnormal_metrics:
                    continue
                
                # 复查日期：优先用上传时 AI 解析的 followup_date；无则按异常默认 90 天
                followup_date = report.followup_date or (
                    report.exam_date + timedelta(days=90)
                )

                # 计算距离复查日的天数
                days_until_followup = (followup_date - today).days
                
                # 在到期前 2 周、1 周、3 天、当天提醒
                should_remind = days_until_followup in [14, 7, 3, 0]
                
                if should_remind and days_until_followup >= 0:
                    # 构建提醒内容
                    abnormal_names = [m.metric_name for m in abnormal_metrics[:3]]  # 最多显示 3 个
                    abnormal_text = "、".join(abnormal_names)
                    
                    if days_until_followup == 0:
                        reminder_text = f"今天是复查日，建议复查{abnormal_text}"
                    else:
                        reminder_text = f"距复查还有 {days_until_followup} 天，建议复查{abnormal_text}"
                    
                    # 发送给用户本人
                    await send_push_to_user(
                        db=db,
                        user_id=report.user_id,
                        title="体检复查提醒",
                        body=reminder_text,
                        data={
                            "type": "followup_exam_reminder",
                            "report_id": report.id,
                            "days_until_followup": days_until_followup,
                            "abnormal_metrics": abnormal_names
                        },
                        reminder_type="followup_exam"
                    )
                    
                    # 通知所有家人
                    family_relations = db.query(UserRelationship).filter(
                        or_(
                            UserRelationship.user_id == report.user_id,
                            UserRelationship.related_user_id == report.user_id
                        ),
                        UserRelationship.relationship_type == "family",
                        UserRelationship.status == "accepted"
                    ).all()
                    
                    for rel in family_relations:
                        family_member_id = rel.related_user_id if rel.user_id == report.user_id else rel.user_id
                        await send_push_to_user(
                            db=db,
                            user_id=family_member_id,
                            title="家人体检复查提醒",
                            body=f"您的家人{reminder_text}",
                            data={
                                "type": "family_followup_exam_reminder",
                                "family_member_id": report.user_id,
                                "report_id": report.id,
                                "days_until_followup": days_until_followup
                            },
                            reminder_type="followup_exam"
                        )
                    
                    reminder_count += 1
                    logger.info(f"[复查提醒] user_id={report.user_id}, 距复查 {days_until_followup} 天")
                    
            except Exception as e:
                logger.error(f"[复查提醒] 处理报告 {report.id} 失败: {e}")
        
        logger.info(f"[复查提醒] 检查完成，发送 {reminder_count} 条提醒")
        
    except Exception as e:
        logger.error(f"[复查提醒] 任务执行失败: {e}")
    finally:
        db.close()


async def check_missing_exam_reminders():
    """
    未上传提醒：用户年龄 > 50 且从未上传体检报告
    
    每周 1 号执行一次，持续 1 个月（共 4 次）：
    - 查询年龄 > 50 且从未上传过体检报告的用户
    - 发送提醒"建议上传您的体检报告，AI 帮您分析健康状况"
    """
    from shared.models.database import SessionLocal
    from shared.models.user_models import User, UserProfile
    from shared.models.exam_models import ExamReport
    from shared.services.push_service import send_push_to_user
    
    logger.info("[未上传提醒] 开始检查")
    
    db = SessionLocal()
    try:
        # 查询最近 7 天活跃的用户
        cutoff_date = datetime.now() - timedelta(days=7)
        active_users = db.query(User).filter(User.last_login >= cutoff_date).all()
        
        reminder_count = 0
        
        for user in active_users:
            try:
                # 获取用户档案
                profile = db.query(UserProfile).filter(
                    UserProfile.user_id == user.id
                ).first()
                
                if not profile or not profile.birth_date:
                    continue
                
                # 计算年龄
                today = date.today()
                age = today.year - profile.birth_date.year
                if (today.month, today.day) < (profile.birth_date.month, profile.birth_date.day):
                    age -= 1
                
                # 只提醒年龄 > 50 的用户
                if age <= 50:
                    continue
                
                # 检查是否从未上传过体检报告
                has_report = db.query(ExamReport).filter(
                    ExamReport.user_id == user.id
                ).first()
                
                if has_report:
                    continue
                
                # 发送提醒
                await send_push_to_user(
                    db=db,
                    user_id=user.id,
                    title="体检报告上传提醒",
                    body="建议上传您的体检报告，AI 帮您分析健康状况",
                    data={
                        "type": "missing_exam_reminder",
                        "age": age
                    },
                    reminder_type="missing_exam"
                )
                
                reminder_count += 1
                logger.info(f"[未上传提醒] user_id={user.id}, 年龄 {age} 岁")
                
            except Exception as e:
                logger.error(f"[未上传提醒] 处理用户 {user.id} 失败: {e}")
        
        logger.info(f"[未上传提醒] 检查完成，发送 {reminder_count} 条提醒")
        
    except Exception as e:
        logger.error(f"[未上传提醒] 任务执行失败: {e}")
    finally:
        db.close()


def setup_exam_reminder_tasks(scheduler):
    """
    注册体检提醒定时任务到调度器
    
    Args:
        scheduler: APScheduler 实例
    """
    from apscheduler.triggers.cron import CronTrigger
    
    # 每月 1 号 09:00 检查年度体检提醒
    scheduler.add_job(
        check_annual_exam_reminders,
        trigger=CronTrigger(day=1, hour=9, minute=0),
        id="check_annual_exam_reminders",
        name="年度体检提醒检查",
        replace_existing=True
    )
    logger.info("年度体检提醒任务已注册 (每月 1 号 09:00)")
    
    # 每天 08:30 检查复查提醒
    scheduler.add_job(
        check_followup_exam_reminders,
        trigger=CronTrigger(hour=8, minute=30),
        id="check_followup_exam_reminders",
        name="复查提醒检查",
        replace_existing=True
    )
    logger.info("复查提醒任务已注册 (每天 08:30)")
    
    # 每周一 10:00 检查未上传提醒
    scheduler.add_job(
        check_missing_exam_reminders,
        trigger=CronTrigger(day_of_week='mon', hour=10, minute=0),
        id="check_missing_exam_reminders",
        name="未上传提醒检查",
        replace_existing=True
    )
    logger.info("未上传提醒任务已注册 (每周一 10:00)")
