#!/usr/bin/env bash
set -euo pipefail

for branch in agent/add-android-ci feature/sprint5-merge; do
  if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    git push origin --delete "$branch"
  fi
done
