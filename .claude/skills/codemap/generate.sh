#!/usr/bin/env bash
# Regenerate docs/architecture/CODEMAP.md from the current repo state.
# Deterministic: same input -> byte-identical output (no timestamp churn
# unless the repo actually changed).
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

OUT="docs/architecture/CODEMAP.md"
TMP=$(mktemp)

GODOT="godot"
EVENT_BUS="$GODOT/scripts/autoload/event_bus.gd"
PROJECT_CFG="$GODOT/project.godot"

# Derive "last changed" from the newest mtime of files we summarise, so the
# header updates only when real inputs change.
STAMP=$(find \
    "$GODOT/project.godot" \
    "$GODOT/scripts" \
    "$GODOT/scenes" \
    "$GODOT/data" \
    -type f \( -name '*.gd' -o -name '*.tscn' -o -name '*.json' -o -name 'project.godot' \) \
    -exec stat -f '%m' {} + 2>/dev/null \
    | sort -n | tail -1)
STAMP_ISO=$(date -r "$STAMP" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)

# --- Helpers ---------------------------------------------------------------

list_files() {
    # Usage: list_files <glob>
    # Prints paths sorted, relative to repo root.
    local pattern="$1"
    # shellcheck disable=SC2086
    find $pattern -type f 2>/dev/null | LC_ALL=C sort
}

md_link() {
    # Usage: md_link <label> <path>
    printf '[%s](../../%s)' "$1" "$2"
}

bullet_file() {
    # Usage: bullet_file <path>
    local path="$1"
    local name
    name=$(basename "$path")
    printf -- '- %s\n' "$(md_link "$name" "$path")"
}

# --- Write output ----------------------------------------------------------

