# OpenTelemetry Endpoint Configuration Guide

## 🎯 Overview

This guide provides comprehensive instructions for configuring applications to send telemetry data to your monitoring stack deployed on EC2. The OpenTelemetry Collector serves as the central ingestion point for all observability data.

## 🌐 Endpoint Details

### Primary OTLP Endpoints

Your OpenTelemetry Collector exposes the following endpoints:

| Protocol | Port | Endpoint URL | Use Case |
|----------|------|--------------|----------|
| **OTLP gRPC** | 4317 | `http://your-ec2-ip:4317` | High-performance binary protocol |
| **OTLP HTTP** | 4318 | `http://your-ec2-ip:4318` | HTTP-based protocol, firewall-friendly |

### Additional Endpoints

| Service | Port | Endpoint | Purpose |
|---------|------|----------|---------|
| Health Check | 13133 | `http://your-ec2-ip:13133` | Service health monitoring |
| Prometheus Metrics | 8888 | `http://your-ec2-ip:8888/metrics` | Collector internal metrics |
| zPages Debug | 55679 | `http://your-ec2-ip:55679` | Debug and diagnostics |
| pprof Profiling | 1888 | `http://your-ec2-ip:1888` | Performance profiling |

## 🔧 Language-Specific Configuration

### Python Applications

#### Using OpenTelemetry Python SDK

```python
# requirements.txt
opentelemetry-api==1.21.0
opentelemetry-sdk==1.21.0
opentelemetry-exporter-otlp==1.21.0
opentelemetry-instrumentation-requests==0.42b0
opentelemetry-instrumentation-flask==0.42b0  # if using Flask
opentelemetry-instrumentation-django==0.42b0  # if using Django

# app.py
import os
from opentelemetry import trace, metrics, baggage
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource

# Configure resource attributes
resource = Resource.create({
    "service.name": "your-python-app",
    "service.version": "1.0.0",
    "deployment.environment": "production",
})

# Configure tracing
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

# Configure OTLP span exporter
otlp_exporter = OTLPSpanExporter(
    endpoint="http://your-ec2-ip:4317",
    insecure=True,
    headers={"api-key": "your-api-key"}  # Optional
)

# Add span processor
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Configure metrics
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(
        endpoint="http://your-ec2-ip:4317",
        insecure=True
    ),
    export_interval_millis=30000,
)
metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))

# Example usage
@tracer.start_as_current_span("process_request")
def process_request():
    # Your application logic here
    pass
```

#### Using Auto-Instrumentation

```bash
# Install auto-instrumentation
pip install opentelemetry-distro[otlp]
opentelemetry-bootstrap -a install

# Run with auto-instrumentation
export OTEL_EXPORTER_OTLP_ENDPOINT="http://your-ec2-ip:4318"
export OTEL_SERVICE_NAME="your-python-app"
export OTEL_RESOURCE_ATTRIBUTES="service.version=1.0.0,deployment.environment=production"

opentelemetry-instrument python your_app.py
```

### Node.js Applications

#### Manual Configuration

```javascript
// package.json dependencies
{
  "@opentelemetry/api": "^1.7.0",
  "@opentelemetry/sdk-node": "^0.45.0",
  "@opentelemetry/exporter-otlp-http": "^0.45.0",
  "@opentelemetry/auto-instrumentations-node": "^0.40.0"
}

// tracing.js
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'your-node-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: 'production',
  }),
  traceExporter: new OTLPTraceExporter({
    url: 'http://your-ec2-ip:4318/v1/traces',
    headers: {
      'api-key': 'your-api-key', // Optional
    },
  }),
  metricExporter: new OTLPMetricExporter({
    url: 'http://your-ec2-ip:4318/v1/metrics',
  }),
  instrumentations: [getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-fs': {
      enabled: false, // Disable noisy file system instrumentation
    },
  })],
});

sdk.start();

// app.js
require('./tracing'); // Import tracing configuration first
const express = require('express');
const { trace } = require('@opentelemetry/api');

const app = express();
const tracer = trace.getTracer('your-node-app');

app.get('/api/users', (req, res) => {
  const span = tracer.startSpan('get_users');
  
  // Your application logic
  span.setAttributes({
    'user.count': 42,
    'request.path': req.path,
  });
  
  span.end();
  res.json({ users: [] });
});

app.listen(3000);
```

#### Environment Variables Configuration

