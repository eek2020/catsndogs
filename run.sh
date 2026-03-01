#!/bin/bash
# Whisper Crystals launcher
# Ensures virtualenv is active and PYTHONPATH is set correctly

set -e

# Detect and activate venv if present
if [ -d ".venv" ]; then
    echo "Activating virtual environment..."
    source .venv/bin/activate
elif [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
else
    echo "No virtual environment found. Using system Python."
fi

# Ensure dependencies are installed
echo "Checking dependencies..."
pip install -q -r requirements.txt

# Run the game with correct PYTHONPATH for src layout
echo "Starting Whisper Crystals..."
PYTHONPATH=src python3 -m whisper_crystals
