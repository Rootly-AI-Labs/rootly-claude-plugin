# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-04-30

### Added — Tier 0 (critical workflow gaps)
- **`/rootly:alert <short-id>`** — alert triage. Pulls the alert record, event timeline, sibling alerts in the same group, and any incident the alert is attached to. Read-only.
- **`/rootly:action [list|add]`** — incident action items from the terminal. List your open items or create new ones with explicit confirmation. First write actions in the plugin.
- **`/rootly:my`** — personal Rootly dashboard: your active incidents, open action items, and upcoming on-call shifts in one glanceable view.

### Added — Tier 1 (high-frequency daily workflow)
- **`/rootly:lookup <service-or-team>`** — service / team / catalog-entity lookup. Returns owner, on-call, recent reliability, active incidents.
- **`/rootly:trend [service|team|all]`** — 30-day reliability trend with prior-period comparison. Incident volume, severity mix, MTTR direction.
- **`/rootly:swap [date|"next"]`** — request someone cover one of your shifts. Lists candidates via `create_override_recommendation`, creates the override on confirmation.
- **`/rootly:cover [team-or-schedule]`** — offer to cover someone else's shift. Lists upcoming uncovered shifts, creates the override on confirmation.
- **`/rootly:announce <incident>`** — draft and post a stakeholder update on an incident's status page (or internal incident stream). Draft → confirm → post pattern.

### Changed
- **Marked forked skills (`/rootly:respond`, `/rootly:retro`, `/rootly:deploy-check`) as experimental.** They use `context: fork` to delegate to subagents, but in some Claude Code contexts the forked subagent does not inherit the plugin's MCP tools. The `Tool Usage Rules` from 2.0.2 prevent token leakage in that failure mode (the agent stops rather than falling back to bash/curl), but the affected skills won't always complete successfully. Inline alternatives — `/rootly:brief`, `/rootly:status`, `/rootly:oncall` — cover most of the same use cases reliably.

### Notes
- All new write actions (`/rootly:action add`, `/rootly:action done`, `/rootly:swap`, `/rootly:cover`, `/rootly:announce`) follow a strict draft → confirm → execute pattern. They never mutate Rootly state without explicit user `yes`.
- The plugin now exposes 18 skills; 14 are stable inline, 3 are forked-experimental, 1 is the test skill.

## [2.0.2] - 2026-04-30

### Security
- **Prevent token leakage from agents.** When the `mcp__rootly__*` tools were unreachable inside a forked subagent context, the `incident-investigator` and `deploy-guardian` agents would fall back to `Bash` and issue raw `curl` calls to `api.rootly.com` with the bearer token inlined into the command — leaking it to shell history, process listings, and tool-use logs. Added explicit "Tool Usage Rules" sections to all three plugin agents that:
  - Require `mcp__rootly__*` tools exclusively for Rootly API access
  - Forbid `curl`, `wget`, raw HTTP, or any Bash-based call to `api.rootly.com` / `mcp.rootly.com`
  - Forbid embedding the API token as a literal in any command line
  - Direct the agent to stop and report rather than fall back to Bash when MCP tools are unavailable

  `Bash` remains available to `incident-investigator` and `deploy-guardian` for non-Rootly local operations only (`git log`, `git diff`, file inspection).

### Note
Anyone who ran `/rootly:respond <id>` or the `incident-investigator` / `deploy-guardian` agents on 2.0.0 or 2.0.1 should rotate their Rootly API token in **Settings → API Keys**, since it may be present in shell history or transcripts.

## [2.0.1] - 2026-04-30

### Fixed
- **CRITICAL**: MCP `Authorization` header now uses `${user_config.ROOTLY_API_TOKEN}` instead of `${ROOTLY_API_TOKEN}`. The previous form only resolved from a literal OS env var, so marketplace-installed users (who paste the token at the plugin's userConfig prompt) silently authenticated with an empty bearer token and every MCP-backed command failed.
- Numeric incident references (`4460`, `#4460`, `INC-4460`) now resolve to a UUID via `mcp__rootly__list_incidents` with bounded page lookup, instead of triggering open-ended page-walking. The agent matches on `incidents[*].incident_number` and reads the UUID from the paired `incident_id`.
- Added the `mcp__rootly__` prefix to tool references in `incident-investigator`, `deploy-guardian`, and `retro-analyst` agents. The v2.0.0 changelog claimed this was fixed everywhere, but the agents were missed.

### Changed
- README and `/rootly:setup` skill now describe the MCP-vs-hook auth split honestly: the userConfig prompt is the canonical token path, while the `ROOTLY_API_TOKEN` env var only feeds the commit/push hook scripts.
- Removed the unused bash resolver script and dropped `Bash` from `skills/respond/SKILL.md` `allowed-tools`.

## [2.0.0] - 2026-04-08

### Added
- New `/rootly:brief` skill for generating executive stakeholder briefs
- New `/rootly:handoff` skill for shift transition documentation
- Comprehensive token configuration guide with multiple approaches

### Changed
- **BREAKING**: Fixed MCP tool name references across all skills (added `mcp__rootly__` prefix)
- Improved token verification in setup to test actual API access
- Reorganized README structure (Installation before Setup & Configuration)
- Streamlined token management for better user experience

### Fixed
- Plugin loading and caching issues resolved with version bump
- Command namespacing now displays correctly (`/rootly:setup` not `/setup`)
- Plugin manifest validation errors corrected
- MCP server configuration updated for better compatibility

### Technical
- Updated `.mcp.json` to use `${ROOTLY_API_TOKEN}` environment variable
- Enhanced setup skill to verify both MCP connection and API authentication
- Improved error handling and user feedback in setup process

## [1.1.0] - Previous Release

### Added
- Initial plugin release with core incident management skills
- Integration with Rootly MCP server
- Basic token configuration
- Core skills: deploy-check, respond, oncall, retro, status, ask, setup

---

**Note**: Version 2.0.0 includes breaking changes to MCP tool naming. Existing installations should update to ensure all skills work correctly.
