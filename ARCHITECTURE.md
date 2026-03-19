# Rootly Claude Plugin - Architecture Plan

## Overview

A Claude Code plugin that wraps Rootly's existing MCP server (101 tools) into opinionated, developer-friendly workflows for the full incident lifecycle: prevent, respond, learn. The plugin is primarily prompt engineering and workflow orchestration. All incident data flows through the Rootly MCP server at `mcp.rootly.com`. Hook scripts make minimal direct REST API calls as an intentional trade-off for speed (documented below).

---

## Directory Structure

```
claude-rootly-plugin/
├── .claude-plugin/
│   ├── plugin.json                          # Plugin manifest (required)
│   └── marketplace.json                     # Marketplace listing (for self-hosted marketplace)
├── .mcp.json                                # Rootly MCP server reference
├── skills/
│   ├── setup/
│   │   └── SKILL.md                         # /rootly:setup (first-run experience)
│   ├── deploy-check/
│   │   └── SKILL.md                         # /rootly:deploy-check
│   ├── respond/
│   │   └── SKILL.md                         # /rootly:respond
│   ├── oncall/
│   │   └── SKILL.md                         # /rootly:oncall
│   ├── retro/
│   │   └── SKILL.md                         # /rootly:retro
│   ├── status/
│   │   └── SKILL.md                         # /rootly:status
│   └── ask/
│       └── SKILL.md                         # /rootly:ask
├── agents/
│   ├── incident-investigator.md             # Deep incident investigation agent
│   ├── deploy-guardian.md                   # Deployment risk analysis agent
│   └── retro-analyst.md                     # Post-incident pattern analysis agent
├── hooks/
│   └── hooks.json                           # SessionStart + PreToolUse hooks
├── scripts/
│   ├── check-active-incidents.sh            # Lightweight pre-commit check
│   ├── validate-token.sh                    # SessionStart token validation
│   └── register-deploy.sh                   # Optional: post-push deployment registration
├── README.md
├── LICENSE
└── CHANGELOG.md
```

---

## Component Specifications

### 1. Plugin Manifest (`.claude-plugin/plugin.json`)

```json
{
  "name": "rootly",
  "version": "1.0.0",
  "description": "Full-lifecycle incident management from your IDE. Prevent incidents before deploy, respond in real-time, and learn from post-mortems -- powered by Rootly.",
  "author": {
    "name": "Rootly AI Labs",
    "email": "support@rootly.com",
    "url": "https://rootly.com"
  },
  "homepage": "https://rootly.com/integrations/claude",
  "repository": "https://github.com/Rootly-AI-Labs/claude-rootly-plugin",
  "license": "Apache-2.0",
  "keywords": [
    "incident-management",
    "on-call",
    "sre",
    "devops",
    "deploy-safety",
    "retrospectives",
    "rootly"
  ]
}
```

### 2. Marketplace Entry (`.claude-plugin/marketplace.json`)

This file lives inside `.claude-plugin/` so the repo itself can serve as a marketplace. Users add it via:
```
/plugin marketplace add Rootly-AI-Labs/claude-rootly-plugin
```

```json
{
  "name": "rootly-plugins",
  "owner": {
    "name": "Rootly AI Labs",
    "email": "support@rootly.com"
  },
  "metadata": {
    "description": "Official Rootly plugins for Claude Code",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "rootly",
      "source": "./",
      "description": "Full-lifecycle incident management: deploy safety, incident response, on-call management, and retrospectives.",
      "version": "1.0.0",
      "author": {
        "name": "Rootly AI Labs"
      },
      "license": "Apache-2.0",
      "keywords": ["incident-management", "on-call", "sre", "devops", "rootly"]
    }
  ]
}
```

### 3. MCP Server Reference (`.mcp.json`)

Points to Rootly's hosted MCP server. No bundled server binary.

```json
{
  "mcpServers": {
    "rootly": {
      "type": "http",
      "url": "https://mcp.rootly.com/mcp",
      "headers": {
        "Authorization": "Bearer ${ROOTLY_API_TOKEN}"
      }
    }
  }
}
```

**Authentication**: Users set `ROOTLY_API_TOKEN` as an environment variable (in shell profile or via `~/.claude/settings.json` under `"env"`). Claude Code resolves `${VAR}` syntax in HTTP transport headers, including arbitrary env vars -- this is confirmed in the official docs. The `${VAR:-default}` fallback syntax is also supported.

