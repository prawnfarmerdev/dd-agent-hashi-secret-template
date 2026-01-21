#!/bin/bash
set -e

echo "🔍 Podman Configuration Diagnostic Tool"
echo "========================================"

# Check Podman version and installation
echo ""
echo "1. Podman Installation:"
if command -v podman >/dev/null 2>&1; then
    podman --version
else
    echo "❌ Podman not found in PATH"
    exit 1
fi

# Check OCI runtimes
echo ""
echo "2. OCI Runtime Availability:"
if command -v crun >/dev/null 2>&1; then
    echo "✅ crun found: $(crun --version 2>&1 | head -1)"
else
    echo "⚠️  crun not found (this may cause 'OCI runtime crun not found' error)"
fi

if command -v runc >/dev/null 2>&1; then
    echo "✅ runc found: $(runc --version 2>&1 | head -1)"
else
    echo "⚠️  runc not found"
fi

# Check Podman info
echo ""
echo "3. Podman Configuration:"
if podman info --format json >/dev/null 2>&1; then
    echo "✅ Podman info accessible"
    RUNTIME=$(podman info --format '{{.Host.OCIRuntime.Name}}' 2>/dev/null || echo "unknown")
    echo "   Default OCI runtime: $RUNTIME"
else
    echo "❌ Cannot get podman info"
    echo "   Error: $(podman info 2>&1 | head -5)"
fi

# Check storage configuration
echo ""
echo "4. Storage Configuration:"
RUNROOT=$(podman info --format '{{.Store.RunRoot}}' 2>/dev/null || echo "unknown")
GRAPHROOT=$(podman info --format '{{.Store.GraphRoot}}' 2>/dev/null || echo "unknown")
echo "   RunRoot: $RUNROOT"
echo "   GraphRoot: $GRAPHROOT"

# Check if runroot is writable
if [ -d "$RUNROOT" ]; then
    if touch "$RUNROOT/.test-write" 2>/dev/null; then
        echo "✅ RunRoot is writable"
        rm -f "$RUNROOT/.test-write"
    else
        echo "❌ RunRoot is NOT writable: $RUNROOT"
        echo "   This can cause 'invalid argument' errors"
        echo "   Check permissions: ls -la $(dirname "$RUNROOT")"
    fi
else
    echo "⚠️  RunRoot directory doesn't exist: $RUNROOT"
    echo "   Creating directory..."
    sudo mkdir -p "$RUNROOT" 2>/dev/null || echo "   Failed to create directory"
fi

# Check user namespace
echo ""
echo "5. User Namespace Configuration:"
if podman unshare ls >/dev/null 2>&1; then
    echo "✅ User namespace works"
else
    echo "❌ User namespace issues"
    echo "   Check /etc/subuid and /etc/subgid"
fi

# Check container registries
echo ""
echo "6. Container Registry Configuration:"
if [ -f /etc/containers/registries.conf ]; then
    echo "✅ Registry config found: /etc/containers/registries.conf"
else
    echo "⚠️  No registry config found"
fi

# Check podman-compose
echo ""
echo "7. Podman Compose:"
if command -v podman-compose >/dev/null 2>&1; then
    podman-compose --version
else
    echo "⚠️  podman-compose not found"
    echo "   Install with: pip install --user podman-compose"
fi

# Test simple container
echo ""
echo "8. Simple Container Test:"
if podman run --rm hello-world >/dev/null 2>&1; then
    echo "✅ Simple container test passed"
else
    echo "❌ Simple container test failed"
    ERROR=$(podman run --rm hello-world 2>&1 | tail -5)
    echo "   Error: $ERROR"
fi

# Check systemd socket
echo ""
echo "9. Podman Socket:"
if systemctl --user status podman.socket >/dev/null 2>&1; then
    echo "✅ User podman socket active"
elif systemctl status podman.socket >/dev/null 2>&1; then
    echo "✅ System podman socket active"
else
    echo "⚠️  No podman socket found"
    echo "   Start with: systemctl --user start podman.socket"
fi

# Check common issues
echo ""
echo "10. Common Issue Checks:"
echo "    a) SELinux/AppArmor:"
if command -v getenforce >/dev/null 2>&1; then
    echo "       SELinux: $(getenforce 2>/dev/null || echo 'not installed')"
fi

echo "    b) Firewall:"
if command -v firewall-cmd >/dev/null 2>&1; then
    echo "       FirewallD: $(firewall-cmd --state 2>/dev/null || echo 'not running')"
fi

echo "    c) Cgroups:"
if [ -f /proc/cgroups ]; then
    echo "       Cgroups v2: $(grep -q cgroup2 /proc/filesystems && echo 'yes' || echo 'no')"
fi

echo ""
echo "📋 Recommended Fixes:"
echo "===================="
echo "1. Install missing OCI runtime:"
echo "   - Arch: sudo pacman -S crun"
echo "   - Ubuntu/Debian: sudo apt install crun"
echo "   - Fedora/RHEL: sudo dnf install crun"
echo ""
echo "2. Fix RunRoot permissions:"
echo "   sudo chown -R $(whoami):$(whoami) $RUNROOT"
echo "   sudo chmod 755 $RUNROOT"
echo ""
echo "3. Configure alternative runtime (runc):"
echo "   Create /etc/containers/containers.conf with:"
echo "   [engine]"
echo "   runtime = \"runc\""
echo ""
echo "4. Reset Podman storage:"
echo "   podman system reset"
echo "   (WARNING: removes all containers and images)"
echo ""
echo "✅ Diagnostic complete!"