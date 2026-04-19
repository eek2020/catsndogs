#!/usr/bin/env python3
"""Wipe the sandbox experiment contents.

Clears every promotable subdirectory under sandbox/ (scripts, scenes, assets,
resources, shaders, data) plus the `.experiment.json` manifest. Deliberately
KEEPS `project.godot`, `.godot/` (import cache), `README.md`, and `icon.svg`
so the sandbox project stays openable.

Designed to be called by /new-experiment. Pass --force to skip confirmation.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SANDBOX_DIR = REPO_ROOT / "sandbox"

CLEAN_DIRS = ("scripts", "scenes", "assets", "resources", "shaders", "data")
CLEAN_FILES = (".experiment.json",)


def _clear_dir(path: Path) -> int:
    """Remove every child of `path`, preserving the directory itself."""
    if not path.exists():
        return 0
    removed = 0
    for child in path.iterdir():
        if child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink()
        removed += 1
    return removed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    parser.add_argument("--force", action="store_true", help="Skip confirmation prompt")
    args = parser.parse_args(argv)

    if not SANDBOX_DIR.exists():
        print(f"error: {SANDBOX_DIR} not found", file=sys.stderr)
        return 2

    if not args.force:
        print(f"About to wipe contents of {SANDBOX_DIR}:")
        for d in CLEAN_DIRS:
            print(f"  - sandbox/{d}/*")
        for f in CLEAN_FILES:
            print(f"  - sandbox/{f}")
        reply = input("Proceed? [y/N]: ").strip().lower()
        if reply != "y":
            print("Aborted.")
            return 1

    total = 0
    for d in CLEAN_DIRS:
        total += _clear_dir(SANDBOX_DIR / d)
    for f in CLEAN_FILES:
        target = SANDBOX_DIR / f
        if target.exists():
            target.unlink()
            total += 1

    # Ensure the clean dirs still exist so next experiment can populate them.
    for d in CLEAN_DIRS:
        (SANDBOX_DIR / d).mkdir(parents=True, exist_ok=True)

    print(f"Sandbox reset. Removed {total} item(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
