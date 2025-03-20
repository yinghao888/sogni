#!/bin/bash

check_system_requirements() {
    # Check for Nvidia 4090 or 5090 GPU
    if command -v nvidia-smi &> /dev/null; then
        GPU_MODEL=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null || echo "UNKNOWN")
    else
        echo "NVIDIA drivers not found. Please install NVIDIA drivers and try again."
        echo "This worker requires an NVIDIA GPU."
        exit 1
    fi
    if [[ "$GPU_MODEL" != *"RTX 5090"* ]] && [[ "$GPU_MODEL" != *"RTX 5080"* ]] && [[ "$GPU_MODEL" != *"RTX 5070 Ti"* ]] && [[ "$GPU_MODEL" != *"RTX 4090"* ]] && [[ "$GPU_MODEL" != *"RTX 4080"* ]] && [[ "$GPU_MODEL" != *"RTX 4070 Ti Super"* ]] && [[ "$GPU_MODEL" != *"RTX 3090"* ]] && [[ "$GPU_MODEL" != *"RTX 6000"* ]] && [[ "$GPU_MODEL" != *"RTX A6000"* ]] && [[ "$GPU_MODEL" != *"H100"* ]] && [[ "$GPU_MODEL" != *"A100"* ]]; then
        echo "Running a Sogni Fast Worker currently requires one of the following NVIDIA GPUs:"
        echo "- RTX 5090"
        echo "- RTX 5080"
        echo "- RTX 5070 Ti"
        echo "- RTX 4090"
        echo "- RTX 4080"
        echo "- RTX 4070 Ti Super"
        echo "- RTX 3090"
        echo "- RTX 6000"
        echo "- RTX A6000"
        echo "- H100"
        echo "- A100"
        echo "Detected GPU: $GPU_MODEL"
        exit 1
    fi
    echo "Detected GPU: $GPU_MODEL"

    # Check for at least 64GB of RAM
    if [[ "$(uname)" == "Darwin" ]]; then
        TOTAL_RAM=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))
    else
        TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    fi
    if [ "$TOTAL_RAM" -lt 48 ]; then
        echo "Sogni Fast Worker requires at least 48GB of RAM."
        echo "Detected RAM: ${TOTAL_RAM}GB"
        exit 1
    fi

    # Check for at least 30GB of free disk space
    if [[ "$(uname)" == "Darwin" ]]; then
        FREE_DISK_GB=$(df -g / | tail -1 | awk '{print $4}')
    else
        FREE_DISK_GB=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    fi
    if [ "$FREE_DISK_GB" -lt 30 ]; then
        echo "This install requires at least 30GB of free disk space."
        echo "Detected free disk space: ${FREE_DISK_GB}GB"
        exit 1
    fi
}

# Call the function at the top of the script
check_system_requirements

echo "Select the type of Sogni Fast Worker you want to run (you can run this installer again later to change your choice):"
echo "1) Sogni Flux Worker (17.29GB)"
echo "2) Sogni Stable Diffusion Worker (16.45GB)"
read -p "Enter your choice (1 or 2): " WORKER_CHOICE

if [ "$WORKER_CHOICE" == "1" ]; then
    WORKER_IMAGE="sogni/sogni-flux-worker:latest"
