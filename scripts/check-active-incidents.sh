#!/bin/bash
# PreToolUse hook: warn about active incidents before git commit/push.
# hooks/hooks.json now filters to the relevant Bash commands, so this script
# only needs to perform the incident check.

ROOTLY_TOKEN="${CLAUDE_PLUGIN_OPTION_ROOTLY_API_TOKEN:-${ROOTLY_API_TOKEN:-}}"
if [ -z "$ROOTLY_TOKEN" ]; then
  exit 0  # Silent if not configured
fi

# Check for active high-severity incidents
# Uses JSON:API filter syntax per Rootly REST API spec
# Configurable base URL via ROOTLY_API_URL for self-hosted instances
ROOTLY_URL="${ROOTLY_API_URL:-https://api.rootly.com}"
RESPONSE=$(curl -s \
  -H "Authorization: Bearer $ROOTLY_TOKEN" \
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
