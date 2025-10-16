#!/bin/bash

################################################################################
# Telemetry Testing Script
# Purpose: Send fake traces, metrics, and logs to test Grafana dashboards
# Usage: ./test-telemetry-data.sh [options]
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OTEL_ENDPOINT=${OTEL_ENDPOINT:-"http://localhost:4318"}
NUM_ITERATIONS=${NUM_ITERATIONS:-10}
DELAY_SECONDS=${DELAY_SECONDS:-2}

# Service names for testing
SERVICES=("web-frontend" "api-gateway" "auth-service" "database" "cache-service")
OPERATIONS=("HTTP GET" "HTTP POST" "HTTP PUT" "HTTP DELETE" "database.query" "cache.get" "cache.set")
HTTP_METHODS=("GET" "POST" "PUT" "DELETE")
HTTP_PATHS=("/api/users" "/api/products" "/api/orders" "/api/login" "/api/logout" "/health" "/metrics")
STATUS_CODES=(200 201 204 400 401 403 404 500 503)

################################################################################
# Helper Functions
################################################################################

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

# Generate random element from array
random_element() {
    local arr=("$@")
    echo "${arr[RANDOM % ${#arr[@]}]}"
}

# Generate random number in range
random_range() {
    local min=$1
    local max=$2
    echo $((RANDOM % (max - min + 1) + min))
}

# Generate trace ID (32 hex characters)
generate_trace_id() {
    echo $(openssl rand -hex 16)
}

# Generate span ID (16 hex characters)
generate_span_id() {
    echo $(openssl rand -hex 8)
}

# Get current timestamp in nanoseconds
get_timestamp_ns() {
    echo $(($(date +%s) * 1000000000))
}

################################################################################
# Send Traces
################################################################################

send_trace() {
    local service_name="$1"
    local operation="$2"
    local duration_ms="$3"
    local status_code="$4"
    local trace_id=$(generate_trace_id)
    local span_id=$(generate_span_id)
    local parent_span_id=$(generate_span_id)
    local start_time=$(get_timestamp_ns)
    local end_time=$((start_time + duration_ms * 1000000))
    
    local http_method=$(random_element "${HTTP_METHODS[@]}")
    local http_path=$(random_element "${HTTP_PATHS[@]}")
    
    local payload=$(cat <<EOF
{
  "resourceSpans": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {
              "stringValue": "$service_name"
            }
          },
          {
            "key": "service.version",
            "value": {
              "stringValue": "1.0.0"
            }
          },
          {
            "key": "deployment.environment",
            "value": {
              "stringValue": "production"
            }
          },
          {
            "key": "host.name",
            "value": {
              "stringValue": "$(hostname)"
            }
          }
        ]
      },
      "scopeSpans": [
        {
          "scope": {
            "name": "test-instrumentation",
            "version": "1.0.0"
          },
          "spans": [
            {
              "traceId": "$trace_id",
              "spanId": "$span_id",
              "parentSpanId": "$parent_span_id",
              "name": "$operation",
              "kind": 2,
              "startTimeUnixNano": "$start_time",
              "endTimeUnixNano": "$end_time",
              "attributes": [
                {
                  "key": "http.method",
                  "value": {
                    "stringValue": "$http_method"
                  }
                },
                {
                  "key": "http.url",
                  "value": {
                    "stringValue": "$http_path"
                  }
                },
                {
                  "key": "http.status_code",
                  "value": {
                    "intValue": $status_code
                  }
                },
                {
                  "key": "http.user_agent",
                  "value": {
                    "stringValue": "TestAgent/1.0"
                  }
                },
                {
                  "key": "net.peer.ip",
                  "value": {
                    "stringValue": "192.168.1.$(random_range 1 255)"
                  }
                }
              ],
              "status": {
                "code": $(if [ $status_code -ge 400 ]; then echo 2; else echo 0; fi)
              }
            }
          ]
        }
      ]
    }
  ]
}
EOF
)
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "$OTEL_ENDPOINT/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "202" ]; then
        print_success "Trace sent: $service_name - $operation (${duration_ms}ms, HTTP $status_code)"
        return 0
    else
        print_error "Failed to send trace: HTTP $http_code"
        return 1
    fi
}

