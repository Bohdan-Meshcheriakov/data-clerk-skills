# Onboarding a new project to Data Clerk

Two halves: the **operator** creates the cluster side (namespace, database, domain, image registry, keys), and **you** prepare the repo. Do the repo half while the operator does theirs, and fill in `PROJECT.md` with the values they send.

## 1. What to ask the operator for

Send this (the user forwards it):

```
New Data Clerk project
- GitHub repo: <owner/repo>  (private is fine — please add the deploy key)
- App name: <short-lowercase-name>
- Wanted URL: <name>.data-clerk.com  (or own domain: <domain>)
- Stack: <e.g. Node 22 SSR (TanStack Start) / Next.js / Python FastAPI / Go>
- Shape: <one full-stack container / SPA served by the backend / separate frontend + API containers>
- Needs Postgres: yes/no
- Migration command (runs before each deploy): <e.g. node scripts/migrate.mjs>
- Health path: /healthz
- Port: 3000
- Needs file storage / cron / websockets: <yes/no each>
```

The operator replies with: the image path, the GitHub workload identity provider and service account (CI pushes images without any stored password), the age public key and the private key file, the memory/CPU limits, and confirms the URL. Put the non-secret values into `PROJECT.md`. The private key file goes to `scripts/install-tools.* --key`, never into the repo.

## 2. Files to add to the repo

Copy from `assets/` and replace every `__PLACEHOLDER__` with the value from PROJECT.md:

| From `assets/` | To | Notes |
|---|---|---|
| `PROJECT.md` | `deploy-data-clerk/PROJECT.md` | fill all fields |
| `Dockerfile.node` | `deploy-data-clerk/Dockerfile` | adapt to the stack (see below) |
| `kustomization.yaml` | `deploy-data-clerk/kustomization.yaml` | `__APP__-env` = secret name the operator wires |
| `deploy-cluster.yml` | `.github/workflows/deploy-cluster.yml` | image, provider and service account from PROJECT.md |
| `sops.yaml` | `.sops.yaml` (repo root, note the dot) | age public key |
| `gitattributes` | append to `.gitattributes` | keeps `secrets.env` LF |
| `dockerignore` | `.dockerignore` | merge with any existing one |

Then create the secrets file:

```bash
printf 'APP_ENV=production\n' > deploy-data-clerk/secrets.env
sops encrypt -i deploy-data-clerk/secrets.env
sops set deploy-data-clerk/secrets.env '["AUTH_SECRET"]' "\"$(openssl rand -base64 32)\""
```

Add every runtime variable the app reads (check the code for `process.env.`, `os.environ`, `os.Getenv`) except `DATABASE_URL` and `PORT`. Generate app-owned secrets (session/auth secrets, salts, VAPID keys) now, so they stay stable across restarts.

## 3. Make the app fit the contract

Go through the contract in SKILL.md. The usual changes:

- **Server mode, not static/serverless:** frameworks with deploy presets (Nitro, Next, SvelteKit, Astro) must build a Node server, not `vercel`/`netlify`/`static`. E.g. Nitro `preset: "node-server"`; Next `output: "standalone"`; SvelteKit `adapter-node`; Astro `@astrojs/node` standalone.
- Listen on `process.env.PORT`, host `0.0.0.0`.
- Add a `/healthz` route that returns 200 with no DB call.
- A migration command with the exit-code contract (`database.md`). If the app migrates at startup, that also works, but a separate command is safer: a failing migration then blocks the deploy instead of crash-looping.
- Nothing written to local disk that must survive a restart.
- Real client IP from `CF-Connecting-IP`.

## 4. Dockerfile per stack

Read `stacks.md`. It has the universal contract any language must meet, the choice between one full-stack container and a separate frontend + API, and recipes for Node, Python (FastAPI), Go and other stacks. Templates: `assets/Dockerfile.node`, `assets/Dockerfile.python`, `assets/Dockerfile.go`.

Build it locally once if Docker is available: `docker build --platform linux/amd64 -f deploy-data-clerk/Dockerfile -t test .` and `docker run --rm -e PORT=3000 -p 3000:3000 test`, then open http://localhost:3000/healthz.

## 5. First deploy

1. Commit everything (encrypted `secrets.env` included) and push to `main`.
2. Watch `gh run list --workflow "Deploy to cluster"` go green.
3. Tell the operator "first image is pushed". They switch the cluster to it. From then on every push deploys by itself.
4. Open the public URL and check the main flows (sign-in, a DB write).
5. Add OAuth callback URLs, API key referrer restrictions, etc. at providers using the public URL.
