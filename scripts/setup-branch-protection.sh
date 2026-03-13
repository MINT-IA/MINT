#!/usr/bin/env bash
# Setup branch protection rules for MINT (dev, staging, main)
# Usage: ./scripts/setup-branch-protection.sh
#
# Requires: gh CLI authenticated (gh auth login)
#
# What this does (on all 3 branches):
#   - Requires PR to merge (no direct push)
#   - Requires CI Gate to pass before merge
#   - Blocks force-push
#   - Auto-deletes branches after merge

set -euo pipefail

REPO="$(gh repo view --json nameWithOwner -q '.nameWithOwner')"
echo "Configuring branch protection for: $REPO"

TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" << 'ENDJSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI Gate"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_linear_history": false
}
ENDJSON

for branch in staging main; do
  echo ""
  echo "Setting up branch protection on '${branch}'..."
  gh api \
    --method PUT \
    "repos/${REPO}/branches/${branch}/protection" \
    --input "$TMPFILE"
  echo "  Done: '${branch}' protected."
done

# ─── Dev branch: allow direct push, block force-push ─────────────
echo ""
echo "Configuring dev branch: allow direct push, block force-push..."
gh api \
  --method PUT \
  "repos/${REPO}/branches/dev/protection" \
  --input "$TMPFILE" \
  --field required_pull_request_reviews=null \
  --field required_status_checks=null
echo "  Done: dev branch allows direct push, force-push blocked."

# ─── Repo settings: auto-delete + auto-merge ─────────────────
echo ""
echo "Enabling auto-delete of merged branches + auto-merge..."

gh api \
  --method PATCH \
  "repos/${REPO}" \
  --field delete_branch_on_merge=true \
  --field allow_auto_merge=true

echo ""
echo "Done. Protection rules:"
echo "  - dev: direct push allowed, force-push blocked"
echo "  - staging/main: PR required, CI Gate must pass, force-push blocked"
echo "  - Auto-merge enabled (gh pr merge --auto --squash)"
echo "  - Merged branches auto-deleted"
