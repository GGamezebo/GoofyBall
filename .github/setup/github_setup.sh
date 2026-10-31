#!/usr/bin/env bash
# One-time GitHub setup: labels, milestones, main protection.
# Needs GitHub CLI logged in with admin rights: gh auth login
# Usage: .github/setup/github_setup.sh [owner/repo]
set -euo pipefail
REPO="${1:-GGamezebo/GoofyBall}"
cd "$(dirname "$0")/../.."

# Labels from .github/labels.yml
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  name="${line%%:*}"; rest="${line#*: }"
  color="${rest%% | *}"; desc="${rest#* | }"
  gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force
done < .github/labels.yml

# Milestones from docs/roadmap.md iterations (existing ones are skipped)
mk() { gh api "repos/$REPO/milestones" -f title="$1" -f description="$2" >/dev/null || true; }
mk "Iteration 1 - Network slice" "Smooth 1x1 over the internet: quizmatik skeleton, volley_sim (Classic, arena S), one blob, vs AI, local 2P on PC, room by code via self-hosted Nakama relay, rollback, net overlay, lag emulation, Windows + Android builds, determinism and e2e tests"
mk "Iteration 2 - Chaos" "Modifier, BuffBase, BuffRegistry, EnvDirector, Action button and self_destruct; first pickups, env events, two characters with passives; all online under rollback"
mk "Iteration 3 - Look and feel" "Jelly blob, glow check in Compatibility, camera FX, buff visuals, HUD, sound, touch polish"
mk "Iteration 4 - Online for everyone" "Hosted Nakama, platform sign-in, guest + soft save, rated queue (Glicko-2), ranks, leaderboards, reconnect, web build"

# Protect main: PR only, no force push, no deletion
gh api -X PUT "repos/$REPO/branches/main/protection" --input - <<JSON
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {"required_approving_review_count": 0, "dismiss_stale_reviews": true},
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
echo "Done: labels, milestones, main protection for $REPO"
