#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#     "lz4",
# ]
# ///

import json
import lz4.block
import glob
import os
from pathlib import Path


def get_zen_profile_path():
    """Find the most recent Zen profile in ~/.config/zen."""
    zen_dir = Path.home() / ".config" / "zen"

    if not zen_dir.exists():
        return None

    # Find all profile directories (exclude Profile Groups and config files)
    profile_dirs = [
        d
        for d in zen_dir.iterdir()
        if d.is_dir() and d.name not in ("Profile Groups", "profiles.ini")
    ]

    if not profile_dirs:
        return None

    # Sort by modification time and return the most recent
    return max(profile_dirs, key=lambda d: d.stat().st_mtime)


def get_tab_count():
    """Count tabs in the most recent Zen browser profile."""
    profile_path = get_zen_profile_path()

    if not profile_path:
        return "Error: Could not find Zen profile."

    # Zen uses sessionstore-backups/recovery.jsonlz4
    session_file = profile_path / "sessionstore-backups" / "recovery.jsonlz4"

    if not session_file.exists():
        return f"Error: Could not find session file in {profile_path.name}"

    try:
        with open(session_file, "rb") as f:
            magic = f.read(8)
            if magic != b"mozLz40\0":
                return "Error: Not a valid Zen lz4 file."

            # Decompress the remaining content
            decompressed = lz4.block.decompress(f.read())
            data = json.loads(decompressed)

            # Sum tabs across all open windows
            return sum(len(win["tabs"]) for win in data.get("windows", []))
    except Exception as e:
        return f"Error reading file: {e}"


if __name__ == "__main__":
    count = get_tab_count()
    profile_name = get_zen_profile_path().name if get_zen_profile_path() else "Unknown"
    print(f"{profile_name}: Current Zen Tabs: {count}")
