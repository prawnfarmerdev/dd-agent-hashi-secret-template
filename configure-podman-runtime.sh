#!/bin/bash
set -e

echo "⚙️  Podman Runtime Configuration Tool"
echo "====================================="

# Check if crun is available
if command -v crun >/dev/null 2>&1; then
    echo "✅ crun is already installed: $(crun --version 2>&1 | head -1)"
    echo "   No configuration needed."
    exit 0
fi

echo "⚠️  crun not found"

# Check if runc is available
if command -v runc >/dev/null 2>&1; then
    echo "✅ runc is available: $(runc --version 2>&1 | head -1)"
else
    echo "❌ Neither crun nor runc is available"
    echo ""
    echo "Please install an OCI runtime:"
    echo "   - Arch Linux: sudo pacman -S crun"
    echo "   - Ubuntu/Debian: sudo apt install crun"
    echo "   - Fedora/RHEL: sudo dnf install crun"
    echo "   Or install runc: sudo pacman -S runc / sudo apt install runc"
    exit 1
fi

# Check current runtime configuration
USER_CONFIG="$HOME/.config/containers/containers.conf"
SYSTEM_CONFIG="/etc/containers/containers.conf"

echo ""
echo "Current Podman runtime: $(podman info --format '{{.Host.OCIRuntime.Name}}' 2>/dev/null || echo 'unknown')"

# Ask user if they want to configure runc as default
echo ""
echo "Do you want to configure Podman to use runc instead of crun?"
read -p "This will create/update $USER_CONFIG [y/N]: " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Configuration cancelled."
    exit 0
fi

# Create user config directory if needed
mkdir -p "$(dirname "$USER_CONFIG")"

# Create or update containers.conf
if [ -f "$USER_CONFIG" ]; then
    echo "⚠️  User containers.conf already exists at $USER_CONFIG"
    echo "   Backing up to $USER_CONFIG.backup"
    cp "$USER_CONFIG" "$USER_CONFIG.backup"
fi

echo "Creating $USER_CONFIG with runc as default runtime..."
cat > "$USER_CONFIG" << 'EOF'
# Podman configuration to use runc instead of crun
# Created by configure-podman-runtime.sh

[containers]

[engine]
# Use runc as the OCI runtime
runtime = "runc"

# List of OCI runtimes that are supported
runtimes = [
    "runc",
    "crun"
]

[network]

EOF

echo "✅ Configuration saved to $USER_CONFIG"
echo ""
echo "Note: This configuration only affects your user account."
echo "To apply system-wide, you would need to edit $SYSTEM_CONFIG"
echo ""
echo "You may need to restart Podman services for changes to take effect."
echo "Try: podman system reset (warning: removes all containers/images)"
echo "Or simply log out and log back in."