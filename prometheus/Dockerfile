FROM prom/prometheus:v2.48.0

# Copy Prometheus configuration
COPY prometheus.yml /etc/prometheus/prometheus.yml

# Create directory for rules (optional)
RUN mkdir -p /etc/prometheus/rules

# Expose Prometheus port
EXPOSE 9090

# Set proper permissions
USER nobody

# Override the entrypoint to use our config
ENTRYPOINT ["/bin/prometheus"]
CMD ["--config.file=/etc/prometheus/prometheus.yml", \
     "--storage.tsdb.path=/prometheus", \
     "--web.console.libraries=/usr/share/prometheus/console_libraries", \
     "--web.console.templates=/usr/share/prometheus/consoles", \
     "--web.enable-lifecycle", \
     "--web.enable-admin-api"]

