#!/usr/bin/env python3
"""Whisper Crystals launcher script.
Ensures dependencies are installed and runs the game with correct PYTHONPATH.
"""

import subprocess
import sys
import os
from pathlib import Path

def main():
    project_root = Path(__file__).parent
    src_path = project_root / "src"
    
    # Add src to Python path
    env = os.environ.copy()
    env["PYTHONPATH"] = str(src_path) + os.pathsep + env.get("PYTHONPATH", "")
    
    # Check/install dependencies
    print("Checking dependencies...")
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", "-r", "requirements.txt"], 
                      cwd=project_root, check=True)
    except subprocess.CalledProcessError:
        print("Failed to install dependencies")
        sys.exit(1)
    
    # Run the game
    print("Starting Whisper Crystals...")
    try:
        subprocess.run([sys.executable, "-m", "whisper_crystals"], 
                      cwd=project_root, env=env, check=True)
    except subprocess.CalledProcessError:
        print("Game failed to start")
        sys.exit(1)

if __name__ == "__main__":
    main()
