#!/bin/bash

# Get the number of GPUs available
NUM_GPUS=$(nvidia-smi --list-gpus | wc -l)

# Start writing the docker-compose.yml file
cat > docker-compose-generated.yml <<EOF
version: '3.8'

services:
EOF

# Base host ports
BASE_PORT1=8000
BASE_PORT2=7860

for (( i=0; i<$NUM_GPUS; i++ ))
do
  HOST_PORT1=$((BASE_PORT1 + i))
  HOST_PORT2=$((BASE_PORT2 + i))
  SERVICE_NAME="server${i}"
  GPU_ID="${i}"
  DATA_VOLUME="./data${i}:/data"
  DATA_MODELS_VOLUME="./data-models:/data-models"
  cat >> docker-compose-generated.yml <<EOF
  ${SERVICE_NAME}:
    build:
      context: .
    env_file:
      - .env
    image: sogni/sogni-stable-diffusion-worker:latest
    restart: unless-stopped
    pull_policy: always
    ports:
      - ${HOST_PORT1}:8000
      - "\${WEBUI_PORT:-${HOST_PORT2}}:7860"
    volumes:
      - ${DATA_VOLUME}
      - ${DATA_MODELS_VOLUME}
      - ./output:/output
    stop_signal: SIGTERM
    tty: true
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['${GPU_ID}']
              capabilities: [compute, utility]
EOF
done

# Add update checker service
cat >> docker-compose-generated.yml <<EOF
  update_checker:
    image: alpine
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: >
      sh -c "
        apk add --no-cache docker-cli curl;
        while true;
        do
          sleep 3600;
          if docker compose pull | grep -q 'Downloaded newer image'; then
            echo 'New update available. Restarting services...';
            docker compose down;
            docker compose up -d;
          fi;
          docker image prune -f;
        done
      "
    restart: unless-stopped
EOF