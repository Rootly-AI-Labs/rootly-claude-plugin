#!/bin/bash
# SessionStart hook: check if ROOTLY_API_TOKEN is configured
# Outputs setup guidance if missing, silent if present

if [ -z "$ROOTLY_API_TOKEN" ]; then
  echo "Rootly plugin: No API token found. Run /rootly:setup to configure."
  exit 0
fi

# Quick validation ping (with strict timeout)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $ROOTLY_API_TOKEN" \
  "${ROOTLY_API_URL:-https://api.rootly.com}/v1/users/me" \
  --max-time 2 2>/dev/null)

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
  echo "Rootly plugin: API token appears invalid (HTTP $HTTP_CODE). Run /rootly:setup to reconfigure."
fi

exit 0
