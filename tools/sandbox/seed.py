#!/usr/bin/env python3
"""Seed the sandbox with selected subtrees from the main project.

Example:
  python3 tools/sandbox/seed.py --from assets/tiles --from assets/characters

Each `--from <relpath>` is resolved against godot/ and copied to the same
relative path under sandbox/. Existing files in the destination are skipped
unless --overwrite is given. Deliberately one-shot: later sandbox edits do
NOT propagate back to godot/ -- that's what /promote-experiment is for.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SANDBOX_DIR = REPO_ROOT / "sandbox"
MAIN_DIR = REPO_ROOT / "godot"


def _copy_tree(src: Path, dst: Path, overwrite: bool) -> tuple[int, int]:
    """Copy `src` -> `dst`. Returns (copied, skipped)."""
    copied = 0
    skipped = 0
    if src.is_file():
        if dst.exists() and not overwrite:
            return 0, 1
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        return 1, 0

    for path in src.rglob("*"):
        if path.is_dir():
            continue
        rel = path.relative_to(src)
        target = dst / rel
        if target.exists() and not overwrite:
            skipped += 1
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        copied += 1
    return copied, skipped


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    parser.add_argument(
        "--from",
        dest="sources",
        action="append",
        required=True,
        help="Relative path under godot/ to copy into sandbox/ (repeatable)",
    )
    parser.add_argument("--overwrite", action="store_true", help="Replace files that already exist in sandbox/")
    args = parser.parse_args(argv)

    total_copied = 0
    total_skipped = 0
    for rel in args.sources:
        src = MAIN_DIR / rel
        dst = SANDBOX_DIR / rel
        if not src.exists():
            print(f"warn: {src} not found, skipping", file=sys.stderr)
            continue
        c, s = _copy_tree(src, dst, args.overwrite)
        total_copied += c
        total_skipped += s
        print(f"  {rel}: copied={c} skipped={s}")

    print(f"Done. Copied {total_copied} file(s). Skipped {total_skipped}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
