#!/bin/bash
set -e

# Function to check API_KEY and NFT_TOKEN_ID
if [ ! -f .env ]; then
    touch .env
fi

source .env

validate_credentials() {
    if [ ! -z "$API_KEY" ]; then
        RESPONSE=$(curl -s -w "%{http_code}" -X POST "https://api.sogni.ai/v1/account/api-key/token" \
            -H "Content-Type: application/json" \
            -d "{\"apiKey\":\"$API_KEY\",\"tokenId\":\"$NFT_TOKEN_ID\"}")
        
        HTTP_CODE=${RESPONSE: -3}
        RESPONSE_BODY=${RESPONSE:0:-3}
        
        if [ "$HTTP_CODE" != "200" ]; then
            echo "Invalid credentials detected. Please enter new credentials."
            API_KEY=""
            NFT_TOKEN_ID=""
        fi
    fi

    if [ -z "$API_KEY" ]; then
        while true; do
            echo "API_KEY or NFT_TOKEN_ID not found in .env file."
            echo "Please go to https://nft.sogni.ai to mint a free NFT to authenticate the worker."
            echo "Once you have minted the NFT, enter the API Key from your selected NFT."
            read -p "Enter your API Key: " API_KEY
            read -p "Enter your NFT Token ID: " NFT_TOKEN_ID

            RESPONSE=$(curl -s -w "%{http_code}" -X POST "https://api.sogni.ai/v1/account/api-key/token" \
                -H "Content-Type: application/json" \
                -d "{\"apiKey\":\"$API_KEY\",\"tokenId\":\"$NFT_TOKEN_ID\"}")
            
            HTTP_CODE=${RESPONSE: -3}
            RESPONSE_BODY=${RESPONSE:0:-3}
            
            if [ "$HTTP_CODE" == "200" ]; then
                break
            else
                echo "The combination of API Key and NFT Token ID is invalid. Please try again."
            fi
        done

        # Create new .env with existing non-credential settings and new credentials
        TEMP_ENV=$(mktemp)
        if [ -f .env ]; then
            grep -v "^API_KEY=\|^NFT_TOKEN_ID=" .env > "$TEMP_ENV"
        fi
        echo "API_KEY=$API_KEY" >> "$TEMP_ENV"
        echo "NFT_TOKEN_ID=$NFT_TOKEN_ID" >> "$TEMP_ENV"
        mv "$TEMP_ENV" .env

        echo "Validation successful! API Key and NFT Token ID saved to .env file."
    fi
}

validate_credentials

# Check for updates before starting
if docker compose pull | grep -q "Downloaded newer image"; then
    echo "New update available. Restarting container..."
    docker compose down
fi

docker compose up -d

if [ $? -ne 0 ]; then
    echo "An error occurred while starting Sogni Fast Worker."
    exit 1
fi

echo "Sogni Fast Worker started as a background process."
echo "Monitor your worker at: https://nft.sogni.ai/analytics (it may take several minutes to appear)"
echo "Stop your worker by: Running ./worker-stop.sh"

# Start the update checker in background
nohup ./worker-update-checker.sh > update-checker.log 2>&1 &
exit 0