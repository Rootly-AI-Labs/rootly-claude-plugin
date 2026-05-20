<p align="center">
  <img src="assets/logo.png" alt="Rootly for Claude Code" width="500" />
</p>

<h1 align="center">Rootly for Claude Code</h1>

<p align="center">
  <strong>Incident management meets AI-powered development.</strong><br />
  Prevent, respond, and learn from incidents -- without leaving your terminal.
</p>

<p align="center">
  <a href="https://rootly.com/integrations/claude"><img src="https://img.shields.io/badge/rootly-integration-D97757?style=flat-square&logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48Y2lyY2xlIGN4PSIxMiIgY3k9IjEyIiByPSIxMCIgZmlsbD0id2hpdGUiLz48L3N2Zz4=" alt="Rootly Integration" /></a>
  <a href="https://github.com/Rootly-AI-Labs/rootly-claude-plugin/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0-blue?style=flat-square" alt="License" /></a>
  <a href="#installation"><img src="https://img.shields.io/badge/claude--code-plugin-4A154B?style=flat-square" alt="Claude Code Plugin" /></a>
</p>

<br />

---

## Why

You're in the zone writing code. Then:

- You `git push` and realize there's a SEV-1 in progress
- You get paged and scramble between Slack, Datadog, and your incident tool
- The retro after an incident takes hours to compile

**This plugin brings Rootly's incident lifecycle into Claude Code** -- so you can assess deployment risk, investigate incidents, check on-call, and generate retrospectives from the same terminal where you write code.

---

## What You Get

<table>
<tr>
<td width="50%">

### Before You Deploy
```
> /rootly:deploy-check
```
Analyzes your git diff against past incidents. Warns you if similar changes caused outages before. Checks if on-call coverage exists.

</td>
<td width="50%">

### When You Get Paged
```
> /rootly:respond INC-4521
```
Pulls full incident context, finds similar past incidents, suggests proven solutions, and shows who's on-call -- all in one brief.

</td>
</tr>
<tr>
<td width="50%">

### During Your Shift
```
> /rootly:oncall
```
See who's on-call across all schedules, shift metrics, upcoming handoffs, and health risk indicators.

</td>
<td width="50%">

### Service Health Check
```
> /rootly:status
```
Quick overview of all services with active incidents grouped by severity and age.

</td>
</tr>
<tr>
<td width="50%">

### Stakeholder Communication
```
> /rootly:brief INC-4521
```
Generate executive-friendly incident summaries with impact, timeline, and current status for stakeholder updates.

</td>
<td width="50%">

### Shift Handoffs
```
> /rootly:handoff
```
Create structured handoff documents for incident commanders or on-call transitions with context and next steps.

</td>
</tr>
<tr>
<td width="50%">

### Ask Questions
```
> /rootly:ask "incidents this week"
```
Natural language queries about your incident data, on-call schedules, and service reliability patterns.

</td>
<td width="50%">

### After the Dust Settles
```
> /rootly:retro INC-4521
```
Generates structured retrospectives from incident data: timeline, contributing factors, action items, and systemic patterns.

</td>
</tr>
</table>

## Installation

You can use this plugin in two ways:

- **Marketplace install** for a persistent Claude Code installation
- **Local `--plugin-dir` loading** for development and evaluation from source

### Marketplace Install

This repository includes `.claude-plugin/marketplace.json`, so Claude Code can use the repo itself as a marketplace source.

1. Add the marketplace:

```text
/plugin marketplace add Rootly-AI-Labs/rootly-claude-plugin
```

2. Open the plugin manager:

```text
/plugin
```

3. In the **Discover** tab, select `rootly` and install it to your preferred scope:

- **User**: available across all your projects
- **Project**: shared through this repository's `.claude/settings.json`
- **Local**: only for you in this repository

4. Reload plugins so the install takes effect immediately:

```text
/reload-plugins
```

5. Run setup -- Claude will automatically handle OAuth2 login when it connects to the MCP server:

```text
/rootly:setup
```

A browser window will open for you to log in to Rootly and grant access. No API token needed.

### Local Source Loading

#### Step 1: Clone the Plugin

```bash
git clone https://github.com/Rootly-AI-Labs/rootly-claude-plugin.git
cd rootly-claude-plugin
```

#### Step 2: Load It in Claude Code

```bash
claude --plugin-dir .
```

Claude Code loads the plugin directly from this directory for the current session. This is the recommended flow for local development and evaluation. For a persistent install, use the marketplace flow above.

#### Step 3: Verify

```
/rootly:setup
```

### Direct MCP Access

This repository is a Claude Code plugin. If you only want direct Rootly MCP access in Claude Desktop / Cowork, configure the MCP server separately:

```json
{
  "mcpServers": {
    "rootly": {
      "url": "https://mcp.rootly.com/mcp"
    }
  }
}
```

Claude will handle OAuth2 login automatically -- a browser window opens for you to authenticate with Rootly. No API token needed.

---

## Setup & Configuration

After installation, run the setup command:
```
> /rootly:setup
```
First-time plugin setup with API token validation, service mapping, and quick-start guide.

---

## Authentication

### OAuth2 (Recommended)

MCP commands use OAuth2 automatically. When Claude connects to the Rootly MCP server, it handles the OAuth2 flow -- a browser window opens for you to log in and grant access. No configuration needed.

To re-authenticate, disconnect and reconnect the MCP server via `/mcp`.

### API Token (Hook Scripts)

Hook scripts (active-incident warnings on commit/push) still use API tokens since they run outside the MCP context:

