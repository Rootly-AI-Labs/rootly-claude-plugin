---
name: respond
description: Investigate and respond to a production incident. Pulls context, finds similar past incidents, suggests solutions, and enables coordination -- all from the terminal. Use when paged or when an incident needs attention.
argument-hint: [incident-id]
context: fork
allowed-tools: Bash, mcp__rootly__*
---

# Incident Response

You are helping the user investigate and respond to a production incident. This runs in a forked context to keep incident data separate from the main coding session.

## Workflow

### 1. Identify the Incident

**If `$ARGUMENTS` contains an incident ID**: Use that ID directly.

**If no incident ID provided**:
1. Call `search_incidents` filtered to active status (`started`)
2. If no active incidents, report "No active incidents found" and stop
3. If multiple active incidents, list them sorted by severity (critical first, then high, then medium, then low) and ask the user to select one
4. For long lists, show critical/high severity first with a note about additional lower-severity incidents

### 2. Gather Full Context

Once you have the incident ID:

1. Call `getIncident` to get the full incident record (note: camelCase tool name)
2. Call `get_alert_by_short_id` or search alerts for associated alert details and timeline
3. Call `find_related_incidents` to find historically similar incidents
4. Call `suggest_solutions` to get resolution recommendations
5. Call `get_oncall_handoff_summary` for current team status

### 3. Present Response Brief

```
## Incident Response Brief

### Summary
**[Incident title]** (ID: [id])
- **Status**: [status] | **Severity**: [severity]
- **Started**: [time] ([duration] ago)
- **Affected services**: [list]

### Timeline
[Key events from alert and incident data, chronological]

### Related Historical Incidents
[Top matches from find_related_incidents]
- [Incident title] ([date]) - Confidence: [score] - Resolution: [what fixed it]
[If all scores < 0.3: "Low confidence matches -- manual investigation recommended"]

### Suggested Solutions
[From suggest_solutions, ranked by confidence]
1. [Solution] (confidence: [score], source: [incident/runbook])

### Current Responders & On-Call
- **Assigned**: [responders]
- **On-call**: [name] (since [time])
- **Next handoff**: [time]

### Available Actions
The following actions require your explicit approval:
- Update severity
- Add responder
- Post status update
- Escalate to next on-call
```

### 4. Human-in-the-Loop for Write Operations

**CRITICAL**: NEVER execute write operations automatically. Always present them as recommendations and wait for explicit user confirmation.

Write operations include:
- `updateIncident` (changing severity, status, or any incident field)
- Adding or removing responders
- Posting status updates
- Escalating incidents
- Any other mutation of Rootly data

When the user approves an action, execute it and report the result.

### 5. Error Handling

- **MCP tool errors**: Report the specific error message and suggest manual steps (e.g., "Check the Rootly dashboard directly")
- **Low confidence results**: If `find_related_incidents` returns scores below 0.3, explicitly flag: "These matches are low confidence -- consider manual investigation"
- **Missing data**: If any tool call returns empty results, note it and continue with available data rather than failing entirely
