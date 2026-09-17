#!/usr/bin/env bash
set -euo pipefail

# modules/screenshot-studio/module.sh
# Installs Flameshot and points the Print Screen key at it through Cinnamon's
# dconf keybinding store. The package install is the single, visible,
# menu-confirmed root step (its command string lives here; lib/elevate.sh is
# the only file that holds the privileged executor); the key binding is
# recorded before it changes and restored again by undo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${MINTBUTLER_LIB_DIR:-$(cd "${SCRIPT_DIR}/../../lib" && pwd)}"

# Pass this module's slug so lib/elevate.sh can check the manifest's risk
# declaration before anything privileged runs.
export MINTBUTLER_MODULE_SLUG="${MINTBUTLER_MODULE_SLUG:-screenshot-studio}"

# shellcheck source=lib/elevate.sh
source "${LIB_DIR}/elevate.sh"

# Fixed, reviewed install command; the privileged prefix is added by
# lib/elevate.sh, which shows the full line before it runs anything.
INSTALL_COMMAND="apt-get install -y flameshot"

BUILTIN_KEY="/org/cinnamon/keybindings/screenshot"
CUSTOM_LIST_KEY="/org/cinnamon/keybindings/custom-list"
CUSTOM_SLOT="/org/cinnamon/keybindings/custom/mintbutler-flameshot"

SLOT_NAME="Flameshot (mintbutler)"
SLOT_COMMAND="flameshot gui"
SLOT_BINDING="['Print']"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mintbutler/screenshot-studio"
STATE_FILE="${STATE_DIR}/binding.paths"

describe() {
  printf 'Installs Flameshot and points the Print Screen key at it; the key binding is undoable.\n'
}

plan() {
  printf 'Plan for screenshot-studio:\n'
  printf '1. Check whether Flameshot is installed; if it is missing, run the single\n'
  printf '   elevated, confirmed step: %s\n' "$(elevate_command_line "${INSTALL_COMMAND}")"
  printf '2. Check that dconf is available; stop without writing if it is not.\n'
  printf '3. If %s/command already points at flameshot, report it and stop.\n' "${CUSTOM_SLOT}"
  printf '4. Record the current %s and %s values in\n' "${BUILTIN_KEY}" "${CUSTOM_LIST_KEY}"
  printf '   %s (UNSET when a value was empty)\n' "${STATE_FILE}"
  printf '5. Write the custom slot %s/\n' "${CUSTOM_SLOT}"
  printf '   (name, command, binding) and add the slot to custom-list.\n'
  printf '6. Clear %s only if it still holds Print.\n' "${BUILTIN_KEY}"
  printf '7. Re-read the slot to verify, then report the mixed undo story.\n'
}

dry_run() {
  plan
  printf '\n'
  printf 'Exact commands (nothing runs now; values as written):\n'
  printf '  %s\n' "$(elevate_command_line "${INSTALL_COMMAND}")"
  printf '  dconf read %s ; dconf read %s ; dconf read %s/command\n' \
    "${BUILTIN_KEY}" "${CUSTOM_LIST_KEY}" "${CUSTOM_SLOT}"
  printf "  dconf write %s/name '%s'\n" "${CUSTOM_SLOT}" "${SLOT_NAME}"
  printf "  dconf write %s/command '%s'\n" "${CUSTOM_SLOT}" "${SLOT_COMMAND}"
  printf '  dconf write %s/binding %s\n' "${CUSTOM_SLOT}" "${SLOT_BINDING}"
  printf "  dconf write %s (current list plus '%s/')\n" "${CUSTOM_LIST_KEY}" "${CUSTOM_SLOT}"
  printf '  dconf write %s @as [] (only if it holds Print)\n' "${BUILTIN_KEY}"
  printf '  undo: dconf reset or write back the recorded values, drop the slot from\n'
  printf '        custom-list, dconf reset -f %s/, remove the state file\n' "${CUSTOM_SLOT}"
}

dconf_read() {
  local key="${1:-}"
  local value=""
  value="$(dconf read "${key}" 2>/dev/null)" || value=""
  printf '%s' "${value}"
}

dconf_write() {
  local key="${1:-}"
  local value="${2:-}"
  dconf write "${key}" "${value}"
}

