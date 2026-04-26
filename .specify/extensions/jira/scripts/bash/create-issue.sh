#!/usr/bin/env bash
# Jira extension: create-issue.sh
# Create a Jira issue from a feature spec.md and store the resulting key.
#
# Usage: create-issue.sh <SPEC_DIR> [--type <IssueType>] [--epic <EPIC-KEY>]

set -e

SPEC_DIR="${1:-}"
ISSUE_TYPE=""
EPIC_KEY=""

shift || true
while [ $# -gt 0 ]; do
    case "$1" in
        --type)  ISSUE_TYPE="$2"; shift 2 ;;
        --epic)  EPIC_KEY="$2";   shift 2 ;;
        *) shift ;;
    esac
done

if [ -z "$SPEC_DIR" ]; then
    echo "Usage: $0 <SPEC_DIR> [--type <IssueType>] [--epic <EPIC-KEY>]" >&2
    exit 1
fi

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/jira-common.sh"

REPO_ROOT=$(_find_project_root "$SCRIPT_DIR") || REPO_ROOT="$(pwd)"
cd "$REPO_ROOT"

JIRA_CONFIG_FILE="$REPO_ROOT/.specify/extensions/jira/jira-config.yml"
JIRA_LINKS_FILE="$REPO_ROOT/.specify/memory/jira-links.yml"
JIRA_TASK_MAP_FILE="$REPO_ROOT/.specify/memory/jira-task-map.yml"

SPEC_FILE="${SPEC_DIR%/}/spec.md"
if [ ! -f "$SPEC_FILE" ]; then
    echo "[jira] Error: spec.md not found at ${SPEC_FILE}" >&2
    exit 1
fi

project_key=$(jira_setting "JIRA_PROJECT_KEY" "project_key")
_require_credential "$project_key" "JIRA_PROJECT_KEY"

[ -z "$ISSUE_TYPE" ] && ISSUE_TYPE=$(jira_setting "" "issue_type" "Story")

# Extract title (first H1) and first non-empty paragraph after it
title=$(grep -m1 '^# ' "$SPEC_FILE" | sed 's/^# //' | sed 's/Feature Specification: //')
[ -z "$title" ] && title=$(basename "$SPEC_DIR")

description=$(awk '/^## /{p=0} /^## (Summary|User Scenarios)/{p=1; next} p && /^[^#\-\*[:space:]]/{print; exit}' "$SPEC_FILE" || true)
[ -z "$description" ] && description="Created from spec: ${SPEC_DIR}"

# Escape for JSON
_json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g;s/$/\\n/' | tr -d '\n' | sed 's/\\n$//'; }

title_escaped=$(_json_escape "$title")
desc_escaped=$(_json_escape "$description")

# Build request body (Jira API v3 uses Atlassian Document Format for description)
body=$(cat <<JSON
{
  "fields": {
    "project":   { "key": "${project_key}" },
    "summary":   "${title_escaped}",
    "issuetype": { "name": "${ISSUE_TYPE}" },
    "description": {
      "type": "doc", "version": 1,
      "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "${desc_escaped}" }] }]
    }
  }
}
JSON
)

# Append epic link if provided (field name varies by Jira config; try both common names)
if [ -n "$EPIC_KEY" ]; then
    body=$(echo "$body" | sed "s/^}/,\"customfield_10014\": \"${EPIC_KEY}\"}/")
fi

echo "[jira] Creating ${ISSUE_TYPE} in ${project_key}..." >&2
response=$(_jira_api POST "/issue" "$body")

if echo "$response" | grep -q '"errorMessages"\|"errors":{[^}]*[^}][^}]'; then
    echo "[jira] Error creating issue:" >&2
    echo "$response" >&2
    exit 1
fi

issue_key=$(echo "$response" | grep -o '"key":"[^"]*"' | head -1 | sed 's/"key":"//;s/"//')
if [ -z "$issue_key" ]; then
    echo "[jira] Error: Could not parse issue key from response:" >&2
    echo "$response" >&2
    exit 1
fi

feature_num=$(_feature_num_from_branch)
_store_jira_link "$feature_num" "$issue_key"

base_url=$(jira_setting "JIRA_BASE_URL" "base_url")
echo "[jira] ✓ Created ${issue_key}: ${title}" >&2
[ -n "$base_url" ] && echo "       View: ${base_url%/}/browse/${issue_key}" >&2
echo "[jira] ✓ Stored link: feature '${feature_num}' → ${issue_key}" >&2