elif [ "$WORKER_CHOICE" == "2" ]; then
    WORKER_IMAGE="sogni/sogni-stable-diffusion-worker:latest"

    # handle .env configuration
    if [ ! -f .env ]; then
        touch .env
    fi

    # Create temporary file
    TEMP_ENV=$(mktemp)

    # Copy existing non-credential settings
    if [ -f .env ]; then
        grep -v "^MAX_MODEL_FOLDER_SIZE_GB=\|^AUTO_DOWNLOAD_TO_MIN_MODEL_COUNT=" .env > "$TEMP_ENV"
    fi

    # Add default values
    echo "MAX_MODEL_FOLDER_SIZE_GB=999" >> "$TEMP_ENV"
    echo "AUTO_DOWNLOAD_TO_MIN_MODEL_COUNT=9999" >> "$TEMP_ENV"

    echo "Current environment variables for Stable Diffusion Worker:"
    echo "MAX_MODEL_FOLDER_SIZE_GB=999"
    echo "AUTO_DOWNLOAD_TO_MIN_MODEL_COUNT=9999"
    read -p "Do you want to change these values? (Y/N): " CHANGE_ENV_VARS

    if [[ "$CHANGE_ENV_VARS" =~ ^[Yy]$ ]]; then
        read -p "Enter MAX_MODEL_FOLDER_SIZE_GB (default 999): " MAX_MODEL_SIZE
        read -p "Enter AUTO_DOWNLOAD_TO_MIN_MODEL_COUNT (default 9999): " AUTO_DOWNLOAD_COUNT

        # Use default values if empty
        MAX_MODEL_SIZE=${MAX_MODEL_SIZE:-999}
        AUTO_DOWNLOAD_COUNT=${AUTO_DOWNLOAD_COUNT:-9999}

        # Update values in temp file
        sed -i '/MAX_MODEL_FOLDER_SIZE_GB=/d' "$TEMP_ENV"
        sed -i '/AUTO_DOWNLOAD_TO_MIN_MODEL_COUNT=/d' "$TEMP_ENV"
        echo "MAX_MODEL_FOLDER_SIZE_GB=$MAX_MODEL_SIZE" >> "$TEMP_ENV"
        echo "AUTO_DOWNLOAD_TO_MIN_MODEL_COUNT=$AUTO_DOWNLOAD_COUNT" >> "$TEMP_ENV"
    fi

    # Replace original .env with temp file
    mv "$TEMP_ENV" .env
else
    echo "Invalid choice. Exiting installer."
    exit 1
fi

# Update docker-compose.yaml with selected image
sed -i "s|^\(\s*image:\s*\).*|\1${WORKER_IMAGE}|" docker-compose.yaml

echo "Docker image updated to ${WORKER_IMAGE}"

set -e

# Step 1: Check if Docker is installed
echo "Checking if Docker is installed..."
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed."
    echo "Please install Docker and then run this script again."
    echo "Visit https://docs.docker.com/engine/install/ubuntu/ for instructions."
    exit 1
fi

# Step 2: Check if Docker Engine is running
echo "Checking if Docker Engine is running..."
if [[ "$(uname)" == "Darwin" ]]; then
    if ! docker info &>/dev/null; then
        echo "Docker Engine is not running. Please start Docker Desktop."
        exit 1
    fi
else
    if ! systemctl is-active --quiet docker; then
        echo "Docker Engine is not running. Starting Docker..."
        sudo systemctl start docker
        # Wait a few seconds for Docker to start
        sleep 10
        if ! systemctl is-active --quiet docker; then
            echo "Docker failed to start. Please check the Docker service and try again."
            exit 1
        fi
    fi
fi

echo "Docker Engine is running!"
echo

# Configure Docker to start on boot
echo "We recommend configuring Docker to automatically start with the computer."
read -p "Would you like to enable Docker to start on boot? (Y/N): " ENABLE_DOCKER_STARTUP
if [[ "$ENABLE_DOCKER_STARTUP" =~ ^[Yy]$ ]]; then
    echo "Enabling Docker to start on boot..."
    sudo systemctl enable docker
    echo "Docker will now start automatically when the system boots."
fi
echo

# Prompt to disable sleep mode
echo "Would you like to disable sleep mode while the service is running? (Y/N)"
read -p "(This requires administrative privileges): " DISABLE_SLEEP
if [[ "$DISABLE_SLEEP" =~ ^[Yy]$ ]]; then
    echo "Disabling sleep mode..."
    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
    echo "Sleep modes have been disabled. You can re-enable them by running:"
    echo "sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target"
fi
echo

echo "Success! Sogni Fast Worker is configured and ready to run!"
echo "You can run this installer again anytime to change settings."
echo
echo "To START: Run ./worker-start.sh"
echo "To STOP:  Run ./worker-stop.sh"
echo
exit 0
