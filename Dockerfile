FROM datadog/agent:latest

# Install Python dependencies for secret backend
RUN apt-get update && apt-get install -y python3-pip curl && \
    pip3 install hvac>=1.1.0 requests && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create scripts directory
RUN mkdir -p /scripts

# Copy essential scripts
COPY scripts/secret_backend.py /scripts/
RUN chmod +x /scripts/secret_backend.py
COPY scripts/startup.sh /scripts/
RUN chmod +x /scripts/startup.sh

# Copy configuration
COPY datadog.yaml /etc/datadog-agent/
COPY conf.d/ /etc/datadog-agent/conf.d/

# Ensure correct permissions
RUN chown dd-agent /scripts/secret_backend.py && \
    chmod 500 /scripts/secret_backend.py

# Environment variables for Vault (will be set at runtime)
ENV VAULT_ADDR=http://vault:8200
ENV VAULT_TOKEN=

# Use custom startup script as entrypoint
ENTRYPOINT ["/scripts/startup.sh"]
CMD ["agent", "run"]