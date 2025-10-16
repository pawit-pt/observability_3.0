FROM grafana/tempo:2.3.1

# Copy Tempo configuration
COPY tempo.yaml /etc/tempo.yaml

# Create necessary directories with proper permissions
# The tempo image runs as user 10001 by default
USER root
RUN mkdir -p /var/tempo/wal /var/tempo/blocks /var/tempo/generator/wal && \
    chown -R 10001:10001 /var/tempo

USER 10001

# Expose ports
# 3200 - HTTP API
# 4317 - OTLP gRPC
# 4318 - OTLP HTTP
# 9096 - gRPC
EXPOSE 3200 4317 4318 9096

# Start Tempo
CMD ["-config.file=/etc/tempo.yaml"]

