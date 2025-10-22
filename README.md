# Monitoring Operations Stack

A comprehensive observability platform built with OpenTelemetry, providing metrics, logs, and traces collection and visualization for applications running on EC2.

## ⚡ Quick Start for E-Commerce Dashboard

**Your Grafana dashboard is now working!** 🎉

```bash
# 1. Start monitoring stack
docker-compose -f docker-compose-telemetry.yaml up -d

# 2. Send test data
./script/test-ecommerce-metrics.sh -n 100 -d 2

# 3. View dashboard
open http://localhost:30700
# Login: admin / admin
# Dashboard: E-Commerce Application Monitoring
```

**Or use your real Next.js app:**
```bash
cd /Users/admin/Work/ODT/New_front_EC/renewal
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 pnpm dev
```

📚 **Documentation:**
- **Quick Start**: `QUICK_START.md` - 3-step guide
- **Troubleshooting**: `TROUBLESHOOTING.md` - Debugging guide  
- **App Integration**: `renewal/MONITORING_INTEGRATION.md` - Full integration
- **Solution**: `SOLUTION_SUMMARY.md` - What was fixed

---

## 🏗️ Architecture Overview

This monitoring stack implements the three pillars of observability:
- **Metrics**: Collected via Prometheus and OpenTelemetry
- **Logs**: Aggregated through Loki
- **Traces**: Stored and analyzed with Tempo
- **Visualization**: Unified dashboards in Grafana

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                EC2 Instance                                     │
│                                                                                 │
│  ┌─────────────────┐    ┌──────────────────────────────────────────────────┐   │
│  │   Applications  │    │              Docker Network                      │   │
│  │                 │    │            monitoring_ops (172.18.0.0/16)        │   │
│  │ ┌─────────────┐ │    │                                                  │   │
│  │ │ Your App 1  │ │───▶│  ┌─────────────────────────────────────────────┐ │   │
│  │ │ (Python)    │ │    │  │        OpenTelemetry Collector              │ │   │
│  │ └─────────────┘ │    │  │         (172.18.0.10)                       │ │   │
│  │                 │    │  │                                             │ │   │
│  │ ┌─────────────┐ │    │  │  ┌─────────────┐  ┌─────────────────────┐  │ │   │
│  │ │ Your App 2  │ │───▶│  │  │ Receivers   │  │    Processors       │  │ │   │
│  │ │ (Node.js)   │ │    │  │  │             │  │                     │  │ │   │
│  │ └─────────────┘ │    │  │  │ OTLP gRPC   │  │ • Batch             │  │ │   │
│  │                 │    │  │  │ :4317       │  │ • Memory Limiter    │  │ │   │
│  │ ┌─────────────┐ │    │  │  │             │  │ • Resource          │  │ │   │
│  │ │ Your App 3  │ │───▶│  │  │ OTLP HTTP   │  │   Enrichment        │  │ │   │
│  │ │ (Java)      │ │    │  │  │ :4318       │  │                     │  │ │   │
│  │ └─────────────┘ │    │  │  └─────────────┘  └─────────────────────┘  │ │   │
│  └─────────────────┘    │  └─────────────────────────────────────────────┘ │   │
│                         │                        │                          │   │
│                         │                        ▼                          │   │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                        Storage Layer                                    │   │
│  │                                                                         │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐ │   │
│  │  │   Prometheus    │  │      Loki       │  │         Tempo           │ │   │
│  │  │ (172.18.0.11)   │  │ (172.18.0.13)   │  │    (172.18.0.12)        │ │   │
│  │  │                 │  │                 │  │                         │ │   │
│  │  │ • Metrics       │  │ • Logs          │  │ • Traces                │ │   │
│  │  │ • Time Series   │  │ • Label-based   │  │ • Service Maps          │ │   │
│  │  │ • PromQL        │  │ • LogQL         │  │ • Trace Correlation     │ │   │
│  │  │ • Port: 9090    │  │ • Port: 3100    │  │ • Port: 3200            │ │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                        │
│                                        ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                    Visualization Layer                                  │   │
│  │                                                                         │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│  │  │                      Grafana                                    │   │   │
│  │  │                 (172.18.0.14)                                   │   │   │
│  │  │                                                                 │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │   │   │
│  │  │  │ Dashboards  │  │  Alerting   │  │    Data Correlation     │ │   │   │
│  │  │  │             │  │             │  │                         │ │   │   │
│  │  │  │ • Metrics   │  │ • Rules     │  │ • Metrics ↔ Traces      │ │   │   │
│  │  │  │ • Logs      │  │ • Channels  │  │ • Logs ↔ Traces         │ │   │   │
│  │  │  │ • Traces    │  │ • Policies  │  │ • Exemplars             │ │   │   │
│  │  │  │ • Combined  │  │             │  │ • Service Maps          │ │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────────────────┘ │   │   │
│  │  │                                                                 │   │   │
│  │  │                    Port: 30700                                  │   │   │
│  │  └─────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘

External Access Points:
• Grafana UI: http://your-ec2-ip:30700
• OTLP Endpoints: http://your-ec2-ip:4317 (gRPC) / :4318 (HTTP)
• Prometheus API: http://your-ec2-ip:9090
• Direct Service APIs: Loki (:3100), Tempo (:3200)
```

### Data Flow Architecture

```
Applications                 OpenTelemetry Collector              Storage Backends
     │                              │                                    │
     │ ┌─────────────────────────────┼─────────────────────────────┐     │
     │ │                             │                             │     │
     ▼ ▼                             ▼                             ▼     ▼
┌─────────┐     OTLP Protocol    ┌─────────┐                 ┌─────────────┐
│ Metrics │────────────────────▶ │ Metrics │────────────────▶│ Prometheus  │
│ Logs    │     gRPC/HTTP       │ Logs    │                 │ Loki        │
│ Traces  │     :4317/:4318     │ Traces  │                 │ Tempo       │
└─────────┘                     └─────────┘                 └─────────────┘
     │                               │                             │
     │                               │ Processing Pipeline         │
     │                               │ • Batching                  │
     │                               │ • Memory Management         │
     │                               │ • Resource Enrichment       │
     │                               │ • Routing                   │
     │                               │                             │
     │                               ▼                             ▼
     │                         ┌─────────────┐              ┌─────────────┐
     │                         │ Extensions  │              │   Grafana   │
     │                         │             │              │             │
     │                         │ • Health    │◀─────────────│ • Query     │
     │                         │ • Metrics   │              │ • Visualize │
     │                         │ • Debug     │              │ • Alert     │
     │                         └─────────────┘              │ • Correlate │
     │                                                      └─────────────┘
     │                                                             ▲
     └─────────────────── Direct Access ──────────────────────────┘
                        (Port 30700)
```

### Components

| Component | Purpose | Port | Endpoint |
|-----------|---------|------|----------|
| **OpenTelemetry Collector** | Telemetry gateway and processor | 4317/4318 | `http://localhost:4318` |
| **Prometheus** | Metrics storage and querying | 9090 | `http://localhost:9090` |
| **Loki** | Log aggregation system | 3100 | `http://localhost:3100` |
| **Tempo** | Distributed tracing backend | 3200 | `http://localhost:3200` |
| **Grafana** | Visualization and dashboards | 30700 | `http://localhost:30700` |

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- EC2 instance with sufficient resources (minimum 4GB RAM recommended)
- Network access to ports: 30700, 9090, 4317, 4318

### Deployment Options

#### Option 1: Full Telemetry Stack (Recommended)
```bash
# Deploy complete observability stack
docker-compose -f docker-compose-telemetry.yaml up -d
```

#### Option 2: Logging Only
```bash
# Deploy logs-only stack
docker-compose -f docker-compose-logging-complete.yaml up -d
```

### Verification

1. **Check all services are running:**
   ```bash
   docker-compose -f docker-compose-telemetry.yaml ps
   ```

2. **Access Grafana Dashboard:**
   - URL: `http://your-ec2-ip:30700`
   - Username: `admin`
   - Password: `admin`

3. **Verify OpenTelemetry Collector:**
   ```bash
   curl http://localhost:13133  # Health check
   curl http://localhost:55679  # zPages debugging
   ```

## 📊 OpenTelemetry Endpoint Configuration