################################################################################
# Send Metrics
################################################################################

send_metrics() {
    local service_name="$1"
    local timestamp=$(get_timestamp_ns)
    
    local cpu_usage=$(awk -v min=10 -v max=90 'BEGIN{srand(); print min+rand()*(max-min)}')
    local memory_usage=$(awk -v min=100 -v max=8000 'BEGIN{srand(); print int(min+rand()*(max-min))}')
    local request_count=$(random_range 50 500)
    local error_count=$(random_range 0 50)
    local response_time=$(awk -v min=10 -v max=5000 'BEGIN{srand(); print min+rand()*(max-min)}')
    
    local payload=$(cat <<EOF
{
  "resourceMetrics": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {
              "stringValue": "$service_name"
            }
          },
          {
            "key": "service.version",
            "value": {
              "stringValue": "1.0.0"
            }
          },
          {
            "key": "deployment.environment",
            "value": {
              "stringValue": "production"
            }
          }
        ]
      },
      "scopeMetrics": [
        {
          "scope": {
            "name": "test-metrics",
            "version": "1.0.0"
          },
          "metrics": [
            {
              "name": "system.cpu.usage",
              "description": "CPU usage percentage",
              "unit": "percent",
              "gauge": {
                "dataPoints": [
                  {
                    "asDouble": $cpu_usage,
                    "timeUnixNano": "$timestamp",
                    "attributes": [
                      {
                        "key": "cpu.state",
                        "value": {
                          "stringValue": "used"
                        }
                      }
                    ]
                  }
                ]
              }
            },
            {
              "name": "system.memory.usage",
              "description": "Memory usage in MB",
              "unit": "MB",
              "gauge": {
                "dataPoints": [
                  {
                    "asDouble": $memory_usage,
                    "timeUnixNano": "$timestamp"
                  }
                ]
              }
            },
            {
              "name": "http.server.request.count",
              "description": "Total HTTP requests",
              "unit": "1",
              "sum": {
                "dataPoints": [
                  {
                    "asInt": $request_count,
                    "startTimeUnixNano": "$timestamp",
                    "timeUnixNano": "$timestamp",
                    "attributes": [
                      {
                        "key": "http.method",
                        "value": {
                          "stringValue": "GET"
                        }
                      },
                      {
                        "key": "http.route",
                        "value": {
                          "stringValue": "/api/users"
                        }
                      }
                    ]
                  }
                ],
                "aggregationTemporality": 2,
                "isMonotonic": true
              }
            },
            {
              "name": "http.server.error.count",
              "description": "Total HTTP errors",
              "unit": "1",
              "sum": {
                "dataPoints": [
                  {
                    "asInt": $error_count,
                    "startTimeUnixNano": "$timestamp",
                    "timeUnixNano": "$timestamp"
                  }
                ],
                "aggregationTemporality": 2,
                "isMonotonic": true
              }
            },
            {
              "name": "http.server.duration",
              "description": "HTTP request duration",
              "unit": "ms",
              "histogram": {
                "dataPoints": [
                  {
                    "startTimeUnixNano": "$timestamp",
                    "timeUnixNano": "$timestamp",
                    "count": 100,
                    "sum": $response_time,
                    "bucketCounts": [10, 20, 30, 25, 10, 5],
                    "explicitBounds": [50, 100, 200, 500, 1000],
                    "attributes": [
                      {
                        "key": "http.status_code",
                        "value": {
                          "intValue": 200
                        }
                      }
                    ]
                  }
                ],
                "aggregationTemporality": 2
              }
            }
          ]
        }
      ]
    }
  ]
}
EOF
)
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "$OTEL_ENDPOINT/v1/metrics" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "202" ]; then
        print_success "Metrics sent: $service_name (CPU: ${cpu_usage}%, MEM: ${memory_usage}MB, REQ: $request_count)"
        return 0
    else
        print_error "Failed to send metrics: HTTP $http_code"
        return 1
    fi
}

