#!/bin/bash
# Database Backup Script for American Authorship Database
# This script creates automated backups of the PostgreSQL database
# with rotation and compression

# CONFIGURATION
BACKUP_DIR="${BACKUP_DIR:-./backups}"
DB_NAME="${DB_NAME:-american_authorship}"
DB_USER="${DB_USER:-authorship_admin}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"  # Keep backups for 30 days
MAX_BACKUPS="${MAX_BACKUPS:-10}"  # Keep maximum 10 recent backups

# Timestamp for backup filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/american_authorship_${TIMESTAMP}.sql"
COMPRESSED_FILE="${BACKUP_FILE}.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo -e "${GREEN}=== American Authorship Database Backup ===${NC}"
echo "Timestamp: $(date)"
echo "Database: $DB_NAME"
echo "Host: $DB_HOST"
echo "Backup file: $COMPRESSED_FILE"
echo ""

# Check if PostgreSQL is running
if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" &>/dev/null; then
    echo -e "${RED}ERROR: Cannot connect to PostgreSQL${NC}"
    echo "Please ensure PostgreSQL is running and connection settings are correct"
    exit 1
fi

# Perform backup
echo -e "${YELLOW}Creating backup...${NC}"
if pg_dump \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -F plain \
    --clean \
    --if-exists \
    --create \
    --encoding=UTF8 \
    "$DB_NAME" > "$BACKUP_FILE" 2>&1; then

    echo -e "${GREEN}✓ Backup created successfully${NC}"

    # Compress backup
    echo -e "${YELLOW}Compressing backup...${NC}"
    if gzip -9 "$BACKUP_FILE"; then
        echo -e "${GREEN}✓ Backup compressed${NC}"

        # Calculate backup size
        BACKUP_SIZE=$(du -h "$COMPRESSED_FILE" | cut -f1)
        echo "Backup size: $BACKUP_SIZE"
    else
        echo -e "${RED}✗ Compression failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Backup failed${NC}"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Cleanup old backups
echo -e "${YELLOW}Cleaning up old backups...${NC}"

# Remove backups older than RETENTION_DAYS
find "$BACKUP_DIR" -name "american_authorship_*.sql.gz" -type f -mtime +"$RETENTION_DAYS" -delete

# Keep only MAX_BACKUPS most recent backups
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/american_authorship_*.sql.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
    DELETE_COUNT=$((BACKUP_COUNT - MAX_BACKUPS))
    ls -1t "$BACKUP_DIR"/american_authorship_*.sql.gz | tail -n "$DELETE_COUNT" | xargs rm -f
    echo -e "${GREEN}✓ Removed $DELETE_COUNT old backup(s)${NC}"
fi

# Show remaining backups
REMAINING=$(ls -1 "$BACKUP_DIR"/american_authorship_*.sql.gz 2>/dev/null | wc -l)
echo -e "${GREEN}Total backups: $REMAINING${NC}"

# Create symlink to latest backup
ln -sf "$(basename "$COMPRESSED_FILE")" "$BACKUP_DIR/latest.sql.gz"

echo ""
echo -e "${GREEN}=== Backup Complete ===${NC}"
echo "Latest backup: $COMPRESSED_FILE"
echo ""

# Optional: Upload to cloud storage (uncomment and configure as needed)
# if command -v aws &> /dev/null; then
#     echo "Uploading to S3..."
#     aws s3 cp "$COMPRESSED_FILE" "s3://your-bucket/database-backups/"
# fi

exit 0
