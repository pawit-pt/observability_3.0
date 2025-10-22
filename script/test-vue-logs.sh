#!/bin/bash

# Test Vue Logs Flow to Loki
# This script tests the complete logging pipeline from Vue app to Loki

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Vue Logs to Loki - Flow Test${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to check if service is healthy
check_service() {
    local service=$1
    local url=$2
    echo -ne "${YELLOW}Checking ${service}...${NC} "
    if curl -sf "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ Not responding${NC}"
        return 1
    fi
}

# Check all services
echo -e "${BLUE}1. Checking Service Health${NC}"
echo "-----------------------------------"
check_service "OTEL Collector" "http://localhost:13133"
check_service "Loki" "http://localhost:3100/ready"
check_service "Grafana" "http://localhost:30700/api/health"
echo ""

# Test OTLP endpoint
echo -e "${BLUE}2. Testing OTLP HTTP Endpoint${NC}"
echo "-----------------------------------"
TIMESTAMP=$(date +%s)000000000  # Convert to nanoseconds

TEST_LOG_PAYLOAD=$(cat <<EOF
{
  "resourceLogs": [{
    "resource": {
      "attributes": [
        { "key": "service.name", "value": { "stringValue": "vue-test-app" } },
        { "key": "service.version", "value": { "stringValue": "1.0.0" } },
        { "key": "deployment.environment", "value": { "stringValue": "test" } }
      ]
    },
    "scopeLogs": [{
      "scope": {
        "name": "vue-test-logger",
        "version": "1.0.0"
      },
      "logRecords": [{
        "timeUnixNano": "$TIMESTAMP",
        "severityNumber": 9,
        "severityText": "INFO",
        "body": {
          "stringValue": "Test log from Vue logging system - $(date)"
        },
        "attributes": [
          { "key": "component", "value": { "stringValue": "TestComponent" } },
          { "key": "action", "value": { "stringValue": "test_log" } },
          { "key": "route", "value": { "stringValue": "/test" } },
          { "key": "test_id", "value": { "stringValue": "$(uuidgen)" } }
        ]
      }]
    }]
  }]
}
EOF
)

echo "Sending test log to OTEL Collector..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -d "$TEST_LOG_PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Log sent successfully (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}✗ Failed to send log (HTTP $HTTP_CODE)${NC}"
    echo "$RESPONSE" | head -n -1
fi
echo ""

# Wait for log processing
echo -e "${YELLOW}Waiting 5 seconds for log processing...${NC}"
sleep 5
echo ""

# Query Loki for the test log
echo -e "${BLUE}3. Querying Loki for Logs${NC}"
echo "-----------------------------------"

# Query for all ec-frontend logs
echo "Querying for ec-frontend logs..."
LOKI_QUERY='{service_name="ec-frontend"}'
LOKI_URL="http://localhost:3100/loki/api/v1/query_range"
START_TIME=$(($(date +%s) - 3600))  # Last hour
END_TIME=$(date +%s)

LOKI_RESPONSE=$(curl -s -G "$LOKI_URL" \
  --data-urlencode "query=$LOKI_QUERY" \
  --data-urlencode "start=${START_TIME}000000000" \
  --data-urlencode "end=${END_TIME}000000000" \
  --data-urlencode "limit=10")

LOG_COUNT=$(echo "$LOKI_RESPONSE" | jq -r '.data.result | length' 2>/dev/null || echo "0")

if [ "$LOG_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $LOG_COUNT log stream(s) in Loki${NC}"
    echo ""
    echo "Recent logs:"
    echo "$LOKI_RESPONSE" | jq -r '.data.result[0].values[-5:][] | "  [\(.[0])] \(.[1])"' 2>/dev/null | head -5
else
    echo -e "${YELLOW}⚠ No logs found yet. This might be normal if you just started the services.${NC}"
fi
echo ""

# Query for test logs
echo "Querying for test logs..."
TEST_LOKI_QUERY='{service_name="vue-test-app"}'
TEST_LOKI_RESPONSE=$(curl -s -G "$LOKI_URL" \
  --data-urlencode "query=$TEST_LOKI_QUERY" \
  --data-urlencode "start=${START_TIME}000000000" \
  --data-urlencode "end=${END_TIME}000000000" \
  --data-urlencode "limit=5")

TEST_LOG_COUNT=$(echo "$TEST_LOKI_RESPONSE" | jq -r '.data.result | length' 2>/dev/null || echo "0")

if [ "$TEST_LOG_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found test log in Loki${NC}"
    echo ""
    echo "Test log content:"
    echo "$TEST_LOKI_RESPONSE" | jq -r '.data.result[0].values[-1][] | "  [\(.[0])] \(.[1])"' 2>/dev/null
else
    echo -e "${YELLOW}⚠ Test log not found in Loki yet${NC}"
fi
echo ""

# Check Grafana datasource
echo -e "${BLUE}4. Verifying Grafana Datasource${NC}"
echo "-----------------------------------"
GRAFANA_DS=$(curl -s -u admin:admin http://localhost:30700/api/datasources/name/Loki)
DS_STATUS=$(echo "$GRAFANA_DS" | jq -r '.name' 2>/dev/null)

if [ "$DS_STATUS" = "Loki" ]; then
    echo -e "${GREEN}✓ Loki datasource configured in Grafana${NC}"
    echo "  URL: $(echo "$GRAFANA_DS" | jq -r '.url')"
    echo "  UID: $(echo "$GRAFANA_DS" | jq -r '.uid')"
else
    echo -e "${RED}✗ Loki datasource not found in Grafana${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Log Flow Path:"
echo "  Vue App (port 3000)"
echo "    ↓ HTTP POST to /v1/logs"
echo "  OTEL Collector (port 4318)"
echo "    ↓ Loki exporter"
echo "  Loki (port 3100)"
echo "    ↓ Query via datasource"
echo "  Grafana (port 30700)"
echo ""
echo "Useful URLs:"
echo "  • Grafana: http://localhost:30700 (admin/admin)"
echo "  • Loki API: http://localhost:3100"
echo "  • OTEL Collector: http://localhost:4318"
echo "  • OTEL Health: http://localhost:13133"
echo ""
echo "Grafana Log Query Examples:"
echo "  • All frontend logs: {service_name=\"ec-frontend\"}"
echo "  • Error logs: {service_name=\"ec-frontend\"} |= \"ERROR\""
echo "  • Specific component: {service_name=\"ec-frontend\"} | json | component=\"ProductCard\""
echo "  • User interactions: {service_name=\"ec-frontend\"} | json | action=\"user_interaction\""
echo ""
echo -e "${GREEN}Test completed!${NC}"
echo ""

