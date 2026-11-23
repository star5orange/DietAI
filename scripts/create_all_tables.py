"""建全套表 —— 供部署平台的 database.migrate 步骤使用。

平台的运行账号只有 DML 权限、没有建表权限，所以表必须在这一步（以持 DDL 的迁移账号）
建好；应用启动时的 create_tables() 只是兜底（失败不阻断启动）。

运行方式（平台执行 migrate 时会把制品自带 venv 的 bin 放上 PATH）：
    python scripts/create_all_tables.py
"""
import os
import sys

# 允许以 `python scripts/create_all_tables.py` 直接从发布根运行
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _bootstrap_runtime_requirements() -> None:
    """让本脚本在「裸跑」下也自给自足。

    平台执行建表命令时会绕过镜像的 docker-entrypoint.sh（实测 order 59：
    直接 `python scripts/create_all_tables.py`），于是 RS256 模式必需的
    jwtrs256-key.pem/.pub 不存在，settings 在 import 期即抛 ValueError：

        settings.py: settings = get_settings()
        ValueError: RS256 模式下必须设置 JWT 密钥对文件

    这里复刻 entrypoint 的幂等生成逻辑；并给字段加密密钥兜个临时值
    （建表只用到列类型，不写任何业务数据，真实密钥由运行期 shared/.env 提供）。
    """
    if os.environ.get("DIETAI_JWT_ALGORITHM", "RS256") == "RS256":
        priv, pub = "jwtrs256-key.pem", "jwtrs256-key.pub"
        if not (os.path.getsize(priv) if os.path.exists(priv) else 0) or not (os.path.getsize(pub) if os.path.exists(pub) else 0):
            import base64 as _b64  # noqa: PLC0415

            from cryptography.hazmat.primitives import serialization  # noqa: PLC0415
            from cryptography.hazmat.primitives.asymmetric import rsa  # noqa: PLC0415

            key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
            with open(priv, "wb") as fh:
                fh.write(
                    key.private_bytes(
                        serialization.Encoding.PEM,
                        serialization.PrivateFormat.PKCS8,
                        serialization.NoEncryption(),
                    )
                )
            with open(pub, "wb") as fh:
                fh.write(
                    key.public_key().public_bytes(
                        serialization.Encoding.PEM,
                        serialization.PublicFormat.SubjectPublicKeyInfo,
                    )
                )
            print("[create_all_tables] 已就地生成临时 RS256 密钥对（弃用，不参与运行期）")
    if not os.environ.get("DIETAI_FIELD_ENCRYPTION_KEY"):
        import base64 as _b64  # noqa: PLC0415

        os.environ["DIETAI_FIELD_ENCRYPTION_KEY"] = _b64.b64encode(os.urandom(32)).decode()


_bootstrap_runtime_requirements()

from shared.models import (  # noqa: E402
    user_models,
    food_models,
    food_label_models,
    conversation_models,
    saved_meal_models,
    exercise_models,
    water_models,
    reminder_models,
    notification_models,
    wellness_models,
    social_models,
    message_models,
    exam_models,
    proxy_models,
    device_models,
    pet_models,
    achievement_models,
    fasting_models,
    advisor_models,
)
from shared.models.database import create_tables, engine  # noqa: E402


def main() -> None:
    print(f"[create_all_tables] 目标库: {engine.url.render_as_string(hide_password=True)}")
    create_tables()
    print(f"[create_all_tables] 建表完成（方言: {engine.dialect.name}）")


if __name__ == "__main__":
    main()
