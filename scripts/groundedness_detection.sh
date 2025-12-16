#!/bin/bash
# Azure Content Safety - Groundedness Detection
# Checks if LLM output is factually grounded in provided source documents
#
# Required environment variables:
#   AZURE_CS_ENDPOINT - Your Content Safety endpoint
#   AZURE_CS_KEY      - Your Content Safety API key
#   AZURE_CS_VERSION  - API version (e.g., 2024-09-01)
#
# Usage: ./groundedness_detection.sh <llm_output_file> <grounding_source_file>
#    or: ./groundedness_detection.sh -t "llm output text" -s "source document text"

set -e

# Parse arguments
LLM_OUTPUT=""
GROUNDING_SOURCE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -t)
            LLM_OUTPUT="$2"
            shift 2
            ;;
        -s)
            GROUNDING_SOURCE="$2"
            shift 2
            ;;
        *)
            if [ -z "$LLM_OUTPUT" ] && [ -f "$1" ]; then
                LLM_OUTPUT=$(cat "$1")
            elif [ -z "$GROUNDING_SOURCE" ] && [ -f "$1" ]; then
                GROUNDING_SOURCE=$(cat "$1")
            else
                echo "Error: Unknown argument or file not found: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$LLM_OUTPUT" ] || [ -z "$GROUNDING_SOURCE" ]; then
    echo "Usage: $0 <llm_output_file> <grounding_source_file>"
    echo "   or: $0 -t \"llm output\" -s \"source document\""
    echo ""
    echo "Example: $0 output.txt source.txt"
    echo "Example: $0 -t \"The meeting was on Monday\" -s \"The team met on Tuesday to discuss Q3 results\""
    exit 1
fi

# Validate environment variables
if [ -z "$AZURE_CS_ENDPOINT" ] || [ -z "$AZURE_CS_KEY" ] || [ -z "$AZURE_CS_VERSION" ]; then
    echo "Error: Missing required environment variables"
    echo "Please set: AZURE_CS_ENDPOINT, AZURE_CS_KEY, AZURE_CS_VERSION"
    exit 1
fi

# Escape text for JSON
ESCAPED_OUTPUT=$(echo "$LLM_OUTPUT" | jq -Rs .)
ESCAPED_SOURCE=$(echo "$GROUNDING_SOURCE" | jq -Rs .)

echo "Checking groundedness of LLM output..."
echo "----------------------------------------"

curl -s -X POST "${AZURE_CS_ENDPOINT}/contentsafety/text:detectGroundedness?api-version=${AZURE_CS_VERSION}" \
  -H "Ocp-Apim-Subscription-Key: ${AZURE_CS_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"domain\": \"Generic\",
    \"task\": \"QnA\",
    \"text\": ${ESCAPED_OUTPUT},
    \"groundingSources\": [${ESCAPED_SOURCE}],
    \"reasoning\": true
  }" | jq .
