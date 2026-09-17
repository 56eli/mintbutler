#!/usr/bin/env bash
set -euo pipefail

# modules/appimage-installer/module.sh
# Installs an AppImage for the current user: validates the file, copies it
# to a managed user-owned location, marks it executable, and registers a
# menu entry strictly through the shared lib/desktop-entry.sh pipeline.
# The original file is only ever read — never modified, moved, deleted, or
# executed. Undo removes exactly the entry and the installed copy.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${MINTBUTLER_LIB_DIR:-$(cd "${SCRIPT_DIR}/../../lib" && pwd)}"

# shellcheck source=lib/ask.sh
source "${LIB_DIR}/ask.sh"
# shellcheck source=lib/desktop-entry.sh
source "${LIB_DIR}/desktop-entry.sh"

MODULE_SLUG="appimage-installer"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/mintbutler-appimages"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mintbutler/${MODULE_SLUG}"

describe() {
  printf 'Validates an AppImage, installs a private executable copy for the current user, and registers a menu entry; undo removes both.\n'
}

plan() {
  cat <<'EOF'
Plan for appimage-installer:
1. Ask for the path to the .AppImage file (q cancels at every question)
2. Validate it: existing, regular, readable, named .AppImage or .appimage
3. Ask for the menu entry name (Enter accepts the derived default)
4. Ask for apply confirmation (Enter = no; nothing is written before a yes)
5. Copy to ~/.local/share/mintbutler-appimages/<name>.AppImage, chmod +x
   (same bytes already there -> reuse; a different one lands as -2, -3, ...)
6. Create the menu entry via the shared lib/desktop-entry.sh pipeline and
   mark it trusted
7. Record entry + copy under ~/.local/state/mintbutler/appimage-installer/
EOF
}

dry_run() {
  plan
  printf '\n'
  printf 'Exact paths for this machine (dry-run writes nothing):\n'
  printf '  install dir:      %s\n' "${INSTALL_DIR}"
  printf '  private copy:     %s/<name>.AppImage (or <name>-N.AppImage on a collision)\n' "${INSTALL_DIR}"
  printf '  applications dir: %s\n' "${APP_DIR}"
  printf '  menu entry:       %s/<name>.desktop\n' "${APP_DIR}"
  printf '  undo state:       %s/\n' "${STATE_DIR}"
  printf 'The AppImage file is only read — never modified, moved, deleted, or executed.\n'
}