# Append the slot path to a custom-list value. Opaque-string handling: the
# current value is only inspected for the slot and for a trailing ']'.
slot_append_to_list() {
  local current="${1:-}"
  if [[ -z "${current}" || "${current}" == "[]" || "${current}" == "@as []" ]]; then
    printf "['%s/']\n" "${CUSTOM_SLOT}"
    return 0
  fi
  if [[ "${current}" == *"${CUSTOM_SLOT}"* ]]; then
    printf '%s\n' "${current}"
    return 0
  fi
  if [[ "${current}" != *"]" ]]; then
    printf 'Unexpected custom-list value (%s); refusing to rewrite it.\n' "${current}" >&2
    return 1
  fi
  local body="${current%]}"
  body="${body%"${body##*[![:space:]]}"}"
  body="${body%,}"
  printf "%s, '%s/']\n" "${body}" "${CUSTOM_SLOT}"
}

# Remove the slot path from a custom-list value; empty output means "reset".
slot_remove_from_list() {
  local current="${1:-}"
  if [[ -z "${current}" ]]; then
    return 0
  fi
  if [[ "${current}" != *"${CUSTOM_SLOT}"* ]]; then
    printf '%s\n' "${current}"
    return 0
  fi
  local inner="${current#\[}"
  inner="${inner%\]}"
  local -a raw_parts=()
  IFS=',' read -r -a raw_parts <<< "${inner}" || true
  local part trimmed kept="" kept_count=0
  for part in "${raw_parts[@]}"; do
    trimmed="${part#"${part%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    if [[ -z "${trimmed}" ]]; then
      continue
    fi
    if [[ "${trimmed}" == *"${CUSTOM_SLOT}"* ]]; then
      continue
    fi
    if [[ "${kept_count}" -eq 0 ]]; then
      kept="${trimmed}"
    else
      kept="${kept}, ${trimmed}"
    fi
    kept_count=$(( kept_count + 1 ))
  done
  if [[ "${kept_count}" -eq 0 ]]; then
    return 0
  fi
  printf '[%s]\n' "${kept}"
}

run() {
  local install_code=0
  if command -v flameshot >/dev/null 2>&1; then
    printf 'Flameshot is already installed; skipping the install step.\n'
  else
    printf 'Flameshot is missing; running the single elevated step.\n'
    elevate_run "${INSTALL_COMMAND}" || install_code="$?"
    if ! command -v flameshot >/dev/null 2>&1; then
      printf 'The flameshot install did not succeed (elevated command exited %d); nothing else was changed.\n' \
        "${install_code}" >&2
      exit 1
    fi
    printf 'Flameshot is installed now.\n'
  fi

  if ! command -v dconf >/dev/null 2>&1; then
    printf 'dconf not available; keybinding changes need the Cinnamon session tools\n' >&2
    exit 1
  fi

  local slot_command=""
  slot_command="$(dconf_read "${CUSTOM_SLOT}/command")"
  if [[ -n "${slot_command}" && "${slot_command}" == *flameshot* ]]; then
    local slot_binding=""
    slot_binding="$(dconf_read "${CUSTOM_SLOT}/binding")"
    printf 'Already configured: the custom slot already points at flameshot.\n'
    printf '  slot:    %s/\n' "${CUSTOM_SLOT}"
    printf '  command: %s\n' "${slot_command}"
    printf '  binding: %s\n' "${slot_binding:-unset}"
    printf 'Nothing to do.\n'
    return 0
  fi

  local builtin_value="" list_value=""
  builtin_value="$(dconf_read "${BUILTIN_KEY}")"
  list_value="$(dconf_read "${CUSTOM_LIST_KEY}")"
  mkdir -p "${STATE_DIR}"
  {
    printf 'screenshot=%s\n' "${builtin_value:-UNSET}"
    printf 'custom_list=%s\n' "${list_value:-UNSET}"
  } > "${STATE_FILE}"
  printf 'Recorded the current binding in %s\n' "${STATE_FILE}"

  local new_list=""
  if ! new_list="$(slot_append_to_list "${list_value}")"; then
    exit 1
  fi

  local list_written="0" builtin_cleared="0"
  dconf_write "${CUSTOM_SLOT}/name" "'${SLOT_NAME}'"
  dconf_write "${CUSTOM_SLOT}/command" "'${SLOT_COMMAND}'"
  dconf_write "${CUSTOM_SLOT}/binding" "${SLOT_BINDING}"
  printf 'Wrote the custom slot %s/ (name, command, binding)\n' "${CUSTOM_SLOT}"

  if [[ "${new_list}" != "${list_value}" ]]; then
    dconf_write "${CUSTOM_LIST_KEY}" "${new_list}"
    list_written="1"
    printf 'Added the slot to %s\n' "${CUSTOM_LIST_KEY}"
  fi

  if [[ "${builtin_value}" == *Print* ]]; then
    dconf_write "${BUILTIN_KEY}" "@as []"
    builtin_cleared="1"
    printf 'Cleared the built-in %s (it held Print)\n' "${BUILTIN_KEY}"
  fi

  local verify_command="" verify_binding=""
  verify_command="$(dconf_read "${CUSTOM_SLOT}/command")"
  verify_binding="$(dconf_read "${CUSTOM_SLOT}/binding")"
  if [[ "${verify_command}" != *flameshot* || "${verify_binding}" != *Print* ]]; then
    printf 'Verification failed: the custom slot read back as command=%s binding=%s; nothing further was changed and undo can reverse this.\n' \
      "${verify_command:-unset}" "${verify_binding:-unset}" >&2
    exit 1
  fi

  printf 'Verified: %s/command=%s binding=%s\n' "${CUSTOM_SLOT}" "${verify_command}" "${verify_binding}"
  printf 'Print Screen now starts Flameshot.\n'
  printf "Undo: the key binding is restored by [u]ndo in the menu; flameshot stays installed because package installs don't cleanly undo.\n"
  if [[ "${list_written}" == "0" && "${builtin_cleared}" == "0" ]]; then
    printf 'No previous binding needed clearing.\n'
  fi
}

undo() {
  if [[ ! -f "${STATE_FILE}" ]]; then
    printf 'Nothing to undo.\n'
    return 0
  fi

  if ! command -v dconf >/dev/null 2>&1; then
    printf 'dconf not available; keybinding changes need the Cinnamon session tools\n' >&2
    return 1
  fi

  local recorded_builtin="" recorded_list="" line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    case "${line}" in
      screenshot=*) recorded_builtin="${line#screenshot=}" ;;
      custom_list=*) recorded_list="${line#custom_list=}" ;;
    esac
  done < "${STATE_FILE}"

  if [[ -z "${recorded_builtin}" || "${recorded_builtin}" == "UNSET" ]]; then
    dconf reset "${BUILTIN_KEY}"
    printf 'Reset %s (it was unset before)\n' "${BUILTIN_KEY}"
  else
    dconf_write "${BUILTIN_KEY}" "${recorded_builtin}"
    printf 'Restored %s = %s\n' "${BUILTIN_KEY}" "${recorded_builtin}"
  fi

  local current_list="" new_list=""
  current_list="$(dconf_read "${CUSTOM_LIST_KEY}")"
  # Defensive: if the key now reads empty, fall back to the recorded value so
  # undo still removes the slot entry it added.
  if [[ -z "${current_list}" ]]; then
    current_list="${recorded_list}"
  fi
  if [[ "${current_list}" == "UNSET" ]]; then
    current_list=""
  fi
  if ! new_list="$(slot_remove_from_list "${current_list}")"; then
    return 1
  fi
  if [[ -z "${new_list}" && -n "${current_list}" ]]; then
    dconf reset "${CUSTOM_LIST_KEY}"
    printf 'Reset %s (the slot was its only entry)\n' "${CUSTOM_LIST_KEY}"
  elif [[ -n "${new_list}" && "${new_list}" != "${current_list}" ]]; then
    dconf_write "${CUSTOM_LIST_KEY}" "${new_list}"
    printf 'Left %s without the slot\n' "${CUSTOM_LIST_KEY}"
  fi

  dconf reset -f "${CUSTOM_SLOT}/"
  printf 'Removed the custom slot %s/\n' "${CUSTOM_SLOT}"

  rm -f "${STATE_FILE}"
  rmdir "${STATE_DIR}" 2>/dev/null || true

  printf "Flameshot stays installed — package installs don't cleanly undo.\n"
  printf 'Undo complete.\n'
  return 0
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
    undo)
      undo
      ;;
    *)
      printf 'Unknown action: %s\n' "${action}" >&2
      exit 1
      ;;
  esac
}

main "$@"
