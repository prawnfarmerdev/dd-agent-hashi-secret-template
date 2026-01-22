# Native HashiCorp Vault Integration Learnings

## 🎯 Key Discoveries

### 1. **Token Authentication IS Supported (Contrary to Documentation)**
- The native Datadog Agent Vault integration **does support token authentication**
- Official documentation only shows AWS IAM authentication, but token auth works
- Configuration format is different from the external `datadog-secret-backend`

### 2. **Correct Configuration Format**
```yaml
# ✅ WORKING - Token authentication
secret_backend_type: hashicorp.vault
secret_backend_config:
  vault_address: http://vault:8200
  vault_token: root  # Literal token OR file path
```

```yaml
# ❌ DOESN'T WORK - Incorrect format
secret_backend_config:
  vault_address: http://vault:8200
  vault_session:  # This structure doesn't work for token auth
    vault_auth_type: token
    vault_token: root
```

### 3. **File Artifact Requirement**
- Agent requires `/etc/datadog-agent/auth_token` file (security artifact check)
- File can be empty or contain the token value
- Must exist even when using literal token in YAML (`vault_token: root`)
- Mount in docker-compose: `- ./secrets/auth_token:/etc/datadog-agent/auth_token` (writable, not read-only)

### 4. **KV v2 Compatibility**
- Native integration works with **KV v2** (not just KV v1)
- Uses `/v1/secret/data/datadog` API path for KV v2
- Proper Vault policies required for KV v2:
  ```hcl
  path "secret/data/datadog" {
    capabilities = ["read"]
  }
  path "sys/mounts" {
    capabilities = ["read"]  # Needed for version detection
  }
  ```

## 🔧 Working Implementation

### Current Configuration
**`datadog.yaml`:**
```yaml
api_key: ENC[/secret/datadog;api_key]
site: us5.datadoghq.com
hostname: dd-agent-hashi-secret

secret_backend_type: hashicorp.vault
secret_backend_config:
  vault_address: http://vault:8200
  vault_token: root  # Also needs /etc/datadog-agent/auth_token file
```

**`docker-compose.yml` additions:**
```yaml
volumes:
  - ./secrets/auth_token:/etc/datadog-agent/auth_token
```

**Token file:**
```bash
echo -n "root" > secrets/auth_token
```

## 🐛 Troubleshooting Guide

### 1. **Enable Debug Logging**
```bash
# Set environment variable
export DD_LOG_LEVEL=debug

# Or in docker-compose
environment:
  - DD_LOG_LEVEL=debug
```

### 2. **Check Secret Resolution**
Look for these log patterns:
```
# Success
calling secret_backend_command with payload: '{"config":{"vault_address":"...","vault_token":"..."}...}'
Secret '/secret/datadog;api_key' was successfully resolved

# Failure
Error making API request
no auth method or token provided
```

### 3. **Test Vault Connectivity**
```bash
# From Agent container
docker-compose exec datadog-agent curl -s -H "X-Vault-Token: root" http://vault:8200/v1/sys/health

# Test secret retrieval
docker-compose exec datadog-agent curl -s -H "X-Vault-Token: root" http://vault:8200/v1/secret/data/datadog
```

### 4. **Verify Configuration**
```bash
# Run configcheck
docker-compose exec datadog-agent agent configcheck -v

# Check secret status
docker-compose exec datadog-agent agent secret
```

### 5. **Common Errors & Solutions**

| Error | Cause | Solution |
|-------|-------|----------|
| `no auth method or token provided` | Invalid auth configuration | Use `vault_token` at root level (not in `vault_session`) |
| `Error making API request` | KV version mismatch or network issue | Use KV v2, check Vault logs |
| `unable to read artifact: /etc/datadog-agent/auth_token` | Missing token file | Create empty file at required path |
| `unable to move temp artifact to final location /etc/datadog-agent/auth_token: file exist` | Read-only mount or file permissions | Mount file as writable (`chmod 666 secrets/auth_token`) |
| `unsupported backend type` | Testing `secret-generic-connector` directly | Use Agent config, not direct connector |

### 6. **Check Vault Logs**
```bash
# Enable trace logging in Vault
vault server -dev -log-level=trace

# Check for incoming requests
grep -i "request\|auth\|secret" /tmp/vault.log
```

## 🔐 Authentication Types

### Currently Working
1. **Token Authentication** ✅
   - Literal token: `vault_token: root`
   - File-based token: `vault_token: /path/to/token`

