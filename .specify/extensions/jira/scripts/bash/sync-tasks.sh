#!/usr/bin/env bash
# Jira extension: sync-tasks.sh
# Sync unchecked tasks from tasks.md to Jira subtasks.
#
# Usage: sync-tasks.sh <SPEC_DIR> [--parent <ISSUE-KEY>] [--dry-run]

set -e

SPEC_DIR="${1:-}"
PARENT_KEY=""
DRY_RUN=false

shift || true
while [ $# -gt 0 ]; do
    case "$1" in
        --parent)   PARENT_KEY="$2"; shift 2 ;;
        --dry-run)  DRY_RUN=true; shift ;;
        *) shift ;;
    esac
done

if [ -z "$SPEC_DIR" ]; then
    echo "Usage: $0 <SPEC_DIR> [--parent <KEY>] [--dry-run]" >&2
    exit 1
fi

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/jira-common.sh"

REPO_ROOT=$(_find_project_root "$SCRIPT_DIR") || REPO_ROOT="$(pwd)"
cd "$REPO_ROOT"

JIRA_CONFIG_FILE="$REPO_ROOT/.specify/extensions/jira/jira-config.yml"
JIRA_LINKS_FILE="$REPO_ROOT/.specify/memory/jira-links.yml"
JIRA_TASK_MAP_FILE="$REPO_ROOT/.specify/memory/jira-task-map.yml"

TASKS_FILE="${SPEC_DIR%/}/tasks.md"
if [ ! -f "$TASKS_FILE" ]; then
    echo "[jira] Error: tasks.md not found at ${TASKS_FILE}" >&2
    exit 1
fi

# Resolve parent issue key
if [ -z "$PARENT_KEY" ]; then
    feature_num=$(_feature_num_from_branch)
    PARENT_KEY=$(_get_jira_link "$feature_num" || true)
fi

if [ -z "$PARENT_KEY" ]; then
    echo "[jira] Error: No linked Jira issue found for this feature." >&2
    echo "       Run 'speckit.jira.link' or 'speckit.jira.create' first," >&2
    echo "       or pass --parent <ISSUE-KEY> explicitly." >&2
    exit 1
fi

subtask_type=$(jira_setting "" "subtask_type" "Subtask")
project_key=$(jira_setting "JIRA_PROJECT_KEY" "project_key")
_require_credential "$project_key" "JIRA_PROJECT_KEY"

# Initialise task map file
[ ! -f "$JIRA_TASK_MAP_FILE" ] && printf "# Jira task map — managed by speckit.jira.sync\n" > "$JIRA_TASK_MAP_FILE"

feature_section="${feature_num:-unknown}"
# Ensure a section for this feature exists in the map
grep -q "^${feature_section}:" "$JIRA_TASK_MAP_FILE" 2>/dev/null \
    || echo "${feature_section}:" >> "$JIRA_TASK_MAP_FILE"

_task_already_synced() {
    local task_id="$1"
    grep -q "^[[:space:]]*${task_id}:" "$JIRA_TASK_MAP_FILE" 2>/dev/null
}

_store_task_link() {
    local task_id="$1" issue_key="$2"
    # Append under the feature section
    sed -i.bak "/^${feature_section}:/a\\  ${task_id}: ${issue_key}" "$JIRA_TASK_MAP_FILE"
    rm -f "${JIRA_TASK_MAP_FILE}.bak"
}

# Parse unchecked task lines: "- [ ] TXXX description"
created=0 skipped=0 failed=0 total=0
current_phase="general"

while IFS= read -r line; do
    # Track current phase heading
    if echo "$line" | grep -qE '^## Phase'; then
        current_phase=$(echo "$line" | sed 's/^## //' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -dc 'a-z0-9-')
        continue
    fi

    # Only process unchecked tasks
    echo "$line" | grep -qE '^\s*- \[ \] ' || continue

    task_id=$(echo "$line" | grep -oE '\bT[0-9]{3,}\b' | head -1 || true)
    [ -z "$task_id" ] && continue

    summary=$(echo "$line" | sed 's/^\s*- \[ \] //' | sed "s/\b${task_id}\b//" | \
              sed 's/\[P\]//g;s/\[US[0-9]*\]//g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    [ -z "$summary" ] && summary="$task_id"

    total=$((total + 1))

    if _task_already_synced "$task_id"; then
        existing=$(grep "^[[:space:]]*${task_id}:" "$JIRA_TASK_MAP_FILE" | sed "s/^[[:space:]]*${task_id}:[[:space:]]*//" | tr -d '[:space:]')
        echo "[jira] — ${task_id} already synced (${existing}), skipped" >&2
        skipped=$((skipped + 1))
        continue
    fi

    if $DRY_RUN; then
        echo "[jira] [dry-run] Would create subtask: ${task_id} — ${summary}" >&2
        created=$((created + 1))
        continue
    fi

    # Escape for JSON
    summary_escaped=$(printf '%s' "$summary" | sed 's/\\/\\\\/g;s/"/\\"/g')

    body=$(cat <<JSON
{
  "fields": {
    "project":   { "key": "${project_key}" },
    "summary":   "${summary_escaped}",
    "issuetype": { "name": "${subtask_type}" },
    "parent":    { "key": "${PARENT_KEY}" },
    "labels":    ["speckit-${task_id}", "phase-${current_phase}"]
  }
}
JSON
)

    response=$(_jira_api POST "/issue" "$body")
    if echo "$response" | grep -q '"errorMessages"\|"errors":{[^}]*[^}]'; then
        echo "[jira] ✗ ${task_id} failed: $(echo "$response" | grep -o '"errorMessages":\[[^]]*\]')" >&2
        failed=$((failed + 1))
        continue
    fi

    issue_key=$(echo "$response" | grep -o '"key":"[^"]*"' | head -1 | sed 's/"key":"//;s/"//')
    if [ -n "$issue_key" ]; then
        _store_task_link "$task_id" "$issue_key"
        echo "[jira] ✓ ${task_id} → ${issue_key} (${summary})" >&2
        created=$((created + 1))
    else
        echo "[jira] ✗ ${task_id}: could not parse key from response" >&2
        failed=$((failed + 1))
    fi
done < "$TASKS_FILE"

echo "[jira] Done: ${created} created, ${skipped} skipped, ${failed} failed (${total} total)" >&2
[ "$failed" -gt 0 ] && exit 1 || exit 0
