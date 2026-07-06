#!/bin/sh
set -eu

branch="$(git rev-parse --abbrev-ref HEAD)"

if [ "$branch" != "main" ]; then
  echo "Auto-push skipped: current branch is $branch."
  exit 0
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Auto-push skipped: working tree has uncommitted changes."
  exit 0
fi

echo "Auto-pushing main and tags to origin..."
git push origin main
git push origin --tags
