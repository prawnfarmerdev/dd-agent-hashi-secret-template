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

# Check podman-compose availability
echo "Checking podman-compose..."
if ! command -v podman-compose >/dev/null 2>&1; then
    echo "❌ podman-compose not found in PATH"
    echo "   Install with: pip install --user podman-compose"
    echo "   Or on Arch: sudo pacman -S podman-compose"
    exit 1
fi

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
if [ -S "/run/podman/podman.sock" ]; then
    echo "✓ Found system podman socket: /run/podman/podman.sock"
    echo "⚠️  Note: Using system socket may require root privileges"
elif [ -S "/run/user/$(id -u)/podman/podman.sock" ]; then
    echo "✓ Found user podman socket: /run/user/$(id -u)/podman/podman.sock"
else
    echo "⚠️  No podman socket found. Ensure podman service is running."
    echo "   Start with: systemctl --user start podman.socket"
fi

echo "✅ Environment initialization complete!"