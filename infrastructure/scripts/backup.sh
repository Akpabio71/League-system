#!/bin/bash
# NexGen Database Backup Script
# Backs up PostgreSQL database to S3
# Usage: ./backup.sh [staging|production]

set -e

ENVIRONMENT=${1:-local}
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="nexgen_backup_${ENVIRONMENT}_${BACKUP_DATE}.sql"
BACKUP_DIR="${BACKUP_STORAGE_PATH:-.}/backups"

echo "Starting backup for ${ENVIRONMENT}..."

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Perform backup
if [ "$ENVIRONMENT" = "local" ]; then
    docker-compose exec -T postgres pg_dump \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        --verbose \
        --file="/backups/${BACKUP_FILE}"
    echo "Local backup completed: ${BACKUP_DIR}/${BACKUP_FILE}"
else
    # Production backup to S3
    pg_dump \
        -h "${DB_HOST}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        --verbose | \
    aws s3 cp - "s3://${S3_BUCKET_NAME}/backups/${BACKUP_FILE}" \
        --region "${S3_REGION}"
    echo "Cloud backup completed: s3://${S3_BUCKET_NAME}/backups/${BACKUP_FILE}"
fi

# Cleanup old backups (keep last 30 days)
echo "Cleaning up backups older than 30 days..."
find "$BACKUP_DIR" -name "nexgen_backup_*.sql" -mtime +30 -delete

echo "Backup completed successfully."
