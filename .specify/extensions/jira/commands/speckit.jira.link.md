---
description: "Link the current feature spec to an existing Jira issue"
---

# Link Feature to Jira Issue

Associate the current feature specification with an existing Jira issue key. The link is
stored in `.specify/memory/jira-links.yml` and can be referenced by other Jira commands.

## User Input

```text
$ARGUMENTS
```

If `$ARGUMENTS` contains a Jira issue key (e.g. `PROJ-123`), use it directly.
Otherwise prompt the user: **"Enter the Jira issue key to link (e.g. PROJ-123):"**

## Prerequisites

- A feature spec directory must exist under `specs/` for the current branch.
- Credentials must be available (env vars or `jira-config.yml`).

## Execution

Run the script with the resolved issue key and the current feature number:

```bash
.specify/extensions/jira/scripts/bash/link-issue.sh <ISSUE_KEY> [FEATURE_NUM]
```

- `FEATURE_NUM` is extracted from the current branch name (e.g. branch `003-dashboard` → `003`).
  If the branch cannot be detected, pass the spec directory path instead.
- The script validates that the issue exists in Jira before storing the link.

## Output

On success:
```
[jira] ✓ Feature 003 linked to PROJ-123
       View: https://yourcompany.atlassian.net/browse/PROJ-123
```

## Graceful Degradation

- If `curl` is not installed: warn and skip.
- If credentials are missing: print setup instructions and skip.
- If the issue key does not exist in Jira: print the API error and exit non-zero.
- If not inside a spec feature branch: warn and skip without error.
