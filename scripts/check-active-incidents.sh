#!/bin/bash
# PreToolUse hook: warn about active incidents before git commit/push
# Receives hook context as JSON on stdin (per Claude Code hooks spec)
# Outputs warning text via stdout if active incidents found, empty if clear
# Always exits 0 (warn, never block)

# Read hook input from stdin
INPUT=$(cat)

# Extract the Bash command from the hook JSON
# Uses python3 for JSON parsing (available on macOS/Linux by default)
# Falls back to jq if available
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
elif command -v python3 &>/dev/null; then
  COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)
else
  exit 0  # No JSON parser available, fail silent
fi

# Only trigger on git commit or git push commands
if [[ "$COMMAND" != *"git commit"* ]] && [[ "$COMMAND" != *"git push"* ]]; then
  exit 0
fi

# Requires ROOTLY_API_TOKEN
if [ -z "$ROOTLY_API_TOKEN" ]; then
  exit 0  # Silent if not configured
fi

# Check for active high-severity incidents
# Uses JSON:API filter syntax per Rootly REST API spec
# Configurable base URL via ROOTLY_API_URL for self-hosted instances
ROOTLY_URL="${ROOTLY_API_URL:-https://api.rootly.com}"
RESPONSE=$(curl -s \
  -H "Authorization: Bearer $ROOTLY_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  "$ROOTLY_URL/v1/incidents?filter[status]=started&filter[severity]=critical&page[size]=50" \
  --max-time 2 2>/dev/null)

if [ $? -ne 0 ]; then
  exit 0  # Silent on network failure
fi

# Count incidents from JSON:API response (data is an array)
if command -v jq &>/dev/null; then
  COUNT=$(echo "$RESPONSE" | jq '.data | length' 2>/dev/null)
elif command -v python3 &>/dev/null; then
  COUNT=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(len(data.get('data', [])))
except:
    print('0')
" 2>/dev/null)
else
  exit 0
fi

if [ "$COUNT" != "0" ] && [ "$COUNT" != "null" ] && [ -n "$COUNT" ]; then
  echo "WARNING: $COUNT active critical incident(s) detected. Run /rootly:status for details before deploying."
fi