```bash
# Set environment variables
export OTEL_EXPORTER_OTLP_ENDPOINT="http://your-ec2-ip:4318"
export OTEL_SERVICE_NAME="your-node-app"
export OTEL_RESOURCE_ATTRIBUTES="service.version=1.0.0,deployment.environment=production"
export OTEL_EXPORTER_OTLP_HEADERS="api-key=your-api-key"

# Run your application
node --require @opentelemetry/auto-instrumentations-node/register app.js
```

### Java Applications

#### Using OpenTelemetry Java Agent

```bash
# Download the Java agent
wget https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

# Run your application with the agent
java -javaagent:opentelemetry-javaagent.jar \
     -Dotel.exporter.otlp.endpoint=http://your-ec2-ip:4318 \
     -Dotel.service.name=your-java-app \
     -Dotel.resource.attributes=service.version=1.0.0,deployment.environment=production \
     -Dotel.exporter.otlp.headers=api-key=your-api-key \
     -jar your-application.jar
```

#### Manual Configuration with Spring Boot

```xml
<!-- pom.xml -->
<dependencies>
    <dependency>
        <groupId>io.opentelemetry</groupId>
        <artifactId>opentelemetry-api</artifactId>
        <version>1.32.0</version>
    </dependency>
    <dependency>
        <groupId>io.opentelemetry</groupId>
        <artifactId>opentelemetry-exporter-otlp</artifactId>
        <version>1.32.0</version>
    </dependency>
    <dependency>
        <groupId>io.opentelemetry.instrumentation</groupId>
        <artifactId>opentelemetry-spring-boot-starter</artifactId>
        <version>1.32.0-alpha</version>
    </dependency>
</dependencies>
```

```yaml
# application.yml
otel:
  exporter:
    otlp:
      endpoint: http://your-ec2-ip:4318
      headers:
        api-key: your-api-key
  service:
    name: your-java-app
  resource:
    attributes:
      service.version: 1.0.0
      deployment.environment: production
```

### .NET Applications

#### Using OpenTelemetry .NET

```xml
<!-- Your.csproj -->
<PackageReference Include="OpenTelemetry" Version="1.7.0" />
<PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol" Version="1.7.0" />
<PackageReference Include="OpenTelemetry.Extensions.Hosting" Version="1.7.0" />
<PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore" Version="1.7.0" />
<PackageReference Include="OpenTelemetry.Instrumentation.Http" Version="1.7.0" />
```

```csharp
// Program.cs
using OpenTelemetry;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenTelemetry()
    .WithTracing(tracerProviderBuilder =>
        tracerProviderBuilder
            .AddSource("YourApp")
            .SetResourceBuilder(ResourceBuilder.CreateDefault()
                .AddService("your-dotnet-app", "1.0.0")
                .AddAttributes(new Dictionary<string, object>
                {
                    ["deployment.environment"] = "production"
                }))
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri("http://your-ec2-ip:4318");
                options.Headers = "api-key=your-api-key";
            }));

var app = builder.Build();
app.Run();
```

### Go Applications

#### Using OpenTelemetry Go

```go
// go.mod
module your-go-app

go 1.21

require (
    go.opentelemetry.io/otel v1.21.0
    go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp v1.21.0
    go.opentelemetry.io/otel/sdk v1.21.0
    go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.46.0
)

// main.go
package main

import (
    "context"
    "log"
    "net/http"
    "time"

    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
    "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

func initTracer() func() {
    ctx := context.Background()

    res, err := resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceName("your-go-app"),
            semconv.ServiceVersion("1.0.0"),
            semconv.DeploymentEnvironment("production"),
        ),
    )
    if err != nil {
        log.Fatal(err)
    }

    exporter, err := otlptracehttp.New(ctx,
        otlptracehttp.WithEndpoint("http://your-ec2-ip:4318"),
        otlptracehttp.WithInsecure(),
        otlptracehttp.WithHeaders(map[string]string{
            "api-key": "your-api-key",
        }),
    )
    if err != nil {
        log.Fatal(err)
    }

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
    )

    otel.SetTracerProvider(tp)
    otel.SetTextMapPropagator(propagation.TraceContext{})

    return func() {
        ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
        defer cancel()
        if err := tp.Shutdown(ctx); err != nil {
            log.Fatal(err)
        }
    }
}

func main() {
    cleanup := initTracer()
    defer cleanup()

    handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Write([]byte("Hello, World!"))
    })

    wrappedHandler := otelhttp.NewHandler(handler, "hello")
    http.Handle("/", wrappedHandler)

    log.Println("Server starting on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

## 🐳 Docker Configuration

### Environment Variables

```yaml
# docker-compose.yml
version: '3.8'
services:
  your-app:
    image: your-app:latest
    environment:
      # OpenTelemetry configuration
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://your-ec2-ip:4318
      - OTEL_SERVICE_NAME=your-app
      - OTEL_RESOURCE_ATTRIBUTES=service.version=1.0.0,deployment.environment=production
      - OTEL_EXPORTER_OTLP_HEADERS=api-key=your-api-key
      
      # Optional: Configure specific exporters
      - OTEL_TRACES_EXPORTER=otlp
      - OTEL_METRICS_EXPORTER=otlp
      - OTEL_LOGS_EXPORTER=otlp
      
      # Optional: Sampling configuration
      - OTEL_TRACES_SAMPLER=traceidratio
      - OTEL_TRACES_SAMPLER_ARG=0.1  # Sample 10% of traces
    networks:
      - monitoring_ops

