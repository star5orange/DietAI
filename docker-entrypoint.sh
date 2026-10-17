#!/bin/sh
# 镜像模式入口脚本。
# 两件事：① RS256 模式下就地生成 JWT 密钥对（.pem 属凭据、严禁进镜像）；
#         ② 以平台下发的端口启动 uvicorn（端口由部署单/deploy.yml 决定，见 $PORT）。
set -e

APP_DIR=/app
ALG="${DIETAI_JWT_ALGORITHM:-RS256}"

if [ "$ALG" = "RS256" ]; then
  if [ ! -s "$APP_DIR/jwtrs256-key.pem" ] || [ ! -s "$APP_DIR/jwtrs256-key.pub" ]; then
    echo "[entrypoint] 生成 RS256 JWT 密钥对（幂等：已存在则复用）"
    python -c "from cryptography.hazmat.primitives.asymmetric import rsa; from cryptography.hazmat.primitives import serialization as s; k=rsa.generate_private_key(public_exponent=65537,key_size=2048); open('$APP_DIR/jwtrs256-key.pem','wb').write(k.private_bytes(s.Encoding.PEM,s.PrivateFormat.PKCS8,s.NoEncryption())); open('$APP_DIR/jwtrs256-key.pub','wb').write(k.public_key().public_bytes(s.Encoding.PEM,s.PublicFormat.SubjectPublicKeyInfo))"
  fi
fi

PORT="${PORT:-19002}"
echo "[entrypoint] 启动 uvicorn main:app，监听 0.0.0.0:${PORT}"
exec uvicorn main:app --host 0.0.0.0 --port "$PORT"