{
cat <<HEADER
# Whisper Crystals — Code Map

> **Auto-generated.** Do not hand-edit. Regenerate via the \`codemap\` skill or
> \`bash .claude/skills/codemap/generate.sh\`.
>
> Inputs last changed: **${STAMP_ISO}**

Code-anchored index: every section links to real files. This is the
companion to [.claude/PROJECT_INDEX.md](../../.claude/PROJECT_INDEX.md)
(narrative project overview) and [CLAUDE.md](../../CLAUDE.md)
(architecture rules).

## Contents

- [Autoloads](#autoloads)
- [EventBus signals](#eventbus-signals)
- [Core](#core)
- [Entities](#entities)
- [Systems](#systems)
- [Cutscene subsystem](#cutscene-subsystem)
- [World layer](#world-layer)
- [ViewModels](#viewmodels)
- [UI screens](#ui-screens)
- [Scenes](#scenes)
- [Data files](#data-files)
- [Inventory](#inventory)

---

## Autoloads

Registered in [project.godot](../../${PROJECT_CFG}) under \`[autoload]\`.

| Singleton | Script |
|---|---|
HEADER

# Parse [autoload] section of project.godot
awk '
    /^\[autoload\]/ { inside=1; next }
    /^\[/ { inside=0 }
    inside && /=/ {
        name=$0; sub(/=.*/, "", name)
        path=$0; sub(/^[^=]*=/, "", path)
        gsub(/"/, "", path); sub(/^\*/, "", path); sub(/^res:\/\//, "godot/", path)
        if (name != "") printf "| `%s` | [%s](../../%s) |\n", name, path, path
    }
' "$PROJECT_CFG"

cat <<'SEC'

## EventBus signals

Single source of truth: [event_bus.gd](../../godot/scripts/autoload/event_bus.gd).
Groups match the `# --- Foo events ---` section headers in that file.
SEC

# Extract signal groups + signals with line numbers
awk '
    /^# --- .* ---$/ {
        group=$0; gsub(/^# --- | ---$/, "", group)
        printf "\n### %s\n\n", group
        next
    }
    /^signal / {
        sig=$2; gsub(/\(.*$/, "", sig)
        printf "- `%s` — [event_bus.gd:%d](../../godot/scripts/autoload/event_bus.gd#L%d)\n", sig, NR, NR
    }
' "$EVENT_BUS"

echo
echo "## Core"
echo
echo "Reusable primitives in \`godot/scripts/core/\`."
echo
while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$GODOT/scripts/core/*.gd")

echo
echo "## Entities"
echo
echo "Data models in \`godot/scripts/entities/\`."
echo
while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$GODOT/scripts/entities/*.gd")

echo
echo "## Systems"
echo
echo "Gameplay systems in \`godot/scripts/systems/\` (excluding cutscene subsystem)."
echo
while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$GODOT/scripts/systems/*.gd")

echo
echo "## Cutscene subsystem"
echo
echo "3D / scripted-cutscene pieces under \`godot/scripts/systems/cutscene/\`."
echo
while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$GODOT/scripts/systems/cutscene/*.gd")

echo
echo "## World layer"
echo
echo "Player / NPC / scene-transition controllers in \`godot/scripts/world/\`."
echo
while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$GODOT/scripts/world/*.gd")

cat <<'SEC'

## ViewModels

Per-screen RefCounted wrappers around `GameSession` — the only layer allowed
to touch the session autoload. See CLAUDE.md → "UI ↔ GameSession coupling via
ViewModels".

| ViewModel | Screen controller | Scene |
|---|---|---|
SEC

# Pair each VM with its screen script + scene
while IFS= read -r vm; do
    base=$(basename "$vm" .gd)
    screen_base=${base%_view_model}
    screen_script=""
    for candidate in "$GODOT/scripts/ui/${screen_base}.gd" \
                     "$GODOT/scripts/ui/${screen_base}_screen.gd" \
                     "$GODOT/scripts/ui/${screen_base}_ui.gd"; do
        [ -f "$candidate" ] && screen_script="$candidate" && break
    done
    scene=""
    for candidate in "$GODOT/scenes/ui/${screen_base}.tscn" \
                     "$GODOT/scenes/ui/${screen_base}_screen.tscn" \
                     "$GODOT/scenes/ui/${screen_base}_ui.tscn"; do
        [ -f "$candidate" ] && scene="$candidate" && break
    done
    vm_cell="[$(basename "$vm")](../../$vm)"
    screen_cell="${screen_script:+[$(basename "$screen_script")](../../${screen_script})}"
    screen_cell=${screen_cell:--}
    scene_cell="${scene:+[$(basename "$scene")](../../${scene})}"
    scene_cell=${scene_cell:--}
    printf "| %s | %s | %s |\n" "$vm_cell" "$screen_cell" "$scene_cell"
done < <(list_files "$GODOT/scripts/ui/view_models/*.gd")

cat <<'SEC'

## UI screens

All UI controllers in `godot/scripts/ui/` (top-level). Subfolders
(`combat/`, `star_map/`, `view_models/`) are listed separately.
SEC
echo
while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$GODOT/scripts/ui/*.gd")

echo
echo "### UI subfolder: combat"
echo
while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$GODOT/scripts/ui/combat/*.gd")

echo
echo "### UI subfolder: star_map"
echo
while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$GODOT/scripts/ui/star_map/*.gd")

cat <<'SEC'

## Scenes

### Entry point

- [main.tscn](../../godot/scenes/main.tscn) — set as `run/main_scene` in project.godot

### UI scenes
SEC
echo
while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$GODOT/scenes/ui/*.tscn")

echo
echo "### World scenes"
echo
while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$GODOT/scenes/world/*.tscn")

echo
echo "### Cutscene scenes"
echo
while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$GODOT/scenes/cutscenes/*.tscn")

cat <<'SEC'

## Data files

All JSON content lives under `godot/data/`. Each subfolder is one category.
SEC

# One section per data subfolder (sorted)
while IFS= read -r dir; do
    sub=$(basename "$dir")
    echo
    echo "### data/$sub"
    echo
    while IFS= read -r f; do bullet_file "$f"; done < <(list_files "$dir/*.json")
done < <(find "$GODOT/data" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort)

# --- Counts ---------------------------------------------------------------

AUTOLOAD_COUNT=$(awk '/^\[autoload\]/{f=1;next} /^\[/{f=0} f && /=/' "$PROJECT_CFG" | wc -l | tr -d ' ')
SIGNAL_COUNT=$(grep -c '^signal ' "$EVENT_BUS" || true)
SYSTEM_COUNT=$(list_files "$GODOT/scripts/systems/*.gd" | wc -l | tr -d ' ')
UI_COUNT=$(list_files "$GODOT/scripts/ui/*.gd" | wc -l | tr -d ' ')
VM_COUNT=$(list_files "$GODOT/scripts/ui/view_models/*.gd" | wc -l | tr -d ' ')
SCENE_COUNT=$(find "$GODOT/scenes" -name '*.tscn' -type f | wc -l | tr -d ' ')
DATA_COUNT=$(find "$GODOT/data" -name '*.json' -type f | wc -l | tr -d ' ')

cat <<FOOTER

## Inventory

| Category | Count |
|---|---|
| Autoloads | ${AUTOLOAD_COUNT} |
| EventBus signals | ${SIGNAL_COUNT} |
| Systems | ${SYSTEM_COUNT} |
| UI screens (top-level) | ${UI_COUNT} |
| ViewModels | ${VM_COUNT} |
| Scenes | ${SCENE_COUNT} |
| Data JSON files | ${DATA_COUNT} |
FOOTER

} > "$TMP"

mkdir -p "$(dirname "$OUT")"
if [ -f "$OUT" ] && cmp -s "$TMP" "$OUT"; then
    rm "$TMP"
    echo "codemap: no changes ($OUT)"
else
    mv "$TMP" "$OUT"
    echo "codemap: wrote $OUT"
fi
