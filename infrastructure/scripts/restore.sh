#!/bin/bash
# NexGen Database Restore Script
# Restores PostgreSQL database from backup
# Usage: ./restore.sh <backup_file_path>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <backup_file_path>"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "WARNING: This will overwrite the current database."
read -p "Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo "Restoring from backup: $BACKUP_FILE"

if command -v docker &> /dev/null; then
    # Docker restore
    cat "$BACKUP_FILE" | docker-compose exec -T postgres psql -U "${DB_USER}" -d "${DB_NAME}"
else
    # Direct restore
    psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" < "$BACKUP_FILE"
fi

echo "Restore completed successfully."
echo "Database validation:"
echo "SELECT COUNT(*) as user_count FROM users;" | psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}"
