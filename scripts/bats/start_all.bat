@echo off
REM ============================================================================
REM  DietAI one-click start script (PRD 5.1)  -  ASCII-only entry point
REM  All human-readable (Chinese) output is produced by start_all.ps1.
REM  Usage: double-click this file, or run: scripts\bats\start_all.bat
REM ============================================================================

REM Use UTF-8 console so the PowerShell script can print Chinese correctly
chcp 65001 >nul

REM --- 1) Never let a system proxy hijack local dependency traffic ----------
set "NO_PROXY=localhost,127.0.0.1,::1"
set "no_proxy=localhost,127.0.0.1,::1"

REM --- 2) Force debug off: main.py uses reload=settings.debug (no --reload) --
set "DIETAI_DEBUG=false"

set "SCRIPT_DIR=%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%start_all.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo [DietAI] Startup did not complete successfully. Exit code: %EXIT_CODE%
)

if "%DIETAI_START_PAUSE%"=="1" pause
exit /b %EXIT_CODE%
