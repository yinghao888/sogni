#!/bin/bash
set -e

while true; do
    sleep 900  # 15 minutes

    # Check if worker is running
    if ! docker compose ps | grep -q "running"; then
        echo "Worker stopped, ending update checker."
        exit 0
    fi

    # Check for updates
    if docker compose pull | grep -q "Downloaded newer image"; then
        echo "New update available. Restarting container..."
        docker compose down
        docker compose up -d --force-recreate
    fi

    # Prune unused images
    docker image prune -f >/dev/null 2>&1
done 