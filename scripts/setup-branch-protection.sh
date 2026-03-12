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
#   - Linear history enforced (rebase only)
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
  "required_linear_history": true
}
ENDJSON

for branch in dev staging main; do
  echo ""
  echo "Setting up branch protection on '${branch}'..."
  gh api \
    --method PUT \
    "repos/${REPO}/branches/${branch}/protection" \
    --input "$TMPFILE"
  echo "  Done: '${branch}' protected."
done

# ─── Auto-delete head branches ────────────────────────────────
echo ""
echo "Enabling auto-delete of merged branches..."

gh api \
  --method PATCH \
  "repos/${REPO}" \
  --field delete_branch_on_merge=true

echo ""
echo "Done. Protection rules on dev, staging, main:"
echo "  - PR required (no direct push)"
echo "  - CI Gate must pass before merge"
echo "  - Force-push blocked"
echo "  - Linear history (rebase only, no merge commits)"
echo "  - Merged branches auto-deleted"
echo ""
echo "To test: try 'git push origin dev' directly — it should be rejected."
