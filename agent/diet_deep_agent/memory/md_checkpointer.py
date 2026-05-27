"""
MarkdownCheckpointSaver - StateBackend 的底层持久化实现

将 LangGraph 检查点写入 MD 文件，每个 thread 一个目录：
  sessions/{thread_id}/checkpoint.md  — 序列化状态（YAML frontmatter + base64）
  sessions/{thread_id}/messages.md    — 人类可读对话记录
"""

import base64
import json
import logging
from collections.abc import Iterator, Sequence
from datetime import datetime
from pathlib import Path
from typing import Any, Optional

import yaml
from langchain_core.runnables import RunnableConfig
from langgraph.checkpoint.base import (
    BaseCheckpointSaver,
    ChannelVersions,
    Checkpoint,
    CheckpointMetadata,
    CheckpointTuple,
)

from agent.diet_deep_agent.memory.namespaces import SESSIONS_DIR

logger = logging.getLogger(__name__)


class MarkdownCheckpointSaver(BaseCheckpointSaver):
    """
    StateBackend 的底层持久化实现。

    将图执行状态持久化为 MD 文件：
    - checkpoint.md: 序列化图状态 (frontmatter + typed-serialized payload)
    - messages.md: 人类可读对话记录

    使用 serde.dumps_typed / loads_typed 与 LangGraph 运行时保持兼容。

    物理路径: {base_path}/{user_id}/sessions/{thread_id}/
    """

    def __init__(self, base_path: str = "agents/UserMemory"):
        super().__init__()
        self.base_path = Path(base_path)

    def _get_session_dir(self, config: RunnableConfig) -> Path:
        """从 config 中提取 thread_id 和 user_id，构造会话目录路径"""
        configurable = config.get("configurable", {})
        thread_id = configurable.get("thread_id", "default")
        user_id = configurable.get("user_id", "default")
        return self.base_path / str(user_id) / SESSIONS_DIR / str(thread_id)

    # ─── 核心接口实现 ───

    def get_tuple(self, config: RunnableConfig) -> Optional[CheckpointTuple]:
        """从 checkpoint.md 恢复检查点"""
        session_dir = self._get_session_dir(config)
        checkpoint_file = session_dir / "checkpoint.md"

        if not checkpoint_file.exists():
            return None

        try:
            content = checkpoint_file.read_text(encoding="utf-8")
            frontmatter, serialized_data = self._parse_checkpoint_md(content)

            if not serialized_data:
                return None

            # 解析序列化数据（JSON 格式，包含 typed serde 信息）
            stored = json.loads(base64.b64decode(serialized_data))

            # 反序列化检查点（使用 typed serde）
            checkpoint_typed = (
                stored["checkpoint_type"],
                base64.b64decode(stored["checkpoint_data"]),
            )
            checkpoint: Checkpoint = self.serde.loads_typed(checkpoint_typed)

            # 反序列化 metadata
            metadata_typed = (
                stored["metadata_type"],
                base64.b64decode(stored["metadata_data"]),
            )
            metadata: CheckpointMetadata = self.serde.loads_typed(metadata_typed)

            # 构造 parent_config
            parent_config: Optional[RunnableConfig] = None
            parent_id = frontmatter.get("parent_checkpoint_id")
            if parent_id:
                parent_config = RunnableConfig(
                    configurable={
                        **config.get("configurable", {}),
                        "checkpoint_id": parent_id,
                    }
                )

            # 返回 config 需要包含 checkpoint_id
            result_config = RunnableConfig(
                configurable={
                    **config.get("configurable", {}),
                    "checkpoint_id": frontmatter.get("checkpoint_id", ""),
                }
            )

            return CheckpointTuple(
                config=result_config,
                checkpoint=checkpoint,
                metadata=metadata,
                parent_config=parent_config,
            )
        except Exception as e:
            logger.error(f"Error loading checkpoint from {checkpoint_file}: {e}")
            return None

    def put(
        self,
        config: RunnableConfig,
        checkpoint: Checkpoint,
        metadata: CheckpointMetadata,
        new_versions: ChannelVersions,
    ) -> RunnableConfig:
        """写入 checkpoint.md + 更新 messages.md"""
        session_dir = self._get_session_dir(config)
        session_dir.mkdir(parents=True, exist_ok=True)

        # 生成 checkpoint_id
        checkpoint_id = checkpoint.get("id", datetime.now().isoformat())

        # 使用 typed serde 序列化（与 LangGraph 运行时兼容）
        cp_type, cp_data = self.serde.dumps_typed(checkpoint)
        md_type, md_data = self.serde.dumps_typed(metadata)

        # 打包为 JSON → base64 存储
        stored = json.dumps({
            "checkpoint_type": cp_type,
            "checkpoint_data": base64.b64encode(cp_data).decode("ascii"),
            "metadata_type": md_type,
            "metadata_data": base64.b64encode(md_data).decode("ascii"),
        })
        serialized = base64.b64encode(stored.encode("utf-8")).decode("ascii")

        # 父 checkpoint_id
        parent_id = config.get("configurable", {}).get("checkpoint_id")

        # 写入 checkpoint.md
        checkpoint_md = self._render_checkpoint_md(
            config, checkpoint, metadata, serialized, checkpoint_id, parent_id
        )
        (session_dir / "checkpoint.md").write_text(
            checkpoint_md, encoding="utf-8"
        )

        # 写入 messages.md（人类可读）
        messages_md = self._render_messages_md(checkpoint)
        if messages_md:
            (session_dir / "messages.md").write_text(
                messages_md, encoding="utf-8"
            )

        # 返回新 config（包含新 checkpoint_id）
        return RunnableConfig(
            configurable={
                **config.get("configurable", {}),
                "checkpoint_id": checkpoint_id,
            }
        )

    def put_writes(
        self,
        config: RunnableConfig,
        writes: Sequence[tuple[str, Any]],
        task_id: str,
        task_path: str = "",
    ) -> None:
        """写入中间状态（pending writes）- 目前不需要持久化"""
        pass

    def list(
        self,
        config: Optional[RunnableConfig],
        *,
        filter: Optional[dict[str, Any]] = None,
        before: Optional[RunnableConfig] = None,
        limit: Optional[int] = None,
    ) -> Iterator[CheckpointTuple]:
        """遍历 sessions/ 目录，列出会话检查点"""
        if config is None:
            return

        configurable = config.get("configurable", {})
        user_id = configurable.get("user_id", "default")
        sessions_dir = self.base_path / str(user_id) / SESSIONS_DIR

        if not sessions_dir.exists():
            return

        count = 0
        for session_dir in sorted(sessions_dir.iterdir(), reverse=True):
            if not session_dir.is_dir():
                continue
            if limit is not None and count >= limit:
                break

            thread_id = session_dir.name
            session_config: RunnableConfig = RunnableConfig(
                configurable={
                    **configurable,
                    "thread_id": thread_id,
                }
            )

            result = self.get_tuple(session_config)
            if result:
                yield result
                count += 1

    def delete_thread(self, thread_id: str) -> None:
        """删除整个会话目录"""
        if not self.base_path.exists():
            return
        for user_dir in self.base_path.iterdir():
            if user_dir.is_dir():
                session_dir = user_dir / SESSIONS_DIR / thread_id
                if session_dir.exists():
                    import shutil
                    shutil.rmtree(session_dir)
                    logger.info(f"Deleted session: {session_dir}")

    # ─── MD 渲染辅助方法 ───

    def _render_checkpoint_md(
        self,
        config: RunnableConfig,
        checkpoint: Checkpoint,
        metadata: CheckpointMetadata,
        serialized: str,
        checkpoint_id: str,
        parent_id: Optional[str],
    ) -> str:
        """渲染 checkpoint.md 内容"""
        configurable = config.get("configurable", {})
        now = datetime.now().isoformat()

        # frontmatter 只放可读的元信息（不放 metadata 原始数据，那个在 serialized 里）
        frontmatter = {
            "thread_id": configurable.get("thread_id", ""),
            "checkpoint_id": checkpoint_id,
            "parent_checkpoint_id": parent_id,
            "created_at": now,
            "last_updated": now,
        }

        channel_values = checkpoint.get("channel_values", {})
        messages = channel_values.get("messages", [])
        message_count = len(messages) if isinstance(messages, list) else 0

        fm_yaml = yaml.dump(frontmatter, allow_unicode=True, default_flow_style=False)

        return f"""---
{fm_yaml.strip()}
---

# 检查点状态

## 通道摘要
- messages: {message_count} 条
- channels: {len(channel_values)} 个

<!-- SERIALIZED_STATE_START
{serialized}
SERIALIZED_STATE_END -->
"""

    def _render_messages_md(self, checkpoint: Checkpoint) -> Optional[str]:
        """渲染 messages.md（人类可读对话记录）"""
        channel_values = checkpoint.get("channel_values", {})
        messages = channel_values.get("messages", [])

        if not messages or not isinstance(messages, list):
            return None

        configurable_id = checkpoint.get("id", "unknown")
        now = datetime.now().isoformat()

        lines = [
            "---",
            f'checkpoint_id: "{configurable_id}"',
            f"message_count: {len(messages)}",
            f'last_updated: "{now}"',
            "---",
            "",
            "# 对话记录",
            "",
        ]

        for msg in messages:
            if hasattr(msg, "type"):
                role = "用户" if msg.type == "human" else "AI"
                content = msg.content if hasattr(msg, "content") else str(msg)
            elif isinstance(msg, dict):
                role_raw = msg.get("type", msg.get("role", "unknown"))
                role = "用户" if role_raw in ("human", "user") else "AI"
                content = msg.get("content", "")
            else:
                continue

            timestamp = datetime.now().strftime("%H:%M")
            lines.append(f"## [{timestamp}] {role}")
            lines.append(str(content)[:500])
            lines.append("")

        return "\n".join(lines)

    def _parse_checkpoint_md(self, content: str) -> tuple[dict, Optional[str]]:
        """解析 checkpoint.md，提取 frontmatter 和序列化数据"""
        frontmatter = {}
        serialized = None

        if content.startswith("---"):
            parts = content.split("---", 2)
            if len(parts) >= 3:
                try:
                    frontmatter = yaml.safe_load(parts[1]) or {}
                except yaml.YAMLError as e:
                    logger.warning(f"Failed to parse checkpoint frontmatter: {e}")

        start_marker = "<!-- SERIALIZED_STATE_START\n"
        end_marker = "\nSERIALIZED_STATE_END -->"

        start_idx = content.find(start_marker)
        end_idx = content.find(end_marker)

        if start_idx != -1 and end_idx != -1:
            serialized = content[start_idx + len(start_marker) : end_idx].strip()

        return frontmatter, serialized
