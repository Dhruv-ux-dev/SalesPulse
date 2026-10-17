#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ./scripts/push-to-github.sh https://github.com/YOUR-USERNAME/SalesPulse.git" >&2
  echo "Create an empty GitHub repository first (do not initialize it with a README or license)." >&2
  exit 2
fi

remote_url="$1"
if [[ ! "$remote_url" =~ ^https://github\.com/[^/]+/[^/]+\.git$ ]]; then
  echo "Please pass an HTTPS GitHub repository URL ending in .git." >&2
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Git is required. Install Git, then rerun this script." >&2
  exit 2
fi

if [[ ! -d .git ]]; then
  git init -b main
fi

git add .
if ! git diff --cached --quiet; then
  git commit -m "Initial commit: build SalesPulse Salesforce app"
fi

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$remote_url"
else
  git remote add origin "$remote_url"
fi

git push -u origin main
