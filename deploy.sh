#!/bin/bash
set -e

echo "🚀 Starting deployment..."

# Run initialization checks (source to get environment variables)
source ./init.sh

# Determine compose command
COMPOSE_CMD="$COMPOSE_TOOL $COMPOSE_ARGS"

# Determine container runtime (podman or docker)
CONTAINER_RUNTIME="podman"
if [ "$COMPOSE_TOOL" = "docker-compose" ]; then
    CONTAINER_RUNTIME="docker"
fi

echo "Building and starting services..."
$COMPOSE_CMD up -d --build

echo "⏳ Waiting for services to start..."
sleep 10

# Check if containers are running
echo "Checking container status..."
if $CONTAINER_RUNTIME ps --format "table {{.Names}}\t{{.Status}}" | grep -q "vault.*healthy"; then
    echo "✅ Vault container is running and healthy"
else
    echo "⚠️  Vault container may not be healthy. Checking logs..."
    $CONTAINER_RUNTIME logs vault --tail 10 2>/dev/null || true
fi

if $CONTAINER_RUNTIME ps --format "table {{.Names}}\t{{.Status}}" | grep -q "datadog-agent.*Up"; then
    echo "✅ Datadog Agent container is running"
else
    echo "⚠️  Datadog Agent container may not be running. Checking logs..."
    $CONTAINER_RUNTIME logs datadog-agent --tail 10 2>/dev/null || true
fi

echo ""
echo "📊 Deployment Summary:"
echo "======================"
$CONTAINER_RUNTIME ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔍 Quick tests:"
echo "1. Test secret backend:"
echo '   echo '\''{"secrets": ["secret/datadog#api_key"]}'\'' | $CONTAINER_RUNTIME exec -i datadog-agent /scripts/secret_backend.py'

echo ""
echo "2. Check agent status:"
echo "   $CONTAINER_RUNTIME exec datadog-agent agent status"

echo ""
echo "📝 Next steps:"
echo "- Update .env with your real Datadog API key"
echo "- Update conf.d/http_check.yaml with your service URL"
echo "- Monitor logs: $COMPOSE_CMD logs -f"

echo ""
echo "✅ Deployment complete!"