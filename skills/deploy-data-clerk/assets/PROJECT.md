# Data Clerk project

Values the operator gave for this project. Nothing here is secret. Agents read this file first (see `deploy-data-clerk/SKILL.md`).

| Field | Value |
|---|---|
| App name | `__APP__` |
| Public URL | `https://__HOST__` |
| Deployed branch | `main` |
| Deploy folder | `deploy-data-clerk/` |
| Container port | `3000` |
| Health path | `/healthz` |
| Start command | `__START_COMMAND__` (Dockerfile `CMD`) |
| Migration command | `__MIGRATE_COMMAND__` (or `none`) |
| Database | Postgres 18, `DATABASE_URL` injected (or `none`) |
| Memory / CPU limit | `__MEMORY__` / `__CPU__` |
| Image | `us-central1-docker.pkg.dev/data-clerk-chat/__NAMESPACE__/__APP__` |
| Workload identity provider | `__WIF_PROVIDER__` |
| CI service account | `__CI_SERVICE_ACCOUNT__` |
| sops age public key | `__AGE_PUBLIC_KEY__` |
| Env secret name | `__APP__-env` |
| Operator contact | `__OPERATOR_CONTACT__` |

## Project-specific notes

Anything special about this app's setup (extra headers, storage bucket, cron jobs, quirks) goes here.
