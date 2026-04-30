---
name: setup
description: Set up the Rootly plugin. Checks for API token, verifies MCP server connection, and guides through configuration. Run this after installing the plugin.
disable-model-invocation: true
allowed-tools:
  - Bash
  - mcp__rootly__*
---

# Rootly Plugin Setup

You are running the first-time setup for the Rootly Claude plugin. Follow these steps in order:

## Step 1: Verify MCP Connection and Token

First, test the MCP server connection by calling `mcp__rootly__get_server_version`.

If that succeeds, verify the API token actually works by calling `mcp__rootly__getCurrentUser`.

- **Both succeed**: Report success and continue to Step 2.
- **get_server_version fails**: MCP server connection issue.
- **getCurrentUser fails**: Token authentication issue.

If either fails, provide these instructions:

> **Rootly API Token Required**
>
> 1. Go to your Rootly dashboard: **Settings > API Keys**
> 2. Create a new API key with read access (write access needed only for incident response actions)
> 3. Provide the token through the plugin's userConfig prompt. This is the canonical path for both marketplace installs and `--plugin-dir` loading. The MCP server reads `${user_config.ROOTLY_API_TOKEN}` and will not pick up an arbitrary shell env var.
>    - If the prompt did not appear, open `/plugin`, find Rootly, and re-enable it to trigger the configuration dialog.
> 4. As a secondary path for hook scripts only, you can `export ROOTLY_API_TOKEN="..."`. The hook scripts (active-incident warnings on commit/push) honor it, but MCP commands like this one will still need the userConfig value above.
> 5. Reload plugins or restart Claude Code, then run `/rootly:setup` again.

Then stop here -- no further steps possible without a working token.

**Additional troubleshooting:**
- If `get_server_version` works but `getCurrentUser` fails: Your token is configured but invalid or lacks permissions
- If both fail: Token is missing or MCP server can't reach Rootly

## Step 2: Service Mapping Configuration

Check if `.claude/rootly-config.json` exists in the current project directory.

**If the file does NOT exist**, offer to create it:

1. Ask the user which Rootly service(s) correspond to this repository
2. Ask which team owns this service (optional)
3. Create `.claude/rootly-config.json` with the format:
   ```json
   {
     "services": ["service-name-1", "service-name-2"],
     "team": "team-name"
   }
   ```

**If the file exists**, read and display its current configuration.

## Step 3: Show Quick-Start Guide

Once setup is complete, display:

> **Rootly plugin is ready!**
>
> | Command | Description |
> |---------|-------------|
> | `/rootly:deploy-check` | Check deployment safety before pushing |
> | `/rootly:respond [incident-id]` | Investigate and respond to an incident |
> | `/rootly:oncall` | View on-call dashboard |
> | `/rootly:retro [incident-id]` | Generate post-incident retrospective |
> | `/rootly:status` | Service health overview |
> | `/rootly:ask [question]` | Ask questions about your incident data |
> | `/rootly:brief [incident-id]` | Generate stakeholder brief for executives |
> | `/rootly:handoff [incident-id]` | Prepare incident or on-call handoff docs |
>
> Hooks are active:
> - **Session start**: Token validation (already ran)
> - **Pre-commit/push**: Active critical incident warnings
