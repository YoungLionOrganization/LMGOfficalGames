@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Compatibility wrapper. Canonical build entry point is build.bat.
call "%~dp0build.bat" %*
exit /b %ERRORLEVEL%
