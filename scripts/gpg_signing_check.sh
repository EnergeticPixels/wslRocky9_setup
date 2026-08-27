#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -eq 0 && -n "${SUDO_USER:-}" && "${GPG_SIGN_CHECK_REEXEC_AS_USER:-0}" != "1" ]]; then
  export GPG_SIGN_CHECK_REEXEC_AS_USER=1
  exec sudo -u "$SUDO_USER" -H bash "$0" "$@"
fi

mode="preflight"
if [[ "${1:-}" == "--sign-test" ]]; then
  mode="sign-test"
fi

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

warn() {
  echo "WARN: $*" >&2
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required command: $cmd"
  fi
  pass "Command available: $cmd"
}

resolve_pinentry_binary() {
  local conf path
  conf="$HOME/.gnupg/gpg-agent.conf"

  if [[ -f "$conf" ]]; then
    path="$(awk '/^[[:space:]]*pinentry-program[[:space:]]+/ {print $2; exit}' "$conf" || true)"
    if [[ -n "$path" && -x "$path" ]]; then
      echo "$path"
      return 0
    fi
  fi

  if command -v pinentry-curses >/dev/null 2>&1; then
    command -v pinentry-curses
    return 0
  fi

  if command -v pinentry-tty >/dev/null 2>&1; then
    command -v pinentry-tty
    return 0
  fi

  if command -v pinentry >/dev/null 2>&1; then
    command -v pinentry
    return 0
  fi

  return 1
}

resolve_signing_key() {
  local key
  key="$(git config --global --get user.signingkey || true)"
  if [[ -n "$key" ]]; then
    echo "$key"
    return 0
  fi

  key="$({ gpg --batch --with-colons --list-secret-keys 2>/dev/null || true; } | awk -F: '$1 == "sec" { print $5; exit }')"
  if [[ -n "$key" ]]; then
    echo "$key"
    return 0
  fi

  return 1
}

ensure_agent_tty() {
  if [[ -n "${GPG_TTY:-}" ]]; then
    export GPG_TTY
  elif [[ -t 0 ]]; then
    export GPG_TTY
    GPG_TTY="$(tty)"
  fi

  gpgconf --kill gpg-agent >/dev/null 2>&1 || true
  gpgconf --launch gpg-agent >/dev/null 2>&1 || true
  gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
}

run_sign_test_commit() {
  local signing_key repo_dir git_name git_email commit_output

  signing_key="$1"
  git_name="$(git config --global --get user.name || true)"
  git_email="$(git config --global --get user.email || true)"

  [[ -n "$git_name" ]] || fail "Global git user.name is not set"
  [[ -n "$git_email" ]] || fail "Global git user.email is not set"

  repo_dir="$(mktemp -d)"
  trap 'rm -rf "$repo_dir"' EXIT

  pushd "$repo_dir" >/dev/null
  git init -q
  git config user.name "$git_name"
  git config user.email "$git_email"
  git config user.signingkey "$signing_key"
  git config commit.gpgsign true

  echo "signing test $(date +%s)" > sign-test.txt
  git add sign-test.txt

  if commit_output="$(git commit -S -m "test: verify gpg signing pipeline" 2>&1)"; then
    pass "Signed commit test succeeded"
  else
    echo "$commit_output" >&2
    fail "Signed commit test failed"
  fi

  popd >/dev/null
  rm -rf "$repo_dir"
  trap - EXIT
}

echo "Running GPG signing readiness check (mode=$mode)"

require_cmd gpg
require_cmd git
require_cmd gpgconf

pinentry_bin="$(resolve_pinentry_binary || true)"
if [[ -z "$pinentry_bin" ]]; then
  fail "No pinentry binary found (pinentry-curses/pinentry-tty/pinentry)."
fi
pass "Pinentry available: $pinentry_bin"

ensure_agent_tty

signing_key="$(resolve_signing_key || true)"
if [[ -z "$signing_key" ]]; then
  fail "No signing key found. Configure git user.signingkey or create a GPG secret key first."
fi
pass "Signing key available: $signing_key"

if ! gpg --batch --list-secret-keys "$signing_key" >/dev/null 2>&1; then
  fail "Signing key '$signing_key' not found in secret keyring."
fi
pass "Signing key present in keyring"

if [[ "$mode" == "sign-test" ]]; then
  if [[ ! -t 0 ]]; then
    fail "--sign-test requires an interactive terminal for pinentry prompt."
  fi
  run_sign_test_commit "$signing_key"
else
  warn "Preflight mode does not perform an actual signing operation. Use --sign-test for full verification."
  pass "Preflight checks passed"
fi
