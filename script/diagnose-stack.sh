#!/bin/bash

################################################################################
# Diagnostic Script for Monitoring Stack
# Purpose: Verify all services are working and data flows correctly
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_header "Monitoring Stack Diagnostics"
echo ""

# Check Docker services
print_header "1. Docker Services Status"
docker-compose -f docker-compose-telemetry.yaml ps

echo ""
print_header "2. Service Health Checks"

# Tempo
if curl -sf http://localhost:3200/ready > /dev/null 2>&1; then
    print_success "Tempo is ready (HTTP API: 3200)"
else
    print_error "Tempo is NOT ready"
fi

# Prometheus
if curl -sf http://localhost:9090/-/ready > /dev/null 2>&1; then
    print_success "Prometheus is ready (HTTP API: 9090)"
else
    print_error "Prometheus is NOT ready"
fi

# Loki
if curl -sf http://localhost:3100/ready > /dev/null 2>&1; then
    print_success "Loki is ready (HTTP API: 3100)"
else
    print_error "Loki is NOT ready"
fi

# OTEL Collector
if curl -sf http://localhost:13133 > /dev/null 2>&1; then
    print_success "OTEL Collector is ready (Health: 13133)"
else
    print_error "OTEL Collector is NOT ready"
fi

# Grafana
if curl -sf http://localhost:30700/api/health > /dev/null 2>&1; then
    print_success "Grafana is ready (HTTP: 30700)"
else
    print_error "Grafana is NOT ready"
fi

echo ""
print_header "3. OTEL Collector Endpoints"

# Check OTLP HTTP endpoint
if curl -sf -X POST http://localhost:4318/v1/traces \
    -H "Content-Type: application/json" \
    -d '{}' > /dev/null 2>&1; then
    print_success "OTEL HTTP endpoint is accessible (4318)"
else
    print_error "OTEL HTTP endpoint is NOT accessible (4318)"
fi

# Check metrics endpoint
if curl -sf http://localhost:8888/metrics > /dev/null 2>&1; then
    print_success "OTEL Metrics endpoint is accessible (8888)"
else
    print_error "OTEL Metrics endpoint is NOT accessible (8888)"
fi

# Check Prometheus exporter
if curl -sf http://localhost:8889/metrics > /dev/null 2>&1; then
    print_success "OTEL Prometheus exporter is accessible (8889)"
else
    print_error "OTEL Prometheus exporter is NOT accessible (8889)"
fi

echo ""
print_header "4. Data in Backend Services"

# Check Prometheus has data
PROM_SERIES=$(curl -sf "http://localhost:9090/api/v1/query?query=up" | grep -o '"status":"success"' || echo "")
if [ ! -z "$PROM_SERIES" ]; then
    print_success "Prometheus has data"
    # Count time series
    SERIES_COUNT=$(curl -sf "http://localhost:9090/api/v1/label/__name__/values" | grep -o '"[^"]*"' | wc -l)
    print_info "  Prometheus has $SERIES_COUNT metric names"
else
    print_error "Prometheus has NO data or is not responding"
fi

# Check Loki has data
LOKI_LABELS=$(curl -sf "http://localhost:3100/loki/api/v1/labels" | grep -o '"status":"success"' || echo "")
if [ ! -z "$LOKI_LABELS" ]; then
    print_success "Loki is responding"
    # Try to get label values
    LOKI_DATA=$(curl -sf "http://localhost:3100/loki/api/v1/query_range?query={job=~\".+\"}&limit=1" 2>/dev/null || echo "")
    if echo "$LOKI_DATA" | grep -q '"status":"success"'; then
        print_info "  Loki query API is working"
    fi
else
    print_error "Loki is not responding properly"
fi

# Check Tempo has data
TEMPO_SERVICES=$(curl -sf "http://localhost:3200/api/search/tag/service.name/values" 2>/dev/null || echo "")
if [ ! -z "$TEMPO_SERVICES" ]; then
    print_success "Tempo is responding"
    # Parse service names
    SERVICE_COUNT=$(echo "$TEMPO_SERVICES" | grep -o '"[^"]*"' | wc -l)
    if [ $SERVICE_COUNT -gt 0 ]; then
        print_info "  Tempo has $SERVICE_COUNT indexed services"
        echo "$TEMPO_SERVICES" | grep -o '"[^"]*"' | head -5 | while read -r service; do
            print_info "    - Service: $service"
        done
    else
        print_info "  Tempo has no traces yet"
    fi
