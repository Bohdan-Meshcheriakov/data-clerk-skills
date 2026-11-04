# Data Clerk skills

Agent skills for apps hosted on **Data Clerk** (data-clerk.com). They teach your AI coding agent (Claude Code, Codex, Cursor, Copilot, Gemini CLI, …) how your app gets deployed, how to change env vars and secrets, how migrations and backups work, and when to ask the operator, so you can keep vibe-coding and simply push to `main`.

| Skill | What it covers |
|---|---|
| [`deploy-data-clerk`](skills/deploy-data-clerk/SKILL.md) | push-to-deploy, `secrets.env` with sops (plus safe tool install), Postgres + migrations, 7-day point-in-time backups, Cloudflare/Traefik facts, troubleshooting, onboarding a new repo |

## Install into your app's repo

Easiest: tell your agent

> Install the Data Clerk deploy skill from https://github.com/Bohdan-Meshcheriakov/data-clerk-skills into this repo.

Or run it yourself from your repo root:

```bash
curl -fsSL https://raw.githubusercontent.com/Bohdan-Meshcheriakov/data-clerk-skills/main/install.sh | bash
```

```powershell
irm https://raw.githubusercontent.com/Bohdan-Meshcheriakov/data-clerk-skills/main/install.ps1 | iex
```

This puts the skill in `deploy-data-clerk/` (next to your Dockerfile and encrypted `secrets.env`) and adds a short pointer to `AGENTS.md` and `CLAUDE.md` plus `.claude/skills/deploy-data-clerk/`, so every agent finds it. Commit the result. Re-run any time to update; your `PROJECT.md` is never overwritten.

Then:

1. Fill in `deploy-data-clerk/PROJECT.md` with the values your operator sent (or ask your agent to).
2. Install the tools and your key: `bash deploy-data-clerk/scripts/install-tools.sh --key ~/Downloads/<project>.key` (Windows: `install-tools.ps1 -Key …`).

## Claude Code plugin (optional, per machine)

```
/plugin marketplace add Bohdan-Meshcheriakov/data-clerk-skills
/plugin install data-clerk@data-clerk-skills
```

The in-repo install above is still recommended: it travels with the repo, works with every agent, and keeps project values in `PROJECT.md`.

## License

Proprietary. Data Clerk customers may use and adapt these files in their own repositories for apps hosted on Data Clerk; see [LICENSE](LICENSE).
