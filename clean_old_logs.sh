#!/bin/bash

TARGET_DIR=${1:-/var/log}
DAYS_OLD=${2:-14}

echo "🧼   Cleaning up logs in $TARGET_DIR old than $DAYS_OLD days..."
find "$TARGET_DIR" -type f -name "*.log" -mtime +"$DAYS_OLD" -exec rm -v {} \;
echo "✅   Cleanup complete!"