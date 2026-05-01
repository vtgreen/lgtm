#!/usr/bin/env bash
# Start the LGTM server if nothing is listening on port 9900, and register
# the current Claude session's cwd as an LGTM project.
# During development, npm run dev:all occupies the port — start is skipped then.
if ! lsof -ti:9900 >/dev/null 2>&1; then
  # Install production deps on first run (or when package.json changes).
  # Uses CLAUDE_PLUGIN_DATA for persistent storage across sessions.
  if [ -n "${CLAUDE_PLUGIN_DATA}" ]; then
    if ! diff -q "${CLAUDE_PLUGIN_ROOT}/package.json" "${CLAUDE_PLUGIN_DATA}/package.json" >/dev/null 2>&1; then
      cp "${CLAUDE_PLUGIN_ROOT}/package.json" "${CLAUDE_PLUGIN_DATA}/package.json"
      (cd "${CLAUDE_PLUGIN_DATA}" && npm install --production --ignore-scripts >/dev/null 2>&1) || rm -f "${CLAUDE_PLUGIN_DATA}/package.json"
    fi
    export NODE_PATH="${CLAUDE_PLUGIN_DATA}/node_modules"
  fi

  # Fall back to plugin root node_modules (local dev)
  if [ -z "${NODE_PATH}" ] && [ -d "${CLAUDE_PLUGIN_ROOT}/node_modules" ]; then
    export NODE_PATH="${CLAUDE_PLUGIN_ROOT}/node_modules"
  fi

  nohup node "${CLAUDE_PLUGIN_ROOT}/dist/server/server.js" --port 9900 >/dev/null 2>&1 &
  sleep 1
  lsof -ti:9900 >/dev/null 2>&1 || echo "Warning: LGTM server failed to start on port 9900" >&2
fi

# --- auto-register cwd as LGTM project (Phase 1) ---
cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
repo=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0

# Wait for server to be reachable, max ~5s. Probes GET /projects since
# there is no dedicated /health endpoint.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl --silent --fail --max-time 1 "http://127.0.0.1:9900/projects" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

curl --silent --fail --max-time 2 \
  -X POST "http://127.0.0.1:9900/projects" \
  -H "Content-Type: application/json" \
  --data "{\"repoPath\":\"$repo\"}" \
  >/dev/null 2>&1 || true
