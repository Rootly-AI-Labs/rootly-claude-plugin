#!/bin/bash
# Optional: Register a deployment event with Rootly
# NOT wired into hooks by default. Provided as a convenience script.
#
# To enable as a post-push hook, add to your .claude/hooks.json:
# {
#   "hooks": {
#     "PostToolUse": [{
#       "matcher": "Bash",
#       "hooks": [{
#         "type": "command",
#         "command": "<plugin-root>/scripts/register-deploy.sh"
#       }]
#     }]
#   }
# }

# Read stdin (PostToolUse hook input) -- check if this was a git push
INPUT=$(cat)
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
  COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try: print(json.load(sys.stdin).get('tool_input',{}).get('command',''))
except: print('')
" 2>/dev/null)
fi

if [[ "$COMMAND" != *"git push"* ]]; then
  exit 0
fi

if [ -z "$ROOTLY_API_TOKEN" ]; then
  exit 0
fi

ROOTLY_URL="${ROOTLY_API_URL:-https://api.rootly.com}"
COMMIT_SHA=$(git rev-parse HEAD 2>/dev/null)
BRANCH=$(git branch --show-current 2>/dev/null)
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")

curl -s -X POST "$ROOTLY_URL/v1/deployments" \
  -H "Authorization: Bearer $ROOTLY_API_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d "{\"commit_sha\": \"$COMMIT_SHA\", \"branch\": \"$BRANCH\", \"repository\": \"$REPO\"}" \
  --max-time 3 2>/dev/null

exit 0
