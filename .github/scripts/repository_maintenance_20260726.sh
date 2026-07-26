#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_API_URL:?GITHUB_API_URL is required}"

git fetch origin '+refs/heads/*:refs/remotes/origin/*' --prune

report=repository-maintenance-report.md
: > "$report"
{
  echo '# Repository maintenance report (2026-07-26)'
  echo
  echo "Repository: \`$GITHUB_REPOSITORY\`"
  echo
} >> "$report"

main_commit=$(git rev-parse origin/main)
main_tree=$(git rev-parse 'origin/main^{tree}')
camera_commit='missing'
camera_tree='missing'
tree_equal='no'
if git show-ref --verify --quiet refs/remotes/origin/feature/camera-scanner; then
  camera_commit=$(git rev-parse origin/feature/camera-scanner)
  camera_tree=$(git rev-parse 'origin/feature/camera-scanner^{tree}')
  if [[ "$main_tree" == "$camera_tree" ]]; then
    tree_equal='yes'
  fi
fi

{
  echo '## Exact tree comparison'
  echo
  echo "- main commit: \`$main_commit\`"
  echo "- main tree: \`$main_tree\`"
  echo "- feature/camera-scanner commit: \`$camera_commit\`"
  echo "- feature/camera-scanner tree: \`$camera_tree\`"
  echo "- exact tree equality: **$tree_equal**"
  echo
} >> "$report"

tag='archive/main-20260726'
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  tag_result='already existed'
else
  git tag -a "$tag" "$main_commit" -m 'Archive main before DB migration test and repository cleanup (2026-07-26)'
  git push origin "refs/tags/$tag"
  tag_result='created'
fi
{
  echo '## Archive tag'
  echo
  echo "- \`$tag\`: $tag_result at \`$main_commit\`"
  echo
} >> "$report"

delete_candidates=(
  'feature/camera-scanner'
  'feature/accessibility'
  'accessibility-merge'
  'feature/accessibility-merge'
  'feature/ui-polish'
  'feature/export-and-sharing'
  'feature/ocr-sqlite-admob'
  'feature/polish-and-release-prep'
  'feature/quote-revision'
  'feature/requirements-checklist'
  'feature/test-emulator'
  'feature/ocr-confidence'
  'feature/sprint-3'
  'sprint-3-rebased'
  'feature/sprint-3-rebased'
  'agent/sprint-3-rebased'
  'feature/sprint4-validation-and-tests'
  'feature/sprint5-emulator-and-release-validation'
  'agent/fix-full-source-review'
  'agent/fix-full-source-review-20260723'
  'agent/sprint-3-apply'
  'temp/sprint-3-trigger'
  'agent/repository-maintenance-20260726'
)

echo '## Known obsolete branch cleanup' >> "$report"
echo >> "$report"
for branch in "${delete_candidates[@]}"; do
  ref="refs/remotes/origin/$branch"
  if git show-ref --verify --quiet "$ref"; then
    branch_commit=$(git rev-parse "$ref")
    branch_tree=$(git rev-parse "$ref^{tree}")
    if git push origin --delete "$branch" >/tmp/delete-branch.log 2>&1; then
      echo "- deleted \`$branch\` (commit \`$branch_commit\`, tree \`$branch_tree\`)" >> "$report"
    else
      echo "- retained \`$branch\`: deletion failed" >> "$report"
      sed 's/^/  /' /tmp/delete-branch.log >> "$report"
    fi
  else
    echo "- already absent \`$branch\`" >> "$report"
  fi
done
echo >> "$report"

echo '## Remaining remote branches' >> "$report"
echo >> "$report"
git fetch origin '+refs/heads/*:refs/remotes/origin/*' --prune
git for-each-ref --format='- `%(refname:strip=3)` at `%(objectname)`' refs/remotes/origin/ \
  | grep -v '^\- `HEAD`' >> "$report" || true
echo >> "$report"

default_body=$(mktemp)
default_code=$(curl --silent --show-error --output "$default_body" --write-out '%{http_code}' \
  --request PATCH \
  --header 'Accept: application/vnd.github+json' \
  --header "Authorization: Bearer $GH_TOKEN" \
  --header 'X-GitHub-Api-Version: 2022-11-28' \
  "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY" \
  --data '{"default_branch":"main"}' || true)

protection_body=$(mktemp)
protection_code=$(curl --silent --show-error --output "$protection_body" --write-out '%{http_code}' \
  --request PUT \
  --header 'Accept: application/vnd.github+json' \
  --header "Authorization: Bearer $GH_TOKEN" \
  --header 'X-GitHub-Api-Version: 2022-11-28' \
  "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/branches/main/protection" \
  --data '{"required_status_checks":{"strict":true,"contexts":["Format, analyze, test, debug build","Android emulator E2E","Release APK compile"]},"enforce_admins":true,"required_pull_request_reviews":null,"restrictions":null,"required_conversation_resolution":true,"allow_force_pushes":false,"allow_deletions":false,"required_linear_history":false,"block_creations":false,"lock_branch":false,"allow_fork_syncing":false}' || true)

{
  echo '## Repository settings API'
  echo
  echo "- change default branch to main: HTTP $default_code"
  if [[ "$default_code" != '200' ]]; then
    message=$(jq -r '.message // "unknown error"' "$default_body" 2>/dev/null || echo 'unknown error')
    echo "  - response: $message"
  fi
  echo "- protect main with required Flutter CI checks: HTTP $protection_code"
  if [[ "$protection_code" != '200' ]]; then
    message=$(jq -r '.message // "unknown error"' "$protection_body" 2>/dev/null || echo 'unknown error')
    echo "  - response: $message"
  fi
  echo
} >> "$report"

issue_title='Repository maintenance report 2026-07-26'
existing_issue=$(gh api "repos/$GITHUB_REPOSITORY/issues?state=open&per_page=100" \
  --jq ".[] | select(.title == \"$issue_title\") | .number" \
  | head -n 1 || true)

payload=$(mktemp)
jq -n --arg title "$issue_title" --rawfile body "$report" '{title: $title, body: $body}' > "$payload"
if [[ -n "$existing_issue" ]]; then
  gh api --method PATCH "repos/$GITHUB_REPOSITORY/issues/$existing_issue" --input "$payload" >/dev/null
  echo "Updated issue #$existing_issue"
else
  created_issue=$(gh api --method POST "repos/$GITHUB_REPOSITORY/issues" --input "$payload")
  echo "Created issue #$(jq -r '.number' <<< "$created_issue")"
fi
