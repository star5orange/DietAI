"""
MarkdownStore - StoreBackend 的底层持久化实现

将 Agent 的 /memories/* 虚拟路径转换为 MD 文件读写操作，
复用现有 MemoryManager 的目录结构。

数据流：
  Agent write_file("/memories/profile.md", content)
    → StoreBackend → store.put(namespace, key="profile.md", value={"content": ...})
    → MarkdownStore.batch([PutOp(...)]) → MemoryManager 写入物理 MD 文件
"""

import asyncio
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Optional

from langgraph.store.base import (
    BaseStore,
    GetOp,
    Item,
    ListNamespacesOp,
    Op,
    PutOp,
    Result,
    SearchItem,
    SearchOp,
)

from agents.chat_agent.diet_deep_agent.memory.namespaces import (
    MEMORIES_DIR,
)

logger = logging.getLogger(__name__)


class MarkdownStore(BaseStore):
    """
    StoreBackend 的底层持久化实现。

    将 Store 操作映射为 MD 文件读写，适配现有 MemoryManager 的工作区结构。

    Namespace 约定:
      ("memories", "{user_id}") → agent/UserMemory/{user_id}/memories/
    """

    def __init__(self, base_path: str = "agents/UserMemory"):
        self.base_path = Path(base_path)

    def _resolve_path(self, namespace: tuple[str, ...], key: str) -> Path:
        """将 namespace + key 映射为物理 MD 文件路径"""
        # namespace 格式: ("memories", "{user_id}") 或更多层级
        if len(namespace) >= 2:
            user_id = namespace[1]
        else:
            user_id = "default"

        # key 即文件名，如 "profile.md"
        return self.base_path / str(user_id) / MEMORIES_DIR / key

    def _read_file(self, path: Path) -> Optional[str]:
        """同步读取 MD 文件"""
        if not path.exists():
            return None
        try:
            return path.read_text(encoding="utf-8")
        except Exception as e:
            logger.error(f"Error reading {path}: {e}")
            return None

    def _write_file(self, path: Path, content: str) -> None:
        """同步写入 MD 文件"""
        path.parent.mkdir(parents=True, exist_ok=True)
        try:
            path.write_text(content, encoding="utf-8")
            logger.info(f"Wrote store file: {path}")
        except Exception as e:
            logger.error(f"Error writing {path}: {e}")
            raise

    def _delete_file(self, path: Path) -> None:
        """同步删除 MD 文件"""
        try:
            if path.exists():
                path.unlink()
                logger.info(f"Deleted store file: {path}")
        except Exception as e:
            logger.error(f"Error deleting {path}: {e}")
            raise

    def _make_item(
        self, namespace: tuple[str, ...], key: str, content: str
    ) -> Item:
        """从文件内容构造 Item"""
        now = datetime.now(tz=timezone.utc)
        return Item(
            value={"content": content},
            key=key,
            namespace=namespace,
            created_at=now,
            updated_at=now,
        )

    def batch(self, ops: Iterable[Op]) -> list[Result]:
        """同步批量执行 Store 操作"""
        results: list[Result] = []

        for op in ops:
            if isinstance(op, GetOp):
                path = self._resolve_path(op.namespace, op.key)
                content = self._read_file(path)
                if content is not None:
                    results.append(self._make_item(op.namespace, op.key, content))
                else:
                    results.append(None)

            elif isinstance(op, PutOp):
                if op.value is None:
                    # Delete operation
                    path = self._resolve_path(op.namespace, op.key)
                    self._delete_file(path)
                else:
                    path = self._resolve_path(op.namespace, op.key)
                    content = op.value.get("content", "")
                    self._write_file(path, content)
                results.append(None)

            elif isinstance(op, SearchOp):
                items = self._search_files(op.namespace_prefix, op.limit, op.offset)
                results.append(items)

            elif isinstance(op, ListNamespacesOp):
                namespaces = self._list_namespaces(op)
                results.append(namespaces)

            else:
                results.append(None)

        return results

    async def abatch(self, ops: Iterable[Op]) -> list[Result]:
        """异步批量执行（委派给同步实现）"""
        return await asyncio.get_event_loop().run_in_executor(
            None, self.batch, list(ops)
        )

    def _search_files(
        self,
        namespace_prefix: tuple[str, ...],
        limit: int = 10,
        offset: int = 0,
    ) -> list[SearchItem]:
        """列出指定 namespace 下的所有 MD 文件"""
        if len(namespace_prefix) >= 2:
            user_id = namespace_prefix[1]
        else:
            user_id = "default"

        memories_dir = self.base_path / str(user_id) / MEMORIES_DIR
        if not memories_dir.exists():
            return []

        items: list[SearchItem] = []
        md_files = sorted(memories_dir.glob("*.md"))

        for md_file in md_files[offset : offset + limit]:
            content = self._read_file(md_file)
            if content:
                now = datetime.now(tz=timezone.utc)
                items.append(
                    SearchItem(
                        value={"content": content},
                        key=md_file.name,
                        namespace=namespace_prefix,
                        created_at=now,
                        updated_at=now,
                        score=1.0,
                    )
                )

        return items

    def _list_namespaces(self, op: ListNamespacesOp) -> list[tuple[str, ...]]:
        """列出所有用户的 namespace"""
        if not self.base_path.exists():
            return []

        namespaces = []
        for user_dir in self.base_path.iterdir():
            if user_dir.is_dir():
                memories_dir = user_dir / MEMORIES_DIR
                if memories_dir.exists():
                    ns = (MEMORIES_DIR, user_dir.name)
                    namespaces.append(ns)

        return namespaces[op.offset : op.offset + op.limit]
