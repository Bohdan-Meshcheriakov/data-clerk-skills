#!/usr/bin/env bash
set -euo pipefail

SOPS_VERSION="3.13.3"
MIN_SOPS="3.9.0"

KEY_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --key) KEY_FILE="${2:-}"; shift 2 ;;
    -h|--help) echo "usage: install-tools.sh [--key path/to/project.key]"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!! %s\033[0m\n' "$*" >&2; }
die() { printf '\033[31mxx %s\033[0m\n' "$*" >&2; exit 1; }

expected_sha() {
  case "$1" in
    darwin.amd64) echo "42162d5cef10b74fcf80a045a70e658d7ce6e63d6ea1be6f347e44015714468d" ;;
    darwin.arm64) echo "b97c0d434aab577dc40310e8d22ff9e45eef4c80638ab978daae9b4681c59286" ;;
    linux.amd64)  echo "e5bec3346a873ae91d871550f3e698c1aad962aff462a080e40f25fde17fef6b" ;;
    linux.arm64)  echo "53b0abacd38ef1b12a66d6c100956691b9cefce018d91f81e73ddf7438b94d77" ;;
    *) echo "" ;;
  esac
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

version_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

current_sops_version() {
  command -v sops >/dev/null 2>&1 || { echo ""; return; }
  sops --version 2>/dev/null | head -n1 | sed -E 's/^sops ([0-9]+\.[0-9]+\.[0-9]+).*/\1/'
}

install_sops_binary() {
  local os arch target url tmp want got dest
  case "$(uname -s)" in
    Darwin) os=darwin ;;
    Linux) os=linux ;;
    *) die "unsupported OS $(uname -s); on Windows use install-tools.ps1" ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    arm64|aarch64) arch=arm64 ;;
    *) die "unsupported CPU $(uname -m)" ;;
  esac
  target="$os.$arch"
  want="$(expected_sha "$target")"
  [ -n "$want" ] || die "no pinned checksum for $target"
  url="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.${target}"
  tmp="$(mktemp -d)"
  say "downloading sops v${SOPS_VERSION} for ${target} from github.com/getsops/sops"
  curl --proto '=https' --tlsv1.2 --connect-timeout 20 --max-time 900 --retry 2 -fsSL "$url" -o "$tmp/sops" || { rm -rf "$tmp"; die "download failed: $url"; }
  got="$(sha256_of "$tmp/sops")"
  if [ "$got" != "$want" ]; then
    rm -rf "$tmp"
    die "checksum mismatch for sops (expected $want, got $got) — not installing"
  fi
  say "checksum verified"
  dest="$HOME/.local/bin"
  mkdir -p "$dest"
  install -m 755 "$tmp/sops" "$dest/sops"
  rm -rf "$tmp"
  if [ "$os" = darwin ]; then xattr -d com.apple.quarantine "$dest/sops" 2>/dev/null || true; fi
  case ":$PATH:" in
    *":$dest:"*) ;;
    *)
      warn "$dest is not on your PATH; adding it to your shell profile"
      local profile
      case "$(basename "${SHELL:-}")" in
        zsh) profile="$HOME/.zshrc" ;;
        bash) profile="$HOME/.bashrc" ;;
        *) profile="$HOME/.profile" ;;
      esac
      printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$profile"
      export PATH="$dest:$PATH"
      warn "open a new terminal (or run: source $profile) for it to take effect"
      ;;
  esac
}

ensure_sops() {
  local have
  have="$(current_sops_version)"
  if [ -n "$have" ] && version_ge "$have" "$MIN_SOPS"; then
    say "sops $have already installed"
    return
  fi
  [ -n "$have" ] && warn "sops $have is too old (need $MIN_SOPS+)"
  if [ "$(uname -s)" = Darwin ] && command -v brew >/dev/null 2>&1; then
    say "installing sops with Homebrew"
    if [ -n "$have" ]; then brew upgrade sops || brew install sops; else brew install sops; fi
  else
    install_sops_binary
  fi
  have="$(current_sops_version)"
  [ -n "$have" ] && version_ge "$have" "$MIN_SOPS" || die "sops install did not work; see references/setup-tools.md"
  say "sops $have ready"
}

check_tool() {
  local name="$1" hint="$2"
  if command -v "$name" >/dev/null 2>&1; then
    say "$name found"
  else
    warn "$name not found — $hint"
  fi
}

key_dir() {
  if [ -n "${SOPS_AGE_KEY_FILE:-}" ]; then dirname "$SOPS_AGE_KEY_FILE"; return; fi
  case "$(uname -s)" in
    Darwin) echo "$HOME/Library/Application Support/sops/age" ;;
    *) echo "${XDG_CONFIG_HOME:-$HOME/.config}/sops/age" ;;
  esac
}

install_key() {
  local src="$1" dir dest secret
  [ -f "$src" ] || die "key file not found: $src"
  secret="$(grep -E '^AGE-SECRET-KEY-1[0-9A-Z]+$' "$src" | head -n1 || true)"
  [ -n "$secret" ] || die "$src does not look like an age key file (no AGE-SECRET-KEY line)"
  dir="$(key_dir)"
  dest="${SOPS_AGE_KEY_FILE:-$dir/keys.txt}"
  umask 077
  mkdir -p "$dir"
  chmod 700 "$dir"
  if [ -f "$dest" ] && grep -qxF "$secret" "$dest"; then
    say "key already installed in $dest"
  else
    if [ -f "$dest" ]; then printf '\n' >> "$dest"; fi
    cat "$src" >> "$dest"
    say "key added to $dest"
  fi
  chmod 600 "$dest"
  warn "save a backup of $src in a password manager, then delete the downloaded copy"
}

test_decrypt() {
  local f
  for f in deploy-data-clerk/secrets.env deploy/secrets.env; do
    if [ -f "$f" ]; then
      say "test decrypt of $f (key names only):"
      if sops decrypt "$f" | cut -d= -f1 | sed 's/^/    /'; then
        say "secrets are readable — all set"
      else
        warn "could not decrypt $f — is the right key installed? (run again with --key <file>)"
      fi
      return
    fi
  done
}

ensure_sops
check_tool git "install it: macOS 'xcode-select --install', Linux your package manager"
check_tool gh "optional, to watch deploys: https://cli.github.com (macOS: brew install gh)"
[ -n "$KEY_FILE" ] && install_key "$KEY_FILE"
test_decrypt
