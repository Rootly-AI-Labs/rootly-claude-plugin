---
name: setup
description: Set up the Rootly plugin. Checks for API token, verifies MCP server connection, and guides through configuration. Run this after installing the plugin.
argument-hint: []
allowed-tools: Bash, mcp__rootly__*
---

# Rootly Plugin Setup

You are running the first-time setup for the Rootly Claude plugin. Follow these steps in order:

## Step 1: Verify MCP Connection

Test the connection by calling the `get_server_version` MCP tool. This simultaneously validates that the API token is configured and that the MCP server is reachable.

- **Success**: Report the server version and skip to Step 3.
- **Failure**: The token is likely missing or invalid. Provide these instructions:

> **Rootly API Token Required**
>
> 1. Go to your Rootly dashboard: **Settings > API Keys**
> 2. Create a new API key with read access (write access needed only for incident response actions)
> 3. Set the environment variable in your shell profile:
>    ```bash
>    export ROOTLY_API_TOKEN="your-token-here"
>    ```
> 4. Or add it to `~/.claude/settings.json` under `"env"`:
>    ```json
>    {
>      "env": {
>        "ROOTLY_API_TOKEN": "your-token-here"
>      }
>    }
>    ```
> 5. Restart Claude Code and run `/rootly:setup` again.

Then stop here -- no further steps possible without the token.

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
>
> Hooks are active:
> - **Session start**: Token validation (already ran)
> - **Pre-commit/push**: Active critical incident warnings
