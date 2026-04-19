#!/usr/bin/env python3
"""Sandbox -> main project promotion CLI.

Subcommands:
  scan       List changed/new files in sandbox/ vs godot/.
  map        Suggest a target path in godot/ for a sandbox file.
  deps       Scan selected sandbox files for res:// dependency refs.
  stage      Copy sandbox files into godot/ and `git add` them.
  revert     Undo a prior stage using a revert manifest.
  test-open  Run `godot --headless --quit` on godot/ to smoke the project.
  test-gut   Run the GUT unit-test suite headless.
  changelog  Prepend a dated stub entry to docs/changelog/CHANGELOG.md.
  codemap    Regenerate docs/architecture/CODEMAP.md via the .claude skill.

Designed to be driven by the /promote-experiment Windsurf workflow but every
subcommand is usable standalone. All output is JSON where practical so the
workflow can parse it cleanly; human-readable summaries go to stderr.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Iterable


# --------------------------------------------------------------------------- paths

REPO_ROOT = Path(__file__).resolve().parents[2]
SANDBOX_DIR = REPO_ROOT / "sandbox"
MAIN_DIR = REPO_ROOT / "godot"
LOG_DIR = REPO_ROOT / "logs"
LOG_FILE = LOG_DIR / "sandbox-promote.log"
GODOT_BIN = "/Applications/Godot.app/Contents/MacOS/Godot"

# Only these subdirs of sandbox/ are considered for promotion. Everything
# else (project.godot, .godot/, .experiment.json, README.md, etc.) is local
# to the sandbox project and never copied out.
PROMOTABLE_DIRS = ("scripts", "scenes", "assets", "resources", "shaders", "data")

# Skip these during scanning (generated, tooling, or noise).
SKIP_NAMES = {".DS_Store", ".godot", ".import"}
SKIP_SUFFIXES = {".import", ".uid"}  # Godot regenerates these from the source.


# --------------------------------------------------------------------------- logging

def _log(msg: str) -> None:
    """Append a timestamped line to the promote log, best-effort."""
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        stamp = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with LOG_FILE.open("a", encoding="utf-8") as fh:
            fh.write(f"[{stamp}] {msg}\n")
    except OSError:
        pass  # Never let logging crash the CLI.


def _eprint(*args, **kwargs) -> None:
    kwargs.setdefault("file", sys.stderr)
    print(*args, **kwargs)


# --------------------------------------------------------------------------- helpers

def _iter_files(root: Path) -> Iterable[Path]:
    """Yield every file under `root`, skipping junk names / suffixes."""
    if not root.exists():
        return
    for base in PROMOTABLE_DIRS:
        sub = root / base
        if not sub.exists():
            continue
        for path in sub.rglob("*"):
            if path.is_dir():
                continue
            if path.name in SKIP_NAMES:
                continue
            if any(part in SKIP_NAMES for part in path.parts):
                continue
            if path.suffix in SKIP_SUFFIXES:
                continue
            yield path


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _rel_sandbox(path: Path) -> str:
    return str(path.relative_to(SANDBOX_DIR))


def _rel_main(path: Path) -> str:
    return str(path.relative_to(MAIN_DIR))


def _sandbox_to_main(sandbox_path: Path) -> Path:
    """Trivial rewrite: sandbox/X -> godot/X."""
    rel = sandbox_path.relative_to(SANDBOX_DIR)
    return MAIN_DIR / rel


def _git(*args: str, cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    result = subprocess.run(
        ["git", *args],
        cwd=str(cwd or REPO_ROOT),
        capture_output=True,
        text=True,
    )
    if check and result.returncode != 0:
        _log(f"git {' '.join(args)} FAILED: {result.stderr.strip()}")
        raise SystemExit(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result


# --------------------------------------------------------------------------- scan

def cmd_scan(args: argparse.Namespace) -> int:
    """Diff sandbox/ vs godot/ and emit a list of promotion candidates."""
    entries = []
    for src in _iter_files(SANDBOX_DIR):
        target = _sandbox_to_main(src)
        rel = _rel_sandbox(src)
        if not target.exists():
            entries.append(
                {
                    "source": rel,
                    "target": _rel_main(target),
                    "status": "NEW",
                    "size": src.stat().st_size,
                }
            )
            continue
        if _sha256(src) == _sha256(target):
            continue  # UNCHANGED -- nothing to do.
        entries.append(
            {
                "source": rel,
                "target": _rel_main(target),
                "status": "MODIFIED",
                "size": src.stat().st_size,
            }
        )

    payload = {"sandbox": str(SANDBOX_DIR), "main": str(MAIN_DIR), "entries": entries}
    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        if not entries:
            _eprint("No promotion candidates. Sandbox matches godot/ for all tracked dirs.")
        else:
            _eprint(f"Found {len(entries)} promotion candidate(s):")
            for e in entries:
                _eprint(f"  [{e['status']:<8}] {e['source']}  ->  godot/{e['target']}")
    _log(f"scan: {len(entries)} candidate(s)")
    return 0


# --------------------------------------------------------------------------- map

def cmd_map(args: argparse.Namespace) -> int:
    src = Path(args.sandbox_path)
    if not src.is_absolute():
        src = (REPO_ROOT / src).resolve()
    if SANDBOX_DIR not in src.parents:
        _eprint(f"error: {src} is not inside {SANDBOX_DIR}")
        return 2
    target = _sandbox_to_main(src)
    print(str(target.relative_to(REPO_ROOT)))
    return 0


# --------------------------------------------------------------------------- deps

# Matches `preload("res://...")`, `load("res://...")`, and any `path="res://..."`
# attribute in .tscn/.tres files. Kept deliberately simple -- false positives
# are preferable to missed refs since the workflow asks you about each one.
RES_REF_RE = re.compile(r'res://[^"\'\s\)]+')


def _scan_refs(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    return sorted(set(RES_REF_RE.findall(text)))


def _resolve_res(ref: str, staged_targets: set[str]) -> str:
    """Return RESOLVED / MISSING / STAGED for a res:// reference."""
    rel = ref[len("res://"):]
    if rel in staged_targets:
        return "STAGED"
    if (MAIN_DIR / rel).exists():
        return "RESOLVED"
    return "MISSING"


