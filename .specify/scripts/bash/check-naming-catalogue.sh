#!/usr/bin/env bash
# Validates that every service_type listed in the spec's "Naming Pattern Table"
# exists in the catalogue submodule, and vice-versa. Used by the
# `.github/workflows/naming-catalogue.yml` CI gate (US6 / SC-006).
#
# Exits non-zero on drift. Output is grep-friendly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SPEC="${REPO_ROOT}/specs/001-naming-convention-engine/spec.md"
CAT_TOP="${REPO_ROOT}/modules/naming/catalogue/services.tf"

if [[ ! -f "$SPEC" ]]; then
  echo "ERROR: spec file not found: $SPEC" >&2
  exit 2
fi
if [[ ! -f "$CAT_TOP" ]]; then
  echo "ERROR: catalogue file not found: $CAT_TOP" >&2
  exit 2
fi

# Extract service_type identifiers from the catalogue (keys of locals.services map).
# Convention: each row begins at 4-space indent with `"<name>" = {`.
mapfile -t CAT_TYPES < <(
  grep -E '^[[:space:]]{4}"[a-z_]+"[[:space:]]*=[[:space:]]*\{' "$CAT_TOP" \
    | sed -E 's/^[[:space:]]+"([a-z_]+)".*$/\1/' \
    | sort -u
)

# Extract service_type names from the spec's naming pattern table.
# Convention: table rows look like `| service_type | abbr | shape | ... |`.
mapfile -t SPEC_TYPES < <(
  awk -F'|' '
    /^\|[[:space:]]*`?service_type`?[[:space:]]*\|/ { inhdr=1; next }
    inhdr && /^\|[[:space:]]*-/             { intable=1; inhdr=0; next }
    intable && /^\|/ {
      gsub(/[[:space:]]/, "", $2)
      gsub(/`/, "", $2)
      if ($2 != "" && $2 ~ /^[a-z_]+$/) print $2
      next
    }
    intable && !/^\|/ { intable=0 }
  ' "$SPEC" | sort -u
)

missing_in_catalogue=()
for t in "${SPEC_TYPES[@]}"; do
  if ! printf '%s\n' "${CAT_TYPES[@]}" | grep -qx "$t"; then
    missing_in_catalogue+=("$t")
  fi
done

missing_in_spec=()
for t in "${CAT_TYPES[@]}"; do
  if ! printf '%s\n' "${SPEC_TYPES[@]}" | grep -qx "$t"; then
    missing_in_spec+=("$t")
  fi
done

rc=0
if (( ${#missing_in_catalogue[@]} > 0 )); then
  echo "DRIFT: spec lists service_types missing from catalogue:" >&2
  printf '  %s\n' "${missing_in_catalogue[@]}" >&2
  rc=1
fi
if (( ${#missing_in_spec[@]} > 0 )); then
  echo "DRIFT: catalogue contains service_types missing from spec:" >&2
  printf '  %s\n' "${missing_in_spec[@]}" >&2
  rc=1
fi

if (( rc == 0 )); then
  echo "OK: spec and catalogue agree on ${#SPEC_TYPES[@]} service_types."
fi

exit "$rc"
