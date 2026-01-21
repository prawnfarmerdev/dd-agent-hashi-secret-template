#!/bin/sh
set -e

# Function to retry a command with exponential backoff
# Usage: retry_command <max_attempts> <initial_wait> <max_wait> <command>
retry_command() {
    local max_attempts=$1
    local wait_seconds=$2
    local max_wait=$3
    shift 3
    local attempt=1
    local command=("$@")
    
    while [ $attempt -le $max_attempts ]; do
        if "${command[@]}" > /dev/null 2>&1; then
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            echo "Command failed after $max_attempts attempts: ${command[*]}"
            return 1
        fi
        
        echo "Attempt $attempt/$max_attempts failed, waiting ${wait_seconds}s..."
        sleep $wait_seconds
        
        # Exponential backoff with max limit
        wait_seconds=$((wait_seconds * 2))
        if [ $wait_seconds -gt $max_wait ]; then
            wait_seconds=$max_wait
        fi
        attempt=$((attempt + 1))
    done
}

# Wait for Vault to be ready with exponential backoff
echo "Waiting for Vault to be ready..."
max_attempts=30
attempt=1
wait_seconds=2

while [ $attempt -le $max_attempts ]; do
    if curl -s -f http://vault:8200/v1/sys/health > /dev/null 2>&1; then
        echo "Vault is ready after $attempt attempt(s)"
        break
    fi
    
    if [ $attempt -eq $max_attempts ]; then
        echo "ERROR: Vault did not become ready after $max_attempts attempts"
        echo "Check Vault logs with: podman logs vault"
        exit 1
    fi
    
    echo "Attempt $attempt/$max_attempts: Vault not ready, waiting ${wait_seconds}s..."
    sleep $wait_seconds
    
    # Exponential backoff with max 10 seconds
    wait_seconds=$((wait_seconds * 2))
    if [ $wait_seconds -gt 10 ]; then
        wait_seconds=10
    fi
    attempt=$((attempt + 1))
done

# Initialize KV v2 secrets engine with retry
echo "Initializing KV v2 secrets engine..."
if retry_command 5 1 5 curl -s -f -X POST -H "X-Vault-Token: ${VAULT_TOKEN}" \
   -d '{"type":"kv-v2"}' \
   http://vault:8200/v1/sys/mounts/secret; then
    echo "✅ KV v2 secrets engine initialized"
else
    echo "⚠️  KV v2 secrets engine may already exist or initialization failed"
fi

# Write Datadog API key secret with retry
if [ -n "${VAULT_DD_API_KEY}" ]; then
    echo "Writing Datadog API key to Vault..."
    if retry_command 5 1 5 curl -s -f -X POST -H "X-Vault-Token: ${VAULT_TOKEN}" \
       -d "{\"data\":{\"api_key\":\"${VAULT_DD_API_KEY}\"}}" \
       http://vault:8200/v1/secret/data/datadog; then
        echo "✅ Datadog API key written to secret/datadog#api_key"
    else
        echo "⚠️  Datadog API key may already exist or write failed"
    fi
else
    echo "⚠️  VAULT_DD_API_KEY not set, using placeholder from .env"
fi

# Write HTTP check credentials with retry
echo "Writing HTTP check credentials to Vault..."
if retry_command 5 1 5 curl -s -f -X POST -H "X-Vault-Token: ${VAULT_TOKEN}" \
   -d '{"data":{"username":"testuser","password":"testpass"}}' \
   http://vault:8200/v1/secret/data/http_check; then
    echo "✅ HTTP check credentials written to secret/http_check"
else
    echo "⚠️  HTTP check credentials may already exist or write failed"
fi

echo "✅ Secrets initialized. Starting Datadog Agent..."

# Start the original entrypoint
exec "$@"