def cmd_deps(args: argparse.Namespace) -> int:
    pairs = _load_pairs(args.pairs) if args.pairs else None
    if pairs is not None:
        sources = [SANDBOX_DIR / p["source"] for p in pairs]
        staged_targets = {p["target"] for p in pairs}
    else:
        sources = [Path(p) if Path(p).is_absolute() else (REPO_ROOT / p) for p in args.paths]
        staged_targets = set()

    report = []
    for src in sources:
        refs = _scan_refs(src)
        if not refs:
            continue
        file_entry = {"source": str(src.relative_to(REPO_ROOT)), "refs": []}
        for ref in refs:
            status = _resolve_res(ref, staged_targets)
            file_entry["refs"].append({"ref": ref, "status": status})
        report.append(file_entry)

    missing = [r for f in report for r in f["refs"] if r["status"] == "MISSING"]

    if args.json:
        print(json.dumps({"files": report, "missing_count": len(missing)}, indent=2))
    else:
        if not report:
            _eprint("No res:// refs found in provided sources.")
        else:
            for f in report:
                _eprint(f"{f['source']}:")
                for r in f["refs"]:
                    _eprint(f"  [{r['status']:<8}] {r['ref']}")
        _eprint(f"\n{len(missing)} MISSING ref(s).")
    _log(f"deps: {len(report)} file(s), {len(missing)} missing")
    return 0


# --------------------------------------------------------------------------- stage / revert

def _load_pairs(path: str) -> list[dict]:
    raw = json.loads(Path(path).read_text(encoding="utf-8"))
    if isinstance(raw, dict) and "pairs" in raw:
        raw = raw["pairs"]
    if not isinstance(raw, list):
        raise SystemExit(f"{path}: expected a JSON list or {{'pairs': [...]}}")
    out = []
    for p in raw:
        if "source" not in p or "target" not in p:
            raise SystemExit(f"{path}: every pair needs 'source' and 'target'")
        out.append({"source": p["source"], "target": p["target"]})
    return out


