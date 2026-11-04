# Database

## What you get

- **Postgres 18**, run by the operator (CloudNativePG). Your project has its own database and its own user; other projects can't see it, and you can't see theirs.
- The connection string arrives as **`DATABASE_URL`** in the app's environment (runtime only). Don't build it yourself, and don't put it in `secrets.env`.
- The connection is encrypted with a cluster-internal certificate. The URL uses `sslmode=no-verify`, which node-postgres (`pg`) needs: `require` would make `pg` verify against public CAs and fail. Python/Go/libpq treat `sslmode=require` as encrypt-without-verify, so either works there. If a driver complains about the certificate, it is trying to verify; switch it to encrypt-only rather than disabling SSL.
- The database user can't create other databases or roles. One database per app.
- **Disk is small and shared** (a few GB for the whole cluster). Store rows, not files. Photos, video and large blobs belong in object storage: ask the operator.
- There is no direct access from your laptop to the production database. Local development uses a local database (Docker `postgres:18`, or an embedded one like PGlite).

## Migrations

**The contract:** the image contains a migration command (in PROJECT.md, e.g. `node scripts/migrate.mjs`, `npx prisma migrate deploy`, `alembic upgrade head`). Before every new version starts, the cluster runs it with the same env as the app. The command must:

- apply only pending migrations and record what ran (a table like `_migrations`), so running it again is a no-op;
- exit **0** on success *and* when there is nothing to do (also when `DATABASE_URL` is unset, so it is harmless during a Docker build);
- exit non-zero on failure. Then the new version doesn't start and **the old version keeps serving**, so a broken migration doesn't take the site down;
- run each migration in a transaction where the database allows it, and set a short `lock_timeout` (e.g. `10s`) so it fails fast instead of freezing the live site behind a lock. A failed attempt is retried automatically.

Use whatever tool the stack already has. Changing the migration *command* needs the operator; adding migration *files* doesn't.

**Writing migrations:**

1. Add a new file with the next number (`migrations/0029_add_bookings.sql`). **Never edit a migration that already ran in production.** Write a new one that changes it.
2. Forward-only: there is no "down". To undo, write another migration.
3. **Be compatible with the running version.** For ~1 minute the old code runs against the new schema:
   - adding a table, a nullable column, or a column with a default: safe in one deploy;
   - renaming or dropping a column or table: two deploys (first ship code that no longer uses it, then the migration that drops it);
   - making a column `NOT NULL`: first backfill in one migration, then add the constraint in a later one;
   - big data rewrites on large tables: batch them, or ask the operator first.
4. Test locally against an empty database *and* against a copy with data, if the app has a seed.
5. Push. Watch the deploy (`gh run list --workflow "Deploy to cluster"`). If the change isn't live ~10 min after a green build, the migration probably failed: ask the operator for the migration log.

**One-off data fixes** (fix a typo in 3 rows, delete spam): there is no SQL console for clients. Write them as a migration (idempotent: `UPDATE … WHERE …` that is harmless the second time), or ask the operator to run a reviewed query.

## Backups and restore

- **Automatic:** a full backup daily at 03:00 UTC plus continuous archiving of every change (WAL), stored off the server in Google Cloud Storage, kept **7 days**.
- **Restore = point in time.** The operator can bring the database back to its state at any moment in that window, e.g. "Tuesday 14:05 UTC, just before the bad migration". It rewinds the *whole* database: everything written after that moment is gone. Note the exact time a problem started; it decides what can be saved.
- Restores are done by the operator only. Don't attempt your own recovery on the live database first: a hasty fix makes the restore point harder to pick.
- Want an extra copy you control (e.g. on the owner's computer)? That is app-level: an authenticated, encrypted export endpoint plus a scheduled download. Doable, but the cluster backups already cover disasters, so build it only if the owner asks.
