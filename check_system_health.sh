#!/bin/bash

echo "📊   System Health Report - $(date)"
echo "----------------------------------------------"

echo "🧠   Memory Usage:"
free -h
echo

echo "🔥   CPU Load:"
uptime
echo

echo "💾    Disk Space:"
df -h /
echo

echo "✅  Top 5 memory-hungry processes:"
top -b -o +%MEM | head -n 12 | tail -n 6