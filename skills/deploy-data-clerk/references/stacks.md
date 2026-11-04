# App shapes and stacks

Read this when creating a Dockerfile, choosing how to structure a new app, or adapting an existing app in any language.

## Contents
1. The universal contract (any language)
2. App shapes: full-stack, separate frontend + backend, static site
3. Node (full-stack SSR)
4. Python (FastAPI)
5. Go
6. Anything else

---

## 1. The universal contract (any language)

The cluster doesn't care what language the app is in. It runs one Docker image and expects it to behave like this:

| Requirement | Why | How to check |
|---|---|---|
| HTTP server on `0.0.0.0:$PORT` | the cluster routes traffic to that port | `docker run -e PORT=3000 -p 3000:3000 img` then `curl localhost:3000/healthz` |
| `GET /healthz` → 200 fast, no DB | the cluster decides if the app is alive and ready for traffic | same curl, also with the DB down |
| Runs as non-root, no ports < 1024, no capabilities | the cluster forbids privileges | `USER` set in the Dockerfile |
| Built for `linux/amd64` | the server's CPU | `--platform linux/amd64` |
| All config from env vars at **runtime** | `secrets.env` and `DATABASE_URL` arrive only when the container starts | build the image with no env at all; it must still build |
| A migration command: idempotent, exit 0 on success or nothing to do, non-zero on failure | runs before each new version; failure keeps the old version live | run it twice against a local DB; second run is a no-op |
| No precious data on local disk | the disk is wiped on every deploy | restart the container; nothing lost |
| Logs to stdout/stderr, no log files | that's what the operator can read | — |
| Shuts down cleanly on `SIGTERM` within ~30 s | deploys stop the old version this way | most frameworks do this; avoid shell wrappers that swallow signals (use exec-form `CMD [...]`) |
| Trusts proxy headers: `X-Forwarded-Proto`, `CF-Connecting-IP` | HTTPS ends at Cloudflare/Traefik | generated URLs use `https://`, rate limits per real IP |
| Fits the memory limit in PROJECT.md | over the limit = killed | watch memory locally under load |
| Single instance is fine (one replica) | there is one copy running | no reliance on in-memory state across deploys |

If an app meets this table, it deploys, whatever the language.

The Python and Go templates include a `web` stage that builds a SPA from `frontend/` (shape B1). Delete that stage and its `COPY --from=web` line when there is no separate frontend. Adjust paths (`app.main:app`, `./cmd/server`) to the repo's layout.

## 2. App shapes

### A. Full-stack in one container (recommended, the default)

One server process renders pages and serves the API from the same origin. Examples: TanStack Start, Next.js, Nuxt, SvelteKit, Remix, Django, Rails, Laravel, FastAPI + Jinja/HTMX, Go + html/template + HTMX.

Why it's the default: one image, one deploy, one URL, no CORS, cookies just work, one health check, smallest resource footprint. When in doubt, build this.

### B. Separate frontend (SPA) + backend API

A React/Vue/Svelte SPA built with Vite, plus an API in any language. There are two ways to ship it. Prefer the first.

**B1. One container: the backend serves the built SPA (recommended).**
- A multi-stage Dockerfile builds the frontend (`npm ci && npm run build` → `dist/`) and copies `dist/` into the backend image.
- The backend serves `/api/*` itself, serves static files from `dist/`, and returns `index.html` for any other path that isn't a file (so client-side routes like `/profile/42` work on reload).
- The frontend calls the API with **relative URLs** (`fetch("/api/…")`). Then there's no API URL to configure and no CORS. Don't bake `VITE_API_URL=https://…` into the build.
- Runtime config the browser needs (public keys, feature flags): serve it from an endpoint like `GET /api/config` instead of `VITE_*` build variables, which can't come from `secrets.env`.
- Hashed assets (`/assets/*`) can be cached forever (`Cache-Control: public, max-age=31536000, immutable`); `index.html` must be `no-cache`.
- Recipes: FastAPI and Go sections below; for Node, Express/Fastify/Hono with a static middleware.

**B2. Two containers (frontend and API deployed separately).**
- Needs the operator: two Deployments, and either two hostnames (`app.` + `api.`) or one hostname with `/api` routed to the API.
- Prefer one hostname with path routing: no CORS, cookies shared. With two hostnames you need CORS on the API and `SameSite=None; Secure` cookies, or token auth.
- Use it only when there's a real reason (separate teams, the frontend is a large Node SSR app and the API is a different language with its own scaling). Otherwise do B1.
- Each container follows the universal contract, and each gets its own image and image tag stream: ask the operator to set up the second one.

### C. Static site only (no backend)

Plain HTML or a Vite build with no server code. Serve it with a tiny static server image (e.g. `nginxinc/nginx-unprivileged:alpine` listening on 8080, or `caddy` on a high port) and add a `/healthz` file. No database, no migrations. If it later needs a backend, move to B1.

---

## 3. Node (full-stack SSR)

