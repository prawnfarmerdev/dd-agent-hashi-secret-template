# Datadog Agent with HashiCorp Vault (Simplified)

A minimal implementation of Datadog Agent with HashiCorp Vault secret management.

## Quick Start

### Using Helper Scripts (Recommended)

For a unified interface, use the master manager script:
```bash
./manage.sh all   # Clean, init, deploy, and test in sequence
```

Or use individual commands:

1. **Initialize environment:**
   ```bash
   ./init.sh
   # Edit .env file to add your real Datadog API key
   ```

2. **Deploy services:**
   ```bash
   ./deploy.sh
   ```

3. **Test deployment:**
   ```bash
   ./test-deployment.sh
   ```

### Manual Deployment

1. **Copy environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` and add your Datadog API key:**
   ```bash
   VAULT_DD_API_KEY=your_actual_datadog_api_key_here
   ```

3. **Update `datadog.yaml` with your Datadog site:**
   - Change `site: us5.datadoghq.com` to your site (e.g., `datadoghq.com`, `datadoghq.eu`)

4. **Update `conf.d/http_check.yaml` with your service URL:**
   - Change `url: http://test-server:8080` to your actual service endpoint
   - Update credentials in Vault or modify the `secret/http_check` path as needed

5. **Start services with Podman Compose:**
   ```bash
   podman compose --in-pod false up -d --build
   ```

## Podman Support

This template is compatible with Podman Compose. See [PODMAN.md](PODMAN.md) for detailed instructions.

## Resilient Deployment

This template is designed to survive `podman system reset` operations. Key resilience features:

### Version Pinning
- **Vault**: Pinned to version `1.21.2` (stable, confirmed working)
- **Datadog Agent**: Pinned to version `7.74.1` (current stable)

### Helper Scripts
- `clean.sh` - Complete cleanup of containers, networks, and pods
- `init.sh` - Environment validation and setup
- `deploy.sh` - Automated deployment with health checks
- `test-deployment.sh` - Comprehensive deployment verification
- `manage.sh` - Unified manager for all operations (clean, init, deploy, test, status, logs)

### Recovery from System Reset
```bash
# After podman system reset:
./clean.sh      # Clean any residual state
./init.sh       # Validate environment
./deploy.sh     # Deploy fresh instance
./test-deployment.sh  # Verify functionality
```

### Robust Startup
- Exponential backoff for Vault readiness (up to 30 attempts)
- Graceful handling of existing secrets
- Detailed logging for troubleshooting

## Components

- **HashiCorp Vault**: Development server with KV v2 secrets engine
- **Datadog Agent**: Custom container with secret backend integration
- **Secret Backend**: Python script that retrieves secrets from Vault

## Secrets Configuration

The system automatically initializes these secrets in Vault:

1. **Datadog API Key**: `secret/datadog#api_key` (from `VAULT_DD_API_KEY` environment variable)
2. **HTTP Check Credentials**: `secret/http_check#username` and `secret/http_check#password`

## Configuration Files

### Core Configuration
- `datadog.yaml`: Main Datadog Agent configuration
- `conf.d/http_check.yaml`: HTTP check with Vault-secured credentials

### Scripts
- `scripts/secret_backend.py`: Vault integration script
- `scripts/startup.sh`: Service initialization script (with exponential backoff)

### Helper Scripts
- `clean.sh`: Complete cleanup of containers, networks, and pods
- `init.sh`: Environment validation and initialization (includes OCI runtime checks)
- `deploy.sh`: Automated deployment with health checks
- `test-deployment.sh`: Comprehensive deployment verification
- `diagnose-podman.sh`: Diagnostic tool for Podman configuration issues

## Usage

After starting the services:

1. Check Datadog Agent status:
   ```bash
   docker exec datadog-agent agent status
   ```

2. Verify secrets are being retrieved:
   ```bash
   echo '{"secrets": ["secret/datadog#api_key"]}' | docker exec -i datadog-agent /scripts/secret_backend.py
   ```

3. Monitor logs:
   ```bash
   docker-compose logs -f datadog-agent
   ```

## Customization

- Add more secrets to Vault and reference them with `ENC[secret/path#key]`
- Modify `startup.sh` to initialize additional secrets
- Add more check configurations in `conf.d/`

## Stopping Services

```bash
docker-compose down
```

## Production Considerations

⚠️ **Important Security Notes for Production Use:**

This template is designed for **development and demonstration purposes**. For production use, consider the following:

### Security
1. **Vault Dev Mode**: The Vault server runs in `-dev` mode with insecure settings:
   - No TLS/SSL (HTTP only)
   - Pre-generated root token (`root`) 
   - In-memory storage (data lost on container restart)
2. **Hardcoded Secrets**: Default credentials are hardcoded in startup.sh
3. **Root Token Exposure**: The root token is passed as environment variable

### Production Recommendations
1. **Use Production Vault**: Deploy a production Vault cluster with:
   - TLS/SSL encryption
   - Proper authentication (AppRole, Kubernetes auth, etc.)
   - Persistent storage backend
   - HA configuration
2. **Secure Secret Management**:
   - Rotate root token regularly
   - Use namespaced policies
   - Enable audit logging
3. **Network Security**:
   - Isolate Vault on internal network
   - Use mutual TLS (mTLS) for service communication
   - Restrict access with firewall rules
4. **Datadog Agent**:
   - Use dedicated service account
   - Limit secret backend permissions
   - Monitor secret backend usage

### Template Limitations
- No high availability
- No backup/restore mechanism  
- No monitoring/alerting for Vault health
- No secret rotation automation

### Getting Production-Ready
1. Replace Vault dev server with production configuration
2. Update `VAULT_TOKEN` to use limited-privilege token
3. Enable TLS in Vault and update `VAULT_ADDR` to `https://`
4. Implement proper secret lifecycle management
5. Add monitoring and alerting for both Vault and Datadog Agent

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.