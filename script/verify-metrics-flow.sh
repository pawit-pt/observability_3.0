#!/bin/bash

################################################################################
# Verify Metrics Flow - Diagnostic Script
# Purpose: Check if metrics are flowing from OTEL Collector to Prometheus
################################################################################

set -e

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

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}ℹ $1${NC}"; }

################################################################################
# Check Services
################################################################################

check_services() {
    print_header "Checking Docker Services"
    
    services=("otel-collector" "prometheus" "grafana" "tempo" "loki")
    all_running=true
    
    for service in "${services[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
            print_success "$service is running"
        else
            print_error "$service is NOT running"
            all_running=false
        fi
    done
    
    echo ""
    if [ "$all_running" = false ]; then
        print_error "Some services are not running. Start them with:"
        echo "  cd /Users/admin/Work/script/monitoring_ops"
        echo "  docker-compose -f docker-compose-telemetry.yaml up -d"
        exit 1
    fi
}

################################################################################
# Check OTEL Collector
################################################################################

check_otel_collector() {
    print_header "Checking OTEL Collector"
    
    # Health check
    if curl -s http://localhost:13133 > /dev/null; then
        print_success "OTEL Collector health endpoint is accessible"
    else
        print_error "OTEL Collector health endpoint is NOT accessible"
        return 1
    fi
    
    # Check HTTP receiver
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:4318/v1/metrics | grep -q "405\|404"; then
        print_success "OTEL Collector HTTP receiver (4318) is listening"
    else
        print_error "OTEL Collector HTTP receiver is NOT accessible"
        return 1
    fi
    
    # Check Prometheus exporter
    if curl -s http://localhost:8889/metrics > /dev/null; then
        print_success "OTEL Collector Prometheus exporter (8889) is accessible"
    else
        print_error "OTEL Collector Prometheus exporter is NOT accessible"
        return 1
    fi
    
    echo ""
}

################################################################################
# Check Prometheus
################################################################################

check_prometheus() {
    print_header "Checking Prometheus"
    
    # Health check
    if curl -s http://localhost:9090/-/healthy > /dev/null; then
        print_success "Prometheus is healthy"
    else
        print_error "Prometheus is NOT healthy"
        return 1
    fi
    
    # Check if scraping OTEL collector
    print_info "Checking Prometheus targets..."
    targets=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job == "otel-collector-metrics") | .health')
    
    if echo "$targets" | grep -q "up"; then
        print_success "Prometheus is scraping OTEL collector metrics"
    else
        print_error "Prometheus is NOT scraping OTEL collector metrics properly"
        print_info "Target status: $targets"
    fi
    
    # Check if any otel metrics exist
    print_info "Checking for existing otel_ metrics in Prometheus..."
    otel_metrics=$(curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq -r '.data[]' | grep "^otel_" | head -5)
    
    if [ -n "$otel_metrics" ]; then
        print_success "Found otel_ metrics in Prometheus:"
        echo "$otel_metrics" | while read -r metric; do
            echo "  - $metric"
        done
    else
        print_error "No otel_ metrics found in Prometheus yet"
        print_info "This is normal if you haven't sent any test data yet"
    fi
    
    echo ""
}

################################################################################
# Check Grafana
################################################################################

