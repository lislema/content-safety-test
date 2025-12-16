#!/bin/bash
# Azure Content Safety - Protected Material Batch Detector (Full Output, New API Format)
#
# Processes a batch file separated by empty lines. For each block:
#   1. Prints the full Azure JSON response
#   2. Writes the full response and text block to a results file
#   3. Uses the new schema:
#          .protectedMaterialAnalysis.detected  (true/false)
#
# Environment Variables Required:
#   AZURE_CS_ENDPOINT
#   AZURE_CS_KEY
#   AZURE_CS_VERSION
#

set -euo pipefail
MAX_SIZE=2000000   # 2MB safety cap

# ------------------------------------------------------------
# Validate arguments
# ------------------------------------------------------------
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <batch_file> <results_file>"
    exit 1
fi

BATCH_FILE="$1"
RESULTS_FILE="$2"

if [[ ! -f "$BATCH_FILE" ]]; then
    echo "Error: File '$BATCH_FILE' not found"
    exit 1
fi

if [[ $(wc -c < "$BATCH_FILE") -gt $MAX_SIZE ]]; then
    echo "Error: Batch file exceeds ${MAX_SIZE} bytes."
    exit 1
fi

# ------------------------------------------------------------
# Validate environment variables
# ------------------------------------------------------------
: "${AZURE_CS_ENDPOINT:?Missing AZURE_CS_ENDPOINT}"
: "${AZURE_CS_KEY:?Missing AZURE_CS_KEY}"
: "${AZURE_CS_VERSION:?Missing AZURE_CS_VERSION}"

# Reset results file
> "$RESULTS_FILE"

echo "Processing batch: $BATCH_FILE"
echo "Storing detailed results in: $RESULTS_FILE"
echo "------------------------------------------------------------"


# ------------------------------------------------------------
# Function to process a single text block
# ------------------------------------------------------------
process_block() {
    local content="$1"
    [[ -z "$content" ]] && return 0

    # Escape text safely for JSON
    ESCAPED=$(printf "%s" "$content" | jq -Rs .)

    echo
    echo "------------------------------------------------------------"
    echo "REQUEST BLOCK:"
    printf "%s\n" "$content"
    echo "------------------------------------------------------------"
    echo "FULL RESPONSE FROM AZURE:"
    echo

    RESPONSE=$(curl --fail-with-body -s -X POST \
        "${AZURE_CS_ENDPOINT}/contentsafety/text:detectProtectedMaterial?api-version=${AZURE_CS_VERSION}" \
        -H "Ocp-Apim-Subscription-Key: ${AZURE_CS_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"text\": ${ESCAPED}}")

    # Pretty print full response
    echo "$RESPONSE" | jq .
    echo

    # ------------------------------------------------------------
    # New Azure CS Schema:
    #   protectedMaterialAnalysis.detected = true/false
    # ------------------------------------------------------------
    IS_COPY=$(printf "%s" "$RESPONSE" | jq -r '.protectedMaterialAnalysis.detected')

    if [[ "$IS_COPY" == "true" ]]; then
        STATUS="COPYRIGHTED"
        echo "[COPYRIGHTED]"
    else
        STATUS="OK"
        echo "[OK]"
    fi

    # ------------------------------------------------------------
    # Write full details to results file
    # ------------------------------------------------------------
    {
        echo "----- BLOCK START -----"
        echo "TEXT:"
        printf "%s\n" "$content"
        echo
        echo "FULL RESPONSE:"
        echo "$RESPONSE" | jq .
        echo
        echo "STATUS: $STATUS"
        echo "----- BLOCK END -----"
        echo
    } >> "$RESULTS_FILE"
}

# ------------------------------------------------------------
# Read batch file block-by-block (empty-line separated)
# ------------------------------------------------------------
BLOCK=""
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" ]]; then
        process_block "$BLOCK"
        BLOCK=""
    else
        BLOCK="${BLOCK}${line}"$'\n'
    fi
done < "$BATCH_FILE"

# Final block (if file doesn't end with blank line)
process_block "$BLOCK"

echo "------------------------------------------------------------"
echo "Batch processing complete."