else
    print_error "Tempo is not responding properly"
fi

echo ""
print_header "5. Grafana Datasources Status"

# Check Grafana datasources via API
GRAFANA_URL="http://localhost:30700"
AUTH="admin:admin"

DATASOURCES=$(curl -sf -u "$AUTH" "$GRAFANA_URL/api/datasources" 2>/dev/null || echo "")
if [ ! -z "$DATASOURCES" ]; then
    print_success "Grafana API is accessible"
    
    # Check each datasource
    echo "$DATASOURCES" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | while read -r ds_name; do
        print_info "  Datasource found: $ds_name"
    done
    
    # Test datasource health
    echo ""
    print_info "Testing datasource health..."
    
    # Get datasource IDs and test them
    DS_IDS=$(echo "$DATASOURCES" | grep -o '"uid":"[^"]*"' | cut -d'"' -f4)
    for uid in $DS_IDS; do
        DS_NAME=$(echo "$DATASOURCES" | grep -A2 "\"uid\":\"$uid\"" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | head -1)
        HEALTH=$(curl -sf -u "$AUTH" "$GRAFANA_URL/api/datasources/uid/$uid/health" 2>/dev/null || echo "")
        if echo "$HEALTH" | grep -q '"status":"OK"'; then
            print_success "  $DS_NAME datasource is healthy"
        else
            print_error "  $DS_NAME datasource has issues"
            echo "$HEALTH" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 | while read -r msg; do
                print_info "    Error: $msg"
            done
        fi
    done
else
    print_error "Cannot access Grafana API (check credentials)"
fi

echo ""
print_header "6. Recent OTEL Collector Logs"
docker logs otel-collector --tail 10 2>&1 | tail -5

echo ""
print_header "7. Network Connectivity Test"

# Test connectivity between containers
print_info "Testing inter-container connectivity..."

# Test from otel-collector to backends
docker exec otel-collector wget -q -O- http://tempo:3200/ready > /dev/null 2>&1 && \
    print_success "  OTEL → Tempo: OK" || \
    print_error "  OTEL → Tempo: FAILED"

docker exec otel-collector wget -q -O- http://prometheus:9090/-/ready > /dev/null 2>&1 && \
    print_success "  OTEL → Prometheus: OK" || \
    print_error "  OTEL → Prometheus: FAILED"

docker exec otel-collector wget -q -O- http://loki:3100/ready > /dev/null 2>&1 && \
    print_success "  OTEL → Loki: OK" || \
    print_error "  OTEL → Loki: FAILED"

# Test gRPC connection to Tempo
docker exec otel-collector nc -zv tempo 4317 > /dev/null 2>&1 && \
    print_success "  OTEL → Tempo gRPC (4317): OK" || \
    print_error "  OTEL → Tempo gRPC (4317): FAILED"

echo ""
print_header "8. Port Listening Status"

print_info "Checking if services are listening on expected ports..."

# Function to check port
check_port() {
    local container=$1
    local port=$2
    local service=$3
    
    if docker exec $container netstat -tuln 2>/dev/null | grep -q ":$port " || \
       docker exec $container ss -tuln 2>/dev/null | grep -q ":$port "; then
        print_success "  $service is listening on port $port"
    else
        print_error "  $service is NOT listening on port $port"
    fi
}

check_port "tempo" "3200" "Tempo HTTP"
check_port "tempo" "4317" "Tempo OTLP gRPC"
check_port "tempo" "4318" "Tempo OTLP HTTP"
check_port "prometheus" "9090" "Prometheus"
check_port "loki" "3100" "Loki"
check_port "otel-collector" "4317" "OTEL gRPC"
check_port "otel-collector" "4318" "OTEL HTTP"

echo ""
print_header "Summary"
echo ""
print_info "If all checks pass, your stack is ready for testing!"
print_info "Run the test script to generate data:"
echo ""
echo -e "  ${GREEN}./test-telemetry-data.sh${NC}"
echo ""
print_info "Or for a quick test:"
echo ""
echo -e "  ${GREEN}./quick-test.sh${NC}"
echo ""
print_info "Then check Grafana at: ${GREEN}http://localhost:30700${NC}"
print_info "  Username: ${GREEN}admin${NC}"
print_info "  Password: ${GREEN}admin${NC}"
echo ""

