@echo off
setlocal
set "GODOT=%USERPROFILE%\source\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" (
  start "Towers of Dawn" "%GODOT%" --path "%~dp0."
  exit /b 0
)
where godot >nul 2>nul
if not errorlevel 1 (
  godot --path "%~dp0."
  exit /b
)
echo Godot not found. Open project.godot in Godot 4 and press F5.
pause