run() {
  # Question 1 of 3: path to the AppImage (q cancels).
  local src=""
  if ! src="$(ask_value "Path to the .AppImage file (q to cancel)")"; then
    printf 'This module needs interactive input; start it from the butler menu.\n' >&2
    exit 1
  fi
  if [[ "${src}" == "q" || "${src}" == "Q" ]]; then
    printf 'Nothing changed.\n'
    return 0
  fi

  # Validation happens before any write: existing, regular, readable,
  # and named like an AppImage.
  if [[ ! -e "${src}" ]]; then
    printf 'No such file: %s\n' "${src}" >&2
    exit 1
  fi
  if [[ ! -f "${src}" ]]; then
    printf 'Not a regular file: %s\n' "${src}" >&2
    exit 1
  fi
  if [[ ! -r "${src}" ]]; then
    printf 'File is not readable: %s\n' "${src}" >&2
    exit 1
  fi

  local base="" stem=""
  base="$(basename -- "${src}")"
  case "${base}" in
    *.AppImage)
      stem="${base%.AppImage}"
      ;;
    *.appimage)
      stem="${base%.appimage}"
      ;;
    *)
      printf 'Not an AppImage file: %s (the name must end in .AppImage or .appimage)\n' "${base}" >&2
      exit 1
      ;;
  esac

  # Derived default entry name: basename minus extension, dashes and
  # underscores become spaces.
  local derived_name=""
  derived_name="$(printf '%s' "${stem}" | tr '_-' '  ')"

  # Question 2 of 3: the entry name (Enter accepts the derived default).
  local name=""
  if ! name="$(ask_value "Menu entry name [default: ${derived_name}]" "${derived_name}")"; then
    printf 'This module needs interactive input; start it from the butler menu.\n' >&2
    exit 1
  fi
  if [[ "${name}" == "q" || "${name}" == "Q" ]]; then
    printf 'Nothing changed.\n'
    return 0
  fi

  # Sanitized slug keeps the copy name and the entry's Exec value free of
  # spaces and special characters.
  local slug=""
  if ! slug="$(desktop_sanitize_name "${name}")"; then
    exit 1
  fi

  # Question 3 of 3: apply confirmation. Enter defaults to no; nothing has
  # been written up to this point.
  printf 'About to install:\n'
  printf '  from:  %s\n' "${src}"
  printf '  copy:  %s/%s.AppImage (a name collision lands as -2, -3, ...)\n' "${INSTALL_DIR}" "${slug}"
  printf '  entry: %s/%s.desktop (menu name: %s)\n' "${APP_DIR}" "${slug}" "${name}"
  if ! ask_yn "Install this AppImage?"; then
    printf 'Nothing changed.\n'
    return 0
  fi

  # Install the private copy. An identical existing copy is reused as-is;
  # a different file at that name shifts this one to the first free -N.
  # The original is never touched.
  mkdir -p "${INSTALL_DIR}"
  local copy_path="" fresh_copy="no"
  local base_copy="${INSTALL_DIR}/${slug}.AppImage"
  if [[ ! -e "${base_copy}" ]]; then
    cp -- "${src}" "${base_copy}"
    copy_path="${base_copy}"
    fresh_copy="yes"
  elif cmp -s -- "${src}" "${base_copy}"; then
    copy_path="${base_copy}"
    printf 'Already installed: %s (identical copy, reused)\n' "${copy_path}"
  else
    local n=2 candidate=""
    while true; do
      candidate="${INSTALL_DIR}/${slug}-${n}.AppImage"
      if [[ ! -e "${candidate}" ]]; then
        cp -- "${src}" "${candidate}"
        copy_path="${candidate}"
        fresh_copy="yes"
        break
      fi
      if cmp -s -- "${src}" "${candidate}"; then
        copy_path="${candidate}"
        printf 'Already installed: %s (identical copy, reused)\n' "${copy_path}"
        break
      fi
      n=$(( n + 1 ))
    done
  fi
  chmod +x "${copy_path}"
  if [[ "${fresh_copy}" == "yes" ]]; then
    printf 'Installed private copy: %s\n' "${copy_path}"
  fi

  # Menu entry, strictly through the shared desktop-entry pipeline.
  desktop_check_shadowing "${slug}"

  local tmp_desktop=""
  tmp_desktop="$(mktemp)"
  desktop_build_content Application "${name}" "${copy_path}" "" false "" > "${tmp_desktop}"

  mkdir -p "${APP_DIR}"
  local resolve_info="" target_file="" status=""
  resolve_info="$(desktop_resolve_target "${APP_DIR}" "${slug}" "${tmp_desktop}")"
  target_file="$(echo "${resolve_info}" | cut -d' ' -f1)"
  status="$(echo "${resolve_info}" | cut -d' ' -f2)"

  if [[ "${status}" == "already-done" ]]; then
    printf 'Already registered: %s (identical entry, kept)\n' "${target_file}"
  else
    cp -- "${tmp_desktop}" "${target_file}"
    if ! desktop_validate_file "${target_file}"; then
      rm -f "${tmp_desktop}"
      printf 'Entry validation failed for %s\n' "${target_file}" >&2
      return 1
    fi
    desktop_trust_and_exec "${target_file}"
    if [[ "${status}" == "versioned" ]]; then
      printf 'Created menu entry %s; existing %s.desktop was kept.\n' "$(basename -- "${target_file}")" "${slug}"
    else
      printf 'Created menu entry: %s\n' "${target_file}"
    fi
  fi
  rm -f "${tmp_desktop}"

  # Undo depends on both records: the entry and the installed copy.
  desktop_record_path "${MODULE_SLUG}" "${slug}" "${target_file}"
  desktop_record_path "${MODULE_SLUG}" "${slug}" "${copy_path}"

  printf 'Done — "%s" is now in your application menu.\n' "${name}"
  printf 'Undo removes the entry and the installed copy; the original file\n'
  printf 'at %s always stays untouched.\n' "${src}"
  return 0
}

undo() {
  desktop_undo "${MODULE_SLUG}"
  printf 'The original downloaded AppImage was never touched; it stays where you saved it.\n'
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
