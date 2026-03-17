#!/usr/bin/env bash
# Detect GPU display for Godot rendering.
# Sets GPU_DISPLAY env var if NVIDIA GPU found on an X11 display.
# Usage: source gpu_detect.sh

GPU_DISPLAY=""
for lock in /tmp/.X*-lock; do
  [ -f "$lock" ] || continue
  d=":${lock##/tmp/.X}"; d="${d%-lock}"
  if DISPLAY=$d timeout 2 glxinfo 2>/dev/null | grep -qi nvidia; then
    GPU_DISPLAY=$d; break
  fi
done

if [ -n "$GPU_DISPLAY" ]; then
  echo "GPU detected on display $GPU_DISPLAY"
  export GPU_DISPLAY
else
  echo "No GPU detected — will use software rendering (xvfb + lavapipe)"
fi
