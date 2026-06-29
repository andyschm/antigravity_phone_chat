#!/bin/bash

# Navigate to script directory
cd "$(dirname "$0")"

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

# Detect AUTH_TYPE
AUTH_TYPE_VAR="$AUTH_TYPE"
if [ -f ".env" ]; then
    if [ -z "$AUTH_TYPE_VAR" ]; then
        AUTH_TYPE_VAR=$(grep -E "^AUTH_TYPE=" .env | cut -d'=' -f2-)
        # Trim potential quotes or whitespace
        AUTH_TYPE_VAR=$(echo "$AUTH_TYPE_VAR" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
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

# Parse optional command line flags (e.g., --reload, --web)
RELOAD_FLAG=""
WEB_MODE=false
for arg in "$@"; do
    if [ "$arg" = "--reload" ]; then
        RELOAD_FLAG="--reload"
    elif [ "$arg" = "--web" ]; then
        WEB_MODE=true
    fi
done

if [ "$AUTH_TYPE_VAR" = "oauth2_proxy" ]; then
    WEB_MODE=true
    export AUTH_TYPE="oauth2_proxy"
fi

# Validation and setup for --web mode
if [ "$WEB_MODE" = true ]; then
    if [ -f ".env" ]; then
        CF_TOKEN=$(grep -E "^CF_TOKEN=" .env | cut -d'=' -f2-)
        OAUTH2_CLIENT=$(grep -E "^OAUTH2_CLIENT=" .env | cut -d'=' -f2-)
        OAUTH2_SECRET=$(grep -E "^OAUTH2_SECRET=" .env | cut -d'=' -f2-)
        OAUTH2_COOKIE_SECRET=$(grep -E "^OAUTH2_COOKIE_SECRET=" .env | cut -d'=' -f2-)
    fi

    # Trim potential quotes or whitespace
    CF_TOKEN=$(echo "$CF_TOKEN" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    OAUTH2_CLIENT=$(echo "$OAUTH2_CLIENT" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    OAUTH2_SECRET=$(echo "$OAUTH2_SECRET" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    OAUTH2_COOKIE_SECRET=$(echo "$OAUTH2_COOKIE_SECRET" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

    if [ -z "$CF_TOKEN" ] || [ -z "$OAUTH2_CLIENT" ] || [ -z "$OAUTH2_SECRET" ] || [ -z "$OAUTH2_COOKIE_SECRET" ]; then
        echo "[ERROR] --web requires CF_TOKEN, OAUTH2_CLIENT, OAUTH2_SECRET, and OAUTH2_COOKIE_SECRET to be defined in .env"
        exit 1
    fi

    # Verify Docker is available and running
    if ! command -v docker &> /dev/null; then
        echo "[ERROR] Docker is not installed or not in PATH."
        exit 1
    fi
    if ! docker info &>/dev/null; then
        echo "[ERROR] Docker daemon is not running."
        exit 1
    fi
fi

# Cleanup trap setup
cleanup() {
    # Unset traps to avoid recursion
    trap - EXIT SIGINT SIGTERM
    
    if [ "$WEB_MODE" = true ]; then
        echo ""
        echo "[INFO] Stopping docker stack..."
        docker rm -f ag_cloudflared ag_oauth2_proxy &>/dev/null
        echo "✅ Docker stack stopped."
    fi
    
    echo ""
    echo "👋 Stopping remote control..."
    if [ ! -z "$LAUNCHER_PID" ] && kill -0 "$LAUNCHER_PID" 2>/dev/null; then
        kill -INT "$LAUNCHER_PID" 2>/dev/null
        wait "$LAUNCHER_PID" 2>/dev/null
    fi
    
    # Prompt the user if Antigravity IDE is still running (macOS only)
    if [ "$(uname)" = "Darwin" ]; then
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
    fi
}

trap cleanup EXIT SIGINT SIGTERM

# Start Docker stack in --web mode
if [ "$WEB_MODE" = true ]; then
    echo "[INFO] Starting cloudflared and oauth2_proxy docker containers..."
    
    # Pre-clean just in case
    docker rm -f ag_cloudflared ag_oauth2_proxy &>/dev/null
    
    # Start oauth2_proxy
    docker run -d \
      --name ag_oauth2_proxy \
      -p 127.0.0.1:3001:3001 \
      --add-host=host.docker.internal:host-gateway \
      -e OAUTH2_PROXY_CLIENT_ID="$OAUTH2_CLIENT" \
      -e OAUTH2_PROXY_CLIENT_SECRET="$OAUTH2_SECRET" \
      -e OAUTH2_PROXY_COOKIE_SECRET="$OAUTH2_COOKIE_SECRET" \
      quay.io/oauth2-proxy/oauth2-proxy:latest \
      --http-address=0.0.0.0:3001 \
      --upstream=http://host.docker.internal:3000 \
      --provider=google \
      --email-domain="*" \
      --reverse-proxy=true \
      --cookie-secure=true
      
    # Start cloudflared
    docker run -d \
      --name ag_cloudflared \
      --network host \
      cloudflare/cloudflared:latest \
      tunnel --no-autoupdate run --token "$CF_TOKEN"
      
    echo "[SUCCESS] Docker stack is running!"
fi
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

