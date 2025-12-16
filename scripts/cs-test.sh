#!/bin/bash

# === Environment Variables ===
AZURE_CS_ENDPOINT="${AZURE_CS_ENDPOINT}"
AZURE_CS_KEY="${AZURE_CS_KEY}"
AZURE_CS_VERSION="${AZURE_CS_VERSION}"

INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [[ -z "$INPUT_FILE" || -z "$OUTPUT_FILE" ]]; then
  echo "Usage: ./cs-test.sh <input-file> <output-file>"
  exit 1
fi

echo "⚙ Processing batch: $INPUT_FILE"
echo "📄 Saving results to: $OUTPUT_FILE"
echo "--------------------------------------------------"

> "$OUTPUT_FILE"

GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

# Function to process a single prompt
process_prompt() {
  local prompt="$1"
  local prompt_num="$2"
  
  echo ""
  echo "[$prompt_num] ➡ Prompt: ${prompt:0:60}..."

  #################################################################
  # 1) TOXICITY CHECK
  #################################################################
  TOX_PAYLOAD=$(jq -n \
    --arg p "$prompt" \
    '{
      "text": $p,
      "categories": ["Hate","SelfHarm","Sexual","Violence"],
      "haltOnBlocklistHit": false,
      "outputType": "FourSeverityLevels"
    }'
  )

  TOX_RESPONSE=$(curl -s -X POST \
    "$AZURE_CS_ENDPOINT/contentsafety/text:analyze?api-version=$AZURE_CS_VERSION" \
    -H "Ocp-Apim-Subscription-Key: $AZURE_CS_KEY" \
    -H "Content-Type: application/json" \
    -d "$TOX_PAYLOAD"
  )

  SEVERITY=$(
    echo "$TOX_RESPONSE" | jq -r '
      if .error then
        "ERROR"
      elif (.categoriesAnalysis | type == "array") then
        ([.categoriesAnalysis[].severity] | max)
      else
        "UNKNOWN"
      end
    '
  )

  if [[ "$SEVERITY" == "0" ]]; then
    TOX_STATUS="SAFE"
  else
    TOX_STATUS="UNSAFE"
  fi

  #################################################################
  # 2) PROMPT GUARD CHECK
  #################################################################
  SHIELD_PAYLOAD=$(jq -n \
    --arg p "$prompt" \
    '{
      "userPrompt": $p
    }'
  )

  SHIELD_RESPONSE=$(curl -s -X POST \
    "$AZURE_CS_ENDPOINT/contentsafety/text:shieldPrompt?api-version=$AZURE_CS_VERSION" \
    -H "Ocp-Apim-Subscription-Key: $AZURE_CS_KEY" \
    -H "Content-Type: application/json" \
    -d "$SHIELD_PAYLOAD"
  )
  
  ATTACK=$(
    echo "$SHIELD_RESPONSE" | jq -r '
      if .error then
        "ERROR"
      elif .userPromptAnalysis.attackDetected == true then
        "true"
      elif .userPromptAnalysis.attackDetected == false then
        "false"
      else
        "UNKNOWN"
      end
    '
  )

  if [[ "$ATTACK" == "true" ]]; then
    SHIELD_STATUS="ATTACK"
  else
    SHIELD_STATUS="CLEAN"
  fi

  #################################################################
  # COMBINED COLOUR LOGIC
  #################################################################
  if [[ "$TOX_STATUS" == "SAFE" && "$SHIELD_STATUS" == "CLEAN" ]]; then
    COLOR="$GREEN"
  else
    COLOR="$RED"
  fi

  echo -e "     ↳ ${COLOR}TOX:$TOX_STATUS / SHIELD:$SHIELD_STATUS${RESET}"

  #################################################################
  # WRITE TO OUTPUT FILE
  #################################################################
  {
    echo "===== PROMPT #$prompt_num ====="
    echo "PROMPT: $prompt"
    echo "-----"
    echo "TOXICITY: $TOX_STATUS"
    echo "PROMPT_GUARD: $SHIELD_STATUS"
    echo "-----"
    echo "TOX_RESPONSE: $TOX_RESPONSE"
    echo "-----"
    echo "SHIELD_RESPONSE: $SHIELD_RESPONSE"
    echo ""
  } >> "$OUTPUT_FILE"
}

# Main processing logic
prompt_count=0
current_prompt=""

# Read file line by line and accumulate prompts
while IFS= read -r line || [[ -n "$current_prompt" ]]; do
  # If we've reached the end of file, process the last prompt if exists
  if [[ -z "$line" ]] && [[ $? -ne 0 ]]; then
    if [[ -n "$current_prompt" ]]; then
      ((prompt_count++))
      process_prompt "$current_prompt" "$prompt_count"
    fi
    break
  fi
  
  # Check if line is empty (blank line separator)
  if [[ -z "$line" ]]; then
    # Process accumulated prompt if not empty
    if [[ -n "$current_prompt" ]]; then
      ((prompt_count++))
      process_prompt "$current_prompt" "$prompt_count"
      current_prompt=""
    fi
  else
    # Add line to current prompt
    if [[ -z "$current_prompt" ]]; then
      current_prompt="$line"
    else
      current_prompt="$current_prompt
$line"
    fi
  fi
done < "$INPUT_FILE"

# Process the last prompt if file doesn't end with blank line
if [[ -n "$current_prompt" ]]; then
  ((prompt_count++))
  process_prompt "$current_prompt" "$prompt_count"
fi

echo ""
echo "--------------------------------------------------"
echo "✅ Processed $prompt_count prompts"
echo "📊 Results saved to: $OUTPUT_FILE"