---
description: "Create a new Jira issue from the current feature spec"
---

# Create Jira Issue from Spec

Read the current feature's `spec.md`, extract the title and summary, and create a new Jira
issue. The resulting issue key is stored in `.specify/memory/jira-links.yml`.

## User Input

```text
$ARGUMENTS
```

Optional overrides accepted in `$ARGUMENTS`:
- `--type <IssueType>` — override the default issue type (default: value from `jira-config.yml`)
- `--epic <EPIC-KEY>` — link the created issue to an epic

## Prerequisites

- A `spec.md` must exist for the current feature branch under `specs/<feature>/`.
- Credentials must be available (env vars or `jira-config.yml`).
- `JIRA_PROJECT_KEY` or `jira.project_key` in config must be set.

## What Gets Mapped

| spec.md field | Jira field |
|---|---|
| Feature name (H1) | Summary |
| First paragraph under `## Summary` or feature description | Description (first paragraph) |
| Issue type from config | Issue Type |
| `--epic` argument (if provided) | Epic Link |

## Execution

```bash
.specify/extensions/jira/scripts/bash/create-issue.sh <SPEC_DIR> [--type <type>] [--epic <key>]
```

`SPEC_DIR` is resolved to `specs/<feature_num>-*/` from the current branch name.

## Output

On success:
```
[jira] ✓ Created PROJ-456: Dashboard overview feature
       View: https://yourcompany.atlassian.net/browse/PROJ-456
[jira] ✓ Stored link: feature 003 → PROJ-456
```

## Graceful Degradation

- If `curl` is not installed: warn and skip.
- If credentials or `project_key` are missing: print setup instructions and exit non-zero.
- If `spec.md` is not found: warn and exit non-zero.
- If the Jira API returns an error: print the full error body and exit non-zero.
