"""
Utility helpers for synchronizing DNS changes with IPAM / documentation.

This version focuses on emitting Markdown snippets and logging; future
iterations can commit directly into the docs tree and open PRs.
"""

import logging
from datetime import datetime
from pathlib import Path
from typing import List

logger = logging.getLogger(__name__)

IPAM_FILE = Path("docs/IPAM_MASTER_INVENTORY.md")


def build_ipam_note(fqdn: str, content: str) -> str:
    """Return a short Markdown bullet describing the new record."""
    return (
        f"- {datetime.utcnow().isoformat()} UTC — Added `{fqdn}` → `{content}` via Holmes DNS Agent"
    )


def append_ipam_notes(notes: List[str]) -> None:
    """
    Append notes to IPAM master inventory under a dedicated appendix.
    If the file is missing, log a warning but do not raise.
    """
    if not IPAM_FILE.exists():
        logger.warning("IPAM file %s not found; skipping doc update.", IPAM_FILE)
        return

    try:
        content = IPAM_FILE.read_text(encoding="utf-8")
        sentinel = "\n## 📌 DNS Automation Notes\n"
        if sentinel not in content:
            content = content.rstrip() + sentinel + "\n"
        new_content = content + "\n".join(notes) + "\n"
        IPAM_FILE.write_text(new_content, encoding="utf-8")
        logger.info("Appended IPAM notes for %d change(s).", len(notes))
    except Exception as exc:
        logger.error("Failed to append IPAM notes: %s", exc)


