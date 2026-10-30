@echo off
cd /d "%~dp0www"
start "" http://127.0.0.1:8124/
python -m http.server 8124 --bind 127.0.0.1
