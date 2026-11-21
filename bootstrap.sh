#!/bin/bash
set -uo pipefail

# Pin the mise version for any setup script that installs mise
# (the mise.run installer reads MISE_VERSION).
export MISE_VERSION=v2026.11.11

LOG_DIR="$(mktemp -d)"
failed=()

# Find every git repo under the current directory and run its own setup script
# (.claude/cloud/setup.sh and/or setup.py), if it has one. CLAUDE_MULTI_REPO=1
# tells that script it's sharing the environment with other repos, so it can
# skip heavy setup it doesn't need.
while IFS= read -r -d '' gitdir; do
  repo="$(dirname "$gitdir")"
  [ -f "$repo/.claude/cloud/setup.sh" ] || [ -f "$repo/.claude/cloud/setup.py" ] || continue

  echo "==> $repo"
  # Run from inside the repo; show output live and also save it to a log file.
  (
    cd "$repo" || exit 1
    export CLAUDE_MULTI_REPO=1
    status=0
    if [ -f .claude/cloud/setup.sh ]; then bash .claude/cloud/setup.sh || status=1; fi
    if [ -f .claude/cloud/setup.py ]; then python3 .claude/cloud/setup.py || status=1; fi
    exit $status
  ) 2>&1 | tee "$LOG_DIR/$(basename "$repo").log"
  # Remember failures but keep going, so one broken repo doesn't block the rest.
  [ "${PIPESTATUS[0]}" -eq 0 ] || failed+=("$(basename "$repo")")
done < <(find "$PWD" -maxdepth 2 -name .git -print0)

# After all repos have run, fail the whole script if any of them failed.
if [ "${#failed[@]}" -gt 0 ]; then
  echo "Setup failed in: ${failed[*]} (logs in $LOG_DIR/<repo>.log)" >&2
  exit 1
fi

