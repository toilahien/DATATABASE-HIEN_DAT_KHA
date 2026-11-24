#!/usr/bin/env bash
set -Eeuo pipefail

UI_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_URL="http://127.0.0.1:5000"

# Virtual environments contain OS-specific binaries, so keep macOS and Linux separate.
if [[ "$(uname -s)" == "Darwin" ]]; then
    VENV_DIR="$UI_DIR/.venv-macos"
else
    VENV_DIR="$UI_DIR/.venv"
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "Python 3 is not installed. Install Python 3, then run this file again."
    read -r -p "Press Enter to close..."
    exit 1
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    echo "Creating the Python environment..."
    if ! python3 -m venv "$VENV_DIR"; then
        echo "Could not create the Python environment. Check that your Python installation includes venv support."
        read -r -p "Press Enter to close..."
        exit 1
    fi
fi

if ! "$VENV_DIR/bin/python" -c "import flask, pymysql" >/dev/null 2>&1; then
    echo "Installing the web app requirements..."
    "$VENV_DIR/bin/python" -m pip install -r "$UI_DIR/requirements.txt"
fi

export REIMS_DB_HOST="${REIMS_DB_HOST:-127.0.0.1}"
export REIMS_DB_PORT="${REIMS_DB_PORT:-3306}"
export REIMS_DB_USER="${REIMS_DB_USER:-root}"
export REIMS_DB_PASSWORD="${REIMS_DB_PASSWORD:-1}"
export REIMS_DB_NAME="${REIMS_DB_NAME:-reims_db}"

echo "Starting REIMS..."
echo "Open $APP_URL in your browser. Press Ctrl+C here to stop the app."
if command -v xdg-open >/dev/null 2>&1; then
    (sleep 2; xdg-open "$APP_URL" >/dev/null 2>&1) &
elif command -v open >/dev/null 2>&1; then
    (sleep 2; open "$APP_URL" >/dev/null 2>&1) &
fi

cd "$UI_DIR"
exec "$VENV_DIR/bin/python" app.py
