#!/usr/bin/env bash
# Publish this project to GitHub Pages in one step.
#
#   bash publish.sh              # repo named "pbi-score"
#   bash publish.sh my-repo-name # or pick your own name
#
# Creates the GitHub repo (or reuses it), pushes, switches Pages to
# "GitHub Actions", runs the deploy, and prints the live URL.
# Safe to run again later to publish updates.
#
# Needs git and the GitHub CLI (https://cli.github.com; on a Mac:
# `brew install gh`). You'll be asked to sign in the first time.
set -euo pipefail

REPO="${1:-pbi-score}"
VISIBILITY="${VISIBILITY:-public}"   # Pages on a private repo needs a paid GitHub plan
DESCRIPTION="Bedside calculator for the UChicago PBI Imaging Score (head CT, gunshot wounds to the head)"

cd "$(dirname "$0")"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
die() { printf '\n\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

# Make sure this is the web-app folder, not the original project folder.
for f in site/index.html site/sw.js site/manifest.webmanifest .github/workflows/pages.yml; do
  [ -f "$f" ] || die "This folder is missing $f, so it isn't the web-app version of the project.
Unzip UChiCT-webapp.zip and run publish.sh from inside the folder it creates."
done

command -v git >/dev/null || die "git is not installed. On a Mac, run: xcode-select --install"
command -v gh  >/dev/null || die "GitHub CLI is not installed. On a Mac, run: brew install gh   (or see https://cli.github.com)"

# ── 1. Sign in (pushing a workflow file needs the "workflow" scope) ──
if ! gh auth status >/dev/null 2>&1; then
  say "Sign in to GitHub"
  gh auth login --hostname github.com --git-protocol https --web --scopes workflow
elif ! gh auth status 2>&1 | grep -q "workflow"; then
  say "Granting the 'workflow' permission (needed to push the deploy workflow)"
  gh auth refresh --hostname github.com --scopes workflow
fi
gh auth setup-git >/dev/null 2>&1 || true

OWNER="$(gh api user --jq .login)"
say "Publishing as $OWNER/$REPO"

# ── 2. Local git repo + first commit ──
if [ ! -d .git ]; then
  git init -q
fi
git symbolic-ref HEAD refs/heads/main 2>/dev/null || true

if [ -z "$(git config user.email || true)" ]; then
  # No git identity on this machine: use the GitHub no-reply address for this repo only.
  GH_ID="$(gh api user --jq .id)"
  GH_NAME="$(gh api user --jq '.name // .login')"
  git config user.name  "$GH_NAME"
  git config user.email "${GH_ID}+${OWNER}@users.noreply.github.com"
fi

# Never publish the copyrighted article. Make sure PDFs are ignored wherever
# they sit in the folder, then check before committing and before pushing.
touch .gitignore
if ! grep -qx '\*\.pdf' .gitignore; then
  printf '\n# Keep article PDFs out of the repo (publisher-copyrighted).\n*.pdf\n' >> .gitignore
fi

PDF_IN_HISTORY="$(git log --all --name-only --format= 2>/dev/null | grep -i '\.pdf$' | sort -u || true)"
if [ -n "$PDF_IN_HISTORY" ]; then
  die "A PDF is already in this folder's git history, so pushing would upload it:
$PDF_IN_HISTORY
If you haven't published this folder before, run:  rm -rf .git   then run this script again."
fi

if [ -f index.html ] && [ -f site/index.html ]; then
  echo "Note: there's an old index.html at the top of the folder. The app that gets published is site/index.html."
fi

git add -A
PDF_STAGED="$(git diff --cached --name-only | grep -i '\.pdf$' || true)"
if [ -n "$PDF_STAGED" ]; then
  git reset -q 2>/dev/null || git rm -r -q --cached . >/dev/null 2>&1 || true
  die "Refusing to commit PDF files:
$PDF_STAGED
Move them out of this folder (or into reference/), then run this script again."
fi

if ! git diff --cached --quiet; then
  if git rev-parse --verify -q HEAD >/dev/null; then
    git commit -q -m "Update PBI score calculator"
  else
    git commit -q -m "UChicago PBI Imaging Score web app"
  fi
fi

# ── 3. Create or reuse the GitHub repo, then push ──
push_main() {
  if [ "${REPLACE:-0}" = "1" ]; then
    say "Replacing what's on GitHub with this folder"
    git push -q -u --force origin main
  elif ! git push -q -u origin main; then
    die "GitHub's copy of $OWNER/$REPO has different history from this folder.
To replace it with this folder, run:  REPLACE=1 bash publish.sh${1:+ $1}"
  fi
}

if git remote get-url origin >/dev/null 2>&1; then
  say "Pushing to existing remote"
  push_main "${1:-}"
elif gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  say "Repo $OWNER/$REPO already exists; connecting"
  git remote add origin "https://github.com/$OWNER/$REPO.git"
  push_main "${1:-}"
else
  say "Creating $VISIBILITY repo $OWNER/$REPO"
  gh repo create "$OWNER/$REPO" "--$VISIBILITY" --description "$DESCRIPTION" \
    --source . --remote origin --push
fi

# ── 4. Settings → Pages → Source: GitHub Actions ──
say "Turning on GitHub Pages (source: GitHub Actions)"
if gh api "repos/$OWNER/$REPO/pages" >/dev/null 2>&1; then
  gh api -X PUT "repos/$OWNER/$REPO/pages" -f build_type=workflow >/dev/null
else
  gh api -X POST "repos/$OWNER/$REPO/pages" -f build_type=workflow >/dev/null
fi

# ── 5. Deploy and wait ──
# Pushing to main starts a deploy by itself, so wait for that one instead of
# starting a second (two at once cancel each other). Start a fresh run only if
# there's no run for this commit or it didn't succeed: that covers the very
# first publish (the push run starts before Pages is on), re-running after a
# failure, and GitHub hiccups. Up to 3 tries.
say "Deploying (about a minute)"
SHA="$(git rev-parse HEAD)"

# Newest deploy run for this commit, optionally limited to one trigger.
find_run() {
  local filter=".headSha == \"$SHA\""
  [ -n "${1:-}" ] && filter="$filter and .event == \"$1\""
  gh run list --repo "$OWNER/$REPO" --workflow pages.yml --limit 30 \
    --json databaseId,headSha,event --jq "[.[] | select($filter)][0].databaseId // empty" 2>/dev/null || true
}

# Start a new run and print its id once it appears.
start_run() {
  local before after attempt
  before="$(find_run workflow_dispatch)"
  # A just-pushed workflow file takes a few seconds to register ("not found" until then).
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    gh workflow run pages.yml --repo "$OWNER/$REPO" --ref main >/dev/null 2>&1 && break
    [ "$attempt" = 10 ] && return 1
    sleep 3
  done
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    sleep 3
    after="$(find_run workflow_dispatch)"
    if [ -n "$after" ] && [ "$after" != "$before" ]; then echo "$after"; return 0; fi
  done
  return 1
}

RUN_ID=""
for _ in 1 2 3 4 5 6; do            # give the push-triggered run a moment to appear
  RUN_ID="$(find_run push)"
  [ -n "$RUN_ID" ] && break
  sleep 3
done

TRY=1
while :; do
  if [ -z "$RUN_ID" ]; then
    RUN_ID="$(start_run)" || die "GitHub didn't start a deploy. Check the Actions tab: https://github.com/$OWNER/$REPO/actions"
  fi
  echo "  Watching https://github.com/$OWNER/$REPO/actions/runs/$RUN_ID"
  if gh run watch "$RUN_ID" --repo "$OWNER/$REPO" --exit-status >/dev/null 2>&1; then
    break
  fi
  if [ "$TRY" -ge 3 ]; then
    die "Deploy failed 3 times. Details: https://github.com/$OWNER/$REPO/actions/runs/$RUN_ID
Running this script again later is safe; it will retry the deploy."
  fi
  echo "  That run didn't succeed (normal on a first publish; otherwise usually a GitHub hiccup). Trying again."
  TRY=$((TRY + 1))
  RUN_ID=""
done

URL="$(gh api "repos/$OWNER/$REPO/pages" --jq .html_url)"
say "Live at: $URL"
echo "(Give it a minute if you still see the old version; GitHub's cache can lag.)"
