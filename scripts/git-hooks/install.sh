#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

git config core.hooksPath scripts/git-hooks
echo "Configured Git hooks path: scripts/git-hooks"
echo "Set COMMENDO_SKIP_PRE_PUSH=1 to skip local pre-push checks for one push."
