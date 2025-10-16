FROM otel/opentelemetry-collector-contrib:0.137.0

# Copy custom configuration
COPY config.yaml /etc/otel-collector-config.yaml

# Expose ports
# 4317 - OTLP gRPC receiver
# 4318 - OTLP HTTP receiver
# 8888 - Metrics endpoint
# 8889 - Prometheus exporter
# 13133 - Health check
# 1777 - pprof profiling
# 55679 - zPages
EXPOSE 4317 4318 8888 8889 13133 1777 55679

# Set the configuration file
CMD ["--config=/etc/otel-collector-config.yaml"]

