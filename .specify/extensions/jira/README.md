# Jira Integration Extension

Link Spec Kit features to Jira issues, create issues from specs, and sync tasks as subtasks.

## Setup

1. Generate an Atlassian API token at <https://id.atlassian.com/manage-profile/security/api-tokens>

2. Set credentials as environment variables (recommended — keeps secrets out of the repo):

   ```bash
   export JIRA_BASE_URL="https://yourcompany.atlassian.net"
   export JIRA_EMAIL="you@company.com"
   export JIRA_API_TOKEN="your-token"
   export JIRA_PROJECT_KEY="PROJ"
   ```

   Or fill in `.specify/extensions/jira/jira-config.yml` directly (do not commit that file if it contains a token).

## Commands

| Command | Description |
|---|---|
| `speckit.jira.link` | Link current feature to an existing issue (e.g. `PROJ-123`) |
| `speckit.jira.create` | Create a new Jira issue from `spec.md` |
| `speckit.jira.sync` | Push unchecked tasks from `tasks.md` as subtasks |

## Hooks

| Event | Command | Behaviour |
|---|---|---|
| `after_specify` | `speckit.jira.link` | Prompt to link after a spec is created (optional) |
| `after_tasks` | `speckit.jira.sync` | Prompt to sync tasks after `tasks.md` is generated (optional) |

## Stored Data

- `.specify/memory/jira-links.yml` — maps feature numbers → Jira issue keys
- `.specify/memory/jira-task-map.yml` — maps task IDs → Jira subtask keys (prevents duplicates on re-sync)

## Scripts

All scripts are in `scripts/bash/` and require `curl`. `jq` is not required but improves output if available.

```
scripts/bash/
├── jira-common.sh    # Sourced by all scripts — config, API helper, link store
├── link-issue.sh     # Validate and store link to existing issue
├── create-issue.sh   # POST new issue from spec.md
└── sync-tasks.sh     # POST subtasks from tasks.md
```