check_grafana() {
    print_header "Checking Grafana"
    
    # Health check
    if curl -s http://localhost:30700/api/health | jq -r '.database' | grep -q "ok"; then
        print_success "Grafana is healthy"
    else
        print_error "Grafana is NOT healthy"
        return 1
    fi
    
    # Check datasources
    print_info "Checking Grafana datasources..."
    datasources=$(curl -s -u admin:admin http://localhost:30700/api/datasources | jq -r '.[] | select(.type == "prometheus") | .name')
    
    if echo "$datasources" | grep -q "prometheus"; then
        print_success "Prometheus datasource is configured in Grafana"
    else
        print_error "Prometheus datasource is NOT configured properly"
    fi
    
    # Check if dashboard exists
    print_info "Checking for E-Commerce dashboard..."
    dashboards=$(curl -s -u admin:admin http://localhost:30700/api/search?type=dash-db | jq -r '.[] | select(.uid == "ecommerce-monitoring") | .title')
    
    if [ -n "$dashboards" ]; then
        print_success "E-Commerce dashboard is loaded: $dashboards"
    else
        print_error "E-Commerce dashboard is NOT found"
        print_info "Dashboard should be at: grafana/dashboards/observability/ecommerce-monitoring.json"
    fi
    
    echo ""
}

################################################################################
# Test Metric Send
################################################################################

test_send_metric() {
    print_header "Testing Metric Send"
    
    print_info "Sending a test metric to OTEL Collector..."
    
    timestamp=$(($(date +%s) * 1000000000))
    payload=$(cat <<EOF
{
  "resourceMetrics": [{
    "resource": {
      "attributes": [
        {"key": "service.name", "value": {"stringValue": "test-service"}}
      ]
    },
    "scopeMetrics": [{
      "metrics": [{
        "name": "test_metric",
        "sum": {
          "dataPoints": [{
            "asInt": 42,
            "timeUnixNano": "$timestamp",
            "attributes": [{"key": "test", "value": {"stringValue": "true"}}]
          }],
          "aggregationTemporality": 2,
          "isMonotonic": true
        }
      }]
    }]
  }]
}
EOF
)
    
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:4318/v1/metrics \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    if [ "$response" = "200" ] || [ "$response" = "202" ]; then
        print_success "Test metric sent successfully (HTTP $response)"
        print_info "Wait 15 seconds for metric to be scraped by Prometheus..."
        sleep 15
        
        # Check if metric appears in Prometheus
        metric_value=$(curl -s "http://localhost:9090/api/v1/query?query=otel_test_metric" | jq -r '.data.result[0].value[1]' 2>/dev/null)
        
        if [ "$metric_value" != "null" ] && [ -n "$metric_value" ]; then
            print_success "Test metric found in Prometheus with value: $metric_value"
        else
            print_error "Test metric NOT found in Prometheus yet"
            print_info "Check OTEL collector logs: docker logs otel-collector"
        fi
    else
        print_error "Failed to send test metric (HTTP $response)"
    fi
    
    echo ""
}

################################################################################
# Show Dashboard Queries
################################################################################

show_dashboard_info() {
    print_header "Dashboard Query Information"
    
    echo "The E-Commerce dashboard expects these metrics:"
    echo ""
    echo "  1. otel_page_views_total"
    echo "     - Labels: page, user_id"
    echo "     - Query: sum(rate(otel_page_views_total[5m])) * 300"
    echo ""
    echo "  2. otel_user_actions_total"
    echo "     - Labels: action, category, user_id"
    echo "     - Query: sum(rate(otel_user_actions_total[5m])) * 300"
    echo ""
    echo "  3. otel_cart_operations_total"
    echo "     - Labels: operation, product_id, quantity"
    echo "     - Query: sum(rate(otel_cart_operations_total[5m])) * 300"
    echo ""
    echo "  4. otel_auth_operations_total"
    echo "     - Labels: operation, success, user_id"
    echo "     - Query: sum(rate(otel_auth_operations_total[5m])) * 300"
    echo ""
    echo "  5. otel_api_request_duration_ms_bucket"
    echo "     - Labels: endpoint, method, status_code"
    echo "     - Query: histogram_quantile(0.95, sum by (endpoint, le) ...)"
    echo ""
    echo "  6. otel_cart_value_total"
    echo "     - Labels: item_count"
    echo "     - Query: sum(otel_cart_value_total)"
    echo ""
}

################################################################################
# Main
################################################################################

main() {
    clear 2>/dev/null || true
    echo ""
    print_header "Metrics Flow Verification Tool"
    echo ""
    
    check_services
    check_otel_collector
    check_prometheus
    check_grafana
    test_send_metric
    show_dashboard_info
    
    print_header "Summary & Next Steps"
    echo ""
    print_info "To send E-Commerce test data that matches the dashboard:"
    echo "  ./script/test-ecommerce-metrics.sh -n 100 -d 2"
    echo ""
    print_info "View the dashboard:"
    echo "  http://localhost:30700/d/ecommerce-monitoring"
    echo "  Username: admin"
    echo "  Password: admin"
    echo ""
    print_info "Query Prometheus directly:"
    echo "  http://localhost:9090/graph"
    echo "  Try: otel_page_views_total"
    echo ""
}

main

