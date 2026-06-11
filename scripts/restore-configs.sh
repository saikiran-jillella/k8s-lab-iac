#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <backup-directory>"
    exit 1
fi

BACKUP_DIR=$1

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Directory $BACKUP_DIR not found."
    exit 1
fi

echo "Restoring IaC configs from $BACKUP_DIR..."
cp -r "$BACKUP_DIR"/* ./
echo "Restore complete."
