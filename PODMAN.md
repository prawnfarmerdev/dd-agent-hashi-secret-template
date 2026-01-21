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