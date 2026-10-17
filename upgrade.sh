#!/usr/bin/env bash
# DietAI 制品自带的依赖安装脚本（幂等，重复执行不报错）。
# 平台部署时会在 release 根执行本脚本；venv 必须落在 $RELEASE_DIR/.venv，
# 引擎按 {release}/.venv/bin/python 启动服务。
set -euo pipefail

RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$RELEASE_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"

if [ ! -x "$RELEASE_DIR/.venv/bin/python" ]; then
  echo "[upgrade.sh] 创建 venv: $RELEASE_DIR/.venv"
  "$PYTHON_BIN" -m venv "$RELEASE_DIR/.venv"
fi

VENV_PY="$RELEASE_DIR/.venv/bin/python"

# 目标机多在国内：没有显式指定镜像时走清华源，避免 PyPI 直连超时。
# 再挂一个独立同步的国内镜像兜底：单个镜像同步滞后时（实测清华源上一次解析
# coverage==7.13.4 返回 "from versions: none"），不至于把整个部署卡死。
if [ -n "${PIP_INDEX_URL:-}" ]; then
  PIP_INDEX_ARGS=(--index-url "$PIP_INDEX_URL")
else
  PIP_INDEX_ARGS=(
    --index-url https://pypi.tuna.tsinghua.edu.cn/simple
    --extra-index-url https://mirrors.aliyun.com/pypi/simple/
  )
fi
PIP_NET_ARGS=(--retries 3 --timeout 60 --disable-pip-version-check)

"$VENV_PY" -m pip install "${PIP_NET_ARGS[@]}" "${PIP_INDEX_ARGS[@]}" --upgrade pip >/dev/null

echo "[upgrade.sh] 安装依赖（首次较慢，约 200 个钉死版本的包）"
"$VENV_PY" -m pip install "${PIP_NET_ARGS[@]}" "${PIP_INDEX_ARGS[@]}" -r "$RELEASE_DIR/requirements.txt"

# RS256 模式要求密钥对文件存在，而 .pem 属于凭据、严禁进包（平台会拦），
# 因此在目标机首次部署时就地生成一对：幂等，已存在则复用，重复部署不会换密钥。
# 服务与 database.migrate 的 workdir 都是发布根，所以默认的相对路径正好落在这里。
JWT_KEY="$RELEASE_DIR/jwtrs256-key.pem"
JWT_PUB="$RELEASE_DIR/jwtrs256-key.pub"
if [ ! -s "$JWT_KEY" ] || [ ! -s "$JWT_PUB" ]; then
  echo "[upgrade.sh] 生成 RS256 JWT 密钥对（.pem 不进制品，只落在目标机）"
  JWT_KEY_OUT="$JWT_KEY" JWT_PUB_OUT="$JWT_PUB" "$VENV_PY" - <<'PY'
import os

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
with open(os.environ["JWT_KEY_OUT"], "w", encoding="utf-8") as f:
    f.write(key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode())
with open(os.environ["JWT_PUB_OUT"], "w", encoding="utf-8") as f:
    f.write(key.public_key().public_bytes(
        serialization.Encoding.PEM,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode())
PY
  chmod 600 "$JWT_KEY"
  chmod 644 "$JWT_PUB"
fi

echo "[upgrade.sh] 完成: $RELEASE_DIR/.venv"
