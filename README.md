# Datadog Agent with Native HashiCorp Vault Secret Management

A **minimal, production-ready template** demonstrating native HashiCorp Vault integration with Datadog Agent. This template uses Datadog Agent's built-in secret backend for secure credential management.

> **Key Discovery**: Native Vault integration **does support token authentication** (contrary to documentation that only shows AWS IAM).

## 🚀 Features

- **Native Secret Management**: Uses Datadog Agent's built-in `secret_backend_type: hashicorp.vault`
- **Token Authentication**: Works with Vault token authentication (not just AWS IAM)
- **KV v2 Support**: Compatible with Vault's KV v2 secrets engine
- **Minimal Configuration**: No custom scripts or external dependencies
- **Containerized**: Docker Compose with version-pinned components
- **Production-Ready**: Follows Datadog's official secret management patterns

## 📋 Prerequisites

- Docker 20.10+ and Docker Compose
- Datadog API key (for production use)
- User in `docker` group or `sudo` access

## 🏗️ Architecture

```
+-------------------+     +-------------------+     +-------------------+
|   Datadog Agent   |<--->|  HashiCorp Vault  |<--->|   Secret Storage  |
|  (v7.74.1)        |     |  (v1.21.2)        |     |   (KV v2 Engine)  |
|                   |     |                   |     |                   |
|  Native Vault     |     |  Dev Server       |     |  - API Key        |
|  Integration      |     |  - Token Auth     |     |  - HTTP Creds     |
+-------------------+     +-------------------+     +-------------------+
```

## 🛠️ Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo>
cd dd-agent-hashi-secret-template

# Copy environment template
cp .env.example .env
```

### 2. Configure Secrets

Update `.env` with your Datadog API key:
```bash
# .env
DD_API_KEY=your_actual_datadog_api_key_here
```

Create Vault token file:
```bash
echo "root" > secrets/auth_token  # For development only
```

### 3. Deploy Services

```bash
docker-compose up -d --build
```

### 4. Verify Deployment

```bash
# Check Datadog Agent status
docker exec datadog-agent agent status

# Verify Vault connectivity
curl http://localhost:8200/v1/sys/health

# View logs
docker-compose logs -f datadog-agent
```

## 🔧 Configuration

### Native Vault Integration (`datadog.yaml`)

```yaml
# Datadog API key retrieved from Vault
api_key: ENC[/secret/datadog;api_key]

# Native HashiCorp Vault integration
secret_backend_type: hashicorp.vault
secret_backend_config:
  vault_address: http://vault:8200
  vault_token: root  # Token can be literal or file path
```

### Required File Artifact

The Agent requires `/etc/datadog-agent/auth_token` file for security:
```yaml
# In docker-compose.yml
volumes:
  - ./secrets/auth_token:/etc/datadog-agent/auth_token:ro
```

### Secret References

Secrets are referenced using Datadog's native format:
- API Key: `ENC[/secret/datadog;api_key]`
- HTTP Check Credentials: `ENC[/secret/http_check;username]`, `ENC[/secret/http_check;password]`

### Vault Secrets Structure (KV v2)

```
secret/
├── datadog/
│   └── data/
│       └── api_key: "your_datadog_api_key"
└── http_check/
    └── data/
        ├── username: "testuser"
        └── password: "testpass"
```

## 📊 Verification

```bash
# Check Agent status with native Vault integration
docker exec datadog-agent agent status

# Verify configuration
docker exec datadog-agent agent configcheck

# Test secret resolution
docker exec datadog-agent agent secret-helper /secret/datadog;api_key

# View logs for secret backend operations
docker-compose logs datadog-agent | grep -i vault
```

## 🚨 Production Considerations

### Security
⚠️ **This template uses Vault in development mode (`-dev`) with insecure settings:**
- No TLS/SSL (HTTP only)
- Pre-generated root token (`root`)
- In-memory storage (data lost on container restart)

### Production Recommendations
1. **Use Production Vault**: Deploy a production Vault cluster with TLS, persistent storage, and proper authentication
2. **Rotate Tokens**: Replace root token with limited-privilege token
3. **Enable TLS**: Update `vault_address` to `https://` and configure certificates
4. **Network Security**: Isolate Vault on internal network
5. **Monitoring**: Add health checks and alerting for both Vault and Datadog Agent

### Authentication Methods
The template uses token authentication. For production, consider:
- **AWS IAM**: `vault_auth_type: aws` with instance profiles
- **Kubernetes**: `vault_auth_type: kubernetes` with service accounts
- **AppRole**: Standard machine-to-machine authentication

## 📁 Project Structure

```
.
├── docker-compose.yml          # Service definitions (Vault + Datadog Agent)
├── Dockerfile                  # Datadog Agent with startup script
├── datadog.yaml               # Main Datadog configuration with native Vault

├── conf.d/http_check.yaml     # HTTP check with Vault secrets
├── secrets/                   # Secret files directory
│   ├── .gitkeep              # Keep directory structure
│   └── auth_token            # Vault token file (required, gitignored)
├── scripts/                  # Utility scripts
│   ├── startup.sh            # Agent startup script

├── .env.example              # Environment template
├── .env                      # Environment variables (gitignored)
├── .gitignore               # Git ignore rules
├── learnings.md             # Comprehensive documentation

└── LICENSE                  # MIT License
```

## 🔍 Troubleshooting

### Common Issues

**Vault Token Authentication Issues:**
```bash
# Verify auth_token file exists and is mounted
docker exec datadog-agent ls -la /etc/datadog-agent/auth_token

# Check Vault logs for authentication errors
docker-compose logs vault | grep -i token
```

**Secret Retrieval Issues:**
```bash
# Verify secret format
grep "ENC\[" datadog.yaml conf.d/http_check.yaml
# Should show: ENC[/secret/datadog;api_key] format

# Check Vault secret existence
docker exec vault vault kv get secret/datadog
```

**Datadog Agent Fails to Start:**
```bash
# Check logs
docker-compose logs datadog-agent

# Verify Vault is healthy
curl http://localhost:8200/v1/sys/health
```

### Logs and Diagnostics

```bash
# View all logs
docker-compose logs

# Follow Datadog Agent logs
docker-compose logs -f datadog-agent

# Check agent status
docker exec datadog-agent agent status

# Test secret retrieval
docker exec datadog-agent agent configcheck
```

## 📈 Monitoring

The Datadog Agent automatically monitors:
- System metrics (CPU, memory, disk, network)
- Container metrics (if Docker socket mounted)
- Custom HTTP checks (configured in `conf.d/`)
- Vault health (via HTTP check to `localhost:8200`)

Add additional checks by creating files in `conf.d/` directory.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with descriptive commit messages
4. Test thoroughly
5. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🔗 References

- [Datadog Secret Management Documentation](https://docs.datadoghq.com/agent/configuration/secrets-management/)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Datadog Agent Docker Image](https://hub.docker.com/r/datadog/agent)
- [Native HashiCorp Vault Integration](https://docs.datadoghq.com/agent/configuration/secrets-management/?tab=agentyamlfile#hashicorp-vault-backend)

---

**Note**: Replace placeholder values in `.env`, secrets files, and configuration files before production use. See [learnings.md](learnings.md) for detailed technical documentation.