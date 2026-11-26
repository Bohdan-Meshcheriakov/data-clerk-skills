#!/usr/bin/env bash
set -euo pipefail

REPO="${DATA_CLERK_SKILLS_REPO:-Bohdan-Meshcheriakov/data-clerk-skills}"
REF="${DATA_CLERK_SKILLS_REF:-main}"
SKILL="${1:-deploy-data-clerk}"
SCOPE="${2:-}"

case "$SKILL" in
  deploy-data-clerk | human-touch) ;;
  *) echo "unknown skill '$SKILL' (use: deploy-data-clerk | human-touch)" >&2; exit 1 ;;
esac

if [ "$SKILL" = "deploy-data-clerk" ] && [ ! -d .git ]; then
  echo "run this from the root of your app's git repository" >&2
  exit 1
fi

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

if [ -n "${DATA_CLERK_SKILLS_SRC:-}" ]; then
  src="$DATA_CLERK_SKILLS_SRC/skills/$SKILL"
else
  echo "==> fetching $REPO@$REF"
  curl --proto '=https' --tlsv1.2 -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | tar -xz -C "$tmp"
  src="$(find "$tmp" -maxdepth 4 -type d -path "*/skills/$SKILL" | head -n1)"
fi
[ -n "$src" ] && [ -f "$src/SKILL.md" ] || { echo "skill not found in archive" >&2; exit 1; }

add_pointer() {
  local heading="$1" needle="$2" text="$3" f
  for f in AGENTS.md CLAUDE.md; do
    if [ ! -f "$f" ] || ! grep -qF "$needle" "$f"; then
      printf '\n## %s\n\n%s\n' "$heading" "$text" >> "$f"
    fi
  done
}

install_human_touch() {
  local dest
  if [ "$SCOPE" = "--global" ] || [ ! -d .git ]; then
    dest="${HUMANTOUCH_SKILL_DIR:-$HOME/.claude/skills/human-touch}"
  else
    dest="${HUMANTOUCH_SKILL_DIR:-.claude/skills/human-touch}"
  fi
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -R "$src/." "$dest/"
  if [ "$SCOPE" != "--global" ] && [ -d .git ]; then
    add_pointer "Human Touch" "human-touch/SKILL.md" "To have real people check something you can't be sure of (approvals before risky actions, labels, ratings, native-speaker text checks, web checks), read \`$dest/SKILL.md\`."
  fi
  echo "==> Human Touch skill installed in $dest"
  echo "    next: read $dest/SKILL.md, section \"Getting access\", and connect (your human approves once in the browser)"
}

install_deploy() {
  local dest="deploy-data-clerk"
  mkdir -p "$dest"
  cp "$src/SKILL.md" "$dest/SKILL.md"
  for d in references scripts assets; do
    rm -rf "${dest:?}/$d"
    cp -R "$src/$d" "$dest/$d"
  done
  chmod +x "$dest/scripts/"*.sh
  cp "$src/../../LICENSE" "$dest/LICENSE"
  [ -f "$dest/PROJECT.md" ] || cp "$src/assets/PROJECT.md" "$dest/PROJECT.md"

  mkdir -p ".claude/skills/$SKILL"
  {
    awk 'NR==1 || !done {print} NR>1 && /^---$/ {done=1}' "$src/SKILL.md"
    printf '\nThe full skill lives in the repo at `deploy-data-clerk/SKILL.md`. Read that file now and follow it; its `references/`, `scripts/` and `assets/` are next to it.\n'
  } > ".claude/skills/$SKILL/SKILL.md"

  add_pointer "Hosting" "deploy-data-clerk/SKILL.md" 'Deploying, env vars/secrets (sops), database migrations, backups and hosting: this app runs on Data Clerk. Read `deploy-data-clerk/SKILL.md` before any of that work.'

  echo "==> installed into $dest/ (PROJECT.md kept if it existed)"
  echo "    next: fill in $dest/PROJECT.md with the values from your Data Clerk operator,"
  echo "    then: bash $dest/scripts/install-tools.sh --key <your-project.key>"
}

if [ "$SKILL" = "human-touch" ]; then install_human_touch; else install_deploy; fi
