#!/bin/bash
set -e

echo "🚀 Starting deployment..."

# Run initialization checks
./init.sh

# Determine podman compose command
PODMAN_COMPOSE_CMD="podman compose --in-pod false"

echo "Building and starting services..."
$PODMAN_COMPOSE_CMD up -d --build

echo "⏳ Waiting for services to start..."
sleep 10

# Check if containers are running
echo "Checking container status..."
if podman ps --format "table {{.Names}}\t{{.Status}}" | grep -q "vault.*healthy"; then
    echo "✅ Vault container is running and healthy"
else
    echo "⚠️  Vault container may not be healthy. Checking logs..."
    podman logs vault --tail 10 2>/dev/null || true
fi

if podman ps --format "table {{.Names}}\t{{.Status}}" | grep -q "datadog-agent.*Up"; then
    echo "✅ Datadog Agent container is running"
else
    echo "⚠️  Datadog Agent container may not be running. Checking logs..."
    podman logs datadog-agent --tail 10 2>/dev/null || true
fi

echo ""
echo "📊 Deployment Summary:"
echo "======================"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔍 Quick tests:"
echo "1. Test secret backend:"
echo '   echo '\''{"secrets": ["secret/datadog#api_key"]}'\'' | podman exec -i datadog-agent /scripts/secret_backend.py'

echo ""
echo "2. Check agent status:"
echo "   podman exec datadog-agent agent status"

echo ""
echo "📝 Next steps:"
echo "- Update .env with your real Datadog API key"
echo "- Update conf.d/http_check.yaml with your service URL"
echo "- Monitor logs: podman compose --in-pod false logs -f"

echo ""
echo "✅ Deployment complete!"