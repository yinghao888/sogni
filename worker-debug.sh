#!/bin/bash
echo "Fetching Sogni Fast Worker logs..."

# Get the container ID for the Sogni worker
CONTAINER_ID=$(docker compose ps -q)

if [ -z "$CONTAINER_ID" ]; then
    echo "No running Sogni Fast Worker found."
    echo "Please make sure the worker is running by executing ./worker-start.sh"
    echo "You can also check your worker status at: https://nft.sogni.ai/analytics"
    exit 1
fi

echo "Found running worker container. Displaying logs (Ctrl+C to exit)..."
echo "You can also monitor your worker status at: https://nft.sogni.ai/analytics"
echo "--------------------------------------------------------------------"

# Follow the logs
docker logs -f $CONTAINER_ID 