**Alternative configurations** (documented in README for advanced users):
- **CLI setup**: `claude mcp add rootly --transport http https://mcp.rootly.com/mcp --header "Authorization: Bearer YOUR_TOKEN"`
- **Local MCP server** (for self-hosted Rootly or offline use):
  ```json
  {
    "mcpServers": {
      "rootly": {
        "command": "uvx",
        "args": ["--from", "rootly-mcp-server", "rootly-mcp-server"],
        "env": {
          "ROOTLY_API_TOKEN": "<YOUR_TOKEN>"
        }
      }
    }
  }
  ```

### 4. Skills (Slash Commands)

Each skill is a `skills/<name>/SKILL.md` file with YAML frontmatter.

---

#### 4a. `/rootly:setup` -- First-Run Experience

```
skills/setup/SKILL.md
```

**Purpose**: Guide new users through plugin configuration.

**Frontmatter**:
```yaml
name: setup
description: Set up the Rootly plugin. Checks for API token, verifies MCP server connection, and guides through configuration. Run this after installing the plugin.
argument-hint: []
allowed-tools: Bash, mcp__rootly__*
```

**Workflow**:
1. Check if `ROOTLY_API_TOKEN` env var is set
2. If not set, provide step-by-step instructions:
   - Where to get an API token in the Rootly dashboard (Settings > API Keys)
   - How to set the env var (`export ROOTLY_API_TOKEN=...` in shell profile)
   - How to verify the connection
3. If set, test the MCP connection by calling `get_server_version` (lightweight read-only tool)
4. Confirm success or diagnose failure (invalid token, network issue, etc.)
5. Check for `.claude/rootly-config.json` -- if missing, help create one by listing Rootly services and letting the user pick which map to this repo
6. Show quick-start guide for available commands

---

#### 4b. `/rootly:deploy-check` -- Pre-Deploy Intelligence

```
skills/deploy-check/SKILL.md
```

**Purpose**: Evaluate deployment safety before pushing code.

**Frontmatter**:
```yaml
name: deploy-check
description: Evaluate deployment risk by analyzing code changes against incident history, active incidents, and on-call readiness. Use when a developer is about to deploy, push, or merge code.
argument-hint: [branch-name]
allowed-tools: Bash, mcp__rootly__*
```

**Workflow** (encoded in SKILL.md prompt):
1. Get current git diff via dynamic context injection (`!`git diff --stat HEAD``)
2. Identify affected services using the resolution chain:
   - Read `.claude/rootly-config.json` if present
   - Otherwise match git repo name against Rootly services via `search_incidents`
   - Fall back to asking the user
3. Call `search_incidents` for those services (last 90 days)
4. Call `find_related_incidents` with the change summary
5. Check for active P1/P2 incidents on affected services
6. Call `get_oncall_handoff_summary` to check on-call availability
7. Handle edge case: if git diff is empty, report "no changes to evaluate" and exit
8. Synthesize into a structured deployment brief:
   - Risk level (low/medium/high/critical)
   - Active incidents on affected services
   - On-call status and availability
   - Similar past incidents and what resolved them
   - Go/no-go recommendation with reasoning

**Dynamic context** (injected before Claude sees the prompt):
```markdown
## Current changes
!`git diff --stat HEAD`

## Current branch
!`git branch --show-current`

## Recent commits
!`git log --oneline -5`
```

---

#### 4c. `/rootly:respond` -- Incident Response

```
skills/respond/SKILL.md
```

**Purpose**: Investigate and coordinate incident response from the IDE.

**Frontmatter**:
```yaml
name: respond
description: Investigate and respond to a production incident. Pulls context, finds similar past incidents, suggests solutions, and enables coordination -- all from the terminal. Use when paged or when an incident needs attention.
argument-hint: [incident-id]
context: fork
allowed-tools: Bash, mcp__rootly__*
```

**Workflow**:
1. Accept incident ID from `$ARGUMENTS`. If not provided, call `search_incidents` filtered to active and list for the user to choose.
2. If many active incidents, filter by severity (critical/high first) with pagination.
3. Call `getIncident` for full incident context
4. Call `get_alert_by_short_id` or search alerts via OpenAPI tools for alert details
5. Call `find_related_incidents` for historical matches
6. Call `suggest_solutions` for resolution recommendations
7. Call `get_oncall_handoff_summary` for team status
8. Present structured response brief:
   - Incident summary and timeline
   - Related historical incidents (with confidence scores)
   - Suggested solutions (with confidence scores and sources)
   - Current responders and on-call team
   - Available actions (update severity, add responder, post status update)
