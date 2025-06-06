#!/bin/bash

echo "🧹   Cleaning up dangling images..."
podman image prune -f

echo "🧺   Removing unused container volumes..."
podman volume prune -f

echo "🗑️   Removing stopped containers..."
podman container prune -f

echo "✅   Podman cleanup complete"