################################################################################
# Send Logs
################################################################################

send_logs() {
    local service_name="$1"
    local log_level="$2"
    local message="$3"
    local timestamp=$(get_timestamp_ns)
    local trace_id=$(generate_trace_id)
    local span_id=$(generate_span_id)
    
    local severity_number=9
    case $log_level in
        "ERROR") severity_number=17 ;;
        "WARN") severity_number=13 ;;
        "INFO") severity_number=9 ;;
        "DEBUG") severity_number=5 ;;
    esac
    
    local payload=$(cat <<EOF
{
  "resourceLogs": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {
              "stringValue": "$service_name"
            }
          },
          {
            "key": "deployment.environment",
            "value": {
              "stringValue": "production"
            }
          }
        ]
      },
      "scopeLogs": [
        {
          "scope": {
            "name": "test-logger",
            "version": "1.0.0"
          },
          "logRecords": [
            {
              "timeUnixNano": "$timestamp",
              "severityNumber": $severity_number,
              "severityText": "$log_level",
              "body": {
                "stringValue": "$message"
              },
              "attributes": [
                {
                  "key": "thread.id",
                  "value": {
                    "intValue": $(random_range 1 100)
                  }
                },
                {
                  "key": "logger.name",
                  "value": {
                    "stringValue": "com.example.$service_name"
                  }
                }
              ],
              "traceId": "$trace_id",
              "spanId": "$span_id"
            }
          ]
        }
      ]
    }
  ]
}
EOF
)
    
    local response=$(curl -s -w "\n%{http_code}" -X POST "$OTEL_ENDPOINT/v1/logs" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "202" ]; then
        print_success "Log sent: $service_name - [$log_level] $message"
        return 0
    else
        print_error "Failed to send log: HTTP $http_code"
        return 1
    fi
}

################################################################################
# Test Scenarios
################################################################################

test_healthy_requests() {
    print_header "Testing Healthy Requests (Fast Response Times)"
    
    # Generate more successful requests
    for i in $(seq 1 15); do
        local service=$(random_element "${SERVICES[@]}")
        local operation=$(random_element "${OPERATIONS[@]}")
        local duration=$(random_range 10 200)
        local status_code=$(random_element 200 201 204)
        
        send_trace "$service" "$operation" $duration $status_code
        send_logs "$service" "INFO" "Request processed successfully: $operation"
        sleep 0.2
    done
}

test_slow_requests() {
    print_header "Testing Slow Requests"
    
    for i in $(seq 1 3); do
        local service=$(random_element "${SERVICES[@]}")
        local operation=$(random_element "${OPERATIONS[@]}")
        local duration=$(random_range 1000 5000)
        local status_code=200
        
        send_trace "$service" "$operation" $duration $status_code
        send_logs "$service" "WARN" "Slow request detected: $operation took ${duration}ms"
        sleep 0.5
    done
}

test_error_requests() {
    print_header "Testing Error Requests"
    
    # Generate more errors to make error rate visible
    for i in $(seq 1 10); do
        local service=$(random_element "${SERVICES[@]}")
        local operation=$(random_element "${OPERATIONS[@]}")
        local duration=$(random_range 50 500)
        local status_code=$(random_element 400 401 403 404 500 503)
        
        send_trace "$service" "$operation" $duration $status_code
        send_logs "$service" "ERROR" "Request failed with status $status_code: $operation"
        sleep 0.3
    done
}

test_database_operations() {
    print_header "Testing Database Operations"
    
    local queries=(
        "SELECT * FROM users WHERE id = 123"
        "INSERT INTO orders (user_id, total) VALUES (456, 99.99)"
        "UPDATE products SET stock = stock - 1 WHERE id = 789"
        "DELETE FROM sessions WHERE expired_at < NOW()"
    )
    
    for query in "${queries[@]}"; do
        send_trace "database" "database.query" $(random_range 5 100) 200
        send_logs "database" "INFO" "Executing query: $query"
        sleep 0.5
    done
}

