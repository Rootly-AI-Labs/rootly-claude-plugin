#!/bin/bash
# SessionStart hook: check if a Rootly API token is configured for hook scripts.
# MCP commands use OAuth2 and don't need this token.
# The token is only needed for hook scripts (incident warnings on commit/push).

ROOTLY_TOKEN="${CLAUDE_PLUGIN_OPTION_ROOTLY_API_TOKEN:-${ROOTLY_API_TOKEN:-}}"
ROOTLY_URL="${ROOTLY_API_URL:-https://api.rootly.com}"

if [ -z "$ROOTLY_TOKEN" ]; then
  echo "Rootly plugin: No API token found. MCP commands use OAuth2 (no token needed). For commit/push incident warnings, configure an API token in plugin settings."
  exit 0
fi

# Quick validation ping (with strict timeout)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $ROOTLY_TOKEN" \
  "$ROOTLY_URL/v1/users/me" \
  --max-time 2 2>/dev/null)

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
  echo "Rootly plugin: API token appears invalid (HTTP $HTTP_CODE). Update the plugin config and run /rootly:setup again."
fi

exit 0
