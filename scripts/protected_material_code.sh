#!/bin/bash
# Azure Content Safety - Protected Material Code Detection
# Detects if code matches content from public GitHub repositories
#
# Required environment variables:
#   AZURE_CS_ENDPOINT - Your Content Safety endpoint
#   AZURE_CS_KEY      - Your Content Safety API key
#   AZURE_CS_VERSION  - API version (e.g., 2024-09-01)
#
# Usage: ./protected_material_code.sh <code_file>
#    or: ./protected_material_code.sh -t "code to analyze"

set -e

# Parse arguments
CODE=""
if [ "$1" == "-t" ]; then
    CODE="$2"
elif [ -n "$1" ]; then
    if [ ! -f "$1" ]; then
        echo "Error: File '$1' not found"
        exit 1
    fi
    CODE=$(cat "$1")
else
    echo "Usage: $0 <code_file>"
    echo "   or: $0 -t \"code to analyze\""
    echo ""
    echo "Example: $0 /path/to/generated_code.py"
    echo "Example: $0 -t \"def quicksort(arr): ...\""
    exit 1
fi

# Validate environment variables
if [ -z "$AZURE_CS_ENDPOINT" ] || [ -z "$AZURE_CS_KEY" ] || [ -z "$AZURE_CS_VERSION" ]; then
    echo "Error: Missing required environment variables"
    echo "Please set: AZURE_CS_ENDPOINT, AZURE_CS_KEY, AZURE_CS_VERSION"
    exit 1
fi

# Escape code for JSON
ESCAPED_CODE=$(echo "$CODE" | jq -Rs .)

echo "Checking for protected code material..."
echo "----------------------------------------"

curl -s -X POST "${AZURE_CS_ENDPOINT}/contentsafety/text:detectProtectedMaterialForCode?api-version=${AZURE_CS_VERSION}" \
  -H "Ocp-Apim-Subscription-Key: ${AZURE_CS_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"text\": ${ESCAPED_CODE}
  }" | jq .