```bash
# Via plugin config (persistent)
# Set ROOTLY_API_TOKEN in the plugin's userConfig prompt

# Via env var (session-scoped)
export ROOTLY_API_TOKEN="your-token-here"
```

Get a token from your Rootly dashboard under **Settings > API Keys**.

---

## Commands

### Stable (inline, MCP-native)

| Command | What It Does |
|---------|-------------|
| `/rootly:setup` | First-run configuration and connection check |
| `/rootly:my` | Personal dashboard — your active incidents, action items, and upcoming on-call |
| `/rootly:status [service]` | Service health overview — active incidents at a glance |
| `/rootly:oncall [team]` | On-call dashboard with shift metrics |
| `/rootly:alert [short-id]` | Triage a Rootly alert — events, group context, linked incident |
| `/rootly:lookup [name]` | Look up a service, team, or catalog entity — owner, on-call, reliability |
| `/rootly:trend [scope]` | 30-day reliability trend with prior-period comparison |
| `/rootly:brief [id]` | Stakeholder summary for executives or customers |
| `/rootly:handoff [id]` | Incident or on-call handoff documentation |
| `/rootly:ask [question]` | Natural-language Q&A over your Rootly data |
| `/rootly:action [list\|add\|done]` | Manage incident action items (write actions confirm before mutating) |
| `/rootly:swap [date]` | Request someone cover one of your shifts (write, confirms first) |
| `/rootly:cover [team]` | Offer to cover someone else's shift (write, confirms first) |
| `/rootly:announce [id]` | Draft and post a stakeholder update on an incident (write, confirms first) |

### Experimental (forked subagent — may not have MCP access in all contexts)

| Command | What It Does |
|---------|-------------|
| `/rootly:respond [id]` | Deep incident investigation via the `incident-investigator` agent |
| `/rootly:retro [id]` | Post-incident retrospective via the `retro-analyst` agent |
| `/rootly:deploy-check` | Pre-deploy risk analysis via the `deploy-guardian` agent |

> The experimental skills delegate to forked subagents. In some Claude Code contexts the subagent doesn't inherit the plugin's MCP server; when that happens it stops and reports rather than falling back to bash/curl (which would leak the API token). For reliable coverage of those workflows, prefer `/rootly:brief`, `/rootly:status`, and the inline alternatives above.

### Natural Language Queries

```
/rootly:ask how many SEV-1 incidents did we have last month?
/rootly:ask which service has the most incidents this quarter?
/rootly:ask who's been on-call the most in the last 30 days?
```

---

## Deep Investigation Agents

When a slash command isn't enough, Claude automatically invokes specialized agents for deeper analysis:

| Agent | Triggered When | What It Does |
|-------|---------------|--------------|
| **Incident Investigator** | You need root cause analysis beyond initial triage | Builds hypothesis trees, correlates alerts with code changes, traces causation chains |
| **Deploy Guardian** | Multi-service deployments with cross-team impact | Maps blast radius across dependent services, evaluates downstream risk, builds coordination checklists |
| **Retro Analyst** | You want to understand patterns across incidents | Clusters incidents by failure mode, calculates frequency trends, identifies systemic reliability issues |

---

## Automatic Hooks

Two lightweight hooks run in the background -- they **never block** your workflow:

| Hook | When | What It Does |
|------|------|--------------|
| **Token check** | Session start | Validates your API token and nudges you to configure one if missing |
| **Incident warning** | Before `git commit` / `git push` | Warns if there's an active critical incident -- so you don't deploy into a fire |

---

## Service Mapping

Map your repository to Rootly services by creating `.claude/rootly-config.json`:

```json
{
  "services": ["auth-service", "auth-worker"],
  "team": "platform-team"
}
```

`/rootly:setup` walks you through creating this. Without it, the plugin falls back to matching your git repo name against Rootly service names.

---

## Advanced

<details>
<summary><strong>Self-hosted Rootly</strong></summary>

```bash
export ROOTLY_API_URL="https://rootly.internal.example.com"
```

This overrides the REST API base URL used by hook scripts. Configure the MCP endpoint separately in `.mcp.json`.
</details>

<details>
<summary><strong>Local MCP server</strong></summary>

Replace the HTTP transport in `.mcp.json`:

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
</details>

<details>
<summary><strong>CLI MCP setup</strong></summary>

```bash
claude mcp add rootly --transport http https://mcp.rootly.com/mcp
```

OAuth2 login will be triggered automatically on first use.
</details>

<details>
<summary><strong>Post-push deployment registration</strong></summary>

An optional script (`scripts/register-deploy.sh`) can register deployments with Rootly after `git push`. It is not enabled by default -- see the script header for hook configuration.
</details>

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| OAuth2 login doesn't open browser | Ensure your Rootly org has OAuth2 enabled. Try `/mcp` > disconnect > reconnect Rootly. |
| "No API token found" (hook scripts) | This only affects commit/push warnings. Set `ROOTLY_API_TOKEN` in plugin config or env var. MCP commands use OAuth2 instead. |
| MCP tools not responding | Disconnect and reconnect via `/mcp`, or reload with `/reload-plugins`. |
| OAuth2 consent shows limited permissions | Your org's OAuth2 configuration may need updating -- contact your Rootly admin. |
| Skills not appearing | Run `/reload-plugins`, then check the **Installed** tab in `/plugin`. |
| Hook scripts not running | Run `chmod +x scripts/*.sh` and ensure `jq` or `python3` is available. |

---

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full technical design: MCP integration, hook system, agent orchestration, and data flow.

---

## License

Apache 2.0 -- see [LICENSE](LICENSE).

<p align="center">
  <sub>Built by <a href="https://rootly.com">Rootly AI Labs</a></sub>
</p>
