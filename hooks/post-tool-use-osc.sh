#!/usr/bin/env bash
# Phase 2: notify cmux on selected LGTM MCP tool calls.
#
# RECON Q5 found that Claude Code captures hook stdout into the debug log,
# so OSC bytes written to stdout never reach the terminal. We use the
# `cmux notify` CLI instead (filename retained for task continuity).
#
# Claude Code passes the PostToolUse payload as JSON on stdin (see RECON Q4).
# We extract `tool_name` and `tool_input.repoPath` (falling back to `cwd`).
set -e
payload=$(cat)
tool=$(printf '%s' "$payload" | jq -r .tool_name)
repo=$(printf '%s' "$payload" | jq -r '.tool_input.repoPath // .cwd')
slug=$(printf '%s' "$(basename "$repo")" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-')
case "$tool" in
  mcp__lgtm__comment)      event="new comment" ;;
  mcp__lgtm__add_document) event="document added" ;;
  mcp__lgtm__set_analysis) event="analysis updated" ;;
  mcp__lgtm__reply)        event="reply" ;;
  *) exit 0 ;;
esac
cmux notify --title "LGTM" --subtitle "$slug" --body "$event" >/dev/null 2>&1 || true
