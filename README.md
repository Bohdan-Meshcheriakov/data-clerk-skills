# Data Clerk skills

Agent skills from **Data Clerk** (data-clerk.com) for Claude Code, Codex, Cursor, Copilot, Gemini CLI and other AI agents.

| Skill | What it covers |
|---|---|
| [`human-touch`](skills/human-touch/SKILL.md) | **Human Touch** ([humantouch.data-clerk.com](https://humantouch.data-clerk.com)): real people as a tool for your agent. Approvals before risky actions, labels, ratings, A/B picks, fact checks, web checks from a given country, and native-speaker checks of translations and texts |
| [`deploy-data-clerk`](skills/deploy-data-clerk/SKILL.md) | Hosting on Data Clerk: push-to-deploy, `secrets.env` with sops (plus safe tool install), Postgres + migrations, 7-day point-in-time backups, Cloudflare/Traefik facts, troubleshooting, onboarding a new repo |

## Human Touch

Easiest: tell your agent

> Install the Human Touch skill from https://github.com/Bohdan-Meshcheriakov/data-clerk-skills

Agents: run this, then read the installed `SKILL.md`, section "Getting access", and connect. Your human approves once in the browser (sign in, set a spending cap, Allow).

```bash
curl -fsSL https://raw.githubusercontent.com/Bohdan-Meshcheriakov/data-clerk-skills/main/install.sh | bash -s human-touch
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Bohdan-Meshcheriakov/data-clerk-skills/main/install.ps1))) human-touch
```

Inside a git repo it installs to `.claude/skills/human-touch/` and adds a pointer to `AGENTS.md` and `CLAUDE.md`, so every agent working on that repo finds it. Outside a repo, or with `--global` (`bash -s human-touch --global`, PowerShell `-Global`), it installs to `~/.claude/skills/human-touch/` for all your projects.

Chat apps (Claude.ai, ChatGPT): add the connector `https://humantouch.data-clerk.com/mcp` in the app's settings, then paste [SKILL.md](skills/human-touch/SKILL.md) into the chat, or upload [the zip](https://humantouch.data-clerk.com/skill.zip) as a skill in Claude.

## Deploy on Data Clerk: install into your app's repo

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
/plugin install human-touch@data-clerk-skills
```

The in-repo install above is still recommended: it travels with the repo, works with every agent, and keeps project values in `PROJECT.md`.

## License

Proprietary. Data Clerk customers may use and adapt these files in their own repositories for apps hosted on Data Clerk; see [LICENSE](LICENSE).
