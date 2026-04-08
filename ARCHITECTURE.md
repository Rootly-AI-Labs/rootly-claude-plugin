# Rootly Claude Plugin - Architecture Overview

## Overview

This Claude Code plugin layers opinionated, developer-friendly workflows on top of Rootly's MCP server for the full incident lifecycle: prevent, respond, learn. The implementation is primarily prompt engineering and workflow orchestration. Incident data flows through the Rootly MCP server at `mcp.rootly.com`, while hooks use minimal direct REST API calls for low-latency checks.

---

## Directory Structure

```
rootly-claude-plugin/
├── .claude-plugin/
│   ├── plugin.json                          # Plugin manifest (required)
│   └── marketplace.json                     # Repo-hosted marketplace metadata
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
│   ├── ask/
│   │   └── SKILL.md                         # /rootly:ask
│   ├── brief/
│   │   └── SKILL.md                         # /rootly:brief (stakeholder communication)
│   └── handoff/
│       └── SKILL.md                         # /rootly:handoff (shift transitions)
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
└── LICENSE
```

---

## Component Specifications

### 1. Plugin Manifest (`.claude-plugin/plugin.json`)

```json
{
  "name": "rootly",
  "version": "1.1.0",
  "description": "Full-lifecycle incident management from your IDE. Prevent incidents before deploy, respond in real-time, and learn from post-mortems -- powered by Rootly.",
  "author": {
    "name": "Rootly AI Labs",
    "email": "support@rootly.com",
    "url": "https://rootly.com"
  },
  "homepage": "https://rootly.com/integrations/claude",
  "repository": "https://github.com/Rootly-AI-Labs/rootly-claude-plugin",
  "license": "Apache-2.0",
  "userConfig": {
    "ROOTLY_API_TOKEN": {
      "description": "Rootly API token used for MCP access and incident workflow hooks",
      "sensitive": true
    }
  },
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

This file provides the repo-hosted marketplace metadata for the plugin.

```json
{
  "name": "rootly-plugins",
  "owner": {
    "name": "Rootly AI Labs",
    "email": "support@rootly.com"
  },
  "metadata": {
    "description": "Official Rootly plugins for Claude Code",
    "version": "1.1.0"
  },
  "plugins": [
    {
      "name": "rootly",
      "source": "./",
      "description": "Full-lifecycle incident management: deploy safety, incident response, on-call management, and retrospectives.",
      "version": "1.1.0",
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

This file references Rootly's hosted MCP server. The plugin does not bundle a server binary.

```json
{
  "mcpServers": {
    "rootly": {
      "type": "http",
      "url": "https://mcp.rootly.com/mcp",
      "headers": {
        "Authorization": "Bearer ${user_config.ROOTLY_API_TOKEN}"
      }
    }
  }
}
```

**Authentication**: The plugin declares `ROOTLY_API_TOKEN` in `userConfig`, so Claude Code can prompt for it when the plugin is enabled. The hosted MCP config consumes that value through `${user_config.ROOTLY_API_TOKEN}`. For local development with `--plugin-dir`, the runtime scripts still support `ROOTLY_API_TOKEN` as a fallback environment variable.

**Alternative configurations** (also documented in the README for advanced users):
- **CLI setup**: `claude mcp add rootly --transport http https://mcp.rootly.com/mcp --header "Authorization: Bearer YOUR_TOKEN"`
- **Local MCP server** (for self-hosted Rootly or offline use):
  ```json
  {
    "mcpServers": {
      "rootly": {
        "command": "uvx",
        "args": ["--from", "rootly-mcp-server", "rootly-mcp-server"],
        "env": {
          "ROOTLY_API_TOKEN": "${user_config.ROOTLY_API_TOKEN}"
        }
      }
    }
  }
  ```

### 4. Skills (Slash Commands)

Each skill lives in `skills/<name>/SKILL.md` with YAML frontmatter.

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
disable-model-invocation: true
allowed-tools:
  - Bash
  - mcp__rootly__*
```

**Workflow**:
1. Check if a plugin-configured token or local `ROOTLY_API_TOKEN` fallback is available
2. If not set, provide step-by-step instructions:
   - Where to get an API token in the Rootly dashboard (Settings > API Keys)
   - How to update the plugin configuration with the token
   - How to use `export ROOTLY_API_TOKEN=...` only as a local development fallback
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
disable-model-invocation: true
context: fork
agent: rootly:deploy-guardian
allowed-tools:
  - Bash
  - mcp__rootly__*
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
disable-model-invocation: true
context: fork
agent: rootly:incident-investigator
allowed-tools:
  - Bash
  - mcp__rootly__*
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

**Note**: `context: fork` runs this in an isolated subagent to avoid polluting the main coding context with incident data, and `agent: rootly:incident-investigator` explicitly routes the workflow through the shipped specialist agent.

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
disable-model-invocation: true
allowed-tools:
  - mcp__rootly__*
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
disable-model-invocation: true
context: fork
agent: rootly:retro-analyst
allowed-tools:
  - mcp__rootly__*
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
disable-model-invocation: true
allowed-tools:
  - mcp__rootly__*
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
disable-model-invocation: true
allowed-tools:
  - mcp__rootly__*
```

**Workflow**:
1. Parse the natural language question from `$ARGUMENTS`
2. First, call `list_endpoints` to discover available Rootly MCP tools
3. Select the most appropriate tools for the question
4. Execute queries (may require multiple calls)
5. Synthesize and present answer with supporting data
6. If the question can't be answered with available tools, say so explicitly rather than hallucinating

---

#### 4h. `/rootly:brief` -- Stakeholder Communication

```
skills/brief/SKILL.md
```

**Purpose**: Generate concise executive/stakeholder briefs for incidents.

**Frontmatter**:
```yaml
name: brief
description: Generate a concise stakeholder brief for an incident. Creates executive summary with key details, impact, timeline, and current status.
argument-hint: [incident-id]
disable-model-invocation: true
allowed-tools:
  - mcp__rootly__*
```

**Workflow**:
1. Parse incident ID from `$ARGUMENTS`
2. Call `mcp__rootly__getIncident` for full incident details
3. Call `mcp__rootly__listIncidentAlerts` for associated alerts
4. Generate structured brief with business-focused language:
   - Executive summary with impact and current status
   - Service impact and timeline
   - Next steps and resolution approach
5. Format for non-technical stakeholders (under 200 words)

**Use Cases**: CEO updates, customer communications, legal/compliance documentation, cross-team notifications.

---

#### 4i. `/rootly:handoff` -- Shift Transitions

```
skills/handoff/SKILL.md
```

**Purpose**: Prepare incident or on-call handoff documents for shift changes.

**Frontmatter**:
```yaml
name: handoff
description: Prepare an incident or on-call handoff document. Creates structured summary for shift changes or incident commander transitions.
argument-hint: [incident-id]
disable-model-invocation: true
allowed-tools:
  - mcp__rootly__*
```

**Workflow**:
1. Determine handoff type based on `$ARGUMENTS`:
   - **Incident handoff** (with incident ID): Call `mcp__rootly__getIncident` and `mcp__rootly__listIncidentAlerts`
   - **On-call handoff** (no ID): Call `mcp__rootly__get_oncall_handoff_summary` and `mcp__rootly__search_incidents`
2. Generate structured handoff document with:
   - Current situation summary
   - Actions taken and next steps
   - Key contacts and escalation paths
   - Critical context and monitoring points
3. Format for seamless knowledge transfer

**Use Cases**: Shift changes, incident commander transitions, on-call handoffs, team coordination.

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
description: Deep production-incident investigator for root-cause analysis, evidence gathering, and remediation planning beyond the initial response brief.
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
description: Deployment safety specialist for blast-radius analysis, downstream dependency checks, and cross-team coordination planning.
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
description: Reliability pattern analyst for retrospectives, recurring-incident clustering, and systemic improvement recommendations.
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
            "if": "Bash(git commit *)",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/check-active-incidents.sh"
          },
          {
            "type": "command",
            "if": "Bash(git push *)",
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
- Checks for a configured plugin token, then falls back to `ROOTLY_API_TOKEN` for local development
- If missing, outputs a brief setup message directing user to `/rootly:setup`
- If set, pings the API to validate (with 2s timeout)
- Never blocks -- informational only

**Hook 2: PreToolUse on Bash -- Active Incident Warning**
- Uses hook-level `if` conditions so the script only spawns for `git commit` and `git push`
- If git commit/push, makes one REST API call to check active incidents (< 2s)
- Returns warning via stdout if active critical/high incidents found, empty otherwise
- Exit code 0 always (warn, never block)

**Design trade-off**: Hook scripts make direct REST calls to `api.rootly.com` rather than going through the MCP server. This is intentional -- hooks need to be fast (< 2 seconds) and cannot invoke MCP tools. The REST calls are simple, read-only checks. This means the plugin depends on both the MCP server (for skills/agents) and the REST API (for hooks).

**Why conservative hook design**: Hooks run on every matching event. A noisy or slow hook degrades the entire IDE experience. Only the session-start validation and pre-commit incident check are enabled by default. The post-push deployment registration is provided as an opt-in script.

---

### 7. Scripts

**Runtime dependencies**: Scripts use `curl` for REST calls and either `jq` or `python3` for lightweight JSON parsing. If no parser is available, they fail silently per the graceful degradation principle.

#### `scripts/validate-token.sh`

```bash
#!/bin/bash
# SessionStart hook: check if a Rootly API token is configured.
# Prefer plugin-managed configuration and fall back to the legacy env var
# for local development with --plugin-dir.

ROOTLY_TOKEN="${CLAUDE_PLUGIN_OPTION_ROOTLY_API_TOKEN:-${ROOTLY_API_TOKEN:-}}"
ROOTLY_URL="${ROOTLY_API_URL:-https://api.rootly.com}"

if [ -z "$ROOTLY_TOKEN" ]; then
  echo "Rootly plugin: No API token found. Configure the plugin and then run /rootly:setup."
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
```

#### `scripts/check-active-incidents.sh`

```bash
#!/bin/bash
# PreToolUse hook: warn about active incidents before git commit/push.
# hooks/hooks.json filters to the relevant Bash commands, so this script
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

ROOTLY_TOKEN="${CLAUDE_PLUGIN_OPTION_ROOTLY_API_TOKEN:-${ROOTLY_API_TOKEN:-}}"
if [ -z "$ROOTLY_TOKEN" ]; then
  exit 0
fi

ROOTLY_URL="${ROOTLY_API_URL:-https://api.rootly.com}"
COMMIT_SHA=$(git rev-parse HEAD 2>/dev/null)
BRANCH=$(git branch --show-current 2>/dev/null)
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")

curl -s -X POST "$ROOTLY_URL/v1/deployments" \
  -H "Authorization: Bearer $ROOTLY_TOKEN" \
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

## MCP Tool Reference

The hosted Rootly MCP server exposes many tools, but this plugin depends on a focused subset. Skills and agents reference these by exact name:

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
Skills and agents access incident data through the MCP server. Hook scripts make direct REST calls for simple, time-sensitive checks such as active-incident warnings. This is a pragmatic split: MCP is the primary data channel, and REST is used only where hooks need sub-2-second responses.

### 2. Progressive Disclosure
- **Hooks** (automatic): Ambient awareness, zero effort
- **Skills** (one command): Quick answers for specific questions
- **Agents** (deep): Multi-step investigation when you need thoroughness

### 3. Human-in-the-Loop for Write Operations
All skills that modify Rootly data (`updateIncident`, change severity, add responder) require explicit user approval. The prompt instructions enforce this -- recommendations are presented, but actions require confirmation.

### 4. Graceful Degradation
- No configured token? SessionStart hook guides to `/rootly:setup`, skills explain how to configure, and local development can still use `ROOTLY_API_TOKEN` as a fallback.
- MCP server unreachable? Skills report the specific error and suggest manual steps.
- Low-confidence results from `find_related_incidents` or `suggest_solutions`? Flag explicitly, suggest manual investigation.
- Hooks fail silently on error -- never block the developer's workflow.
- No `jq` or `python3`? Hook scripts exit 0 silently.

### 5. Conservative Hook Design
Only the session-start validation and pre-commit incident check are enabled by default. Both are fast, high-value, and fail silent. Everything else is opt-in.

---

## Authentication Flow

1. User loads the plugin in Claude Code, either from a marketplace install or locally with `claude --plugin-dir`
2. Claude Code prompts for `ROOTLY_API_TOKEN` from the plugin's `userConfig`
3. SessionStart hook validates the configured token and points the user to `/rootly:setup` if it is missing or invalid
4. `/rootly:setup` verifies the MCP connection with `get_server_version` and helps with service mapping
5. Plugin `.mcp.json` passes `${user_config.ROOTLY_API_TOKEN}` to the hosted MCP server
6. Hook scripts read `CLAUDE_PLUGIN_OPTION_ROOTLY_API_TOKEN`, with `ROOTLY_API_TOKEN` kept only as a local development fallback
7. Users can still set `ROOTLY_API_URL` for self-hosted REST endpoints (defaults to `https://api.rootly.com`)

No credentials stored in plugin files. No interactive OAuth flow.

---

## What the Plugin Does NOT Do

- **Bundle or run the MCP server** -- points to hosted endpoint
- **Store persistent state** -- no databases, no caches
- **Auto-execute write operations** -- always requires user confirmation
- **Block developer workflow** -- hooks fail silent, skills are on-demand
- **Assume specific Rootly deployment** -- supports self-hosted via `ROOTLY_API_URL`

---

## Validation Checklist

- **Schema validation**: Run `claude plugin validate` when the Claude CLI is available.
- **Local loading**: From the repo root, run `claude --plugin-dir .` during development.
- **Reload loop**: Use `/reload-plugins` after manifest, skill, agent, or hook changes.
- **Functional checks**: Exercise each skill against a test Rootly organization with a valid token.
- **Edge cases**: Validate missing token, invalid token, network timeout, empty incident history, no on-call configured, self-hosted `ROOTLY_API_URL`, active incident during retro generation, and clean git working tree on deploy-check.
