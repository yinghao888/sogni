#!/bin/bash
echo "Stopping Sogni Fast Worker..."

# Stop the update checker if it's running
pkill -f "worker-update-checker.sh" >/dev/null 2>&1

docker compose down 2>&1
if [ $? -ne 0 ]; then
    echo "An error occurred while stopping Sogni Docker Worker."
    exit 1
fi

echo "Sogni Fast Worker stopped!"
