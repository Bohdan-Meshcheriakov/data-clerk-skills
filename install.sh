#!/usr/bin/env bash
set -euo pipefail

REPO="${DATA_CLERK_SKILLS_REPO:-Bohdan-Meshcheriakov/data-clerk-skills}"
REF="${DATA_CLERK_SKILLS_REF:-main}"
DEST="deploy-data-clerk"
SKILL="deploy-data-clerk"

[ -d .git ] || { echo "run this from the root of your app's git repository" >&2; exit 1; }

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
[ -n "$src" ] || { echo "skill not found in archive" >&2; exit 1; }

mkdir -p "$DEST"
cp "$src/SKILL.md" "$DEST/SKILL.md"
for d in references scripts assets; do
  rm -rf "${DEST:?}/$d"
  cp -R "$src/$d" "$DEST/$d"
done
chmod +x "$DEST/scripts/"*.sh
[ -f "$DEST/PROJECT.md" ] || cp "$src/assets/PROJECT.md" "$DEST/PROJECT.md"

mkdir -p ".claude/skills/$SKILL"
{
  awk 'NR==1 || !done {print} NR>1 && /^---$/ {done=1}' "$src/SKILL.md"
  printf '\nThe full skill lives in the repo at `deploy-data-clerk/SKILL.md`. Read that file now and follow it; its `references/`, `scripts/` and `assets/` are next to it.\n'
} > ".claude/skills/$SKILL/SKILL.md"

POINTER='Deploying, env vars/secrets (sops), database migrations, backups and hosting: this app runs on Data Clerk. Read `deploy-data-clerk/SKILL.md` before any of that work.'
for f in AGENTS.md CLAUDE.md; do
  if [ ! -f "$f" ] || ! grep -qF 'deploy-data-clerk/SKILL.md' "$f"; then
    printf '\n## Hosting\n\n%s\n' "$POINTER" >> "$f"
  fi
done

echo "==> installed into $DEST/ (PROJECT.md kept if it existed)"
echo "    next: fill in $DEST/PROJECT.md with the values from your Data Clerk operator,"
echo "    then: bash $DEST/scripts/install-tools.sh --key <your-project.key>"
