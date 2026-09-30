#!/usr/bin/env bash
# Generate split upstream-sync release notes.
#
# Emits at most two markdown sections:
#   ### TEESimulator-RS 更新
#   ### Tricky Addon 更新
# A section is written ONLY when its commit range (from..to) contains commits;
# when both ranges are empty the script prints nothing (caller decides fallback).
#
# Usage: sync-notes.sh   (prints notes to stdout)
# Env:
#   TEES_REPO  TEES_FROM_SHA  TEES_TO_SHA
#   TA_REPO    TA_FROM_SHA    TA_TO_SHA
#   GH_TOKEN   (used implicitly by `gh api`)
#
# Notes:
#   - Commit list is capped at MAX_COMMITS per section ("...and N more" tail).
#   - If the from..to compare fails (e.g. upstream force-push diverged history),
#     the section falls back to the most recent commits up to `to`.

set -euo pipefail

MAX_COMMITS=30

tmpf=$(mktemp)
trap 'rm -f "$tmpf"' EXIT

emit_section() {
    local title="$1" repo="$2" from="$3" to="$4"
    local commits count

    [ -n "$repo" ] || return 0
    [ -n "$to" ] || return 0
    [ -n "$from" ] || return 0
    [ "$from" != "$to" ] || return 0

    commits=""
    if gh api "repos/$repo/compare/$from...$to" \
            --jq '.commits[] | "- `" + .sha[0:7] + "` " + (.commit.message | split("\n")[0])' \
            > "$tmpf" 2>/dev/null && [ -s "$tmpf" ]; then
        commits=$(cat "$tmpf")
    else
        if gh api "repos/$repo/commits?sha=$to&per_page=$MAX_COMMITS" \
                --jq '.[] | "- `" + .sha[0:7] + "` " + (.commit.message | split("\n")[0])' \
                > "$tmpf" 2>/dev/null && [ -s "$tmpf" ]; then
            commits=$(cat "$tmpf")
        fi
    fi
    [ -n "$commits" ] || { rm -f "$tmpf"; return 0; }

    count=$(printf '%s\n' "$commits" | wc -l | tr -d ' ')

    printf '### %s\n\n' "$title"
    if [ "$count" -gt "$MAX_COMMITS" ]; then
        printf '%s\n' "$commits" | head -n "$MAX_COMMITS"
        printf '\n- …and %s more\n\n' "$((count - MAX_COMMITS))"
    else
        printf '%s\n\n' "$commits"
    fi
    rm -f "$tmpf"
}

EMITTED=0

OUT=$(emit_section "TEESimulator-RS 更新" "${TEES_REPO:-}" "${TEES_FROM_SHA:-}" "${TEES_TO_SHA:-}") || EMITTED=1
if [ -n "$OUT" ]; then EMITTED=1; printf '%s\n\n' "$OUT"; fi

OUT=$(emit_section "Tricky Addon 更新" "${TA_REPO:-}" "${TA_FROM_SHA:-}" "${TA_TO_SHA:-}") || EMITTED=1
if [ -n "$OUT" ]; then EMITTED=1; printf '%s\n\n' "$OUT"; fi

if [ "$EMITTED" = "1" ]; then
    printf -- '---\n> Synced: TEES@%s / TA@%s\n' \
        "${TEES_TO_SHA:0:7}" "${TA_TO_SHA:0:7}"
fi
