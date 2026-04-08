# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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