#!/bin/bash

#######################################################
# Loki Data Backup Script
# 
# Purpose: Backup Loki data before 90-day retention deletes it
# Schedule: Run weekly or monthly via cron
#######################################################

set -e

# Configuration
CURRENT_DIR="/var/www/app/grafana"
BACKUP_DIR="${BACKUP_DIR:-/var/www/app/grafana/backups/loki}"
LOKI_DATA_DIR="/var/www/app/grafana/loki/data"
RETENTION_DAYS=90  # Keep backups for 180 days (2x Loki retention)
DATE_STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="loki-backup-${DATE_STAMP}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Loki Data Backup Script${NC}"
echo -e "${GREEN}=====================================${NC}"
echo "Date: $(date)"
echo "Backup location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo ""

# Check if Loki data directory exists
if [ ! -d "${LOKI_DATA_DIR}" ]; then
    echo -e "${RED}Error: Loki data directory not found: ${LOKI_DATA_DIR}${NC}"
    exit 1
fi

# Check disk space
echo -e "${YELLOW}Checking disk space...${NC}"
LOKI_SIZE=$(du -sh "${LOKI_DATA_DIR}" | cut -f1)
AVAILABLE_SPACE=$(df -h "${BACKUP_DIR}" | awk 'NR==2 {print $4}')
echo "Loki data size: ${LOKI_SIZE}"
echo "Available space: ${AVAILABLE_SPACE}"
echo ""

# Create backup
echo -e "${YELLOW}Creating backup...${NC}"
cd "$(dirname "${LOKI_DATA_DIR}")"

tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
    --exclude='*.tmp' \
    --exclude='compactor' \
    "$(basename "${LOKI_DATA_DIR}")"

# Verify backup
if [ -f "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" ]; then
    BACKUP_SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
    echo -e "${GREEN}✓ Backup created successfully!${NC}"
    echo "Backup size: ${BACKUP_SIZE}"
    echo "Location: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
else
    echo -e "${RED}✗ Backup failed!${NC}"
    exit 1
fi

echo ""

# Create metadata file
cat > "${BACKUP_DIR}/${BACKUP_NAME}.meta" <<EOF
Backup Date: $(date)
Loki Data Directory: ${LOKI_DATA_DIR}
Original Size: ${LOKI_SIZE}
Compressed Size: ${BACKUP_SIZE}
Hostname: $(hostname)
EOF

echo -e "${YELLOW}Cleaning old backups (older than ${RETENTION_DAYS} days)...${NC}"
find "${BACKUP_DIR}" -name "loki-backup-*.tar.gz" -mtime +${RETENTION_DAYS} -delete
find "${BACKUP_DIR}" -name "loki-backup-*.meta" -mtime +${RETENTION_DAYS} -delete

# List recent backups
echo ""
echo -e "${GREEN}Recent backups:${NC}"
ls -lh "${BACKUP_DIR}" | grep "loki-backup" | tail -5

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Backup completed successfully!${NC}"
echo -e "${GREEN}=====================================${NC}"

# Optional: Send notification (uncomment if you have ntfy or similar)
# curl -d "Loki backup completed: ${BACKUP_NAME}.tar.gz" ntfy.sh/your-topic

