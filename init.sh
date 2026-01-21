#!/bin/bash
set -e

echo "🔧 Initializing deployment environment..."

# Check if .env file exists, create from template if not
if [ ! -f .env ]; then
    echo "Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file to add your Datadog API key"
    echo "   Current .env contains: VAULT_DD_API_KEY=placeholder_api_key_123"
else
    echo "✓ .env file already exists"
fi

# Validate .env has required variables
echo "Validating environment variables..."
if grep -q "your_datadog_api_key_here" .env 2>/dev/null || \
   grep -q "placeholder_api_key_123" .env 2>/dev/null; then
    echo "⚠️  WARNING: .env contains placeholder API key"
    echo "   Update .env with your real Datadog API key for proper functionality"
fi

# Check port availability
echo "Checking port availability..."
if command -v ss >/dev/null 2>&1; then
    if ss -tlnp | grep -q ":8200"; then
        echo "❌ Port 8200 is already in use. Please free this port."
        exit 1
    fi
    if ss -tlnp | grep -q ":8125"; then
        echo "⚠️  Port 8125 (DogStatsD) is in use, may cause conflicts"
    fi
    if ss -tlnp | grep -q ":8126"; then
        echo "⚠️  Port 8126 (Trace Agent) is in use, may cause conflicts"
    fi
fi

# Check compose tool availability
echo "Checking compose tool availability..."
COMPOSE_TOOL=""
COMPOSE_ARGS=""

if command -v podman-compose >/dev/null 2>&1; then
    COMPOSE_TOOL="podman-compose"
    COMPOSE_ARGS="--in-pod false"
    echo "✅ Using podman-compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_TOOL="docker-compose"
    COMPOSE_ARGS=""
    echo "✅ Using docker-compose"
else
    echo "❌ Neither podman-compose nor docker-compose found in PATH"
    echo "   Install podman-compose: pip install --user podman-compose"
    echo "   Or install docker-compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Export for use in other scripts
export COMPOSE_TOOL
export COMPOSE_ARGS

# Check OCI runtime availability
echo "Checking OCI runtime..."
if command -v crun >/dev/null 2>&1; then
    echo "✅ crun OCI runtime found"
elif command -v runc >/dev/null 2>&1; then
    echo "✅ runc OCI runtime found"
    echo "⚠️  Note: Using runc instead of crun (crun is preferred)"
else
    echo "❌ No OCI runtime found (crun or runc)"
    echo "   Install with:"
    echo "   - Arch: sudo pacman -S crun"
    echo "   - Ubuntu/Debian: sudo apt install crun"
    echo "   - Fedora/RHEL: sudo dnf install crun"
    exit 1
fi

# Check podman socket
echo "Checking podman socket..."
SOCKET_STARTED=false
USER_SOCKET="/run/user/$(id -u)/podman/podman.sock"
SYSTEM_SOCKET="/run/podman/podman.sock"

# Check if socket is active (listening)
if systemctl --user status podman.socket >/dev/null 2>&1; then
    echo "✅ User podman socket is active and listening"
    SOCKET_ACTIVE=true
    SOCKET_PATH="$USER_SOCKET"
elif systemctl status podman.socket >/dev/null 2>&1; then
    echo "✅ System podman socket is active and listening"
    SOCKET_ACTIVE=true
    SOCKET_PATH="$SYSTEM_SOCKET"
elif [ -S "$USER_SOCKET" ]; then
    echo "⚠️  User podman socket exists but may not be active: $USER_SOCKET"
    echo "   Starting user podman socket..."
    if systemctl --user start podman.socket >/dev/null 2>&1; then
        echo "✅ User podman socket started"
        SOCKET_STARTED=true
        SOCKET_ACTIVE=true
        SOCKET_PATH="$USER_SOCKET"
    else
        echo "❌ Failed to start user podman socket"
        SOCKET_ACTIVE=false
    fi
elif [ -S "$SYSTEM_SOCKET" ]; then
    echo "⚠️  System podman socket exists but may not be active: $SYSTEM_SOCKET"
    echo "   Note: System socket requires root privileges for containers"
    SOCKET_ACTIVE=true
    SOCKET_PATH="$SYSTEM_SOCKET"
else
    echo "⚠️  No podman socket found. Attempting to start user podman socket..."
    if systemctl --user start podman.socket >/dev/null 2>&1; then
        echo "✅ User podman socket started"
        SOCKET_STARTED=true
        SOCKET_ACTIVE=true
        SOCKET_PATH="$USER_SOCKET"
    else
        echo "❌ Failed to start user podman socket"
        echo "   Start manually with: systemctl --user start podman.socket"
        SOCKET_ACTIVE=false
    fi
fi

# If socket was started, wait a moment for it to be ready
if [ "$SOCKET_STARTED" = true ]; then
    echo "⏳ Waiting for socket to be ready..."
    sleep 2
fi

# Suggest CONTAINER_HOST setting for podman-compose
if [ -n "$SOCKET_PATH" ] && [ "$SOCKET_ACTIVE" = true ]; then
    echo "✓ Podman socket available at: $SOCKET_PATH"
    if [ -z "$CONTAINER_HOST" ]; then
        echo "💡 Tip: Set CONTAINER_HOST for podman-compose:"
        echo "   export CONTAINER_HOST=\"unix://$SOCKET_PATH\""
    fi
elif [ "$SOCKET_ACTIVE" = false ]; then
    echo "⚠️  Podman socket may not be available. Containers may fail to start."
fi

# Check configuration files
echo ""
echo "Checking configuration files..."

# Check datadog.yaml site configuration
if [ -f datadog.yaml ]; then
    if grep -q "site: us5.datadoghq.com" datadog.yaml; then
        echo "⚠️  Datadog site is set to default us5.datadoghq.com"
        echo "   Update datadog.yaml with your site (datadoghq.com, datadoghq.eu, etc.)"
    else
        echo "✅ Datadog site configured"
    fi
fi

# Check http_check.yaml URL
if [ -f conf.d/http_check.yaml ]; then
    if grep -q "url: http://test-server:8080" conf.d/http_check.yaml; then
        echo "⚠️  HTTP check URL is set to example test-server:8080"
        echo "   Update conf.d/http_check.yaml with your actual service URL"
    else
        echo "✅ HTTP check URL configured"
    fi
fi

echo "✅ Environment initialization complete!"