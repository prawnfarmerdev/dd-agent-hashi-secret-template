#!/bin/sh
set -e

# Wait for Vault to be ready
echo "Waiting for Vault..."
until curl -s -f http://localhost:8200/v1/sys/health > /dev/null; do
    sleep 2
done

# Initialize secrets (if not already)
curl -s -X POST -H "X-Vault-Token: ${VAULT_TOKEN}" -d '{"type":"kv-v2"}' http://localhost:8200/v1/sys/mounts/secret > /dev/null 2>&1 || true

# Write Datadog API key secret (if not set)
if [ -n "${VAULT_DD_API_KEY}" ]; then
    curl -s -X POST -H "X-Vault-Token: ${VAULT_TOKEN}" -d "{\"data\":{\"api_key\":\"${VAULT_DD_API_KEY}\"}}" http://localhost:8200/v1/secret/data/datadog > /dev/null 2>&1 || true
fi

# Write HTTP check credentials (if not set)
curl -s -X POST -H "X-Vault-Token: ${VAULT_TOKEN}" -d '{"data":{"username":"testuser","password":"testpass"}}' http://localhost:8200/v1/secret/data/http_check > /dev/null 2>&1 || true

echo "Secrets initialized. Starting Datadog Agent..."

# Start the original entrypoint
exec "$@"