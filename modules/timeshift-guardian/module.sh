#!/usr/bin/env bash
set -euo pipefail

# modules/timeshift-guardian/module.sh
# Diagnose-first Timeshift guardian: reports whether Timeshift is installed
# and configured, shows the snapshot count, and creates ONE owner-commented
# on-demand snapshot through the single visible menu-confirmed elevated step.
# Snapshots are ADDITIVE by owner policy: this module never deletes, prunes,
# or restores snapshots, and honestly says undo is not offered.
#
# Safety confirmations live in the MENU, never in this module (MODULE_SPEC §3,
# owner ruling 2026-09-18, MB-004): the menu takes the single typed-slug
# confirmation for an elevated run before this module launches, and the module
# then runs to completion without re-asking. The one question that remains is
# a VALUE question (the snapshot comment); Enter takes the default, q aborts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${MINTBUTLER_LIB_DIR:-$(cd "${SCRIPT_DIR}/../../lib" && pwd)}"

# Pass this module's slug so lib/elevate.sh can check the manifest's risk
# declaration before anything privileged runs.
export MINTBUTLER_MODULE_SLUG="${MINTBUTLER_MODULE_SLUG:-timeshift-guardian}"

# shellcheck source=lib/elevate.sh
source "${LIB_DIR}/elevate.sh"
# shellcheck source=lib/ask.sh
source "${LIB_DIR}/ask.sh"

describe() {
  printf 'Diagnose-first Timeshift guardian: checks status, shows snapshots, creates one additive snapshot.\n'
}

plan() {
  printf 'Plan for timeshift-guardian:\n'
  printf '1. Check whether Timeshift is installed (Software Manager is the installer).\n'
  printf '2. Inspect Timeshift configuration via: %s\n' "$(elevate_command_line timeshift --list)"
  printf '   Stop with guidance if Timeshift is not yet configured.\n'
  printf '3. Ask for a snapshot comment (the one question this module asks; default:\n'
  printf '   mintbutler guard <YYYY-MM-DD>; q aborts with nothing changed).\n'
  printf '4. Create ONE snapshot with the single elevated step (the menu took the run\n'
  printf '   confirmation before launch; this module asks no safety question):\n'
  printf '   %s\n' "$(elevate_command_line timeshift --create --comments "<comment>")"
  printf '5. Verify the snapshot via: %s\n' "$(elevate_command_line timeshift --list)"
  printf '6. Policy: snapshots are additive; this module never deletes them and offers no undo.\n'
}

dry_run() {
  plan
  printf '\n'
  printf 'Exact commands (nothing runs now; values as written):\n'
  printf '  %s\n' "$(elevate_command_line timeshift --list)"
  printf '  %s\n' "$(elevate_command_line timeshift --create --comments "<comment>")"
  printf '  %s\n' "$(elevate_command_line timeshift --list)"
  printf '  undo: none (snapshots are additive and remain until managed in Timeshift)\n'
}

# Heuristic to detect whether Timeshift is configured from `timeshift --list` output.
# Configured: contains snapshot rows or a named device / partition.
# Not configured: empty, error, "not found", "not configured", or no device/snapshot info.
is_timeshift_configured() {
  local output="${1:-}"
  if [[ -z "${output}" ]]; then
    return 1
  fi
  local lowered
  lowered="$(printf '%s\n' "${output}" | tr '[:upper:]' '[:lower:]')"

  if printf '%s\n' "${lowered}" | grep -q -E 'not found|not configured|no snapshot|no device|select a snapshot device|unconfigured'; then
    if ! printf '%s\n' "${output}" | grep -q -E '(/dev/|[0-9]{4}-[0-9]{2}-[0-9]{2})'; then
      return 1
    fi
  fi

  if printf '%s\n' "${output}" | grep -q -E '(/dev/|Device[[:space:]]*:|Mounted at[[:space:]]*:|>[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2})'; then
    return 0
  fi

  return 1
}

run() {
  # (i) Check Timeshift installed
  if ! command -v timeshift >/dev/null 2>&1; then
    printf 'Timeshift is not installed; install it from the Software Manager and configure it once in the Timeshift GUI — this module does not install it\n' >&2
    exit 1
  fi

  # (ii) Status via elevate_run timeshift --list
  local list_output list_code=0
  list_output="$(elevate_run timeshift --list)" || list_code="$?"
  if [[ "${list_code}" -ne 0 ]]; then
    printf 'Failed to inspect Timeshift status (elevated command exited %d)\n' "${list_code}" >&2
    exit "${list_code}"
  fi

  # Display the raw output verbatim
  printf '%s\n' "${list_output}"

  # Check if configured
  if ! is_timeshift_configured "${list_output}"; then
    printf '\nTimeshift is not yet configured. Please open the Timeshift GUI once from the system menu, select a snapshot type (RSYNC or BTRFS) and a destination storage device, and complete the initial setup wizard. Then re-run this module to create on-demand snapshots.\n'
    exit 0
  fi

  # (iii) Ask comment
  local today default_comment comment
  today="$(date +%Y-%m-%d)"
  default_comment="mintbutler guard ${today}"

  if ! comment="$(ask_value "Snapshot comment (Enter for default, 'q' to abort)" "${default_comment}")"; then
    printf 'Nothing changed.\n'
    exit 0
  fi

  if [[ "${comment}" == "q" || "${comment}" == "Q" ]]; then
    printf 'Nothing changed.\n'
    exit 0
  fi

  if [[ -z "${comment}" ]]; then
    comment="${default_comment}"
  fi

  # The comment travels as ONE argv word from here to sudo; the displayed
  # line is derived from that same list (MB-001).
  printf '\nCreating the snapshot with: %s\n' "$(elevate_command_line timeshift --create --comments "${comment}")"

  # No in-module safety question (MODULE_SPEC §3): the menu took the single
  # confirmation for this run before this module launched.
  local create_code=0
  elevate_run timeshift --create --comments "${comment}" || create_code="$?"
  if [[ "${create_code}" -ne 0 ]]; then
    printf 'Failed to create Timeshift snapshot (elevated command exited %d)\n' "${create_code}" >&2
    exit "${create_code}"
  fi

  # Re-run timeshift --list to show new count
  printf '\nUpdated Timeshift status:\n'
  local updated_list updated_code=0
  updated_list="$(elevate_run timeshift --list)" || updated_code="$?"
  if [[ "${updated_code}" -ne 0 ]]; then
    printf 'Failed to re-read Timeshift status (elevated command exited %d)\n' "${updated_code}" >&2
    exit "${updated_code}"
  fi
  printf '%s\n' "${updated_list}"

  # (iv) Success message ends with honest additive statement
  printf '\nSnapshot created successfully.\n'
  printf 'Notice: snapshots are additive by policy. This snapshot stays until removed in Timeshift itself; this module never deletes snapshots and offers no undo.\n'
}

main() {
  local action="${1:-describe}"
  case "${action}" in
    describe)
      describe
      ;;
    plan)
      plan
      ;;
    dry-run)
      dry_run
      ;;
    run)
      run
      ;;
    *)
      printf 'Unknown action: %s\n' "${action}" >&2
      exit 1
      ;;
  esac
}

main "$@"
