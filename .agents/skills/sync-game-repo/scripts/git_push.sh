#!/usr/bin/env bash
set -e

COMMIT_MSG="${1:-feat: sync game scripts from Roblox Studio}"

# Always cd to the git repository root
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "Checking git status..."
git status -s

if [ -z "$(git status -s)" ]; then
    echo "No changes detected. Repository is already up to date."
    exit 0
fi

echo "Staging changed files..."
git add -A

echo "Committing changes..."
git commit -m "$COMMIT_MSG"

echo "Pushing to GitHub..."
git push origin main

echo "Sync completed successfully!"