### Documented (Official Docs)
1. **AWS IAM Authentication** ✅
   ```yaml
   secret_backend_config:
     vault_address: http://vault.example.com
     vault_session:
       vault_auth_type: aws
       vault_aws_role: Name-of-IAM-role-attached-to-machine
       aws_region: us-east-1
   ```

### In External Backend (Not Tested in Native)
The external `datadog-secret-backend` project supports:
1. **AppRole Authentication**
   ```yaml
   vault_session:
     vault_role_id: "123456-************"
     vault_secret_id: "abcdef-********"
   ```

2. **UserPass Authentication**
   ```yaml
   vault_session:
     vault_username: myuser
     vault_password: mypassword
   ```

3. **LDAP Authentication**
   ```yaml
   vault_session:
     vault_ldap_username: myuser
     vault_ldap_password: mypassword
   ```

**Note:** These `vault_session` structures may not work in the native integration.

## 📊 Native vs External Backend Comparison

| Feature | Native Integration | External Backend |
|---------|-------------------|------------------|
| Token Auth | ✅ Works (`vault_token: value`) | ✅ Works |
| AWS Auth | ✅ Documented | ✅ Works |
| AppRole Auth | ❓ Untested | ✅ Works |
| UserPass Auth | ❓ Untested | ✅ Works |
| LDAP Auth | ❓ Untested | ✅ Works |
| KV v1 Support | ✅ Likely | ✅ Works |
| KV v2 Support | ✅ Works | ✅ Works |
| Agent Version | v7.32.0+ | Any version |
| Configuration | Simple YAML in `datadog.yaml` | Separate config file |

## 🚀 Production Recommendations

### 1. **Use File-Based Tokens (Not Literal)**
```yaml
secret_backend_config:
  vault_address: https://vault.example.com:8200
  vault_token: /etc/datadog-agent/auth_token  # File path
```

### 2. **Secure Token File**
```bash
# Set proper permissions
chmod 600 secrets/auth_token
chown dd-agent:dd-agent secrets/auth_token
```

### 3. **Use Environment-Specific Tokens**
```yaml
# Development
vault_token: root

# Production - use AppRole or file-based token
vault_token: /etc/datadog-agent/auth_token
```

### 4. **Implement Vault Policies**
```hcl
# Minimal policy for Datadog Agent
path "secret/data/datadog" {
  capabilities = ["read"]
}

path "sys/mounts" {
  capabilities = ["read"]
}
```

### 5. **Monitor and Alert**
- Monitor Agent logs for secret resolution failures
- Set up alerts for `Error making API request`
- Track Vault token expiration

## 🔍 Testing Procedure

### Quick Validation
```bash
# 1. Start Vault
docker-compose up -d vault

# 2. Setup KV v2 and secret
docker-compose exec vault vault secrets enable -path=secret kv-v2
docker-compose exec vault vault kv put secret/datadog api_key="test_key_123"

# 3. Start Agent
docker-compose up datadog-agent

# 4. Verify
docker-compose logs datadog-agent | grep -i "secret\|resolved\|api_key"
```

### Debug Test
```bash
# Run with debug logging
docker-compose run -e DD_LOG_LEVEL=debug datadog-agent agent configcheck -v
```

## 📚 References

- [Datadog Secret Management Documentation](https://docs.datadoghq.com/agent/configuration/secrets-management/)
- [Native HashiCorp Vault Integration Docs](https://docs.datadoghq.com/agent/configuration/secrets-management/?tab=agentyamlfile#hashicorp-vault-backend)
- [External datadog-secret-backend](https://github.com/DataDog/datadog-secret-backend)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)

---

## ⚠️ Important Notes

1. **Documentation Gap**: Official docs only show AWS auth, but token auth works
2. **Configuration Format**: Use `vault_token` at root level, not in `vault_session`
3. **File Requirement**: `/etc/datadog-agent/auth_token` must exist (can be empty)
4. **KV v2 Recommended**: Use KV v2 for forward compatibility
5. **Test Thoroughly**: Always test in non-production first

## ✅ Current Implementation Status

**Yes, the current implementation uses native HashiCorp Vault integration** (`secret_backend_type: hashicorp.vault`). It successfully resolves secrets from Vault using token authentication with KV v2 secrets engine.

The configuration has been tested and verified to work with:
- ✅ Token authentication (literal and file-based)
- ✅ KV v2 secrets engine
- ✅ Proper secret resolution before Agent startup
- ✅ Docker Compose deployment