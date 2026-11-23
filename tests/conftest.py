# -*- coding: utf-8 -*-
"""V6 测试公共 fixtures

约定：
- 独立测试数据库 dietai_test_db（不存在时自动创建），绝不碰 dietai_db
- 每个用例包在事务里，测试结束回滚，用例互不污染
- Redis 用内存桩替换（版本号测试不污染开发环境缓存）
- app 的 get_db 依赖被覆写到测试会话，TestClient 走完整请求链但用测试库
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.engine import make_url
from fastapi.testclient import TestClient

from shared.models.database import Base, get_db
from shared.models.user_models import User
from shared.models.family_models import FamilyMember
from shared.models.device_models import Device
from shared.config.settings import get_settings

settings = get_settings()

TEST_DB_NAME = "dietai_test_db"

# 遗留测试：测的收藏匹配逻辑已从 record_food.py 移除（agent 包无 SavedMeal 引用），
# 导入已失效，跳过收集；待功能去向明确后重写或删除
collect_ignore = ["test_record_food_saved_meal.py"]
TEST_DB_MEMORY_MARK = object()  # 占位，避免误用


# ============================================================
# 测试数据库（session 级，只建一次）
# ============================================================

def _ensure_test_database():
    url = make_url(settings.database_url)
    admin_url = url.set(database="postgres")
    admin_engine = create_engine(admin_url, isolation_level="AUTOCOMMIT")
    with admin_engine.connect() as conn:
        exists = conn.execute(
            text("SELECT 1 FROM pg_database WHERE datname = :name"), {"name": TEST_DB_NAME}
        ).first()
        if not exists:
            conn.execute(text(f'CREATE DATABASE "{TEST_DB_NAME}"'))
    admin_engine.dispose()


_ensure_test_database()

_test_url = make_url(settings.database_url).set(database=TEST_DB_NAME)
# 注意：str(URL) 会把密码渲染成 ***，必须用 render_as_string(hide_password=False)
TEST_DATABASE_URL = _test_url.render_as_string(hide_password=False)
test_engine = create_engine(TEST_DATABASE_URL, pool_pre_ping=True)
TestSessionFactory = sessionmaker(bind=test_engine)


@pytest.fixture(scope="session", autouse=True)
def _create_all_tables():
    """建全部表（与 alembic 结构一致即可满足测试；用 metadata 建表避免依赖迁移状态）"""
    Base.metadata.create_all(test_engine)
    yield
    Base.metadata.drop_all(test_engine)


# ============================================================
# Redis 内存桩（autouse）
# ============================================================

class InMemoryRedis:
    """RedisManager 接口的最小内存实现（get/set/exists/incr）"""

    def __init__(self):
        self.store = {}

    def get(self, key):
        return self.store.get(key)

    def set(self, key, value, expire=None):
        self.store[key] = str(value)
        return True

    def exists(self, key):
        return key in self.store

    def incr(self, key):
        current = int(self.store.get(key, 0)) + 1
        self.store[key] = str(current)
        return current


@pytest.fixture(autouse=True)
def stub_redis(monkeypatch):
    """替换 family_member_service 的 redis_manager，版本号测试不出进程"""
    import shared.services.family_member_service as svc

    stub = InMemoryRedis()

    class _StubManager:
        def get_client(self):
            return stub

    monkeypatch.setattr(svc, "redis_manager", _StubManager())
    yield stub


# ============================================================
# 数据库会话（每用例事务回滚）+ get_db 覆写
# ============================================================

@pytest.fixture
def db_session():
    connection = test_engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection, join_transaction_mode="create_savepoint")
    # 供 client fixture 给"自建 SessionLocal 的端点"派生代理会话（同一连接，可见性一致）
    globals()["_test_connection"] = connection
    try:
        yield session
    finally:
        session.close()
        transaction.rollback()
        connection.close()


@pytest.fixture
def client(db_session):
    """TestClient：get_db 覆写到测试会话；不触发 app lifespan（不启动调度器）"""
    from main import app
    import routers.food_router as food_router_module

    def _override_get_db():
        yield db_session

    # food_router 的传统端点/SSE 生成器刻意绕开 DI 自建 SessionLocal（线程安全历史原因），
    # 且结束时会对该会话执行 close()。给它们派生绑在同一连接上的独立代理会话：
    # 能看见用例数据、其 commit/close 不影响用例自己的 db_session
    original_session_local = food_router_module.SessionLocal

    def _proxy_session():
        return Session(
            bind=globals()["_test_connection"],
            join_transaction_mode="create_savepoint",
        )

    food_router_module.SessionLocal = _proxy_session

    app.dependency_overrides[get_db] = _override_get_db
    c = TestClient(app)  # 不用上下文管理器，避免触发 app lifespan（调度器等重启动逻辑）
    yield c
    food_router_module.SessionLocal = original_session_local
    app.dependency_overrides.pop(get_db, None)


# ============================================================
# 业务 fixtures：测试家庭 / 用户令牌 / 设备
# ============================================================

@pytest.fixture
def family_user(db_session):
    """家庭主账号（成员记录全部落它名下）"""
    user = User(username="test_family_user", password_hash="x", status=1)
    db_session.add(user)
    db_session.commit()
    return user


@pytest.fixture
def family(family_user, db_session):
    """3 人测试家庭：奶奶(老人) / 爸爸(成人) / 小宝(儿童)"""
    members = []
    specs = [
        {"display_name": "奶奶", "alias": "妈,妈妈,老妈", "member_type": 1, "sort_order": 1},
        {"display_name": "爸爸", "alias": "老爸,爹", "member_type": 0, "sort_order": 2},
        {"display_name": "小宝", "alias": "宝宝,儿子", "member_type": 2, "sort_order": 3},
    ]
    for spec in specs:
        m = FamilyMember(home_user_id=family_user.id, **spec)
        db_session.add(m)
        members.append(m)
    db_session.commit()
    return {"user": family_user, "members": members}


@pytest.fixture
def user_token(family_user):
    """App 用户 JWT"""
    from shared.utils.auth import AuthService

    return AuthService.create_access_token({"sub": str(family_user.id)})


def _make_device(db_session, user, *, device_type="robot", locked_member=None, key_suffix=""):
    """造一台已绑定设备并颁发 device_token"""
    from shared.services.device_service import _create_device_token

    device = Device(
        user_id=user.id,
        home_user_id=user.id,
        device_key=f"TEST:00:00:00:00:{key_suffix or '01'}",
        is_bound=True,
        device_type=device_type,
        locked_member_id=locked_member.id if locked_member else None,
    )
    db_session.add(device)
    db_session.flush()
    device.device_token = _create_device_token(device.id, user.id)
    db_session.commit()
    return device


@pytest.fixture
def robot_device(family_user, db_session):
    """机器人设备（一家一机，无锁定成员，当前成员空）"""
    return _make_device(db_session, family_user, device_type="robot")


@pytest.fixture
def clock_device(family_user, family, db_session):
    """时钟设备（一人一机，锁定奶奶）"""
    return _make_device(
        db_session, family_user, device_type="clock",
        locked_member=family["members"][0], key_suffix="02",
    )


@pytest.fixture
def device_token(robot_device):
    return robot_device.device_token
