@echo off
setlocal
set SRC=%~dp0..\mobile_flutter\build\app\outputs\flutter-apk\app-release.apk
set DST=%~dp0..\mobile-api\releases\Q-LESS.apk

if not exist "%SRC%" (
  echo ERROR: No existe el APK. Ejecuta antes:
  echo   cd mobile_flutter
  echo   flutter build apk --release
  exit /b 1
)

if not exist "%~dp0..\mobile-api\releases" mkdir "%~dp0..\mobile-api\releases"
copy /Y "%SRC%" "%DST%"
echo.
echo APK copiado a mobile-api\releases\Q-LESS.apk
echo.
echo Siguiente: git add mobile-api/releases/Q-LESS.apk mobile-api/download.html mobile-api/router.php
echo           git commit -m "chore: pagina descarga APK"
echo           git push
echo.
echo Link publico tras deploy:
echo   https://mobile-api-production-21d2.up.railway.app/download
echo   https://mobile-api-production-21d2.up.railway.app/releases/Q-LESS.apk
endlocal
