@echo off
REM ============================================================
REM   Wispr Clone - WINDOWS launcher (double-click to run)
REM ============================================================
cd /d "%~dp0"

echo Starting Wispr Clone (Windows)...
echo Hold RIGHT CTRL and speak. Close this window to quit.
echo.

python wispr_windows.py
if %errorlevel% neq 0 (
  echo.
  echo Could not start. Make sure Python is installed and you ran:
  echo     pip install -r requirements.txt
  pause
)