def cmd_stage(args: argparse.Namespace) -> int:
    pairs = _load_pairs(args.pairs)
    revert_entries = []
    staged = []
    for pair in pairs:
        src = SANDBOX_DIR / pair["source"]
        tgt = MAIN_DIR / pair["target"]
        if not src.exists():
            _eprint(f"warn: source missing, skipping: {src}")
            continue

        pre_existed = tgt.exists()
        pre_hash = _sha256(tgt) if pre_existed else None

        tgt.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, tgt)

        _git("add", "--", str(tgt.relative_to(REPO_ROOT)))

        revert_entries.append(
            {
                "target": str(tgt.relative_to(REPO_ROOT)),
                "pre_existed": pre_existed,
                "pre_hash": pre_hash,
            }
        )
        staged.append(pair["target"])

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    manifest_path = Path(args.manifest) if args.manifest else LOG_DIR / "sandbox-revert.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest = {
        "created": _dt.datetime.now().isoformat(timespec="seconds"),
        "entries": revert_entries,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    summary = {"staged": staged, "revert_manifest": str(manifest_path)}
    if args.json:
        print(json.dumps(summary, indent=2))
    else:
        _eprint(f"Staged {len(staged)} file(s). Revert manifest: {manifest_path}")
        for t in staged:
            _eprint(f"  + godot/{t}")
    _log(f"stage: {len(staged)} file(s), manifest={manifest_path}")
    return 0


def cmd_revert(args: argparse.Namespace) -> int:
    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    entries = manifest.get("entries", [])
    reverted = []
    for entry in entries:
        target_rel = entry["target"]
        abs_target = REPO_ROOT / target_rel

        # Always unstage first.
        _git("restore", "--staged", "--", target_rel, check=False)

        if entry["pre_existed"]:
            # Restore original working tree content from HEAD.
            _git("restore", "--", target_rel, check=False)
        else:
            # File was created by us -- delete it outright.
            if abs_target.exists():
                abs_target.unlink()
        reverted.append(target_rel)

    if args.json:
        print(json.dumps({"reverted": reverted}, indent=2))
    else:
        _eprint(f"Reverted {len(reverted)} file(s).")
        for t in reverted:
            _eprint(f"  - {t}")
    _log(f"revert: {len(reverted)} file(s) from {args.manifest}")
    return 0


# --------------------------------------------------------------------------- test gates

def _run_gate(cmd: list[str], cwd: Path, label: str) -> int:
    """Run a gate command, stream output to the log, return exit code."""
    _log(f"{label}: starting -> {' '.join(cmd)} (cwd={cwd})")
    try:
        result = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)
    except FileNotFoundError as exc:
        _eprint(f"{label}: command not found -- {exc}")
        _log(f"{label}: FileNotFoundError {exc}")
        return 127
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as fh:
        fh.write(f"--- {label} stdout ---\n{result.stdout}\n")
        fh.write(f"--- {label} stderr ---\n{result.stderr}\n")
    _log(f"{label}: exit={result.returncode}")
    # Echo the tail so the workflow surfaces useful context on failure.
    if result.returncode != 0:
        tail = "\n".join((result.stdout + "\n" + result.stderr).splitlines()[-20:])
        _eprint(f"{label} FAILED (exit={result.returncode}). Tail:\n{tail}")
    return result.returncode


def cmd_test_open(args: argparse.Namespace) -> int:
    cmd = [GODOT_BIN, "--headless", "--path", str(MAIN_DIR), "--quit"]
    rc = _run_gate(cmd, REPO_ROOT, "test-open")
    if args.json:
        print(json.dumps({"gate": "test-open", "exit": rc}, indent=2))
    return rc


def cmd_test_gut(args: argparse.Namespace) -> int:
    cmd = [
        GODOT_BIN,
        "--headless",
        "-s",
        "addons/gut/gut_cmdln.gd",
        "-gdir=res://tests/unit",
        "-gexit",
    ]
    rc = _run_gate(cmd, MAIN_DIR, "test-gut")
    if args.json:
        print(json.dumps({"gate": "test-gut", "exit": rc}, indent=2))
    return rc


