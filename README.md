# Datadog Agent with HashiCorp Vault (Simplified)

A minimal implementation of Datadog Agent with HashiCorp Vault secret management.

## Quick Start

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

5. **Start services:**
   ```bash
   docker-compose up --build -d
   ```

## Components

- **HashiCorp Vault**: Development server with KV v2 secrets engine
- **Datadog Agent**: Custom container with secret backend integration
- **Secret Backend**: Python script that retrieves secrets from Vault

## Secrets Configuration

The system automatically initializes these secrets in Vault:

1. **Datadog API Key**: `secret/datadog#api_key` (from `VAULT_DD_API_KEY` environment variable)
2. **HTTP Check Credentials**: `secret/http_check#username` and `secret/http_check#password`

## Configuration Files

- `datadog.yaml`: Main Datadog Agent configuration
- `conf.d/http_check.yaml`: HTTP check with Vault-secured credentials
- `scripts/secret_backend.py`: Vault integration script
- `scripts/startup.sh`: Service initialization script

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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.