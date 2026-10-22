@echo off
setlocal
cd /d "%~dp0"
echo Abra http://127.0.0.1:7357/ quando a compilacao terminar.
call flutter run -d web-server --web-hostname=127.0.0.1 --web-port=7357 --dart-define=SPOTIFY_CLIENT_ID=59ea8a21516947b1936233d03ea53f31
exit /b %errorlevel%
