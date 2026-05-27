"""
Memory Manager - Core read/write manager for multi-workspace memory files.

Provides:
- Multi-workspace file management (shared, goal_tracking, nutrition, chat)
- Async read/write operations
- Section-based incremental updates
- Agent-specific context retrieval
- Directory structure management
"""

import asyncio
import aiofiles
import yaml
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any, List, Union
import logging
import re

from agent.memory.schemas import (
    SharedMemoryData,
    GoalTrackingData,
    NutritionWorkspaceData,
    ChatWorkspaceData,
    UserMemoryData
)

logger = logging.getLogger(__name__)


class MemoryManager:
    """
    多工作区记忆管理器

    Manages user memory files across multiple workspaces:
    - shared/user_memory.md: Shared workspace (all agents read-only)
    - goal_tracking/user_goals.md: Goal Agent workspace (read/write)
    - nutrition/user_nutrition.md: Nutrition Agent workspace (read/write)
    - chat/user_chat.md: Chat Agent workspace (read/write)
    """

    BASE_PATH = Path("agent/UserMemory")

    WORKSPACES = {
        "shared": "shared/user_memory.md",
        "goal_tracking": "goal_tracking/user_goals.md",
        "nutrition": "nutrition/user_nutrition.md",
        "chat": "chat/user_chat.md"
    }

    # Agent type to readable workspaces mapping
    AGENT_WORKSPACES = {
        "goal_tracking": ["shared", "goal_tracking"],
        "nutrition": ["shared", "nutrition"],
        "chat": ["shared", "chat"],
        "all": ["shared", "goal_tracking", "nutrition", "chat"]
    }

    def __init__(self, user_id: int):
        """
        Initialize MemoryManager for a specific user.

        Args:
            user_id: User ID
        """
        self.user_id = user_id
        self.user_dir = self.BASE_PATH / str(user_id)

    def ensure_directories(self) -> None:
        """
        Ensure user's workspace directories exist.
        Creates the full directory structure if not present.
        """
        directories = [
            self.user_dir / "shared",
            self.user_dir / "goal_tracking",
            self.user_dir / "nutrition",
            self.user_dir / "chat",
            self.user_dir / "history"
        ]
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
        logger.debug(f"Ensured directories for user {self.user_id}")

    def get_workspace_path(self, workspace: str) -> Path:
        """
        Get the full path to a workspace file.

        Args:
            workspace: Workspace name (shared, goal_tracking, nutrition, chat)

        Returns:
            Full path to the workspace file
        """
        if workspace not in self.WORKSPACES:
            raise ValueError(f"Unknown workspace: {workspace}. Valid: {list(self.WORKSPACES.keys())}")
        return self.user_dir / self.WORKSPACES[workspace]

    async def read_workspace(self, workspace: str) -> Optional[str]:
        """
        Read the content of a workspace file.

        Args:
            workspace: Workspace name

        Returns:
            File content as string, or None if file doesn't exist
        """
        path = self.get_workspace_path(workspace)

        if not path.exists():
            logger.debug(f"Workspace file does not exist: {path}")
            return None

        try:
            async with aiofiles.open(path, 'r', encoding='utf-8') as f:
                content = await f.read()
            logger.debug(f"Read workspace {workspace} for user {self.user_id}")
            return content
        except Exception as e:
            logger.error(f"Error reading workspace {workspace}: {e}")
            return None

    async def write_workspace(self, workspace: str, content: str) -> bool:
        """
        Write content to a workspace file.

        Args:
            workspace: Workspace name
            content: Content to write

        Returns:
            True if successful, False otherwise
        """
        self.ensure_directories()
        path = self.get_workspace_path(workspace)

        try:
            async with aiofiles.open(path, 'w', encoding='utf-8') as f:
                await f.write(content)
            logger.info(f"Wrote workspace {workspace} for user {self.user_id}")
            return True
        except Exception as e:
            logger.error(f"Error writing workspace {workspace}: {e}")
            return False

    async def read_workspace_structured(self, workspace: str) -> Optional[Dict[str, Any]]:
        """
        Read and parse workspace file to extract YAML frontmatter and sections.

        Args:
            workspace: Workspace name

        Returns:
            Dictionary with 'frontmatter' and 'sections' keys
        """
        content = await self.read_workspace(workspace)
        if not content:
            return None

        return self._parse_markdown(content)

    def _parse_markdown(self, content: str) -> Dict[str, Any]:
        """
        Parse markdown content to extract frontmatter and sections.

        Args:
            content: Raw markdown content

        Returns:
            Dictionary with parsed data
        """
        result = {
            "frontmatter": {},
            "sections": {},
            "raw": content
        }

        # Extract YAML frontmatter
        frontmatter_match = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
        if frontmatter_match:
            try:
                result["frontmatter"] = yaml.safe_load(frontmatter_match.group(1)) or {}
            except yaml.YAMLError as e:
                logger.warning(f"Failed to parse YAML frontmatter: {e}")
            content = content[frontmatter_match.end():]

        # Extract sections (## headers)
        current_section = None
        current_content = []

        for line in content.split('\n'):
            if line.startswith('## '):
                if current_section:
                    result["sections"][current_section] = '\n'.join(current_content).strip()
                current_section = line[3:].strip()
                current_content = []
            else:
                current_content.append(line)

        if current_section:
            result["sections"][current_section] = '\n'.join(current_content).strip()

        return result

    async def update_section(
        self,
        workspace: str,
        section: str,
        content: str,
        replace: bool = True
    ) -> bool:
        """
        Update a specific section in a workspace file.

        Args:
            workspace: Workspace name
            section: Section name (e.g., "健康目标与进度")
            content: New content for the section
            replace: If True, replace section; if False, append

        Returns:
            True if successful
        """
        current = await self.read_workspace(workspace)

        if not current:
            # Create new file with section
            new_content = f"## {section}\n{content}\n"
            return await self.write_workspace(workspace, new_content)

        # Find and replace/append section
        section_pattern = rf'(## {re.escape(section)}\n)(.*?)(?=\n## |\Z)'

        if re.search(section_pattern, current, re.DOTALL):
            if replace:
                new_content = re.sub(
                    section_pattern,
                    f'## {section}\n{content}\n',
                    current,
                    flags=re.DOTALL
                )
            else:
                # Append to existing section
                def append_content(match):
                    return f'{match.group(1)}{match.group(2).strip()}\n{content}\n'
                new_content = re.sub(section_pattern, append_content, current, flags=re.DOTALL)
        else:
            # Section doesn't exist, append at end
            new_content = current.rstrip() + f"\n\n## {section}\n{content}\n"

        # Update frontmatter timestamp
        new_content = self._update_frontmatter_timestamp(new_content)

        return await self.write_workspace(workspace, new_content)

    def _update_frontmatter_timestamp(self, content: str) -> str:
        """Update the last_updated field in frontmatter."""
        timestamp = datetime.now().isoformat()

        # Check if frontmatter exists
        if content.startswith('---\n'):
            # Update existing timestamp
            content = re.sub(
                r'(last_updated:\s*)[^\n]+',
                f'\\1"{timestamp}"',
                content
            )

        return content

    async def get_context_for_agent(self, agent_type: str) -> str:
        """
        Get combined context from all readable workspaces for an agent.

        Args:
            agent_type: Type of agent (goal_tracking, nutrition, chat)

        Returns:
            Combined markdown content from all readable workspaces
        """
        if agent_type not in self.AGENT_WORKSPACES:
            raise ValueError(f"Unknown agent type: {agent_type}")

        workspaces = self.AGENT_WORKSPACES[agent_type]
        contents = []

        for workspace in workspaces:
            content = await self.read_workspace(workspace)
            if content:
                # Add workspace header for clarity
                workspace_header = f"=== {workspace.upper()} WORKSPACE ===\n"
                contents.append(workspace_header + content)

        return "\n\n".join(contents) if contents else ""

    async def archive_snapshot(self, workspace: str = "all") -> bool:
        """
        Create a timestamped snapshot of workspace(s).

        Args:
            workspace: Workspace name or "all" for all workspaces

        Returns:
            True if successful
        """
        self.ensure_directories()
        history_dir = self.user_dir / "history"
        timestamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")

        workspaces = list(self.WORKSPACES.keys()) if workspace == "all" else [workspace]

        for ws in workspaces:
            content = await self.read_workspace(ws)
            if content:
                snapshot_path = history_dir / f"{ws}_{timestamp}.md"
                try:
                    async with aiofiles.open(snapshot_path, 'w', encoding='utf-8') as f:
                        await f.write(content)
                    logger.info(f"Created snapshot: {snapshot_path}")
                except Exception as e:
                    logger.error(f"Error creating snapshot for {ws}: {e}")
                    return False

        return True

    async def workspace_exists(self, workspace: str) -> bool:
        """Check if a workspace file exists."""
        path = self.get_workspace_path(workspace)
        return path.exists()

    async def get_all_workspaces(self) -> Dict[str, Optional[str]]:
        """
        Read all workspace files.

        Returns:
            Dictionary mapping workspace names to their content
        """
        result = {}
        for workspace in self.WORKSPACES:
            result[workspace] = await self.read_workspace(workspace)
        return result

    async def delete_workspace(self, workspace: str) -> bool:
        """
        Delete a workspace file.

        Args:
            workspace: Workspace name

        Returns:
            True if deleted or didn't exist
        """
        path = self.get_workspace_path(workspace)
        try:
            if path.exists():
                path.unlink()
                logger.info(f"Deleted workspace {workspace} for user {self.user_id}")
            return True
        except Exception as e:
            logger.error(f"Error deleting workspace {workspace}: {e}")
            return False

    @classmethod
    def get_all_user_ids(cls) -> List[int]:
        """
        Get all user IDs that have memory directories.

        Returns:
            List of user IDs
        """
        if not cls.BASE_PATH.exists():
            return []

        user_ids = []
        for item in cls.BASE_PATH.iterdir():
            if item.is_dir():
                try:
                    user_ids.append(int(item.name))
                except ValueError:
                    continue
        return user_ids

    async def get_workspace_metadata(self, workspace: str) -> Optional[Dict[str, Any]]:
        """
        Get metadata (frontmatter) from a workspace file.

        Args:
            workspace: Workspace name

        Returns:
            Frontmatter data as dictionary
        """
        parsed = await self.read_workspace_structured(workspace)
        return parsed["frontmatter"] if parsed else None
