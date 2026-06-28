@echo off
setlocal
cd /d "%~dp0"

echo.
echo === Q-LESS: compilando APK release ===
echo.

call flutter pub get
if errorlevel 1 goto :error

call flutter build apk --release
if errorlevel 1 goto :error

set "SRC=build\app\outputs\flutter-apk\app-release.apk"
set "DEST=releases"

if not exist "%DEST%" mkdir "%DEST%"

copy /Y "%SRC%" "%DEST%\Q-LESS-v2.9.3-mobile.apk" >nul
copy /Y "%SRC%" "%DEST%\app-release.apk" >nul

echo.
echo === LISTO ===
echo APK original : %CD%\%SRC%
echo APK para GitHub: %CD%\%DEST%\Q-LESS-v2.9.3-mobile.apk
echo.
echo Abriendo carpeta releases...
start "" "%CD%\%DEST%"
goto :eof

:error
echo.
echo ERROR en la compilacion.
pause
exit /b 1
