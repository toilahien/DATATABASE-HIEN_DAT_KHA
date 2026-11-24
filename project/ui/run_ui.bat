@echo off
setlocal
cd /d "%~dp0"

set "VENV_PY=%CD%\.venv-windows\Scripts\python.exe"

if not exist "%VENV_PY%" (
    echo Creating the Python environment...
    where py >nul 2>&1
    if not errorlevel 1 (
        py -3 -m venv .venv-windows
    ) else (
        where python >nul 2>&1
        if errorlevel 1 (
            echo Python 3 was not found. Install Python 3 and try again.
            pause
            exit /b 1
        )
        python -m venv .venv-windows
    )
    if errorlevel 1 (
        echo Could not create the Python environment.
        pause
        exit /b 1
    )
)

"%VENV_PY%" -c "import flask, pymysql" >nul 2>&1
if errorlevel 1 (
    echo Installing the web app requirements...
    "%VENV_PY%" -m pip install -r requirements.txt
    if errorlevel 1 (
        echo Could not install the required packages.
        pause
        exit /b 1
    )
)

if not defined REIMS_DB_HOST set "REIMS_DB_HOST=127.0.0.1"
if not defined REIMS_DB_PORT set "REIMS_DB_PORT=3306"
if not defined REIMS_DB_USER set "REIMS_DB_USER=root"
if not defined REIMS_DB_PASSWORD set "REIMS_DB_PASSWORD=1"
if not defined REIMS_DB_NAME set "REIMS_DB_NAME=reims_db"

echo Starting REIMS...
echo The browser will open at http://127.0.0.1:5000
start "" http://127.0.0.1:5000
"%VENV_PY%" app.py

echo.
echo REIMS has stopped. Press any key to close this window.
pause >nul
