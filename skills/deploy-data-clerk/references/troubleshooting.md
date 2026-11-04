# Troubleshooting

Look at the cheap evidence first: the deploy run, then the public URL. Logs from inside the cluster come from the operator.

```bash
gh run list --workflow "Deploy to cluster" --limit 5
gh run view <id> --log-failed
curl -sI https://<host>/healthz
```

## "I pushed but the site didn't change"

1. **Was it `main`?** Other branches never deploy.
2. **Did the build pass?** A red run means no new image, so nothing changes. Read `gh run view --log-failed`, fix, push again.
3. **Green build, but still old after ~10 min?** Most likely the new version failed to start: a migration error, a crash on boot, or a failing health check. The old version keeps serving, which is why the site still works. Try the new image's startup path locally (`docker build -f deploy-data-clerk/Dockerfile . && docker run -e PORT=3000 -p 3000:3000 <image>`), check recent migrations, then ask the operator for the startup log.
4. **Browser cache / CDN:** hard-reload. Cloudflare can cache static assets; filenames with hashes avoid that.
5. **Did someone change the tag format** in the workflow? Tags not shaped `YYYYMMDDHHMMSS-<sha>` are silently ignored.

## "I changed an env var and nothing happened"

- Wait ~5 min after the push. The cluster checks every 5 min.
- Is it a **build-time** variable (`VITE_*`, `NEXT_PUBLIC_*`, …)? Those can't come from `secrets.env`; see `secrets.md`.
- Does `sops decrypt deploy-data-clerk/secrets.env` work locally? If not (a hand edit broke the checksum, or CRLF line endings), the cluster can't decrypt either, and **no** env change deploys until the file is valid again.
- Typo in the key name? `sops decrypt … | cut -d= -f1` and compare with what the code reads.
- Still stuck: `gh workflow run "Deploy to cluster"` forces a fresh start with the current env.

## "The site is down / 502 / 504"

- 502/504 from Cloudflare means the app isn't answering: crashing, out of memory, or stuck. Recent push? It still shouldn't take the site down (old version keeps serving), so suspect something at runtime: a request that eats memory, an external API hanging every request, a DB connection leak.
- Ask the operator for logs and restart reasons (OOM = out of memory → reduce memory use or ask for a higher limit).

## Common errors

| Error | Cause | Fix |
|---|---|---|
| `no key could decrypt the data` / `failed to get the data key` | key file missing or in the wrong place | `scripts/install-tools.* --key <file>` |
| `parsing time ... extra text: "\x0d"` | `secrets.env` has Windows line endings | restore LF; keep the `.gitattributes` rule |
| `MAC mismatch` | encrypted file was hand-edited | `git checkout` the last good version, redo the change with `sops set` |
| `sops: unknown command "set"` | sops older than 3.9 | reinstall via the script |
| `exec format error` (from operator logs) | image built for ARM | keep `platforms: linux/amd64` in the workflow |
| `EACCES` binding a port | app binds port < 1024 | listen on `$PORT` |
| users logged out after every deploy | auth secret generated at startup | put it in `secrets.env` |
| uploaded files disappear | written to local disk | DB or object storage |
| everyone shares one rate-limit bucket | limiter keys on `X-Forwarded-For` | use `CF-Connecting-IP` |
| live updates drop every ~100 s | Cloudflare idle timeout | heartbeat every ~30 s + client reconnect |
| `self-signed certificate in certificate chain` (Postgres) | driver verifying the internal cert | encrypt-only SSL mode, see `database.md` |
| `permission denied to create database` | app tries to create a DB | the DB already exists; connect to `DATABASE_URL` as is |

## Asking the operator

Write the request for the user to send (operator contact in PROJECT.md). Keep it short and specific, and never include secret values:

```
Project: <app name> (<public URL>)
What I need: <one line — e.g. "restore the database to 2026-11-04 14:05 UTC" / "app logs for the last hour" / "512Mi → 1Gi memory">
Why: <one or two lines of context>
When it started / deadline: <time with timezone, if relevant>
Commit / deploy run: <short sha or Actions link, if relevant>
```
