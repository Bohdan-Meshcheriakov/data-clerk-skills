---
name: deploy-data-clerk
description: How this app is built, deployed, configured and kept alive on Data Clerk hosting (the data-clerk.com Kubernetes cluster). Use it whenever the user wants to deploy, publish, ship or "put live" the app, add or change an environment variable, API key or secret, edit secrets.env or use sops, install the tools for that, add a database table or migration, asks about the database, backups or restoring data, a domain or HTTPS, why the site is down or did not update after a push, the Dockerfile or the GitHub Actions deploy, or is setting up a new project to run on Data Clerk. Use it even when the user does not say "Data Clerk" but the repo has a deploy-data-clerk/ folder.
---

# Deploying on Data Clerk

This app runs on **Data Clerk**, a small managed Kubernetes cluster run by an operator (a human, contact in `PROJECT.md`). The owner of this repo is usually not an infrastructure person. They should never need to touch servers, Kubernetes or a cloud console: **they push to `main`, and the cluster does the rest.** Your job is to keep it that way: work inside the repo, follow the contract below, and when something genuinely needs the cluster side, write the operator a clear request instead of improvising.

Explain things to the user in plain words ("your site will update in about five minutes"), not in Kubernetes terms.

## Start here

1. Read `deploy-data-clerk/PROJECT.md`. It holds this project's values: public URL, the deploy folder, image name, port, migration command, limits, who the operator is. Everything below that says "from PROJECT.md" means that file. If the folder name in PROJECT.md differs from `deploy-data-clerk/` (older projects use `deploy/`), use what PROJECT.md says.
2. No `PROJECT.md`, or it still has `__PLACEHOLDER__` values? The project is not onboarded yet: follow `references/new-project.md`.
3. Writing or changing a Dockerfile, picking how to structure the app, or the stack isn't Node? Read `references/stacks.md` (any language, full-stack vs separate frontend + API, FastAPI, Go).
4. Before the first secrets task on a machine, make sure the tools work: `sops --version` and a test decrypt (`sops decrypt <deploy folder>/secrets.env > /dev/null`). If either fails, follow `references/setup-tools.md`.

## How a change reaches the live site

| What changed | What happens | Live after |
|---|---|---|
| Code (push to `main`) | GitHub Actions builds a Docker image and pushes it; the cluster notices the new image tag and rolls it out | ~3–7 min (build time + ~1 min) |
| `secrets.env` (push to `main`) | The cluster re-reads the deploy folder every 5 min, decrypts it, updates the app's env and restarts the app | ~5 min |
| A new file in `migrations/` | Runs automatically before the new version starts | with the code deploy |
| Anything outside `main` | Nothing. Branches and PRs are not deployed | — |

The rollout is careful: the new version starts next to the old one, migrations run first, and traffic moves only once the new version answers its health check. **If the build, a migration or the health check fails, the old version keeps serving** and the site stays up. A failed deploy means "the change is not live", not "the site is down".

To check a deploy: `gh run list --workflow "Deploy to cluster" --limit 3` (or the Actions tab on GitHub), then open the public URL. To redeploy without a code change: `gh workflow run "Deploy to cluster"`, which builds a fresh tag, so the app restarts with a fresh environment.

## The contract (what keeps deploys working)

Each rule exists because breaking it fails silently or loses data. Keep to them, and tell the user if a request would break one.

- **Listen on `$PORT`** (the port in PROJECT.md, set by the cluster), on `0.0.0.0`, not `localhost`.
- **The image builds from `<deploy folder>/Dockerfile` for `linux/amd64`** and runs as a non-root user. No root, no ports below 1024, no extra Linux capabilities.
- **Image tags are `YYYYMMDDHHMMSS-<shortsha>`.** The cluster deploys the highest number and silently ignores any tag not in this format. Never change the tag step in `.github/workflows/deploy-cluster.yml`.
- **The container's disk is wiped on every deploy and restart.** Never keep user uploads, SQLite files or anything precious on local disk. Put data in the database; for files (photos, video), ask the operator for object storage.
- **Health check:** the cluster probes the health path in PROJECT.md (`/healthz` recommended). Make it return 200 fast, with no database call or page render, or a slow DB makes the cluster think the app is dead.
- **`DATABASE_URL` comes from the cluster.** Never put it in `secrets.env` (it would override the real one) and never set it at image build time.
- **Runtime vs build time.** `secrets.env` reaches the app **only at runtime**. The image is built in GitHub Actions without it. Anything inlined into the frontend at build time (`VITE_*`, `NEXT_PUBLIC_*`, `REACT_APP_*`) cannot come from `secrets.env`: read such values on the server at runtime and pass them to the page, or (if not secret) commit them in the code.
- **Secrets the app generates for itself when missing** (auth/session secret, encryption salts, push keys): set them in `secrets.env`. Otherwise every restart makes new ones, users get logged out, push subscriptions break, and so on.
- **Migrations must be safe for the old version.** For about a minute both versions run against the new schema. Add columns and tables freely. Rename or drop in two deploys: first stop using it, then remove it. Details in `references/database.md`.