9. Human-in-the-loop: ALWAYS present write operations as recommendations. Require explicit user confirmation before executing any mutation (`updateIncident`, escalate, add responder, etc.)

**Error handling in prompt**:
- If MCP tools return errors, report the specific error and suggest manual steps
- If `find_related_incidents` returns low confidence (< 0.3), flag and suggest manual investigation
- If no incidents are active, report "no active incidents" cleanly

**Note**: `context: fork` runs this in an isolated subagent to avoid polluting the main coding context with incident data.

---

#### 4d. `/rootly:oncall` -- On-Call Dashboard

```
skills/oncall/SKILL.md
```

**Purpose**: Quick view of on-call status and health metrics.

**Frontmatter**:
```yaml
name: oncall
description: Show current on-call status, shift metrics, and health indicators for your team. Use to check who's on-call, handoff context, or on-call workload.
argument-hint: [team-name]
allowed-tools: mcp__rootly__*
```

**Workflow**:
1. Call `get_oncall_handoff_summary` for current/next on-call
2. Call `get_oncall_shift_metrics` for workload data
3. Call `check_oncall_health_risk` for fatigue indicators
4. Present compact dashboard:
   - Current on-call (name, since when, incidents handled this shift)
   - Next on-call (name, handoff time)
   - Shift health (hours worked, fatigue risk)
   - Recent incidents during this shift

---

#### 4e. `/rootly:retro` -- Retrospective Generator

```
skills/retro/SKILL.md
```

**Purpose**: Generate a structured post-incident retrospective.

**Frontmatter**:
```yaml
name: retro
description: Generate a structured post-incident retrospective from incident data. Use after an incident is resolved to document what happened, why, and action items.
argument-hint: [incident-id]
allowed-tools: mcp__rootly__*
```

**Workflow**:
1. Accept incident ID from `$ARGUMENTS`
2. Call `getIncident` for full incident record
3. Check incident status -- if still `started`, warn user that retro is typically done post-resolution and ask to confirm
4. Call `get_alert_by_short_id` or alert search tools for alert timeline
5. Call `find_related_incidents` for pattern context
6. Generate structured retrospective:
   - Summary (1-2 sentences)
   - Impact (duration, affected users/services, severity)
   - Timeline (key events from alert data)
   - Root cause analysis
   - Contributing factors
   - What went well
   - What could be improved
   - Action items (with owners if identifiable)
   - Pattern note (if similar incidents recur -- "This is the Nth incident of this type in the last 90 days")
7. Output as markdown to terminal (copy-pasteable)

---

#### 4f. `/rootly:status` -- Service Health Overview

```
skills/status/SKILL.md
```

**Purpose**: Quick service health dashboard.

**Frontmatter**:
```yaml
name: status
description: Show a compact service health overview including active incidents by severity. Use for a quick health check of your services.
argument-hint: [service-name]
allowed-tools: mcp__rootly__*
```

**Workflow**:
1. Call `search_incidents` filtered to active (`started`) status
2. Group by service and severity
3. Present compact table:
   - Services with active incidents
   - Severity breakdown (critical/high/medium/low)
   - Time-in-incident for each

---

#### 4g. `/rootly:ask` -- Natural Language Query

```
skills/ask/SKILL.md
```

**Purpose**: Free-form questions against incident data.

**Frontmatter**:
```yaml
name: ask
description: Ask natural language questions about incidents, on-call, services, and reliability data. Translates your question into Rootly API calls and returns structured answers.
argument-hint: [your question]
allowed-tools: mcp__rootly__*
```

**Workflow**:
1. Parse the natural language question from `$ARGUMENTS`
2. First, call `list_endpoints` to discover available Rootly MCP tools
3. Select the most appropriate tools for the question
4. Execute queries (may require multiple calls)
5. Synthesize and present answer with supporting data
6. If the question can't be answered with available tools, say so explicitly rather than hallucinating

---

### 5. Agents

Agent frontmatter uses comma-separated string format for `tools` field (matching documented examples).

#### 5a. `incident-investigator` -- Deep Investigation Agent

