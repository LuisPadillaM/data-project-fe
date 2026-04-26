#!/usr/bin/env bash
# Jira extension: jira-common.sh
# Shared helpers sourced by all Jira scripts.

# ── Project root ─────────────────────────────────────────────────────────────

_find_project_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.specify" ] || [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# ── Config helpers ────────────────────────────────────────────────────────────

# Read a leaf key from jira-config.yml (naive grep — no full YAML parser needed).
# Usage: _jira_config_value <leaf_key>
_jira_config_value() {
    local key="$1"
    local config_file="${JIRA_CONFIG_FILE:-}"
    [ -z "$config_file" ] || [ ! -f "$config_file" ] && return 1
    grep -m1 "^[[:space:]]*${key}:[[:space:]]" "$config_file" \
        | sed "s/^[^:]*:[[:space:]]*//" \
        | tr -d '"'"'"
}

# Resolve: env var > config file > default.
# Usage: jira_setting <ENV_VAR> <config_leaf_key> [default]
jira_setting() {
    local env_var="$1" config_key="$2" default="${3:-}"
    local val="${!env_var:-}"
    [ -z "$val" ] && val=$(_jira_config_value "$config_key" 2>/dev/null || true)
    [ -z "$val" ] && val="$default"
    echo "$val"
}

# Abort with a credentials setup message when a required value is empty.
_require_credential() {
    local val="$1" env_var="$2"
    if [ -z "$val" ]; then
        echo "[jira] Error: $env_var is not set." >&2
        echo "       Set it as an environment variable or in .specify/extensions/jira/jira-config.yml" >&2
        exit 1
    fi
}

# ── API call ──────────────────────────────────────────────────────────────────

# Usage: _jira_api <METHOD> <path> [json_body]
# Returns the raw response body; exits non-zero on curl failure.
_jira_api() {
    local method="$1" path="$2" body="${3:-}"

    if ! command -v curl >/dev/null 2>&1; then
        echo "[jira] Error: curl is required but not installed." >&2
        exit 1
    fi

    local base_url email token
    base_url=$(jira_setting "JIRA_BASE_URL"    "base_url")
    email=$(jira_setting    "JIRA_EMAIL"       "email")
    token=$(jira_setting    "JIRA_API_TOKEN"   "api_token")

    _require_credential "$base_url" "JIRA_BASE_URL"
    _require_credential "$email"    "JIRA_EMAIL"
    _require_credential "$token"    "JIRA_API_TOKEN"

    local url="${base_url%/}/rest/api/3${path}"
    local args=(-s -X "$method" "$url" -u "${email}:${token}" -H "Accept: application/json")
    [ -n "$body" ] && args+=(-H "Content-Type: application/json" -d "$body")

    curl "${args[@]}"
}

# ── Issue link store ──────────────────────────────────────────────────────────

JIRA_LINKS_FILE="${REPO_ROOT:-$(pwd)}/.specify/memory/jira-links.yml"
JIRA_TASK_MAP_FILE="${REPO_ROOT:-$(pwd)}/.specify/memory/jira-task-map.yml"

_store_jira_link() {
    local feature="$1" issue_key="$2"
    [ ! -f "$JIRA_LINKS_FILE" ] && printf "# Jira issue links — managed by speckit.jira\nlinks:\n" > "$JIRA_LINKS_FILE"
    # Remove existing entry then append updated one
    grep -v "^[[:space:]]*${feature}:" "$JIRA_LINKS_FILE" > "${JIRA_LINKS_FILE}.tmp" 2>/dev/null || true
    mv "${JIRA_LINKS_FILE}.tmp" "$JIRA_LINKS_FILE"
    grep -q "^links:" "$JIRA_LINKS_FILE" || echo "links:" >> "$JIRA_LINKS_FILE"
    echo "  ${feature}: ${issue_key}" >> "$JIRA_LINKS_FILE"
}

_get_jira_link() {
    local feature="$1"
    [ -f "$JIRA_LINKS_FILE" ] || return 1
    grep "^[[:space:]]*${feature}:" "$JIRA_LINKS_FILE" \
        | sed "s/^[[:space:]]*${feature}:[[:space:]]*//" | tr -d '[:space:]'
}

# ── Branch → feature number ───────────────────────────────────────────────────

_feature_num_from_branch() {
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    # Strip gitflow prefix (e.g. feat/003-name → 003-name)
    branch=$(echo "$branch" | sed 's|^[^/]*/||')
    echo "$branch" | grep -oE '^[0-9]+' || echo "$branch"
}
