#!/bin/bash

# Antigravity Phone Connect - Mac/Linux Launcher
echo "==================================================="
echo "  Antigravity Phone Connect Launcher"
echo "==================================================="

# Check for .env file
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo "[INFO] .env file not found. Creating from .env.example..."
        cp .env.example .env
        echo "[SUCCESS] .env created from template!"
        echo "[ACTION] Please update .env if you wish to change defaults."
        echo ""
    fi
fi

# Check for Python
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "[ERROR] Python is not installed. Please install Python to run the launcher."
    exit 1
fi

echo "[STARTING] Launching via Unified Launcher..."

# Parse optional command line flags (e.g., --reload)
RELOAD_FLAG=""
for arg in "$@"; do
    if [ "$arg" = "--reload" ]; then
        RELOAD_FLAG="--reload"
    fi
done

# Create and use Virtual Environment to avoid PEP 668 issues
if [ ! -d "venv" ]; then
    echo "[INFO] Creating Python virtual environment..."
    $PYTHON_CMD -m venv venv
fi

if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

if [ "$(uname)" = "Darwin" ]; then
    echo "🍎 macOS detected. Enhancing startup..."
    
    PORT_9000_PID=$(lsof -t -i :9000 2>/dev/null)
    CDP_RESPONSIVE=false
    if [ ! -z "$PORT_9000_PID" ]; then
        if curl -s --max-time 2 http://127.0.0.1:9000/json/list >/dev/null; then
            CDP_RESPONSIVE=true
        fi
    fi
    
    IDE_RUNNING=false
    if pgrep -f "Antigravity IDE" >/dev/null; then
        IDE_RUNNING=true
    fi
    
    LAUNCH_IDE=true
    
    if [ "$CDP_RESPONSIVE" = true ]; then
        echo "✅ Responsive Antigravity IDE debug session detected on port 9000."
        LAUNCH_IDE=false
    elif [ "$IDE_RUNNING" = true ]; then
        echo "⚠️  Antigravity IDE is currently running, but it is not listening on debug port 9000."
        echo "   To use remote control, the IDE must be in debug mode."
        echo "   Warning: If you start a new instance in debug mode, it will run side-by-side,"
        echo "   but you will not see the projects from your currently running instance in it."
        echo ""
        printf "Would you like to start a new Antigravity IDE instance in debug mode? (y/N): "
        read -r response
        case "$response" in
            [yY][eE][sS]|[yY])
                echo "🚀 Preparing to launch new debug instance..."
                LAUNCH_IDE=true
                ;;
            *)
                echo "❌ Exiting launcher. Remote control requires Antigravity IDE to be in debug mode."
                exit 1
                ;;
        esac
    fi
    
    if [ "$LAUNCH_IDE" = true ]; then
        # If port 9000 is in use by a non-CDP process, terminate it
        if [ ! -z "$PORT_9000_PID" ] && [ "$CDP_RESPONSIVE" = false ]; then
            echo "⚠️  Terminating unresponsive process on port 9000 (PID $PORT_9000_PID)..."
            kill -9 "$PORT_9000_PID" 2>/dev/null
            sleep 1
        fi
        
        echo "🚀 Starting Antigravity IDE in background on port 9000..."
        open -n "/Applications/Antigravity IDE.app" --args --remote-debugging-port=9000
        
        # Wait for IDE to load and listen on port 9000
        echo "⏳ Waiting for Antigravity IDE to start listening on port 9000..."
        LIMIT=30
        COUNT=0
        while ! curl -s --max-time 2 http://127.0.0.1:9000/json/list >/dev/null; do
            sleep 1
            COUNT=$((COUNT + 1))
            if [ "$COUNT" -ge "$LIMIT" ]; then
                echo "❌ Timeout: Antigravity IDE did not start listening on port 9000."
                exit 1
            fi
        done
        echo "✅ Antigravity IDE is ready and listening on port 9000!"
    fi

    # Cleanup trap setup for macOS
    cleanup() {
        # Unset traps to avoid recursion
        trap - EXIT SIGINT SIGTERM
        
        echo ""
        echo "👋 Stopping remote control..."
        if [ ! -z "$LAUNCHER_PID" ] && kill -0 "$LAUNCHER_PID" 2>/dev/null; then
            kill -INT "$LAUNCHER_PID" 2>/dev/null
            wait "$LAUNCHER_PID" 2>/dev/null
        fi
        
        # Prompt the user if Antigravity IDE is still running
        if pgrep -f "Antigravity IDE" >/dev/null; then
            exec < /dev/tty
            printf "Do you also want to stop the Antigravity IDE? (y/N): "
            read -r response
            case "$response" in
                [yY][eE][sS]|[yY])
                    echo "🛑 Closing Antigravity IDE..."
                    osascript -e 'quit application "Antigravity IDE"' 2>/dev/null
                    sleep 2
                    # Force kill if still running
                    if pgrep -f "Antigravity IDE" >/dev/null; then
                        pkill -f "Antigravity IDE"
                    fi
                    echo "✅ Antigravity IDE closed."
                    ;;
                *)
                    echo "ℹ️  Leaving Antigravity IDE running in the background."
                    ;;
            esac
        fi
    }
    
    trap cleanup EXIT SIGINT SIGTERM
    
    # Run in background
    $PYTHON_CMD launcher.py --mode local $RELOAD_FLAG &
    LAUNCHER_PID=$!
    
    # Wait for the background process
    wait "$LAUNCHER_PID" 2>/dev/null
    
else
    # Non-macOS runs in foreground
    $PYTHON_CMD launcher.py --mode local $RELOAD_FLAG
    
    # Keep terminal open if server crashes
    echo ""
    echo "[INFO] Server stopped."
    printf "Press Enter to exit..."
    read -r
fi

