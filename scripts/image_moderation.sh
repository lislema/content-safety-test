#!/bin/bash
# Azure Content Safety - Image Moderation
# Analyzes images for harmful content (hate, violence, sexual, self-harm)
#
# Required environment variables:
#   AZURE_CS_ENDPOINT - Your Content Safety endpoint
#   AZURE_CS_KEY      - Your Content Safety API key
#   AZURE_CS_VERSION  - API version (e.g., 2024-09-01)
#
# Usage: ./image_moderation.sh <image_file>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <image_file>"
    echo "Example: $0 /path/to/image.jpg"
    exit 1
fi

IMAGE_FILE="$1"

if [ ! -f "$IMAGE_FILE" ]; then
    echo "Error: File '$IMAGE_FILE' not found"
    exit 1
fi

# Validate environment variables
if [ -z "$AZURE_CS_ENDPOINT" ] || [ -z "$AZURE_CS_KEY" ] || [ -z "$AZURE_CS_VERSION" ]; then
    echo "Error: Missing required environment variables"
    echo "Please set: AZURE_CS_ENDPOINT, AZURE_CS_KEY, AZURE_CS_VERSION"
    exit 1
fi

# Convert image to base64
BASE64_IMAGE=$(base64 -w 0 "$IMAGE_FILE" 2>/dev/null || base64 -i "$IMAGE_FILE")

echo "Analyzing image: $IMAGE_FILE"
echo "----------------------------------------"

curl -s -X POST "${AZURE_CS_ENDPOINT}/contentsafety/image:analyze?api-version=${AZURE_CS_VERSION}" \
  -H "Ocp-Apim-Subscription-Key: ${AZURE_CS_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"image\": {
      \"content\": \"${BASE64_IMAGE}\"
    },
    \"categories\": [\"Hate\", \"Violence\", \"Sexual\", \"SelfHarm\"]
  }" | jq .
