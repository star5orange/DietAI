"""
MarkdownStore - StoreBackend 的底层持久化实现

将 Agent 的 /memories/* 虚拟路径转换为 MD 文件读写操作，
复用现有 MemoryManager 的目录结构。

数据流：
  Agent write_file("/memories/profile.md", content)
    → StoreBackend → store.put(namespace, key, value={"content": [行...], ...})
    → MarkdownStore.batch([PutOp(...)]) → 写入物理 MD 文件

value 协议（deepagents >= 0.4 的 StoreBackend 强校验，见 backends/store.py）：
  {"content": list[str]（按 "\n" 切分的行）, "created_at": ISO 字符串, "modified_at": ISO 字符串}
  写入时 SDK 传 list，落到 MD 文件需还原成文本；读回/搜索时反之必须还原成 list，
  否则 SDK 侧 _convert_store_item_to_file_data 会直接抛 ValueError。
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

from agent.diet_deep_agent.memory.namespaces import (
    MEMORIES_DIR,
    VIRTUAL_FILE_TO_WORKSPACE,
)

logger = logging.getLogger(__name__)


def _memory_manager(user_id: str):
    """按 user_id 取 MemoryManager（失败返回 None，走兜底目录）"""
    try:
        from agent.memory.memory_manager import MemoryManager

        return MemoryManager(int(user_id))
    except Exception:
        return None


class MarkdownStore(BaseStore):
    """
    StoreBackend 的底层持久化实现。

    将 Store 操作映射为 MD 文件读写，适配现有 MemoryManager 的工作区结构。

    Namespace 约定:
      ("memories", "{user_id}")
        → 已登记的虚拟文件落到 MemoryManager 工作区文件（单一事实来源，
          与 chat / goal_tracking 等链路共用同一份用户记忆）
        → 未登记的文件落到 {base_path}/{user_id}/memories/
    """

    def __init__(self, base_path: str = "agents/UserMemory"):
        self.base_path = Path(base_path)

    def _resolve_path(self, namespace: tuple[str, ...], key: str) -> Path:
        """将 namespace + key 映射为物理 MD 文件路径。

        StoreBackend 经 CompositeBackend 路由后，key 是已剥离路径前缀的绝对路径
        （如 "/profile.md"），这里只取文件名，避免拼出仓库之外的路径。
        """
        # namespace 格式: ("memories", "{user_id}") 或更多层级
        if len(namespace) >= 2:
            user_id = namespace[1]
        else:
            user_id = "default"

        filename = key.replace("\\", "/").rstrip("/").split("/")[-1] or "untitled.md"

        manager = _memory_manager(str(user_id))
        if manager is not None:
            workspace = VIRTUAL_FILE_TO_WORKSPACE.get(filename)
            if workspace:
                try:
                    return manager.get_workspace_path(workspace)
                except ValueError:
                    pass  # 未登记的 workspace → 走兜底目录
            return manager.user_dir / MEMORIES_DIR / filename

        return self.base_path / str(user_id) / MEMORIES_DIR / filename

    def _iter_entries(self, user_id: str) -> list[tuple[str, Path]]:
        """列出该用户所有记忆文件：(虚拟文件名, 物理路径)"""
        entries: list[tuple[str, Path]] = []
        manager = _memory_manager(user_id)

        if manager is not None:
            for filename, workspace in VIRTUAL_FILE_TO_WORKSPACE.items():
                try:
                    entries.append((filename, manager.get_workspace_path(workspace)))
                except ValueError:
                    continue
            fallback_dir = manager.user_dir / MEMORIES_DIR
        else:
            fallback_dir = self.base_path / str(user_id) / MEMORIES_DIR

        if fallback_dir.exists():
            known = {p for _, p in entries}
            for md_file in sorted(fallback_dir.glob("*.md")):
                if md_file not in known:
                    entries.append((md_file.name, md_file))

        entries.sort(key=lambda item: item[0])
        return entries

    def _read_file(self, path: Path) -> Optional[str]:
        """同步读取 MD 文件"""
        if not path.exists():
            return None
        try:
            return path.read_text(encoding="utf-8")
        except Exception as e:
            logger.error(f"Error reading {path}: {e}")
            return None

    def _write_file(self, path: Path, content: Any) -> None:
        """同步写入 MD 文件（SDK 传的是按行切分的 list，需还原为文本）"""
        path.parent.mkdir(parents=True, exist_ok=True)
        text = (
            content
            if isinstance(content, str)
            else "\n".join(str(line) for line in content or [])
        )
        try:
            path.write_text(text, encoding="utf-8")
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

    @staticmethod
    def _store_value(content: str) -> dict[str, Any]:
        """按 StoreBackend 协议构造 value（content 为行列表；时间戳为 ISO 字符串）"""
        iso_now = datetime.now(tz=timezone.utc).isoformat()
        return {
            "content": content.split("\n"),
            "created_at": iso_now,
            "modified_at": iso_now,
        }

    def _make_item(
        self, namespace: tuple[str, ...], key: str, content: str
    ) -> Item:
        """从文件内容构造 Item（value 字段需符合 SDK 的 FileData 协议）"""
        now = datetime.now(tz=timezone.utc)
        return Item(
            value=self._store_value(content),
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
        """列出指定 namespace 下的所有 MD 文件（工作区文件 + 兜底目录）"""
        if len(namespace_prefix) >= 2:
            user_id = namespace_prefix[1]
        else:
            user_id = "default"

        items: list[SearchItem] = []
        for filename, path in self._iter_entries(str(user_id))[offset : offset + limit]:
            content = self._read_file(path)
            if content:
                now = datetime.now(tz=timezone.utc)
                items.append(
                    SearchItem(
                        value=self._store_value(content),
                        # key 需为后端内部根路径（与 read/write 传入的 "/xxx.md" 一致）
                        key=f"/{filename}",
                        namespace=namespace_prefix,
                        created_at=now,
                        updated_at=now,
                        score=1.0,
                    )
                )

        return items

    def _list_namespaces(self, op: ListNamespacesOp) -> list[tuple[str, ...]]:
        """列出所有用户的 namespace"""
        from agent.memory.memory_manager import MemoryManager

        root = MemoryManager.BASE_PATH
        if not root.exists():
            return []

        namespaces = []
        for user_dir in root.iterdir():
            if user_dir.is_dir():
                ns = (MEMORIES_DIR, user_dir.name)
                namespaces.append(ns)

        return namespaces[op.offset : op.offset + op.limit]
