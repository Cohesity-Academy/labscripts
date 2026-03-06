@echo off
REM Silently set PowerShell execution policy to Unrestricted for the current user
powershell -NoProfile -WindowStyle Hidden -Command "Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force"
