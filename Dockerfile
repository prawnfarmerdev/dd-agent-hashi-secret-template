FROM datadog/agent:7.74.1

# Install curl for health checks (already present in base image)
RUN apt-get update && apt-get install -y curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create scripts directory
RUN mkdir -p /scripts

# Copy startup script for Vault initialization
COPY scripts/startup.sh /scripts/
RUN chmod +x /scripts/startup.sh

# Copy configuration
COPY datadog.yaml /etc/datadog-agent/
COPY conf.d/ /etc/datadog-agent/conf.d/

# Environment variables for Vault (will be set at runtime)
ENV VAULT_ADDR=http://vault:8200

# Use custom startup script as entrypoint
ENTRYPOINT ["/scripts/startup.sh"]
CMD ["agent", "run"]