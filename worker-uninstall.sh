#!/bin/bash

echo "Uninstalling Sogni Fast Worker..."

# Check if Docker is running
echo "Checking Docker status..."
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Please start Docker and try again."
    read -p "Press Enter to continue..."
    exit 1
fi

# Stop running containers
echo "Stopping Sogni containers..."
if docker compose down 2>/dev/null; then
    echo "Containers stopped successfully."
else
    echo "No active Sogni containers found."
fi

# Remove all Sogni Docker images
echo "Removing Sogni Docker images..."
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(sogni/|/sogni)" | grep -q .; then
    docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(sogni/|/sogni)" | xargs -r docker rmi -f
    echo "Removed all Sogni images"
fi

# Remove dangling images
echo "Cleaning up dangling images..."
docker image prune -f

echo
echo "Uninstallation complete! The following actions were performed:"
echo "- Stopped all Sogni Docker containers"
echo "- Removed all Sogni Docker images"
echo
echo "Note: Configuration files (.env and docker-compose.yaml) were preserved."
echo "You may now delete the Sogni Fast Worker folder if you wish. This will clear large model cache files if you need the space."
echo "You may also uninstall Docker Desktop if you no longer need it."
echo "Or you can re-run ./worker-install.sh to start the worker again at any time."
echo
echo "If you have feedback you can reach one of our helpful humans at app@sogni.ai"
