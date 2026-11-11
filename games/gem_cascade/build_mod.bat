@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "VERSION=6.7.0"
set "OUTPUT=%CD%\gem_cascade-%VERSION%.rcc"
set "SMOKE_BUILD=%CD%\.build\qt_rcc_smoke"
set "RCC_INPUT=%~1"
if not defined RCC_INPUT set "RCC_INPUT=rcc.exe"

rem ---------------------------------------------------------------------------
rem Resolve Python used by the source/adversarial validator.
rem ---------------------------------------------------------------------------
set "PYTHON_EXE="
set "PYTHON_ARGS="
where py.exe >nul 2>&1
if not errorlevel 1 (
    set "PYTHON_EXE=py.exe"
    set "PYTHON_ARGS=-3"
) else (
    where python.exe >nul 2>&1
    if not errorlevel 1 set "PYTHON_EXE=python.exe"
)
if not defined PYTHON_EXE (
    echo [ERROR] Python 3 is required for source validation.
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Resolve rcc to an absolute file. This also lets us derive the Qt kit.
rem ---------------------------------------------------------------------------
set "RCC_EXE="
if exist "%RCC_INPUT%" (
    for %%I in ("%RCC_INPUT%") do set "RCC_EXE=%%~fI"
) else (
    for /f "delims=" %%I in ('where "%RCC_INPUT%" 2^>nul') do if not defined RCC_EXE set "RCC_EXE=%%I"
)
if not defined RCC_EXE (
    echo [ERROR] rcc executable not found: %RCC_INPUT%
    echo Usage: build_mod.bat "D:\Qt\6.11.1\llvm-mingw_64\bin\rcc.exe"
    exit /b 1
)

for %%I in ("%RCC_EXE%") do set "QT_BIN=%%~dpI"
for %%I in ("%QT_BIN%..") do set "QT_ROOT=%%~fI"
for %%I in ("%QT_ROOT%\..\..") do set "QT_BASE=%%~fI"
set "QT_CMAKE=%QT_BIN%qt-cmake.bat"
set "CMAKE_EXE=%QT_BASE%\Tools\CMake_64\bin\cmake.exe"
set "NINJA_EXE=%QT_BASE%\Tools\Ninja\ninja.exe"
set "CXX_EXE="
for /d %%D in ("%QT_BASE%\Tools\llvm-mingw*") do if exist "%%~fD\bin\clang++.exe" if not defined CXX_EXE set "CXX_EXE=%%~fD\bin\clang++.exe"
if not defined CXX_EXE (
    for /f "delims=" %%I in ('where clang++.exe 2^>nul') do if not defined CXX_EXE set "CXX_EXE=%%I"
)
if not exist "%CMAKE_EXE%" (
    for /f "delims=" %%I in ('where cmake.exe 2^>nul') do if not exist "%CMAKE_EXE%" set "CMAKE_EXE=%%I"
)
if not exist "%NINJA_EXE%" (
    for /f "delims=" %%I in ('where ninja.exe 2^>nul') do if not exist "%NINJA_EXE%" set "NINJA_EXE=%%I"
)

if not exist "manifest.json" (
    echo [ERROR] manifest.json not found.
    exit /b 1
)
if not exist "mod.qrc" (
    echo [ERROR] mod.qrc not found.
    exit /b 1
)

cls
echo ============================================================
echo   Gem Cascade %VERSION% - VERIFIED RCC BUILD
echo ============================================================
echo RCC    : %RCC_EXE%
echo Qt kit : %QT_ROOT%
echo Output : %OUTPUT%
if defined CXX_EXE echo CXX    : %CXX_EXE%
echo.

rem The verifier is a tiny Qt executable; expose the selected Qt runtime and
rem compiler so it can both build and start outside Qt Creator.
set "PATH=%QT_BIN%;%PATH%"
if defined CXX_EXE for %%I in ("%CXX_EXE%") do set "PATH=%%~dpI;%PATH%"

rem ---------------------------------------------------------------------------
echo [1/5] Validating source, QRC contract, i18n, gameplay and build contract...
"%PYTHON_EXE%" %PYTHON_ARGS% "%CD%\tools\validate_source.py"
if errorlevel 1 goto :fail

rem ---------------------------------------------------------------------------
echo.
echo [2/5] Building binary RCC...
if exist "%OUTPUT%" del /q "%OUTPUT%"
"%RCC_EXE%" --binary "%CD%\mod.qrc" -o "%OUTPUT%"
if errorlevel 1 goto :fail
if not exist "%OUTPUT%" (
    echo [ERROR] rcc returned success but output is missing.
    goto :fail
)
for %%I in ("%OUTPUT%") do if %%~zI LEQ 0 (
    echo [ERROR] RCC output is empty.
    goto :fail
)

rem ---------------------------------------------------------------------------
echo.
echo [3/5] Checking Qt post-build smoke toolchain...
if /I "%GEM_CASCADE_SKIP_QT_SMOKE%"=="1" (
    echo [WARN] GEM_CASCADE_SKIP_QT_SMOKE=1: mounted RCC / QQmlEngine verification skipped by explicit request.
    goto :skip_smoke
)
if not exist "%QT_CMAKE%" (
    echo [ERROR] qt-cmake.bat not found next to the selected rcc:
    echo         %QT_CMAKE%
    echo         Set GEM_CASCADE_SKIP_QT_SMOKE=1 only if you intentionally accept an unverified RCC.
    goto :fail
)
if not exist "%CMAKE_EXE%" (
    echo [ERROR] cmake.exe not found. Expected Qt tool or PATH CMake.
    goto :fail
)
if not exist "%NINJA_EXE%" (
    echo [ERROR] ninja.exe not found. Expected Qt Tools\Ninja or PATH Ninja.
    goto :fail
)

rem ---------------------------------------------------------------------------
echo.
echo [4/5] Building mounted-RCC QQmlEngine verifier...
if exist "%SMOKE_BUILD%" rmdir /s /q "%SMOKE_BUILD%"
if defined CXX_EXE (
    call "%QT_CMAKE%" -S "%CD%\tools\qt_rcc_smoke" -B "%SMOKE_BUILD%" -G Ninja -DCMAKE_MAKE_PROGRAM="%NINJA_EXE%" -DCMAKE_CXX_COMPILER="%CXX_EXE%"
) else (
    call "%QT_CMAKE%" -S "%CD%\tools\qt_rcc_smoke" -B "%SMOKE_BUILD%" -G Ninja -DCMAKE_MAKE_PROGRAM="%NINJA_EXE%"
)
if errorlevel 1 goto :fail
"%CMAKE_EXE%" --build "%SMOKE_BUILD%" --parallel
if errorlevel 1 goto :fail
if not exist "%SMOKE_BUILD%\gem_cascade_rcc_smoke.exe" (
    echo [ERROR] Post-build smoke executable was not created.
    goto :fail
)

rem ---------------------------------------------------------------------------
echo.
echo [5/5] Mounting ACTUAL RCC at /mods/gem_cascade and loading Main.qml...
"%SMOKE_BUILD%\gem_cascade_rcc_smoke.exe" "%OUTPUT%"
if errorlevel 1 goto :fail

goto :success

:skip_smoke
echo.
echo [4/5] Qt smoke build skipped.
echo [5/5] Mounted RCC QML load skipped.

:success
echo.
echo ============================================================
echo [OK] Gem Cascade %VERSION% BUILD COMPLETED
if /I not "%GEM_CASCADE_SKIP_QT_SMOKE%"=="1" echo [OK] RCC mount + QQmlEngine runtime smoke passed.
echo ============================================================
echo %OUTPUT%
exit /b 0

:fail
echo.
echo ============================================================
echo [ERROR] Gem Cascade %VERSION% BUILD FAILED
if exist "%OUTPUT%" del /q "%OUTPUT%" >nul 2>&1
echo No unverified RCC is left behind.
echo ============================================================
exit /b 1
