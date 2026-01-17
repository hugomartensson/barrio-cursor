#!/bin/bash
# Script to create GitHub repository via API
# Usage: ./create-repo.sh <GITHUB_TOKEN>

GITHUB_TOKEN="${1:-$GITHUB_TOKEN}"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GitHub token required"
    echo "Usage: ./create-repo.sh <GITHUB_TOKEN>"
    echo "Or set GITHUB_TOKEN environment variable"
    exit 1
fi

curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/user/repos \
  -d '{
    "name": "barrio-cursor",
    "description": "Hyperlocal Events App - iOS app with backend API",
    "private": true,
    "auto_init": false
  }'

echo ""
echo "Repository created! You can now push your code with:"
echo "  git push -u origin main"
