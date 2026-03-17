#!/usr/bin/env bash
# Capture screenshots from a Godot test script.
#
# Usage: screenshot.sh <task_folder> <test_script> [frame_count] [fps]
#   task_folder  - subfolder name under screenshots/ (e.g., task_01_terrain)
#   test_script  - path to test GDScript (e.g., test/test_task.gd)
#   frame_count  - number of frames to capture (default: 30)
#   fps          - fixed FPS (default: 10; use 1 for static scenes)
#
# On macOS, uses Godot's native rendering directly.
# On Linux, detects GPU via gpu_detect.sh and falls back to xvfb.

set -euo pipefail

TASK_FOLDER="${1:?Usage: screenshot.sh <task_folder> <test_script> [frame_count] [fps]}"
TEST_SCRIPT="${2:?Usage: screenshot.sh <task_folder> <test_script> [frame_count] [fps]}"
FRAME_COUNT="${3:-30}"
FPS="${4:-10}"

MOVIE="screenshots/${TASK_FOLDER}"
rm -rf "$MOVIE" && mkdir -p "$MOVIE"
touch screenshots/.gdignore

case "$(uname)" in
  Darwin)
    # macOS — native rendering
    timeout 30 godot --write-movie "$MOVIE/frame.png" \
        --fixed-fps "$FPS" --quit-after "$FRAME_COUNT" \
        --script "$TEST_SCRIPT" 2>&1
    ;;
  Linux)
    # Source GPU detection
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/gpu_detect.sh"

    if [ -n "$GPU_DISPLAY" ]; then
      timeout 30 DISPLAY="$GPU_DISPLAY" godot --rendering-method forward_plus \
          --write-movie "$MOVIE/frame.png" \
          --fixed-fps "$FPS" --quit-after "$FRAME_COUNT" \
          --script "$TEST_SCRIPT" 2>&1
    else
      timeout 30 xvfb-run -a -s '-screen 0 1280x720x24' godot --rendering-driver vulkan \
          --write-movie "$MOVIE/frame.png" \
          --fixed-fps "$FPS" --quit-after "$FRAME_COUNT" \
          --script "$TEST_SCRIPT" 2>&1
    fi
    ;;
  *)
    echo "Unsupported platform: $(uname)" >&2
    exit 1
    ;;
esac

echo "Screenshots saved to $MOVIE/"
ls -la "$MOVIE/"