```
agents/incident-investigator.md
```

**Frontmatter**:
```yaml
name: incident-investigator
description: >
  Use this agent when the user needs deep investigation of a production incident,
  wants to understand root cause, or needs a thorough analysis that goes beyond
  the initial /rootly:respond summary.

  Examples:

  <example>
  Context: User wants deeper investigation after initial triage
  user: "Dig deeper into INC-4521, the initial suggestions didn't help"
  assistant: "I'll launch the incident-investigator for a thorough analysis."
  <commentary>
  User needs deeper investigation beyond surface-level triage.
  </commentary>
  </example>

  <example>
  Context: User wants to understand root cause of a complex incident
  user: "What's the root cause of this outage? Walk me through everything."
  assistant: "I'll use the incident-investigator to trace the full causation chain."
  <commentary>
  Complex root cause analysis requiring multi-step investigation.
  </commentary>
  </example>

model: sonnet
tools: Read, Grep, Glob, Bash, mcp__rootly__*
```

**System prompt responsibilities**:
1. Gather all alerts, responder actions, and timeline events via `getIncident` and alert tools
2. Search codebase for recent git commits in affected service directories (`git log --since="3 days ago" -- <paths>`)
3. Find top 5 similar historical incidents via `find_related_incidents`
4. Extract resolution patterns from each similar incident
5. Build root cause hypothesis tree with evidence chains
6. Rank hypotheses by confidence
7. Recommend specific remediation steps
8. Output structured investigation report

---

#### 5b. `deploy-guardian` -- Deployment Safety Agent

```
agents/deploy-guardian.md
```

**Frontmatter**:
```yaml
name: deploy-guardian
description: >
  Use this agent for comprehensive deployment safety analysis that goes beyond
  /rootly:deploy-check. Evaluates multi-service blast radius, downstream
  dependency impact, and cross-team coordination needs.

  Examples:

  <example>
  Context: Complex multi-service deployment
  user: "Is it safe to deploy all these changes across auth, payments, and billing?"
  assistant: "I'll launch the deploy-guardian for a full blast radius analysis."
  <commentary>
  Multi-service deployment needs comprehensive risk evaluation beyond simple deploy-check.
  </commentary>
  </example>

  <example>
  Context: Deploying during an incident
  user: "Can I still push this fix even though there's an active incident?"
  assistant: "I'll use the deploy-guardian to evaluate whether this deploy is safe given the active incident."
  <commentary>
  Deployment during active incident needs careful safety analysis.
  </commentary>
  </example>

model: sonnet
tools: Read, Grep, Glob, Bash, mcp__rootly__*
```

**System prompt responsibilities** (differentiated from `/rootly:deploy-check`):
1. Analyze full diff and identify all affected services
2. **Map downstream service dependencies** (what else breaks if this service has issues)
3. Check active incidents, deployment freezes, on-call gaps
4. **Evaluate blast radius across dependent services** (not just the changed service)
5. Cross-reference with incident history for ALL affected services (direct + downstream)
6. Assess on-call readiness and fatigue for all impacted teams
7. **Identify cross-team coordination needs** (do other teams need to be notified?)
8. Produce go/no-go recommendation with full reasoning and a coordination checklist

---

#### 5c. `retro-analyst` -- Pattern Analysis Agent

```
agents/retro-analyst.md
```

**Frontmatter**:
```yaml
name: retro-analyst
description: >
  Use this agent when the user wants to understand systemic patterns across
  incidents, needs trend analysis, or wants to identify recurring reliability
  issues that need architectural attention.

  Examples:

  <example>
  Context: User notices recurring incidents
  user: "Why does the auth service keep having incidents? Show me the pattern."
  assistant: "I'll launch the retro-analyst to analyze the pattern across incidents."
  <commentary>
  Pattern analysis across multiple incidents needs deep investigation.
  </commentary>
  </example>

  <example>
  Context: Quarterly reliability review
  user: "Give me a reliability analysis of our services for the last quarter"
  assistant: "I'll use the retro-analyst to produce a comprehensive reliability report."
  <commentary>
  Broad reliability analysis across time period and services.
  </commentary>
  </example>

model: sonnet
tools: Read, Grep, Glob, mcp__rootly__*
```

