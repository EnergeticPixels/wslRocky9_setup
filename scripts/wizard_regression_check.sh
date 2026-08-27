#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROVISIONING_SCRIPT="$ROOT_DIR/provisioning.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

require_pattern() {
  local pattern="$1"
  local description="$2"

  if grep -Fq "$pattern" "$PROVISIONING_SCRIPT"; then
    pass "$description"
  else
    fail "$description (pattern not found: $pattern)"
  fi
}

echo "Running wizard regression checks against $PROVISIONING_SCRIPT"

# 1) Invalid prompt feedback must go to stderr so command substitution does not capture it.
require_pattern "echo \"Invalid value. Allowed: \$allowed_csv\" >&2" "read_choice sends invalid input feedback to stderr"
require_pattern "echo \"Please enter true/false (or yes/no).\" >&2" "read_bool sends invalid input feedback to stderr"

# 2) Invalid defaults must be sanitized before prompt loop.
require_pattern "echo \"Invalid default '\$default' for prompt '\$prompt'. Falling back to '\${allowed_tokens[0]}'.\" >&2" "read_choice sanitizes invalid defaults"
require_pattern "default=\"\${allowed_tokens[0]}\"" "read_choice falls back to first allowed token"
require_pattern "echo \"Invalid boolean default '\$default' for prompt '\$prompt'. Falling back to false.\" >&2" "read_bool sanitizes invalid defaults"

# 3) Script must remain syntactically valid.
bash -n "$PROVISIONING_SCRIPT"
pass "provisioning.sh syntax check"

# 4) Optional runtime validation (only if .env exists and platform supports command).
if [[ -f "$ROOT_DIR/.env" ]]; then
  if bash "$PROVISIONING_SCRIPT" validate >/dev/null 2>&1; then
    pass "provisioning.sh validate"
  else
    echo "WARN: provisioning.sh validate did not pass in this environment" >&2
  fi
else
  echo "WARN: .env not found, skipping provisioning.sh validate" >&2
fi

echo "Wizard regression checks complete."
