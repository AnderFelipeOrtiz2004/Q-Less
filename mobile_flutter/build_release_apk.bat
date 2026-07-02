@echo off
setlocal
cd /d "%~dp0"

set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"

echo.
echo === Q-LESS v2.9.3: compilando APK release ===
echo.

if exist "env.production" (
  copy /Y "env.production" ".env" >nul
  echo .env actualizado desde env.production
)

call flutter pub get
if errorlevel 1 goto :error

call flutter build apk --release
if errorlevel 1 goto :error

set "SRC=build\app\outputs\flutter-apk\app-release.apk"
set "DEST=releases"
set "API_DEST=..\mobile-api\releases"

if not exist "%DEST%" mkdir "%DEST%"
if not exist "%API_DEST%" mkdir "%API_DEST%"

copy /Y "%SRC%" "%DEST%\Q-LESS-v2.9.3-mobile.apk" >nul
copy /Y "%SRC%" "%DEST%\app-release.apk" >nul
copy /Y "%SRC%" "%API_DEST%\Q-LESS.apk" >nul

echo.
echo === LISTO ===
echo APK GitHub : %CD%\%DEST%\Q-LESS-v2.9.3-mobile.apk
echo APK Railway: %CD%\%API_DEST%\Q-LESS.apk
echo.
start "" "%CD%\%DEST%"
goto :eof

:error
echo.
echo ERROR en la compilacion.
pause
exit /b 1
