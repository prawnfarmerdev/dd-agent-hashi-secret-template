#!/bin/bash
set -e

echo "🧪 Starting deployment test suite..."

# Test 1: Check required images can be pulled
echo ""
echo "1. Testing image availability..."
if podman pull hashicorp/vault:1.21.2 >/dev/null 2>&1; then
    echo "   ✅ Vault image (hashicorp/vault:1.21.2) is available"
else
    echo "   ❌ Failed to pull hashicorp/vault:1.21.2"
    exit 1
fi

if podman pull datadog/agent:7.74.1 >/dev/null 2>&1; then
    echo "   ✅ Datadog Agent image (7.74.1) is available"
else
    echo "   ❌ Failed to pull datadog/agent:7.74.1"
    exit 1
fi

# Test 2: Clean deployment
echo ""
echo "2. Testing clean deployment..."
./clean.sh
./init.sh
podman compose --in-pod false up -d --build

# Test 3: Wait for services to start
echo ""
echo "3. Waiting for services to start (30 seconds)..."
for i in {1..30}; do
    printf "."
    sleep 1
done
echo ""

# Test 4: Verify containers are running
echo ""
echo "4. Verifying container status..."
VAULT_STATUS=$(podman inspect vault --format='{{.State.Status}}' 2>/dev/null || echo "not found")
DD_STATUS=$(podman inspect datadog-agent --format='{{.State.Status}}' 2>/dev/null || echo "not found")

if [ "$VAULT_STATUS" = "running" ]; then
    echo "   ✅ Vault container is running"
else
    echo "   ❌ Vault container status: $VAULT_STATUS"
    podman logs vault --tail 5 2>/dev/null || true
    exit 1
fi

if [ "$DD_STATUS" = "running" ]; then
    echo "   ✅ Datadog Agent container is running"
else
    echo "   ❌ Datadog Agent container status: $DD_STATUS"
    podman logs datadog-agent --tail 5 2>/dev/null || true
    exit 1
fi

# Test 5: Verify network connectivity
echo ""
echo "5. Testing network connectivity..."
if podman exec vault wget -q --spider http://127.0.0.1:8200/v1/sys/health 2>/dev/null; then
    echo "   ✅ Vault health endpoint is accessible"
else
    echo "   ❌ Vault health endpoint not accessible"
    exit 1
fi

# Test 6: Test secret backend
echo ""
echo "6. Testing secret backend..."
SECRET_OUTPUT=$(echo '{"secrets": ["secret/datadog#api_key"]}' | podman exec -i datadog-agent /scripts/secret_backend.py 2>/dev/null || true)
if echo "$SECRET_OUTPUT" | grep -q "placeholder_api_key_123\|your_datadog_api_key_here"; then
    echo "   ✅ Secret backend is functioning"
else
    echo "   ❌ Secret backend test failed"
    echo "   Output: $SECRET_OUTPUT"
    exit 1
fi

# Test 7: Verify agent configuration
echo ""
echo "7. Verifying Datadog Agent configuration..."
if podman exec datadog-agent agent configcheck 2>/dev/null | grep -q "http_check"; then
    echo "   ✅ HTTP check configuration loaded"
else
    echo "   ❌ HTTP check configuration not found"
    exit 1
fi

echo ""
echo "🎉 All tests passed! Deployment is working correctly."
echo ""
echo "Container Summary:"
echo "================="
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.CreatedAt}}"

echo ""
echo "📋 Next steps for production use:"
echo "1. Update .env with your real Datadog API key"
echo "2. Update conf.d/http_check.yaml with your service URL"
echo "3. Add more checks to conf.d/ directory"
echo "4. Monitor logs: podman compose --in-pod false logs -f"