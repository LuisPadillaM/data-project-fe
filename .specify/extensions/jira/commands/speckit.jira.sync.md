---
description: "Sync tasks from tasks.md to Jira subtasks under the linked issue"
---

# Sync Tasks to Jira

Parse `tasks.md` for the current feature and create Jira subtasks under the parent issue
linked via `speckit.jira.link` or `speckit.jira.create`. Already-synced tasks (tracked in
`.specify/memory/jira-task-map.yml`) are skipped to prevent duplicates.

## User Input

```text
$ARGUMENTS
```

Optional flags:
- `--parent <ISSUE-KEY>` — override the parent issue (ignores stored link)
- `--dry-run` — print what would be created without calling the API

## Prerequisites

- `tasks.md` must exist under `specs/<feature>/`.
- The feature must be linked to a Jira issue (run `speckit.jira.link` or `speckit.jira.create` first),
  unless `--parent` is provided.
- Credentials must be available.

## What Gets Synced

Each unchecked task line (`- [ ] TXXX ...`) in `tasks.md` becomes a Jira subtask:

| tasks.md field | Jira field |
|---|---|
| Task description | Summary |
| Task ID (e.g. `T012`) | Label `speckit-T012` |
| Phase heading | Label (e.g. `phase-foundational`) |
| Parent issue key | Parent |

Checked tasks (`- [x]`) are skipped.

## Execution

```bash
.specify/extensions/jira/scripts/bash/sync-tasks.sh <SPEC_DIR> [--parent <key>] [--dry-run]
```

`SPEC_DIR` is resolved from the current branch name as in other Jira commands.

## Task Map

After each successful sync, `.specify/memory/jira-task-map.yml` is updated:

```yaml
003:
  T001: PROJ-457
  T002: PROJ-458
```

On subsequent runs, tasks already present in the map are skipped.

## Output

```
[jira] Syncing 12 tasks to PROJ-456...
[jira] ✓ T001 → PROJ-457 (Create project structure)
[jira] ✓ T002 → PROJ-458 (Initialize dependencies)
[jira] — T003 already synced (PROJ-459), skipped
[jira] Done: 11 created, 1 skipped
```

## Graceful Degradation

- If `curl` is not installed: warn and skip.
- If credentials are missing: print setup instructions and exit non-zero.
- If no parent issue is linked: print instructions to run `speckit.jira.link` first.
- If `tasks.md` is not found: warn and exit non-zero.
- On partial failure (one subtask fails): log the error, continue remaining tasks, exit non-zero at the end.
