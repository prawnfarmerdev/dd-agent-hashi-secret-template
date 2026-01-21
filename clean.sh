#!/bin/bash
set -e

echo "🧹 Starting cleanup process..."

# Detect container runtime
if command -v podman >/dev/null 2>&1; then
    RUNTIME="podman"
    COMPOSE_CMD="podman compose --in-pod false"
elif command -v docker >/dev/null 2>&1; then
    RUNTIME="docker"
    COMPOSE_CMD="docker-compose"
else
    echo "❌ No container runtime found (podman or docker)"
    exit 1
fi

echo "Using $RUNTIME runtime"

# Stop and remove containers from docker-compose
echo "Stopping and removing compose containers..."
$COMPOSE_CMD down 2>/dev/null || true

# Force remove all containers
echo "Force removing all containers..."
$RUNTIME rm -af 2>/dev/null || true

# Remove all networks (except default network)
echo "Pruning networks..."
$RUNTIME network prune -f 2>/dev/null || true

# Remove all pods if any exist (podman only)
if [ "$RUNTIME" = "podman" ]; then
    echo "Removing pods..."
    podman pod rm -af 2>/dev/null || true
fi

# Remove volumes (if any)
echo "Pruning volumes..."
$RUNTIME volume prune -f 2>/dev/null || true

# Clean up temporary files
echo "Cleaning temporary files..."
if [ -f .env ]; then
    if grep -q "your_datadog_api_key_here" .env || grep -q "placeholder_api_key_123" .env; then
        echo "Removing .env file with placeholder credentials..."
        rm -f .env
    else
        echo "⚠️  WARNING: .env file appears to contain real credentials"
        echo "   Backing up to .env.backup and creating fresh .env.example copy..."
        cp .env .env.backup
        cp .env.example .env
        echo "   Original .env backed up to .env.backup"
    fi
fi

echo "✅ Cleanup complete! System is ready for fresh deployment."