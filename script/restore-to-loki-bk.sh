#!/bin/bash

#######################################################
# Restore Backup to Loki_BK (Archive) Script
# 
# Purpose: Restore old data to loki_bk for historical queries
# Usage: ./restore-to-loki-bk.sh <backup-file>
#######################################################

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

BACKUP_FILE="$1"
LOKI_BK_DATA_DIR="/var/www/app/grafana/loki/data-backup"
COMPOSE_FILE="/var/www/app/grafana/docker-compose-logging-complete.yaml"

if [ -z "${BACKUP_FILE}" ]; then
    echo -e "${RED}Usage: $0 <backup-file.tar.gz>${NC}"
    echo ""
    echo "Available backups:"
    ls -lht /var/www/app/grafana/backups/loki/*.tar.gz 2>/dev/null | head -10 || echo "No backups found"
    exit 1
fi

if [ ! -f "${BACKUP_FILE}" ]; then
    echo -e "${RED}Error: Backup file not found: ${BACKUP_FILE}${NC}"
    exit 1
fi

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Restore to Loki_BK (Archive)${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo "Backup file: ${BACKUP_FILE}"
echo "Restore location: ${LOKI_BK_DATA_DIR}"
echo "Port: 3101 (http://localhost:3101)"
echo ""
echo -e "${GREEN}Note: This will restore to loki_bk (archive instance)${NC}"
echo -e "${GREEN}      Your main loki instance will NOT be affected${NC}"
echo ""

# Confirmation
read -p "Continue with restore to loki_bk? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Stop loki_bk
echo -e "${YELLOW}Stopping loki_bk container...${NC}"
docker-compose -f "${COMPOSE_FILE}" stop loki_bk 2>/dev/null || true

# Backup current data (just in case)
if [ -d "${LOKI_BK_DATA_DIR}" ] && [ "$(ls -A ${LOKI_BK_DATA_DIR})" ]; then
    echo -e "${YELLOW}Creating safety backup of current loki_bk data...${NC}"
    SAFETY_BACKUP="/tmp/loki-bk-safety-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "${SAFETY_BACKUP}" -C "$(dirname "${LOKI_BK_DATA_DIR}")" "$(basename "${LOKI_BK_DATA_DIR}")" 2>/dev/null || true
    echo "Safety backup: ${SAFETY_BACKUP}"
fi

# Create directory if it doesn't exist
mkdir -p "${LOKI_BK_DATA_DIR}"

# Clear existing data
echo -e "${YELLOW}Removing existing data from loki_bk...${NC}"
rm -rf "${LOKI_BK_DATA_DIR}"/*

# Extract backup
echo -e "${YELLOW}Restoring from backup...${NC}"
# Extract and rename the directory
TEMP_DIR=$(mktemp -d)
tar -xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"

# Find the extracted data directory and copy contents
if [ -d "${TEMP_DIR}/data" ]; then
    cp -r "${TEMP_DIR}/data/"* "${LOKI_BK_DATA_DIR}/"
else
    # If extracted directly
    cp -r "${TEMP_DIR}/"* "${LOKI_BK_DATA_DIR}/"
fi

rm -rf "${TEMP_DIR}"

# Fix permissions (make it accessible)
echo -e "${YELLOW}Setting permissions...${NC}"
chmod -R 777 "${LOKI_BK_DATA_DIR}"

# Start loki_bk
echo -e "${YELLOW}Starting loki_bk container...${NC}"
docker-compose -f "${COMPOSE_FILE}" up -d loki_bk

# Wait for loki_bk to be ready
echo -e "${YELLOW}Waiting for loki_bk to be ready...${NC}"
sleep 5
for i in {1..30}; do
    if curl -s http://localhost:3101/ready > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Loki_BK is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Restore to loki_bk completed!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Access loki_bk at: http://localhost:3101"
echo ""
echo "Query example:"
echo "  curl -G -s 'http://localhost:3101/loki/api/v1/query_range' \\"
echo "    --data-urlencode 'query={job=\"your-job\"}' \\"
echo "    --data-urlencode 'start=$(date -u -d '90 days ago' +%s)000000000'"
echo ""
echo "Add to Grafana datasource:"
echo "  Name: Loki Archive"
echo "  URL: http://loki_bk:3100"

