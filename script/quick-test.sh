#!/bin/bash

################################################################################
# Quick Test Script
# Purpose: Rapidly send a burst of test data to verify Grafana dashboards
# Usage: ./quick-test.sh
################################################################################

set -e

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

OTEL_ENDPOINT="http://localhost:4318"

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Quick Telemetry Test${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Generate IDs
generate_trace_id() {
    openssl rand -hex 16
}

generate_span_id() {
    openssl rand -hex 8
}

get_timestamp_ns() {
    echo $(($(date +%s) * 1000000000))
}

echo -e "${YELLOW}Sending test traces...${NC}"

# Send a few quick traces
for i in {1..5}; do
    TRACE_ID=$(generate_trace_id)
    SPAN_ID=$(generate_span_id)
    TIMESTAMP=$(get_timestamp_ns)
    DURATION=$((RANDOM % 500 + 50))
    END_TIME=$((TIMESTAMP + DURATION * 1000000))
    
    curl -s -X POST "$OTEL_ENDPOINT/v1/traces" \
        -H "Content-Type: application/json" \
        -d "{
          \"resourceSpans\": [{
            \"resource\": {
              \"attributes\": [{
                \"key\": \"service.name\",
                \"value\": {\"stringValue\": \"quick-test-service\"}
              }]
            },
            \"scopeSpans\": [{
              \"spans\": [{
                \"traceId\": \"$TRACE_ID\",
                \"spanId\": \"$SPAN_ID\",
                \"name\": \"quick-test-operation-$i\",
                \"kind\": 2,
                \"startTimeUnixNano\": \"$TIMESTAMP\",
                \"endTimeUnixNano\": \"$END_TIME\",
                \"attributes\": [{
                  \"key\": \"http.status_code\",
                  \"value\": {\"intValue\": 200}
                }]
              }]
            }]
          }]
        }" > /dev/null
    
    echo -e "${GREEN}✓ Trace $i sent (${DURATION}ms)${NC}"
done

echo ""
echo -e "${YELLOW}Sending test metrics...${NC}"

# Send a few quick metrics
for i in {1..3}; do
    TIMESTAMP=$(get_timestamp_ns)
    CPU=$((RANDOM % 80 + 10))
    MEMORY=$((RANDOM % 7000 + 1000))
    
    curl -s -X POST "$OTEL_ENDPOINT/v1/metrics" \
        -H "Content-Type: application/json" \
        -d "{
          \"resourceMetrics\": [{
            \"resource\": {
              \"attributes\": [{
                \"key\": \"service.name\",
                \"value\": {\"stringValue\": \"quick-test-service\"}
              }]
            },
            \"scopeMetrics\": [{
              \"metrics\": [
                {
                  \"name\": \"system.cpu.usage\",
                  \"gauge\": {
                    \"dataPoints\": [{
                      \"asDouble\": $CPU,
                      \"timeUnixNano\": \"$TIMESTAMP\"
                    }]
                  }
                },
                {
                  \"name\": \"system.memory.usage\",
                  \"gauge\": {
                    \"dataPoints\": [{
                      \"asDouble\": $MEMORY,
                      \"timeUnixNano\": \"$TIMESTAMP\"
                    }]
                  }
                }
              ]
            }]
          }]
        }" > /dev/null
    
    echo -e "${GREEN}✓ Metrics $i sent (CPU: ${CPU}%, MEM: ${MEMORY}MB)${NC}"
done

echo ""
echo -e "${YELLOW}Sending test logs...${NC}"

# Send a few quick logs
LOG_LEVELS=("INFO" "WARN" "ERROR")
MESSAGES=(
    "Application started successfully"
    "Processing user request"
    "Database query completed"
    "Slow query detected"
    "Connection timeout error"
)

for i in {1..5}; do
    TIMESTAMP=$(get_timestamp_ns)
    TRACE_ID=$(generate_trace_id)
    SPAN_ID=$(generate_span_id)
    LEVEL=${LOG_LEVELS[$RANDOM % ${#LOG_LEVELS[@]}]}
    MESSAGE=${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}
    
    case $LEVEL in
        "ERROR") SEVERITY=17 ;;
        "WARN") SEVERITY=13 ;;
        "INFO") SEVERITY=9 ;;
    esac
    
    curl -s -X POST "$OTEL_ENDPOINT/v1/logs" \
        -H "Content-Type: application/json" \
        -d "{
          \"resourceLogs\": [{
            \"resource\": {
              \"attributes\": [{
                \"key\": \"service.name\",
                \"value\": {\"stringValue\": \"quick-test-service\"}
              }]
            },
            \"scopeLogs\": [{
              \"logRecords\": [{
                \"timeUnixNano\": \"$TIMESTAMP\",
                \"severityNumber\": $SEVERITY,
                \"severityText\": \"$LEVEL\",
                \"body\": {\"stringValue\": \"$MESSAGE\"},
                \"traceId\": \"$TRACE_ID\",
                \"spanId\": \"$SPAN_ID\"
              }]
            }]
          }]
        }" > /dev/null
    
    echo -e "${GREEN}✓ Log $i sent [$LEVEL] $MESSAGE${NC}"
done

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Quick test completed!${NC}"
echo ""
echo -e "${YELLOW}Check your Grafana dashboards:${NC}"
echo -e "  URL: ${GREEN}http://localhost:30700${NC}"
echo -e "  Username: ${GREEN}admin${NC}"
echo -e "  Password: ${GREEN}admin${NC}"
echo ""
echo -e "${YELLOW}Wait a few seconds for data to be processed...${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

