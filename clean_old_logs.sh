#!/bin/bash

TARGET_DIR=${1:-/var/log}
DAYS_OLD=${2:-14}

echo "🧼   Cleaning up logs in $TARGET_DIR old than $DAYS_OLD days..."

if [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: $TARGET_DIR is not a valid directory"
    exit 1
fi

find "$TARGET_DIR" -type f -name "*.log" -mtime +"$DAYS_OLD" -exec rm -v {} \;
echo "✅   Cleanup complete!"