**System prompt responsibilities**:
1. Pull incidents for the requested scope (service, team, time period) via `search_incidents`
2. Identify recurring root causes and failure modes
3. Cluster incidents by pattern (same service, same error type, same trigger)
4. Calculate frequency trends (getting better or worse?)
5. Identify systemic issues requiring architectural fixes
6. Correlate with code changes where possible (via Read/Grep on the codebase)
7. Produce structured report with prioritized recommendations

---

### 6. Hooks

#### `hooks/hooks.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/validate-token.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/check-active-incidents.sh"
          }
        ]
      }
    ]
  }
}
```

**Hook 1: SessionStart -- Token Validation**
- Runs once when Claude Code starts
- Checks if `ROOTLY_API_TOKEN` is set
- If missing, outputs a brief setup message directing user to `/rootly:setup`
- If set, pings the API to validate (with 2s timeout)
- Never blocks -- informational only

**Hook 2: PreToolUse on Bash -- Active Incident Warning**
- Fires on all Bash tool calls (unavoidable -- all Bash commands share the tool name)
- Script reads JSON from stdin (per hooks spec), extracts `.tool_input.command`
- If not a git commit/push command, exits immediately (< 1ms overhead)
- If git commit/push, makes one REST API call to check active incidents (< 2s)
- Returns warning via stdout if active critical/high incidents found, empty otherwise
- Exit code 0 always (warn, never block)

**Design trade-off**: Hook scripts make direct REST calls to `api.rootly.com` rather than going through the MCP server. This is intentional -- hooks need to be fast (< 2 seconds) and cannot invoke MCP tools. The REST calls are simple, read-only checks. This means the plugin depends on both the MCP server (for skills/agents) and the REST API (for hooks).

**Why conservative hook design**: Hooks run on every matching event. A noisy or slow hook degrades the entire IDE experience. Only the session-start validation and pre-commit incident check are enabled by default. The post-push deployment registration is provided as an opt-in script.

---

### 7. Scripts

**Soft dependency**: Scripts use `python3` for JSON parsing (reading hook stdin per the Claude Code hooks spec) and `curl` for REST calls. Python 3 is present on virtually all developer machines (macOS ships with it, Linux distros include it). If unavailable, scripts fail silently per the graceful degradation principle. `jq` is recommended but not required.

#### `scripts/validate-token.sh`

```bash
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
```

#### `scripts/check-active-incidents.sh`

```bash
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
```

#### `scripts/register-deploy.sh`

```bash
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
```

---

### 8. Service-to-Repo Mapping (`.claude/rootly-config.json`)

Skills like `deploy-check` need to know which Rootly services correspond to the current repo. Resolution chain (in priority order):

1. **Explicit config**: `.claude/rootly-config.json` in the project:
   ```json
   {
     "services": ["auth-service", "auth-worker"],
     "team": "platform-team"
   }
   ```
2. **Repo name matching**: Match the git repo name against Rootly service names
3. **User prompt**: Ask the user which service(s) this repo maps to, then suggest they create the config file

The `/rootly:setup` skill helps create this config file.

---

## Verified MCP Tool Reference

The Rootly MCP server exposes 101 tools (16 custom + 85 OpenAPI-generated). Skills and agents reference these by exact name. The custom tools used by this plugin:

| Tool Name | Used By | Purpose |
|-----------|---------|---------|
| `find_related_incidents` | deploy-check, respond, retro, incident-investigator | TF-IDF similarity matching against historical incidents |
| `suggest_solutions` | respond, incident-investigator | Mine past resolutions for actionable recommendations |
| `search_incidents` | deploy-check, status, ask, retro-analyst | Search/filter incidents by status, severity, service |
| `getIncident` | respond, retro, incident-investigator | Get full details of a specific incident (camelCase) |
| `updateIncident` | respond (with human approval) | Update incident fields (camelCase) |
| `get_oncall_handoff_summary` | deploy-check, respond, oncall | Current/next on-call with shift context |
| `get_oncall_shift_metrics` | oncall | Shift hours, counts, grouped by user/team |
| `check_oncall_health_risk` | oncall, deploy-guardian | Fatigue and workload risk indicators |
| `get_alert_by_short_id` | respond, retro | Get alert details by short ID |
| `get_shift_incidents` | oncall | Incidents during a specific shift window |
| `get_oncall_schedule_summary` | deploy-guardian | Schedule overview for coordination |
| `check_responder_availability` | deploy-guardian | Whether responders are available |
| `list_endpoints` | ask | Discover available API endpoints |
| `get_server_version` | setup | Lightweight connectivity test |
| `list_shifts` | oncall | List on-call shifts |
| `create_override_recommendation` | oncall (optional) | Suggest schedule overrides |

**Note**: `getIncident` and `updateIncident` use camelCase (exceptions to the snake_case convention). All other tools use snake_case.

---

## Design Principles

### 1. MCP for Data, REST for Speed
Skills and agents access incident data through the MCP server (101 tools, rich context). Hook scripts make direct REST calls for simple, time-sensitive checks (active incident count). This is a pragmatic split -- MCP is the primary data channel, REST is used only where hooks need sub-2-second responses.

### 2. Progressive Disclosure
- **Hooks** (automatic): Ambient awareness, zero effort
- **Skills** (one command): Quick answers for specific questions
- **Agents** (deep): Multi-step investigation when you need thoroughness

### 3. Human-in-the-Loop for Write Operations
All skills that modify Rootly data (`updateIncident`, change severity, add responder) require explicit user approval. The prompt instructions enforce this -- recommendations are presented, but actions require confirmation.

### 4. Graceful Degradation
- No `ROOTLY_API_TOKEN`? SessionStart hook guides to `/rootly:setup`, skills explain how to configure.
- MCP server unreachable? Skills report the specific error and suggest manual steps.
- Low-confidence results from `find_related_incidents` or `suggest_solutions`? Flag explicitly, suggest manual investigation.
- Hooks fail silently on error -- never block the developer's workflow.
- No `jq` or `python3`? Hook scripts exit 0 silently.

### 5. Conservative Hook Design
Only the session-start validation and pre-commit incident check are enabled by default. Both are fast, high-value, and fail silent. Everything else is opt-in.

---

## Authentication Flow

1. User installs plugin via `/plugin marketplace add Rootly-AI-Labs/claude-rootly-plugin`
2. SessionStart hook detects missing token, outputs: "Run /rootly:setup to configure"
3. `/rootly:setup` guides through: get token from Rootly dashboard (Settings > API Keys) -> set `ROOTLY_API_TOKEN` env var -> verify connection via `get_server_version`
4. Plugin's `.mcp.json` passes `${ROOTLY_API_TOKEN}` to the hosted MCP server via HTTP Bearer header
5. Hook scripts read `ROOTLY_API_TOKEN` directly from environment for REST calls
6. Optionally, users set `ROOTLY_API_URL` for self-hosted Rootly instances (defaults to `https://api.rootly.com`)

