#!/usr/bin/env python3
"""
Datadog Agent secret backend script for HashiCorp Vault.
Fetches secrets from Vault's KV engine (v2).
"""
import json
import os
import sys
import hvac

def get_vault_client():
    """Initialize and return a Vault client."""
    vault_addr = os.environ.get('VAULT_ADDR', 'http://vault:8200')
    vault_token = os.environ.get('VAULT_TOKEN')
    if not vault_token:
        raise ValueError('VAULT_TOKEN environment variable is required')
    
    client = hvac.Client(url=vault_addr, token=vault_token)
    if not client.is_authenticated():
        raise Exception('Vault client not authenticated')
    return client

def fetch_secret(secret_handle):
    """
    Fetch secret from Vault.
    secret_handle format: "mount/path#key" where mount is the KV mount and path is the secret path.
    For KV v2, the API path is 'mount/data/path'.
    """
    if '#' not in secret_handle:
        raise ValueError(f'Invalid secret handle format: {secret_handle}. Expected "mount/path#key"')
    
    mount_path, key = secret_handle.split('#', 1)
    # Split mount and path
    parts = mount_path.split('/', 1)
    if len(parts) != 2:
        raise ValueError(f'Invalid mount/path format: {mount_path}. Expected "mount/path"')
    mount, secret_path = parts
    
    client = get_vault_client()
    # Try KV v2 first
    try:
        response = client.secrets.kv.v2.read_secret_version(mount_point=mount, path=secret_path)
        data = response['data']['data']
        if key not in data:
            raise KeyError(f'Key "{key}" not found in secret "{mount}/{secret_path}"')
        return data[key]
    except Exception:
        # If KV v2 fails, try KV v1
        try:
            response = client.secrets.kv.v1.read_secret(mount_point=mount, path=secret_path)
            data = response['data']
            if key not in data:
                raise KeyError(f'Key "{key}" not found in secret "{mount}/{secret_path}"')
            return data[key]
        except Exception as e:
            raise Exception(f'Failed to fetch secret {secret_handle}: {e}')

def main():
    try:
        # Read JSON from stdin
        input_str = sys.stdin.read()
        if not input_str:
            return
        # Log the request for debugging
        sys.stderr.write(f"Secret backend called with: {input_str}\n")
        sys.stderr.flush()
        request = json.loads(input_str)
        
        secrets = request.get('secrets', [])
        result = {}
        for secret_handle in secrets:
            try:
                secret_value = fetch_secret(secret_handle)
                result[secret_handle] = {
                    'value': secret_value,
                    'error': None
                }
            except Exception as e:
                result[secret_handle] = {
                    'value': None,
                    'error': str(e)
                }
        
        # Output result JSON
        sys.stdout.write(json.dumps(result))
        sys.stdout.flush()
    except Exception as e:
        # If something goes wrong, output error
        sys.stderr.write(f'Error in secret backend: {e}')
        sys.exit(1)

if __name__ == '__main__':
    main()