### Primary OTLP Endpoints

Your applications should send telemetry data to:

- **gRPC**: `http://your-ec2-ip:4317`
- **HTTP**: `http://your-ec2-ip:4318`

### Example Application Configuration

#### Python (using opentelemetry-python)
```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Configure tracer
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# Configure OTLP exporter
otlp_exporter = OTLPSpanExporter(
    endpoint="http://your-ec2-ip:4317",
    insecure=True
)

# Add span processor
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)
```

#### Node.js (using @opentelemetry/auto-instrumentations-node)
```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-otlp-http');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'http://your-ec2-ip:4318/v1/traces',
  }),
  instrumentations: [getNodeAutoInstrumentations()]
});

sdk.start();
```

#### Java (using OpenTelemetry Java Agent)
```bash
java -javaagent:opentelemetry-javaagent.jar \
     -Dotel.exporter.otlp.endpoint=http://your-ec2-ip:4318 \
     -Dotel.service.name=your-service-name \
     -jar your-application.jar
```

#### Docker Environment Variables
```yaml
environment:
  - OTEL_EXPORTER_OTLP_ENDPOINT=http://your-ec2-ip:4318
  - OTEL_SERVICE_NAME=your-service
  - OTEL_RESOURCE_ATTRIBUTES=service.version=1.0.0,deployment.environment=production
```

## 🔧 Configuration

### Network Configuration

The stack uses a custom Docker network (`monitoring_ops`) with static IP addresses:
- OpenTelemetry Collector: `172.18.0.10`
- Prometheus: `172.18.0.11`
- Tempo: `172.18.0.12`
- Loki: `172.18.0.13`
- Grafana: `172.18.0.14`

### Data Persistence

All data is persisted using Docker volumes:
- `prometheus-data`: Metrics storage
- `tempo-data`: Trace storage
- `loki-data`: Log storage
- `grafana-data`: Dashboard configurations and user data

### Resource Limits

OpenTelemetry Collector is configured with:
- Memory limit: 512MB
- Spike limit: 128MB
- Batch size: 1024 events
- Batch timeout: 10s

## 📈 Monitoring and Dashboards

### Pre-configured Dashboards

1. **Observability Overview**: High-level system metrics
2. **Metrics-Traces Correlation**: Correlated view of metrics and traces
3. **Test Data Verification**: Validation of telemetry data flow
4. **EC Site Logs**: Application-specific log analysis

### Accessing Dashboards

1. Navigate to Grafana: `http://your-ec2-ip:30700`
2. Login with admin/admin
3. Browse to "Dashboards" → "Browse"
4. Select from available dashboards in the "observability" and "logs" folders

## 🔍 Troubleshooting

### Common Issues

1. **Services not starting:**
   ```bash
   # Check logs
   docker-compose -f docker-compose-telemetry.yaml logs [service-name]
   
   # Restart specific service
   docker-compose -f docker-compose-telemetry.yaml restart [service-name]
   ```

2. **No data in Grafana:**
   - Verify applications are sending data to correct endpoints
   - Check OpenTelemetry Collector logs: `docker logs otel-collector`
   - Ensure network connectivity between services

3. **Memory issues:**
   ```bash
   # Monitor resource usage
   docker stats
   
   # Adjust memory limits in docker-compose file if needed
   ```

### Diagnostic Scripts

Use the provided diagnostic scripts:
```bash
# Quick health check
./script/quick-test.sh

# Comprehensive diagnostics
./script/diagnose-stack.sh

# Test telemetry data flow
./script/test-telemetry-data.sh
```

## 🔒 Security Considerations

- Default Grafana credentials should be changed in production
- Consider enabling authentication for Prometheus and other services
- Use TLS/SSL certificates for production deployments
- Implement network security groups on EC2 to restrict access

## 📚 Additional Resources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Tempo Documentation](https://grafana.com/docs/tempo/)

## 🤝 Contributing

1. Test changes locally before deployment
2. Update documentation for any configuration changes
3. Ensure all health checks pass after modifications
4. Follow semantic versioning for releases

---

**Note**: This stack is optimized for EC2 deployment with Docker Compose. For Kubernetes deployments, consider using Helm charts or operators for each component.
