#!/bin/bash
# verify-setup.sh - Simple verification script for Datadog Agent with Vault integration

set -e

echo "🔍 Verifying Datadog Agent with Vault integration setup..."

# Check required files exist
echo "📁 Checking configuration files..."
required_files=(
    "docker-compose.yml"
    "Dockerfile"
    "datadog.yaml"
    ".env.example"
    "secrets/auth_token"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (missing)"
        exit 1
    fi
done

# Check auth_token file permissions
if [ -f "secrets/auth_token" ]; then
    echo "🔒 Checking auth_token file permissions..."
    perms=$(stat -c "%a" "secrets/auth_token" 2>/dev/null || stat -f "%p" "secrets/auth_token" | sed 's/.*\(...\)/\1/')
    if [[ "$perms" == *"66"* ]] || [[ "$perms" == *"77"* ]]; then
        echo "  ✅ auth_token has proper permissions ($perms)"
    else
        echo "  ⚠️  auth_token may have restrictive permissions ($perms)"
        echo "     Consider running: chmod 666 secrets/auth_token"
    fi
fi

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found, copying from .env.example"
    cp .env.example .env
    echo "  Please update .env with your Datadog API key"
fi

# Check Docker availability
echo "🐳 Checking Docker availability..."
if command -v docker &> /dev/null; then
    echo "  ✅ Docker is available"
else
    echo "  ❌ Docker not found"
    exit 1
fi

# Check Docker Compose availability
if command -v docker-compose &> /dev/null; then
    echo "  ✅ Docker Compose is available"
else
    echo "  ❌ Docker Compose not found"
    exit 1
fi

# Check if services are running
echo "🚀 Checking running services..."
if docker-compose ps | grep -q "Up"; then
    echo "  ✅ Services are running"
    
    # Test Vault connectivity
    echo "🔐 Testing Vault connectivity..."
    if curl -s http://localhost:8200/v1/sys/health > /dev/null 2>&1; then
        echo "  ✅ Vault is responding"
    else
        echo "  ❌ Vault not responding on localhost:8200"
    fi
    
    # Test Datadog Agent
    echo "📊 Testing Datadog Agent..."
    if docker exec datadog-agent agent status > /dev/null 2>&1; then
        echo "  ✅ Datadog Agent is running"
    else
        echo "  ❌ Datadog Agent not responding"
    fi
else
    echo "  ℹ️  Services not running"
    echo "  To start services: docker-compose up -d --build"
fi

echo ""
echo "📋 Summary:"
echo "  - Configuration files: ✅"
echo "  - Docker availability: ✅"
echo "  - Services status: $(docker-compose ps | grep -q "Up" && echo "✅ Running" || echo "⚠️ Not running")"
echo ""
echo "🚀 Next steps:"
echo "  1. Update .env with your Datadog API key"
echo "  2. Run: docker-compose up -d --build"
echo "  3. Check logs: docker-compose logs -f datadog-agent"
echo "  4. Verify: docker exec datadog-agent agent status"
echo ""
echo "✅ Verification complete!"