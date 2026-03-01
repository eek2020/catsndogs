@echo off
REM Whisper Crystals launcher for Windows
REM Ensures virtualenv is active and PYTHONPATH is set correctly

setlocal enabledelayedexpansion

REM Detect and activate venv if present
if exist ".venv\Scripts\activate.bat" (
    echo Activating virtual environment...
    call .venv\Scripts\activate.bat
) else if exist "venv\Scripts\activate.bat" (
    echo Activating virtual environment...
    call venv\Scripts\activate.bat
) else (
    echo No virtual environment found. Using system Python.
)

REM Ensure dependencies are installed
echo Checking dependencies...
pip3 install -q -r requirements.txt

REM Run the game with correct PYTHONPATH for src layout
echo Starting Whisper Crystals...
set PYTHONPATH=src
python3 -m whisper_crystals