- Build a **Node server**, not a serverless/static preset: Nitro/TanStack Start `preset: "node-server"`, Next.js `output: "standalone"`, SvelteKit `adapter-node`, Nuxt default `node-server`, Astro `@astrojs/node` standalone.
- Template: `assets/Dockerfile.node`. If the build output is self-contained (Nitro `.output/`, Next `standalone/`), copy only that into the runtime image, not `node_modules`. Check by running the image.
- Migrations: the framework's tool (`prisma migrate deploy`, `drizzle-kit migrate`, `knex migrate:latest`) or a small script with the exit-code contract. If the bundler makes the tool need full `node_modules`, bundle the migration script with esbuild into one file.
- node-postgres needs `sslmode=no-verify` (already in `DATABASE_URL`). If the code builds its own SSL options, use `ssl: { rejectUnauthorized: false }`.
- Real IP: `req.headers["cf-connecting-ip"]`. Express: `app.set("trust proxy", true)`.

## 4. Python (FastAPI)

- Template: `assets/Dockerfile.python` (uv or pip; `python:3.12-slim`; non-root; uvicorn on `$PORT`).
- Server: `uvicorn app.main:app --host 0.0.0.0 --port $PORT --proxy-headers --forwarded-allow-ips='*'`. One worker is right for the memory limit. Add `--workers 2` only if PROJECT.md's memory allows it and the app is CPU-bound.
- Health: `@app.get("/healthz")` returning `{"ok": True}`, no DB dependency injected.
- Database: SQLAlchemy 2 / SQLModel with `psycopg` (v3). `DATABASE_URL` arrives as `postgresql://…`. SQLAlchemy needs a driver prefix, so convert at startup: `url.replace("postgresql://", "postgresql+psycopg://", 1)`. If the URL contains `sslmode=no-verify` (a node-postgres value libpq doesn't know), replace it with `sslmode=require`, which encrypts without verifying.
- Migrations: **Alembic**. Migration command `alembic upgrade head` (idempotent, exits non-zero on failure). In `env.py` read the URL from `os.environ["DATABASE_URL"]`, and exit 0 early if it's unset. Generate with `alembic revision --autogenerate -m "…"` locally and **review the generated file**: autogenerate misses renames and some type changes.
- SPA (shape B1): build the frontend in a Node stage, copy `dist/` to `/app/static`, then `app.mount("/assets", StaticFiles(directory="static/assets"))` plus a catch-all route returning `static/index.html` for non-`/api` paths. Register API routers **before** the catch-all.
- Real IP: `request.headers.get("cf-connecting-ip") or request.client.host`.
- Background work: no Celery/Redis by default. Small jobs: FastAPI `BackgroundTasks` or an asyncio task. Scheduled jobs: ask the operator for a cron job running the same image with a different command.

## 5. Go

- Template: `assets/Dockerfile.go` (`golang` build stage, `CGO_ENABLED=0 GOOS=linux GOARCH=amd64`, runtime `gcr.io/distroless/static-debian12:nonroot`). A static binary of ~10–30 MB, very low memory.
- Server: `net/http` (Go 1.22+ routing patterns), Gin, Echo or Chi all fine. `addr := ":" + os.Getenv("PORT")`. Handle `SIGTERM` with `http.Server.Shutdown`.
- Embed everything with `//go:embed`: templates, static files, the built SPA (`dist/`) and migrations. Then the image is just the binary.
- Database: `pgx` (v5) or `lib/pq`. `sslmode=require` works (encrypts without verifying). Replace `sslmode=no-verify` with `require` if present.
- Migrations: **goose** (`pressly/goose/v3`) with embedded `migrations/*.sql`, up-only. Two options: run at startup under a Postgres advisory lock, or a subcommand (`/app/server migrate`) used as the migration command. The subcommand is preferred: a failure blocks the deploy instead of crash-looping.
- SPA (shape B1): `http.FileServer(http.FS(sub))` for assets, plus a fallback handler serving `index.html` for unknown non-`/api` paths.
- Real IP: `r.Header.Get("CF-Connecting-IP")`.
- Distroless has no shell: use exec-form `CMD`/`ENTRYPOINT` and a binary subcommand for migrations, not `sh -c`.

## 6. Anything else (Ruby, PHP, Java, Rust, Elixir, .NET…)

Work from the universal contract in section 1:

1. **Pick the production server** the ecosystem uses (Puma, FrankenPHP/php-fpm+Caddy, a fat JAR, a compiled binary, a Phoenix release, Kestrel) and make it bind `0.0.0.0:$PORT`.
2. **Multi-stage Dockerfile**: a build stage with the SDK, a slim runtime stage with only what runs; `USER` non-root; exec-form `CMD`.
3. **Migrations** with the framework's tool (`rails db:migrate`, `php artisan migrate --force`, Flyway/Liquibase, `sqlx migrate run`, `mix ecto.migrate` via release eval, `dotnet ef database update` or a bundled migrator). Confirm it is idempotent and exits non-zero on failure. Ask the operator to set it as the migration command.
4. **DB URL**: some frameworks want a different URL shape (JDBC `jdbc:postgresql://host:port/db?user=…`, .NET connection strings). Parse `DATABASE_URL` at startup and convert; don't ask for a different secret. Use "encrypt, don't verify" SSL (`sslmode=require`).
5. **Memory**: JVM and .NET grab memory based on the host; cap them to the container (`-XX:MaxRAMPercentage=75`, `DOTNET_GCHeapHardLimitPercent`). Check against the limit in PROJECT.md.
6. Add `/healthz`, trust proxy headers, log to stdout, and run the local `docker build` + `docker run` check from section 1.

When the stack needs something the cluster doesn't give by default (a second process, a worker, Redis, a writable volume, more memory), say so to the user and draft the operator request rather than working around it.