test_cache_operations() {
    print_header "Testing Cache Operations"
    
    for i in $(seq 1 10); do
        local operation=$(random_element "cache.get" "cache.set" "cache.delete")
        local duration=$(random_range 1 10)
        
        send_trace "cache-service" "$operation" $duration 200
        send_logs "cache-service" "DEBUG" "Cache operation: $operation"
        sleep 0.3
    done
}

################################################################################
# Main Test Loop
################################################################################

run_continuous_tests() {
    print_header "Starting Continuous Test Data Generation"
    print_info "Endpoint: $OTEL_ENDPOINT"
    print_info "Iterations: $NUM_ITERATIONS"
    print_info "Delay: ${DELAY_SECONDS}s"
    echo ""
    
    for iteration in $(seq 1 $NUM_ITERATIONS); do
        print_header "Iteration $iteration/$NUM_ITERATIONS"
        
        # Send metrics for all services
        for service in "${SERVICES[@]}"; do
            send_metrics "$service"
        done
        
        # Run different test scenarios
        test_healthy_requests
        test_slow_requests
        test_error_requests
        test_database_operations
        test_cache_operations
        
        # Additional random traces
        for i in $(seq 1 5); do
            local service=$(random_element "${SERVICES[@]}")
            local operation=$(random_element "${OPERATIONS[@]}")
            local duration=$(random_range 10 1000)
            local status_code=$(random_element "${STATUS_CODES[@]}")
            
            send_trace "$service" "$operation" $duration $status_code
        done
        
        echo ""
        if [ $iteration -lt $NUM_ITERATIONS ]; then
            print_info "Waiting ${DELAY_SECONDS}s before next iteration..."
            sleep $DELAY_SECONDS
        fi
    done
    
    echo ""
    print_header "Test Completed Successfully!"
    print_info "Check Grafana dashboards at http://localhost:30700"
    print_info "  - Username: admin"
    print_info "  - Password: admin"
}

################################################################################
# Check Prerequisites
################################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed"
        exit 1
    fi
    print_success "curl is available"
    
    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        print_error "openssl is not installed"
        exit 1
    fi
    print_success "openssl is available"
    
    # Check if OTEL collector is reachable
    if curl -s --max-time 5 "$OTEL_ENDPOINT/v1/traces" -o /dev/null -w "%{http_code}" | grep -q "405\|404\|200"; then
        print_success "OTEL Collector is reachable at $OTEL_ENDPOINT"
    else
        print_error "Cannot reach OTEL Collector at $OTEL_ENDPOINT"
        print_info "Make sure the monitoring stack is running: docker-compose up -d"
        exit 1
    fi
    
    echo ""
}

################################################################################
# Usage Information
################################################################################

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Send test telemetry data (traces, metrics, logs) to OpenTelemetry Collector.

OPTIONS:
    -e, --endpoint URL      OTEL Collector endpoint (default: http://localhost:4318)
    -n, --iterations NUM    Number of test iterations (default: 10)
    -d, --delay SECONDS     Delay between iterations (default: 2)
    -h, --help             Show this help message

EXAMPLES:
    # Run with defaults
    $0

    # Run 50 iterations with 1 second delay
    $0 -n 50 -d 1

    # Use custom endpoint
    $0 -e http://remote-host:4318

ENVIRONMENT VARIABLES:
    OTEL_ENDPOINT          Override default OTEL endpoint
    NUM_ITERATIONS         Override default iteration count
    DELAY_SECONDS          Override default delay

After running this script, check your Grafana dashboards:
    URL: http://localhost:30700
    Username: admin
    Password: admin

EOF
}

################################################################################
# Parse Arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--endpoint)
            OTEL_ENDPOINT="$2"
            shift 2
            ;;
        -n|--iterations)
            NUM_ITERATIONS="$2"
            shift 2
            ;;
        -d|--delay)
            DELAY_SECONDS="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

################################################################################
# Main
################################################################################

main() {
    clear 2>/dev/null || true
    echo ""
    print_header "OpenTelemetry Test Data Generator"
    echo ""
    
    check_prerequisites
    run_continuous_tests
}

main

