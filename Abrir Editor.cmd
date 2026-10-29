@echo off
cd /d "%~dp0"
if not exist "%~dp0DungeonKeeperStudio.exe" (
  echo Execute Build-Studio.ps1 primeiro.
  pause
  exit /b 1
)
if not exist "%~dp0DungeonKeeperStudio.pck" (
  echo Pacote do editor nao encontrado. Execute Build-Studio.ps1.
  pause
  exit /b 1
)
start "" "%~dp0DungeonKeeperStudio.exe" --main-pack "%~dp0DungeonKeeperStudio.pck"
