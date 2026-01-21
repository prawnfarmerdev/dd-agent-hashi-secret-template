# Podman Compatibility

This template works with Podman Compose with a few modifications.

## Prerequisites

Install podman and podman-compose:

```bash
# On Arch Linux
sudo pacman -S podman podman-compose

# Alternatively via pip (if system allows)
pip install --user --break-system-packages podman-compose
export PATH=$PATH:~/.local/bin
```

## Changes Made for Podman Compatibility

1. **Healthcheck**: Vault container uses `wget` instead of `curl` (vault image lacks curl)
2. **Healthcheck address**: Changed from `localhost` to `127.0.0.1` to avoid IPv6 issues
3. **Vault configuration**: Simplified to `server -dev` (removed config file mount)
4. **Docker socket**: Removed `/var/run/docker.sock` volume mount (not needed for secret backend)
5. **Startup script**: Updated to connect to `vault` hostname instead of `localhost`
6. **Pod creation**: Disabled with `--in-pod false` flag
7. **Version pinning**: Vault pinned to `1.21.2`, Datadog Agent pinned to `7.74.1` for reproducibility
8. **Robust startup**: Exponential backoff for Vault readiness checks

## Running with Podman Compose

```bash
# Start services
podman compose --in-pod false up -d --build

# Check status
podman compose --in-pod false ps

# View logs
podman compose --in-pod false logs -f

# Stop services
podman compose --in-pod false down
```

## Using Helper Scripts (Recommended)

For resilient deployment that survives `podman system reset`, use the helper scripts:

```bash
# 1. Initialize environment
./init.sh

# 2. Deploy services (includes health checks)
./deploy.sh

# 3. Test deployment
./test-deployment.sh

# 4. Clean up everything
./clean.sh
```

### Script Functions
- `clean.sh`: Complete cleanup of containers, networks, pods, and volumes
- `init.sh`: Environment validation, port checks, .env setup, OCI runtime checks
- `deploy.sh`: Automated deployment with progress monitoring
- `test-deployment.sh`: Comprehensive verification of all components
- `diagnose-podman.sh`: Diagnostic tool for Podman configuration issues
- `configure-podman-runtime.sh`: Configure Podman to use runc if crun is unavailable

## Testing Secret Backend

```bash
# Test secret retrieval
echo '{"secrets": ["secret/datadog#api_key"]}' | podman exec -i datadog-agent /scripts/secret_backend.py

# Check agent status
podman exec datadog-agent agent status
```

## Notes

- The Datadog Agent runs without Docker/Podman socket access, so container monitoring is disabled
- For full container monitoring with Podman, you could mount the Podman socket:
  ```yaml
  volumes:
    - /run/user/1000/podman/podman.sock:/var/run/docker.sock:ro
  ```
  And add `user: "1000"` to the datadog-agent service (requires adjusting script permissions)

- The placeholder API key will cause "API Key invalid" errors; replace with a real Datadog API key in `.env` file

## Troubleshooting

### Common Issues

**Port 8200 already in use**: Ensure no other vault containers are running:
```bash
podman rm -af
podman network prune -f
```

**Healthcheck failures**: Check vault logs:
```bash
podman logs vault
```

**Permission errors on secret_backend.py**: Ensure script has 500 permissions and is owned by dd-agent user.

**"manifest unknown" when pulling vault:latest**: This occurs when Docker Hub doesn't have a `latest` tag for Vault:
- The template now uses pinned version `vault:1.21.2`
- Run `./clean.sh` to remove any partial containers
- Run `./deploy.sh` to deploy with the pinned version

**Recovery from `podman system reset`**:
```bash
# After system reset:
./clean.sh      # Clean residual state
./init.sh       # Validate environment
./deploy.sh     # Deploy fresh instance
```

**OCI format warnings about HEALTHCHECK**: These are harmless warnings from Podman:
- Podman's OCI format doesn't support HEALTHCHECK instruction
- Healthchecks still work via `wget` command in container
- Ignore warnings like "HEALTHCHECK is not supported for OCI image format"

**OCI runtime "crun" not found**: If you see "default OCI runtime 'crun' not found invalid argument":
- Install crun runtime:
  ```bash
  # Arch Linux
  sudo pacman -S crun
  
  # Ubuntu/Debian
  sudo apt install crun
  
  # Fedora/RHEL
  sudo dnf install crun
  ```
- Or configure Podman to use runc instead:
  1. Create `/etc/containers/containers.conf` with:
  ```
  [engine]
  runtime = "runc"
  ```
  2. Install runc if not present: `sudo pacman -S runc` or `sudo apt install runc`
- Check runtime with diagnostic script: `./diagnose-podman.sh`

**RunRoot permissions issues**: If you see "Runroot is pointing to path (/run/user/1000/containers) which is now writable":
- Fix permissions on RunRoot directory:
  ```bash
  RUNROOT=$(podman info --format '{{.Store.RunRoot}}')
  sudo chown -R $(whoami):$(whoami) "$RUNROOT"
  sudo chmod 755 "$RUNROOT"
  ```
- Or reset Podman storage: `podman system reset` (warning: removes all containers/images)

**Container not found errors**: If you see "no container with name datadog-agent":
- Run `./clean.sh` to remove all containers
- Run `./deploy.sh` to recreate everything fresh
- Check if containers exist: `podman ps -a`