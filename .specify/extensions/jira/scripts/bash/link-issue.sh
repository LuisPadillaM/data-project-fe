#!/usr/bin/env bash
# Jira extension: link-issue.sh
# Link a feature spec to an existing Jira issue key.
#
# Usage: link-issue.sh <ISSUE_KEY> [FEATURE_NUM]

set -e

ISSUE_KEY="${1:-}"
FEATURE_NUM="${2:-}"

if [ -z "$ISSUE_KEY" ]; then
    echo "Usage: $0 <ISSUE_KEY> [FEATURE_NUM]" >&2
    exit 1
fi

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/jira-common.sh"

REPO_ROOT=$(_find_project_root "$SCRIPT_DIR") || REPO_ROOT="$(pwd)"
cd "$REPO_ROOT"

JIRA_CONFIG_FILE="$REPO_ROOT/.specify/extensions/jira/jira-config.yml"
JIRA_LINKS_FILE="$REPO_ROOT/.specify/memory/jira-links.yml"
JIRA_TASK_MAP_FILE="$REPO_ROOT/.specify/memory/jira-task-map.yml"

# Resolve feature number from branch if not provided
if [ -z "$FEATURE_NUM" ]; then
    FEATURE_NUM=$(_feature_num_from_branch)
fi

# Validate the issue exists in Jira
echo "[jira] Validating ${ISSUE_KEY}..." >&2
response=$(_jira_api GET "/issue/${ISSUE_KEY}?fields=summary,status")

if echo "$response" | grep -q '"errorMessages"'; then
    echo "[jira] Error: Issue ${ISSUE_KEY} not found or inaccessible." >&2
    echo "$response" >&2
    exit 1
fi

# Extract summary for confirmation output
summary=$(echo "$response" | grep -o '"summary":"[^"]*"' | head -1 | sed 's/"summary":"//;s/"//')

_store_jira_link "$FEATURE_NUM" "$ISSUE_KEY"

base_url=$(jira_setting "JIRA_BASE_URL" "base_url")
echo "[jira] ✓ Feature '${FEATURE_NUM}' linked to ${ISSUE_KEY}: ${summary}" >&2
[ -n "$base_url" ] && echo "       View: ${base_url%/}/browse/${ISSUE_KEY}" >&2
