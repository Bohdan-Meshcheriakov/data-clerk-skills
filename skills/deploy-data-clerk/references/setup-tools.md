# Installing the tools

What the owner's machine needs:

| Tool | Why | Required |
|---|---|---|
| `git` | push = deploy | yes |
| `sops` | read and change `secrets.env` | yes, for any secrets work |
| the age key file | decrypts the secrets | yes, from the operator |
| `gh` (GitHub CLI) | see deploy status, re-run a deploy | recommended |

You do **not** need `age`, `docker`, `kubectl` or any cloud CLI. sops has age built in, images are built by GitHub Actions, and the cluster is the operator's.

## The fast path: run the script

From the repo root:

```bash
bash deploy-data-clerk/scripts/install-tools.sh
bash deploy-data-clerk/scripts/install-tools.sh --key ~/Downloads/myproject.key
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy-data-clerk\scripts\install-tools.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy-data-clerk\scripts\install-tools.ps1 -Key "$HOME\Downloads\myproject.key"
```

What it does, so you can explain it to the user before running it:

1. **sops**: installs a pinned version with a package manager if one is present (Homebrew on macOS, Scoop on Windows; both verify package checksums). Otherwise it downloads the official binary from `github.com/getsops/sops/releases` and **refuses to install it unless its SHA-256 matches the checksum written into the script**. It installs per user (`~/.local/bin` or `%LOCALAPPDATA%\Programs\sops`), with no admin rights.
2. **git / gh**: only checks they exist and prints how to install if missing (it does not install them silently).
3. **`--key` / `-Key`**: copies the key file to the location sops reads (see `secrets.md`). It appends if a keys file already exists and the key isn't already there, restricts permissions to the current user, then tells the user to delete the downloaded copy once they've saved a backup in a password manager.
4. Finally runs `sops --version`, and if a `secrets.env` and key are present, a test decrypt that prints only the key *names*.

Run it with the user's knowledge. It installs software, so say what it will do first.

## Doing it by hand

**macOS**: `brew install sops gh` (install Homebrew from https://brew.sh first if missing; git comes with Xcode Command Line Tools: `xcode-select --install`).

**Linux**: use the script, or download `sops-v<version>.linux.amd64` (or `.arm64`) from the official releases page, check it against `sops-v<version>.checksums.txt` from the same release (`sha256sum -c --ignore-missing`), then `install -m 755` it into `~/.local/bin/sops`. Distro packages are often years old. `gh`: https://cli.github.com.

**Windows**: `scoop install sops gh git` (Scoop: https://scoop.sh), or `choco install sops gh git`. **Avoid `winget` for sops**: it has carried a years-old 3.7.x. Set an editor for `sops <file>`: `$env:EDITOR = "notepad"` (or `code --wait`).

**Verifying more strongly** (optional, for the cautious): each sops release has a Sigstore bundle (`sops-v<version>.checksums.sigstore.json`). With `cosign` installed:

```bash
cosign verify-blob sops-v3.13.3.checksums.txt \
  --bundle sops-v3.13.3.checksums.sigstore.json \
  --certificate-identity-regexp 'https://github.com/getsops' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## After installing

- `sops --version` prints the version (3.9+ needed for `sops set`/`unset`).
- `sops decrypt deploy-data-clerk/secrets.env | cut -d= -f1` lists key names. `no key could decrypt` means the key file is missing or in the wrong place.
- `gh auth login` once, so `gh run list` works.
