#!/bin/bash

################################################################################
# E-Commerce Telemetry Testing Script
# Purpose: Send e-commerce specific metrics to match Grafana dashboard
# Sends metrics that align with: ecommerce-monitoring.json dashboard
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
NUM_ITERATIONS=${NUM_ITERATIONS:-50}
DELAY_SECONDS=${DELAY_SECONDS:-3}

# E-Commerce specific data
PAGES=("home" "products" "product-detail" "cart" "checkout" "account" "login")
ACTIONS=("click" "view" "search" "filter" "add-to-cart" "remove-from-cart")
CATEGORIES=("navigation" "product-interaction" "cart" "checkout" "auth")
CART_OPERATIONS=("add" "remove" "update" "clear")
AUTH_OPERATIONS=("login" "logout" "register")
API_ENDPOINTS=("/api/products" "/api/cart" "/api/auth/login" "/api/checkout" "/api/user")
HTTP_METHODS=("GET" "POST" "PUT" "DELETE")
STATUS_CODES=(200 201 204 400 401 404 500)

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

random_element() {
    local arr=("$@")
    echo "${arr[RANDOM % ${#arr[@]}]}"
}

random_range() {
    local min=$1
    local max=$2
    echo $((RANDOM % (max - min + 1) + min))
}

get_timestamp_ns() {
    echo $(($(date +%s) * 1000000000))
}

################################################################################
# Send E-Commerce Metrics (Matching Dashboard Queries)
################################################################################