No credentials stored in plugin files. No interactive OAuth flow.

---

## What the Plugin Does NOT Do

- **Bundle or run the MCP server** -- points to hosted endpoint
- **Store persistent state** -- no databases, no caches
- **Auto-execute write operations** -- always requires user confirmation
- **Block developer workflow** -- hooks fail silent, skills are on-demand
- **Assume specific Rootly deployment** -- supports self-hosted via `ROOTLY_API_URL`

---

## Implementation Priority

### Phase 1: Core (MVP)
1. Plugin manifest, marketplace entry, and MCP server reference
2. `/rootly:setup` skill (first-run experience)
3. `/rootly:deploy-check` skill
4. `/rootly:respond` skill
5. `/rootly:oncall` skill
6. SessionStart hook (token validation)
7. PreToolUse hook (active incident check)
8. Service-to-repo mapping config support
9. README with installation, setup, and usage guide

### Phase 2: Learning Loop
10. `/rootly:retro` skill
11. `/rootly:status` skill
12. `incident-investigator` agent

### Phase 3: Advanced
13. `/rootly:ask` skill
14. `deploy-guardian` agent
15. `retro-analyst` agent
16. `register-deploy.sh` script (documented opt-in)

---

## Testing Strategy

- **Local testing**: `claude --plugin-dir ./claude-rootly-plugin` during development
- **Reload**: `/reload-plugins` after changes, no restart needed
- **Hook stdin verification**: Test with a debug hook (`cat > /tmp/hook-debug.json`) to capture the exact JSON structure before building the real scripts
- **Validation**: Test each skill with real Rootly API token against a test organization
- **Edge cases**: Missing token, invalid token, network timeout, empty incident history, no on-call configured, self-hosted Rootly URL, active incident during retro generation, clean git working tree on deploy-check