## Environment variables and secrets

All runtime config lives in `<deploy folder>/secrets.env`, committed **encrypted** with sops. Only values are encrypted; key names stay readable. Change it with sops itself. Never decrypt it to a file you might commit, and never print secret values into the chat or logs.

```bash
sops set deploy-data-clerk/secrets.env '["STRIPE_SECRET_KEY"]' '"sk_live_..."'
sops unset deploy-data-clerk/secrets.env '["OLD_KEY"]'
sops decrypt deploy-data-clerk/secrets.env | cut -d= -f1
```

Then commit and push to `main`; it is live in ~5 min. When the user has to supply the value (an API key from some dashboard), have them run the `sops set` line themselves, or paste the value only into their own terminal. The full guide (keys, where they live, rotating, gotchas) is in `references/secrets.md`.

## Database

Postgres 18, managed by the operator. The app gets its own database and user via `DATABASE_URL`. Schema changes are migration files that apply themselves on deploy (`references/database.md`).

**Backups:** a full backup every night at 03:00 UTC plus a continuous log of every change, stored off the server in Google Cloud Storage. The operator can restore the database **to any moment within the last 7 days**. So if data gets deleted or a migration goes wrong, don't panic and don't try to fix it by hand: note the time it happened and ask the operator for a restore (template in `references/troubleshooting.md`). A restore rewinds the whole database, so changes made after that moment are lost.

## Network facts your code may need

- Traffic path: visitor → **Cloudflare** → **Traefik** (cluster ingress) → app. HTTPS certificates are automatic. The app itself speaks plain HTTP on `$PORT`; `X-Forwarded-Proto: https` says the original was HTTPS. Trust the proxy headers, and don't redirect to HTTPS in the app (it would loop).
- **Real visitor IP:** read the `CF-Connecting-IP` header. `X-Forwarded-For` holds a Cloudflare address, so rate limiting on it puts all visitors in one bucket.
- Traefik adds these headers: HSTS (2 years, preload), `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN` (the site cannot be embedded in an iframe on other domains). Extra headers (CSP, COOP/COEP for `SharedArrayBuffer`, allowing iframes) are set by the operator on request.
- The ingress does **not** compress responses. Cloudflare compresses common text types; for full control, compress in the app or ship pre-compressed assets.
- **Long connections** (SSE, websockets) are fine, but Cloudflare drops a connection idle for ~100 s. Send a heartbeat every ~30 s and reconnect on the client.
- **Outbound:** the app can call any public internet endpoint on any port. That includes LLM APIs, Stripe, email, S3, and managed databases or Redis (Neon, Supabase, Atlas, Upstash) on their public endpoints. It cannot reach private networks (VPC peering, PrivateLink, private IPs) or other projects on the cluster. Inbound traffic only comes through the public URL.
- **Third-party services:** put their keys and URLs in `secrets.env`. If a service needs an IP allowlist, the cluster has one static outbound IP: ask the operator for it (it's not published), and tell the user it's shared with other projects on the cluster. The server is in US-central, so prefer US-central/us-east regions for external databases (an EU database adds ~100 ms per query). An external database is the user's own: Data Clerk's backups don't cover it. For slow LLM calls, stream the response or run them as background jobs; a browser request waiting over ~100 s gets cut.
- Resources are capped (memory/CPU in PROJECT.md). Going over the memory limit kills and restarts the app. If that happens, ask the operator for more room rather than fighting it in code.
- One copy of the app runs (one replica). Don't rely on in-memory state surviving a deploy, and keep sessions in the DB or in signed cookies.

## What only the operator can do

The user has no cluster access, and that is by design. Write the operator a short request (see `references/troubleshooting.md` for the template) for:

new domain or subdomain · more memory/CPU · file/object storage · a database restore · app logs or crash reasons · changed security headers · changing the migration or start command, port or health path · scheduled jobs (cron) · extra services (Redis, queues) · a second app in the same project · onboarding a new repo.

## More detail

- `references/stacks.md`: the universal contract for any language; full-stack vs SPA + API vs static; Node, Python FastAPI, Go and other stacks.
- `references/new-project.md`: onboarding a repo (files to add, what to ask the operator for, Dockerfile per stack).
- `references/secrets.md`: sops in depth, the key file, rotating, build-time variables.
- `references/database.md`: migrations, connection string, backups, data fixes.
- `references/setup-tools.md`: installing sops/git/gh safely on macOS, Linux and Windows. Run `scripts/install-tools.sh` or `scripts/install-tools.ps1`.
- `references/troubleshooting.md`: "my change isn't live", "site is down", common errors, the operator request template.
- `assets/`: Dockerfile templates (Node, Python, Go) and templates for the deploy workflow, `kustomization.yaml`, `.sops.yaml`, `.gitattributes` and `PROJECT.md`.
