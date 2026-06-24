@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "PREFIX="

:parse_args
if "%~1"=="" goto args_done
if "%~1"=="--prefix" (
    set "PREFIX=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="--help" goto :help
if "%~1"=="-h" goto :help
if "%~1"=="/?" goto :help

set "ARG=%~1"
if "!ARG:~0,9!"=="--prefix=" (
    set "PREFIX=!ARG:~9!"
    shift
    goto parse_args
)

echo error: unknown option: %~1
echo try install.bat --help
exit /b 1

:args_done

:: ============================================================
::  istation-gateway windows install script
::  reads version from VERSION file in the same directory
::  copies exe to %PREFIX%\gateway\istation-gateway-windows-x86_64-{version}
::  sets ISTATION_GATEWAY_STARTUP in %PREFIX%\env\istation_gateway
:: ============================================================

set "SRC_DIR=%~dp0"
if "%SRC_DIR:~-1%"=="\" set "SRC_DIR=%SRC_DIR:~0,-1%"

:: fallback: %~dp0 can be unreliable (e.g. PowerShell), try %CD%
if not exist "%SRC_DIR%\VERSION" if exist "%CD%\VERSION" set "SRC_DIR=%CD%"
if not exist "%SRC_DIR%\VERSION" (
    echo error: VERSION file not found in %SRC_DIR%
    exit /b 1
)
set /p VERSION=<"%SRC_DIR%\VERSION"
if "%VERSION%"=="" (
    echo error: VERSION file is empty
    exit /b 1
)

:: ----------------------------------------------------------
::  validate required arguments
:: ----------------------------------------------------------
if "%PREFIX%"=="" (
    echo error: --prefix is required
    echo try install.bat --help
    exit /b 1
)

set "SUB_DIR=istation-gateway-windows-x86_64-%VERSION%"
set "ISTATION_HOME=%PREFIX%"

set "GATEWAY_DIR=%ISTATION_HOME%\gateway"
set "TARGET_DIR=%GATEWAY_DIR%\%SUB_DIR%"
if "%TARGET_DIR:~-1%"=="\" set "TARGET_DIR=%TARGET_DIR:~0,-1%"

:: ----------------------------------------------------------
::  discover startup executable name (single exe in package)
:: ----------------------------------------------------------
set "STARTUP="
for %%f in ("%SRC_DIR%\*") do (
    if /i not "%%~nxf"=="install.bat" if /i not "%%~nxf"=="VERSION" if "!STARTUP!"=="" set "STARTUP=%%~nxf"
)
set "STARTUP=%TARGET_DIR%\%STARTUP%"

:: ----------------------------------------------------------
::  persist environment variables to env file
:: ----------------------------------------------------------
set "ENV_FILE=%ISTATION_HOME%\env\istation_gateway"
for %%d in ("%ENV_FILE%\..") do (
    if not exist "%%~fd" mkdir "%%~fd"
)

echo [setenv] ISTATION_HOME=%ISTATION_HOME%
echo [setenv] ISTATION_GATEWAY_STARTUP=%STARTUP%

set "TEMP_FILE=%TEMP%\env_tmp_%RANDOM%.txt"
if exist "%ENV_FILE%" (
    findstr /v /b "ISTATION_HOME= ISTATION_GATEWAY_STARTUP=" "%ENV_FILE%" > "%TEMP_FILE%" 2>nul
    move /y "%TEMP_FILE%" "%ENV_FILE%" >nul
)
echo ISTATION_HOME="%ISTATION_HOME%" >> "%ENV_FILE%"
echo ISTATION_GATEWAY_STARTUP="%STARTUP%" >> "%ENV_FILE%"
if exist "%TEMP_FILE%" del /f /q "%TEMP_FILE%" 2>nul

:: ----------------------------------------------------------
::  create target directory and copy exe
:: ----------------------------------------------------------
if not exist "%TARGET_DIR%" (
    echo [mkdir] %TARGET_DIR%
    mkdir "%TARGET_DIR%"
)

echo [src] %SRC_DIR%
echo [dst] %TARGET_DIR%
echo.

set COUNT=0
for %%f in ("%SRC_DIR%\*") do (
    if /i not "%%~nxf"=="install.bat" if /i not "%%~nxf"=="VERSION" (
        set /a COUNT+=1
        echo [copy] %%~nxf
        copy /y "%%f" "%TARGET_DIR%\" >nul
    )
)

echo.
echo done, %COUNT% files copied.
exit /b 0

:help
echo ===============================================================
echo   istation-gateway Windows Install Script
echo ===============================================================
echo.
echo   Reads version from VERSION file in script directory.
echo   Copies gateway executable to the gateway folder.
echo.
echo   USAGE:
echo     install.bat --prefix=PATH
echo.
echo   OPTIONS:
echo     --prefix=PATH           Installation root directory (required)
echo.
echo   FILES INSTALLED TO:
echo     {PREFIX}\gateway\istation-gateway-windows-x86_64-{version}\
echo.
echo   ENVIRONMENT VARIABLES WRITTEN TO {PREFIX}\env\istation_gateway:
echo     ISTATION_HOME
echo     ISTATION_GATEWAY_STARTUP
echo.
echo   EXAMPLES:
echo     install.bat --prefix=D:\istation
echo     install.bat --help
echo ===============================================================
exit /b 0