# --------------------------------------------------------------------------- changelog / codemap

CHANGELOG_PATH = REPO_ROOT / "docs" / "changelog" / "CHANGELOG.md"


def cmd_changelog(args: argparse.Namespace) -> int:
    if not CHANGELOG_PATH.exists():
        _eprint(f"error: {CHANGELOG_PATH} not found")
        return 2

    files: list[str] = []
    if args.files_from:
        pairs = _load_pairs(args.files_from)
        files = [p["target"] for p in pairs]

    today = _dt.date.today().isoformat()
    lines = [
        f"## {today} - Sandbox promotion: {args.summary}",
        "",
        "### Files promoted",
        "",
    ]
    if files:
        for f in files:
            lines.append(f"- `godot/{f}`")
    else:
        lines.append("- _(no files recorded; promotion manifest not supplied)_")
    lines.append("")
    lines.append("### Notes")
    lines.append("")
    lines.append("- Auto-generated stub from `tools/sandbox/promote.py changelog`. Edit before committing.")
    lines.append("")
    stub = "\n".join(lines) + "\n"

    existing = CHANGELOG_PATH.read_text(encoding="utf-8")
    CHANGELOG_PATH.write_text(stub + existing, encoding="utf-8")
    _eprint(f"Prepended stub entry to {CHANGELOG_PATH}.")
    _log(f"changelog: prepended '{args.summary}' with {len(files)} file(s)")
    return 0


def cmd_codemap(args: argparse.Namespace) -> int:
    script = REPO_ROOT / ".claude" / "skills" / "codemap" / "generate.sh"
    if not script.exists():
        _eprint(f"error: {script} not found")
        return 2
    rc = _run_gate(["bash", str(script)], REPO_ROOT, "codemap")
    if args.json:
        print(json.dumps({"gate": "codemap", "exit": rc}, indent=2))
    return rc


# --------------------------------------------------------------------------- arg parsing

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="promote.py", description=__doc__.split("\n\n", 1)[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("scan", help="Diff sandbox/ vs godot/")
    s.add_argument("--json", action="store_true", help="Emit JSON on stdout")
    s.set_defaults(func=cmd_scan)

    s = sub.add_parser("map", help="Suggest godot/ target path for a sandbox file")
    s.add_argument("sandbox_path")
    s.set_defaults(func=cmd_map)

    s = sub.add_parser("deps", help="Scan sandbox files for res:// refs")
    s.add_argument("paths", nargs="*", help="Paths (absolute or repo-relative) to scan")
    s.add_argument("--pairs", help="Path to a pairs.json; overrides positional paths")
    s.add_argument("--json", action="store_true")
    s.set_defaults(func=cmd_deps)

    s = sub.add_parser("stage", help="Copy sandbox files into godot/ and git-add them")
    s.add_argument("--pairs", required=True, help="pairs.json with [{source,target},...]")
    s.add_argument("--manifest", help="Output revert manifest path")
    s.add_argument("--json", action="store_true")
    s.set_defaults(func=cmd_stage)

    s = sub.add_parser("revert", help="Undo a previous stage using its manifest")
    s.add_argument("--manifest", required=True)
    s.add_argument("--json", action="store_true")
    s.set_defaults(func=cmd_revert)

    s = sub.add_parser("test-open", help="Headless godot --quit on godot/")
    s.add_argument("--json", action="store_true")
    s.set_defaults(func=cmd_test_open)

    s = sub.add_parser("test-gut", help="Headless GUT unit test run")
    s.add_argument("--json", action="store_true")
    s.set_defaults(func=cmd_test_gut)

    s = sub.add_parser("changelog", help="Prepend a dated stub entry to CHANGELOG.md")
    s.add_argument("--summary", required=True)
    s.add_argument("--files-from", help="pairs.json to lift the file list from")
    s.set_defaults(func=cmd_changelog)

    s = sub.add_parser("codemap", help="Regenerate docs/architecture/CODEMAP.md")
    s.add_argument("--json", action="store_true")
    s.set_defaults(func=cmd_codemap)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args) or 0


if __name__ == "__main__":
    raise SystemExit(main())
