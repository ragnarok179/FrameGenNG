@echo off
setlocal

title FrameGenNG Native Test Build
set "REPO_ROOT=%~dp0"
set "BUILD_SCRIPT=%REPO_ROOT%scripts\build-native-release.ps1"

if not exist "%BUILD_SCRIPT%" (
    echo Build script not found:
    echo %BUILD_SCRIPT%
    echo.
    pause
    exit /b 1
)

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%BUILD_SCRIPT%"
set "BUILD_EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%BUILD_EXIT_CODE%"=="0" (
    echo FrameGenNG test build failed. Review the error above.
    pause
    exit /b %BUILD_EXIT_CODE%
)

echo The test package is available in the dist folder.
start "" "%REPO_ROOT%dist"
pause
exit /b 0