networks:
  monitoring_ops:
    external: true
```

### Dockerfile Example

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

# Install OpenTelemetry auto-instrumentation
RUN npm install @opentelemetry/auto-instrumentations-node

# Set OpenTelemetry environment variables
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
ENV OTEL_SERVICE_NAME=your-app
ENV OTEL_RESOURCE_ATTRIBUTES=service.version=1.0.0,deployment.environment=production

# Start with auto-instrumentation
CMD ["node", "--require", "@opentelemetry/auto-instrumentations-node/register", "app.js"]
```

## 🔍 Verification & Testing

### Health Check

```bash
# Check if the collector is receiving data
curl -s http://your-ec2-ip:13133 | jq .

# Expected response:
{
  "status": "Server available",
  "upSince": "2024-01-01T00:00:00Z",
  "uptime": "1h30m45s"
}
```

### Send Test Data

```bash
# Send a test trace using curl
curl -X POST http://your-ec2-ip:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test-service"}
        }]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "12345678901234567890123456789012",
          "spanId": "1234567890123456",
          "name": "test-span",
          "kind": 1,
          "startTimeUnixNano": "1640995200000000000",
          "endTimeUnixNano": "1640995201000000000"
        }]
      }]
    }]
  }'
```

### Monitoring Script

```bash
#!/bin/bash
# monitor-telemetry.sh

echo "Checking OpenTelemetry Collector health..."
curl -s http://your-ec2-ip:13133 || echo "Health check failed"

echo "Checking collector metrics..."
curl -s http://your-ec2-ip:8888/metrics | grep otelcol_receiver_accepted_spans

echo "Checking zPages..."
curl -s http://your-ec2-ip:55679/debug/tracez | grep -o "Spans received in last minute: [0-9]*"
```

## 🚨 Troubleshooting

### Common Issues

1. **Connection Refused**
   ```bash
   # Check if collector is running
   docker ps | grep otel-collector
   
   # Check collector logs
   docker logs otel-collector
   ```

2. **No Data in Grafana**
   ```bash
   # Verify data flow through collector
   curl http://your-ec2-ip:55679/debug/tracez
   
   # Check Prometheus for metrics
   curl http://your-ec2-ip:9090/api/v1/query?query=up
   ```

3. **High Memory Usage**
   ```yaml
   # Adjust memory limits in otel-collector config
   processors:
     memory_limiter:
       limit_mib: 256  # Reduce if needed
       spike_limit_mib: 64
   ```

### Debug Configuration

```yaml
# Add to otel-collector config for debugging
exporters:
  logging:
    verbosity: detailed
    sampling_initial: 5
    sampling_thereafter: 200

service:
  pipelines:
    traces:
      exporters: [otlp/tempo, logging]  # Add logging exporter
```

## 📚 Best Practices

### Resource Attributes
Always include these standard attributes:
- `service.name`: Unique service identifier
- `service.version`: Application version
- `deployment.environment`: Environment (dev/staging/prod)

### Sampling Strategies
- **Development**: 100% sampling for debugging
- **Staging**: 50% sampling for testing
- **Production**: 1-10% sampling based on traffic

### Security Considerations
- Use HTTPS in production environments
- Implement authentication headers
- Restrict network access to collector endpoints
- Rotate API keys regularly

---

This guide provides comprehensive configuration examples for integrating your applications with the OpenTelemetry Collector. Adjust the endpoints and configuration based on your specific EC2 deployment.