send_ecommerce_metrics() {
    local timestamp=$(get_timestamp_ns)
    
    # Random page views
    local page=$(random_element "${PAGES[@]}")
    local user_id="user_$(random_range 1 100)"
    
    # Random user action
    local action=$(random_element "${ACTIONS[@]}")
    local category=$(random_element "${CATEGORIES[@]}")
    
    # Random cart operation
    local cart_op=$(random_element "${CART_OPERATIONS[@]}")
    local product_id="prod_$(random_range 1 500)"
    local quantity=$(random_range 1 5)
    
    # Random auth operation
    local auth_op=$(random_element "${AUTH_OPERATIONS[@]}")
    local auth_success=$([ $RANDOM -gt 16384 ] && echo "true" || echo "false")
    
    # Random API request
    local api_endpoint=$(random_element "${API_ENDPOINTS[@]}")
    local http_method=$(random_element "${HTTP_METHODS[@]}")
    local duration_ms=$(random_range 10 500)
    local status_code=$(random_element "${STATUS_CODES[@]}")
    
    # Random cart value
    local cart_value=$(random_range 1000 50000)
    local item_count=$(random_range 1 10)
    
    local payload=$(cat <<EOF
{
  "resourceMetrics": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {"stringValue": "ec-frontend"}
          },
          {
            "key": "service.version",
            "value": {"stringValue": "1.0.0"}
          }
        ]
      },
      "scopeMetrics": [
        {
          "scope": {
            "name": "ec-metrics",
            "version": "1.0.0"
          },
          "metrics": [
            {
              "name": "page_views_total",
              "description": "Total page views",
              "sum": {
                "dataPoints": [
                  {
                    "asInt": 1,
                    "timeUnixNano": "$timestamp",
                    "attributes": [
                      {"key": "page", "value": {"stringValue": "$page"}},
                      {"key": "user_id", "value": {"stringValue": "$user_id"}}
                    ]
                  }
                ],
                "aggregationTemporality": 2,
                "isMonotonic": true
              }
            },
            {
              "name": "user_actions_total",
              "description": "Total user actions",
              "sum": {
                "dataPoints": [
                  {
                    "asInt": 1,
                    "timeUnixNano": "$timestamp",
                    "attributes": [
                      {"key": "action", "value": {"stringValue": "$action"}},
                      {"key": "category", "value": {"stringValue": "$category"}},
                      {"key": "user_id", "value": {"stringValue": "$user_id"}}
                    ]
                  }
                ],
                "aggregationTemporality": 2,
                "isMonotonic": true
              }
            },
            {
              "name": "cart_operations_total",
              "description": "Total cart operations",
              "sum": {
                "dataPoints": [
                  {
                    "asInt": 1,
                    "timeUnixNano": "$timestamp",
                    "attributes": [
                      {"key": "operation", "value": {"stringValue": "$cart_op"}},
                      {"key": "product_id", "value": {"stringValue": "$product_id"}},
                      {"key": "quantity", "value": {"stringValue": "$quantity"}}
                    ]
                  }
                ],
                "aggregationTemporality": 2,
                "isMonotonic": true
              }
            },
            {
              "name": "auth_operations_total",
              "description": "Total auth operations",
              "sum": {
                "dataPoints": [
                  {
                    "asInt": 1,
                    "timeUnixNano": "$timestamp",
                    "attributes": [
                      {"key": "operation", "value": {"stringValue": "$auth_op"}},
                      {"key": "success", "value": {"stringValue": "$auth_success"}},
                      {"key": "user_id", "value": {"stringValue": "$user_id"}}
                    ]
                  }
                ],
                "aggregationTemporality": 2,
                "isMonotonic": true
              }
            },
            {
              "name": "api_request_duration_ms",
              "description": "API request duration in milliseconds",
              "histogram": {
                "dataPoints": [
                  {
                    "timeUnixNano": "$timestamp",
                    "count": 1,
                    "sum": $duration_ms,
                    "bucketCounts": [0, 0, 1, 0, 0, 0, 0],
                    "explicitBounds": [10, 50, 100, 200, 500, 1000],
                    "attributes": [
                      {"key": "endpoint", "value": {"stringValue": "$api_endpoint"}},
                      {"key": "method", "value": {"stringValue": "$http_method"}},
                      {"key": "status_code", "value": {"stringValue": "$status_code"}}
                    ]
                  }
                ],
                "aggregationTemporality": 2
              }
            },
            {
              "name": "cart_value_total",
              "description": "Current cart value",
              "gauge": {
                "dataPoints": [
                  {
                    "asDouble": $cart_value,
                    "timeUnixNano": "$timestamp",
                    "attributes": [
                      {"key": "item_count", "value": {"stringValue": "$item_count"}}
                    ]
                  }
                ]
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
        print_success "Metrics sent: Page=$page, Action=$action, Cart=$cart_op, Auth=$auth_op, API=${duration_ms}ms"
        return 0
    else
        print_error "Failed to send metrics: HTTP $http_code"
        echo "$response" | head -n -1
        return 1
    fi
}

################################################################################
# Generate Realistic E-Commerce Traffic
################################################################################

generate_shopping_session() {
    print_info "Simulating shopping session..."
    
    # User visits home page
    send_ecommerce_metrics
    sleep 0.5
    
    # Browse products
    for i in {1..3}; do
        send_ecommerce_metrics
        sleep 0.3
    done
    
    # Add items to cart
    for i in {1..2}; do
        send_ecommerce_metrics
        sleep 0.4
    done
    
    # View cart and checkout (maybe)
    if [ $RANDOM -gt 10000 ]; then
        send_ecommerce_metrics
        sleep 0.5
    fi
}

################################################################################
# Check Prerequisites
################################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed"
        exit 1
    fi
    print_success "curl is available"
    
    # Check if OTEL collector is reachable
    if curl -s --max-time 5 "$OTEL_ENDPOINT/v1/metrics" -o /dev/null -w "%{http_code}" | grep -q "405\|404\|200"; then
        print_success "OTEL Collector is reachable at $OTEL_ENDPOINT"
    else
        print_error "Cannot reach OTEL Collector at $OTEL_ENDPOINT"
        print_info "Make sure the monitoring stack is running:"
        print_info "  cd /Users/admin/Work/script/monitoring_ops"
        print_info "  docker-compose -f docker-compose-telemetry.yaml up -d"
        exit 1
    fi
    
    echo ""
}

################################################################################
# Main Test Loop
################################################################################

run_continuous_tests() {
    print_header "Starting E-Commerce Metrics Generation"
    print_info "Endpoint: $OTEL_ENDPOINT"
    print_info "Iterations: $NUM_ITERATIONS"
    print_info "Delay: ${DELAY_SECONDS}s"
    echo ""
    
    local success_count=0
    local error_count=0
    
    for iteration in $(seq 1 $NUM_ITERATIONS); do
        print_header "Iteration $iteration/$NUM_ITERATIONS"
        
        # Generate multiple shopping sessions per iteration
        for session in {1..3}; do
            if generate_shopping_session; then
                ((success_count++))
            else
                ((error_count++))
            fi
        done
        
        echo ""
        if [ $iteration -lt $NUM_ITERATIONS ]; then
            print_info "Waiting ${DELAY_SECONDS}s before next iteration..."
            sleep $DELAY_SECONDS
        fi
    done
    
    echo ""
    print_header "Test Completed!"
    print_success "Successfully sent: $success_count batches"
    if [ $error_count -gt 0 ]; then
        print_error "Failed to send: $error_count batches"
    fi
    echo ""
    print_info "Check Grafana dashboard: http://localhost:30700"
    print_info "  Dashboard: E-Commerce Application Monitoring"
    print_info "  Username: admin"
    print_info "  Password: admin"
    echo ""
    print_info "To check Prometheus metrics directly:"
    print_info "  http://localhost:9090/graph"
    print_info "  Try query: otel_page_views_total"
}

################################################################################
# Show Usage
################################################################################

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Send E-Commerce metrics that match the Grafana dashboard queries.

OPTIONS:
    -e, --endpoint URL      OTEL Collector endpoint (default: http://localhost:4318)
    -n, --iterations NUM    Number of test iterations (default: 50)
    -d, --delay SECONDS     Delay between iterations (default: 3)
    -h, --help             Show this help message

EXAMPLES:
    # Run with defaults
    $0

    # Run 100 iterations with 2 second delay
    $0 -n 100 -d 2

    # Use remote endpoint
    $0 -e http://172.18.0.10:4318

DASHBOARD METRICS:
    This script sends metrics that match the e-commerce-monitoring.json dashboard:
    - page_views_total (by page, user_id)
    - user_actions_total (by action, category, user_id)
    - cart_operations_total (by operation, product_id, quantity)
    - auth_operations_total (by operation, success, user_id)
    - api_request_duration_ms (histogram by endpoint, method, status_code)
    - cart_value_total (gauge by item_count)

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
    print_header "E-Commerce Metrics Test Generator"
    echo ""
    
    check_prerequisites
    run_continuous_tests
}

main

