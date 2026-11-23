# -*- coding: utf-8 -*-
"""V6 联调种子脚本：造一个 3 人测试家庭（老人/成人/儿童）

用途：
  1. 硬件联调前准备测试数据（契约"联调环境约定"：成员 3 人）
  2. App 端成员管理 / 归属纠错 / 对账测试

用法：
  python scripts/seed_family_members.py                # 自动创建测试账号 family_test
  python scripts/seed_family_members.py --user-id 1    # 挂到已有用户名下
  python scripts/seed_family_members.py --reset        # 先清掉该家庭的种子成员再重建

幂等：同名成员已存在则跳过，可重复执行。
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from shared.models.database import SessionLocal
from shared.models.user_models import User
from shared.models.family_models import FamilyMember
from shared.utils.auth import AuthService

TEST_USERNAME = "family_test"
TEST_PASSWORD = "dietai123"

# 3 人测试家庭：老人 / 成人 / 儿童
# default_member_id = 首个创建的成员 → 奶奶（sort_order 1）
SEED_MEMBERS = [
    {
        "display_name": "奶奶",
        "alias": "妈,妈妈,老妈",
        "birth_year": 1952,
        "member_type": 1,   # 老人
        "is_managed": True,
        "sort_order": 1,
    },
    {
        "display_name": "爸爸",
        "alias": "老爸,爹",
        "birth_year": 1978,
        "member_type": 0,   # 成人
        "is_managed": False,
        "sort_order": 2,
    },
    {
        "display_name": "小宝",
        "alias": "宝宝,儿子",
        "birth_year": 2019,
        "member_type": 2,   # 儿童
        "is_managed": True,
        "sort_order": 3,
    },
]


def get_or_create_user(db, user_id: int | None) -> User:
    if user_id is not None:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise SystemExit(f"[错误] user_id={user_id} 不存在")
        return user

    user = db.query(User).filter(User.username == TEST_USERNAME).first()
    if user:
        return user
    user = User(
        username=TEST_USERNAME,
        password_hash=AuthService.hash_password(TEST_PASSWORD),
        status=1,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    print(f"[种子] 已创建测试账号: {TEST_USERNAME} (id={user.id}, 密码 {TEST_PASSWORD})")
    return user


def main():
    parser = argparse.ArgumentParser(description="V6 家庭成员种子脚本")
    parser.add_argument("--user-id", type=int, default=None, help="挂到已有用户名下（默认创建/复用 family_test）")
    parser.add_argument("--reset", action="store_true", help="先删除该家庭下与种子同名的成员再重建")
    args = parser.parse_args()

    db = SessionLocal()
    try:
        user = get_or_create_user(db, args.user_id)

        if args.reset:
            names = [m["display_name"] for m in SEED_MEMBERS]
            deleted = (
                db.query(FamilyMember)
                .filter(
                    FamilyMember.home_user_id == user.id,
                    FamilyMember.display_name.in_(names),
                )
                .delete(synchronize_session=False)
            )
            db.commit()
            if deleted:
                print(f"[重置] 已删除 {deleted} 条同名种子成员")

        created, skipped = [], []
        for spec in SEED_MEMBERS:
            exists = (
                db.query(FamilyMember)
                .filter(
                    FamilyMember.home_user_id == user.id,
                    FamilyMember.display_name == spec["display_name"],
                )
                .first()
            )
            if exists:
                skipped.append(spec["display_name"])
                continue
            member = FamilyMember(home_user_id=user.id, **spec)
            db.add(member)
            db.flush()
            created.append((spec["display_name"], member.id))

        db.commit()

        total = (
            db.query(FamilyMember)
            .filter(FamilyMember.home_user_id == user.id)
            .count()
        )
        print(f"[完成] 家庭主账号: {user.username} (id={user.id})")
        for name, mid in created:
            print(f"  新建成员: {name} (id={mid})")
        for name in skipped:
            print(f"  已存在跳过: {name}")
        print(f"[统计] 该家庭现有成员 {total}/8")

        if total > 8:
            print("[警告] 成员数超过 8 人上限，接口层将拒绝继续创建")
    finally:
        db.close()


if __name__ == "__main__":
    main()
