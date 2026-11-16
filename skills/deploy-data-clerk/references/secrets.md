# Secrets and environment variables

## How it works

- `<deploy folder>/secrets.env` is a dotenv file (`KEY=value` per line) encrypted with **sops** using an **age** key.
- `.sops.yaml` at the repo root holds the project's *public* key (the recipient). Anyone can encrypt with it; only holders of the matching *private* key can decrypt.
- The private key exists in two places: the owner's machine (the key file the operator handed over, e.g. `myproject.key`), and inside the cluster, so it can decrypt on deploy.
- Every 5 minutes the cluster pulls `main`, decrypts `secrets.env` into the app's environment and restarts the app if anything changed.

## The key file

The operator sends a file that looks like:

```
# created: 2026-...
# public key: age1...
AGE-SECRET-KEY-1...
```

sops finds it automatically at:

| OS | Path |
|---|---|
| macOS | `~/Library/Application Support/sops/age/keys.txt` |
| Linux | `~/.config/sops/age/keys.txt` |
| Windows | `%APPDATA%\sops\age\keys.txt` |

`scripts/install-tools.sh --key <file>` (or `install-tools.ps1 -Key <file>`) puts it there safely: it appends instead of overwriting other keys and makes the file readable only by the user. Alternatively set `SOPS_AGE_KEY_FILE=/path/to/key`.

Tell the user, once, plainly:
- **This file is the master key to the project's secrets.** Never commit it, never paste it into chats or AI tools, never email it on.
- **Keep a second copy** somewhere safe (a password manager). Lost key = can't edit secrets (the operator can issue a new one, but it's a hassle).
- If it leaks: tell the operator. They issue a new key, you re-encrypt (`sops updatekeys`), and every secret inside should be rotated at its provider.

Never read, print or move the key file contents through the chat. Use the install script or file-system commands.

## Everyday operations

Run from the repo root (`.sops.yaml` must be found):

```bash
sops set deploy-data-clerk/secrets.env '["KEY"]' '"value"'
sops unset deploy-data-clerk/secrets.env '["KEY"]'
sops decrypt deploy-data-clerk/secrets.env | cut -d= -f1
sops decrypt deploy-data-clerk/secrets.env | grep '^KEY=' | wc -l
sops deploy-data-clerk/secrets.env
```

The last line opens the file decrypted in `$EDITOR` and re-encrypts on save. It is good for humans and useless for agents.

The value argument is a JSON string: wrap it in `'"…"'`. A value with a double quote or backslash needs JSON escaping (`'"a\"b"'`).

PowerShell 7.3+ takes the same command unchanged. Old Windows PowerShell 5.1 strips the inner quotes, so escape them: `sops set deploy-data-clerk/secrets.env '[\"KEY\"]' '\"value\"'`. If quoting still fights you, have the user run `sops deploy-data-clerk/secrets.env` with `$env:EDITOR = "notepad"` and add the line by hand.

After any change: `git add deploy-data-clerk/secrets.env && git commit -m "secrets: add KEY"`, run the leak check from SKILL.md ("Before every push"), and `git push` only if it prints nothing. Live in ~5 min.

When a value must come from the user (an API key from a provider dashboard), don't ask them to paste it into the chat. Give them the exact `sops set` command with a placeholder to run in their own terminal, then verify only that the key name exists.

## Rules and gotchas

- **Never hand-edit the encrypted file** in a normal editor. The file carries a checksum (`sops_mac`). A hand edit breaks it, the cluster can't decrypt, and *no* env changes deploy until it's fixed.
- **Line endings must be LF.** A CRLF file fails to decrypt with `parsing time ... extra text: "\x0d"`. `.gitattributes` pins it (`deploy-data-clerk/secrets.env text eol=lf`). Don't remove that rule.
- **Not `.env`**: the name `secrets.env` keeps it out of common gitignore patterns. Make sure `.gitignore` doesn't exclude it.
- **Don't add `DATABASE_URL` or `PORT`.** The cluster sets them, and yours would override them.
- **Runtime only.** The Docker build never sees `secrets.env`. Build-time variables (`VITE_*`, `NEXT_PUBLIC_*`, `REACT_APP_*`, anything read during `npm run build`) can't come from it. Options: read the value on the server at runtime and hand it to the page; or, if it's not secret, hard-code it or put it in a committed config. A truly secret build-time value is a request for the operator.
- **Public-by-design keys** (e.g. a Google Maps browser key) can live in `secrets.env` and be sent to the browser. Their protection is the provider-side restriction (HTTP referrer = the public URL), not secrecy. Remind the user to set that restriction.
- **OAuth callbacks** use the public URL from PROJECT.md, e.g. `https://<host>/api/auth/callback/google`.
- Local development: keep a separate, unencrypted, gitignored `.env` with dev values. Don't decrypt production secrets onto disk for local dev.

## Rotating a secret

1. Create the new value at the provider (keep the old one active).
2. `sops set …` the new value, commit, push, wait ~5 min, check the app works.
3. Revoke the old value at the provider.
