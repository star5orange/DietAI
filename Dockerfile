# DietAI 后端镜像（平台「镜像化部署」契约：外层 tar.gz 内含 image.tar + deploy.yml）
# 基础镜像走国内镜像源（本机直连 registry-1.docker.io 不可达；
# daocloud 对 python 清单返回 502，改用 1panel 源，实测可拉取）。
FROM docker.1panel.live/library/python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=120 \
    PATH="/app/.local/bin:${PATH}"

WORKDIR /app

# 依赖层单独一层：源码改动不会让依赖层失效
COPY requirements.txt /app/requirements.txt
RUN pip install --retries 5 --timeout 120 \
      --index-url https://pypi.tuna.tsinghua.edu.cn/simple \
      --extra-index-url https://mirrors.aliyun.com/pypi/simple/ \
      -r /app/requirements.txt

# 应用源码（.dockerignore 已排除 4.7GB 的 Flutter 源码与全部凭据）
COPY . /app/

RUN mkdir -p /app/logs /app/agents/VectorStore /app/avatar_output \
    && chmod +x /app/docker-entrypoint.sh

# 容器内监听端口（对外由平台 nginx 承担，如 9002 → 19002）
EXPOSE 19002

# 入口脚本负责：生成 RS256 密钥对 + 以 $PORT 启动 uvicorn
ENTRYPOINT ["/app/docker-entrypoint.sh"]
