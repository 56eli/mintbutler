#!/usr/bin/env bash
set -euo pipefail

# modules/desktop-shortcut-creator/module.sh
# Creates desktop shortcuts via Scan & place or guided Custom launcher.
# Validated, undoable, never sudo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${MINTBUTLER_LIB_DIR:-$(cd "${SCRIPT_DIR}/../../lib" && pwd)}"

# shellcheck source=lib/ask.sh
source "${LIB_DIR}/ask.sh"
# shellcheck source=lib/picker.sh
source "${LIB_DIR}/picker.sh"
# shellcheck source=lib/desktop-entry.sh
source "${LIB_DIR}/desktop-entry.sh"

describe() {
  printf 'Creates desktop shortcuts from installed apps or custom launchers.\n'
}

plan() {
  cat <<'EOF'
Plan for desktop-shortcut-creator:
1. Choose mode: Scan & place installed apps, or create a custom launcher
2. For Scan & place: pick installed applications and place desktop copies
3. For Custom: collect launcher type, target, name, and optional settings
4. Validate desktop entry format and Exec quoting rules
5. Write .desktop file to ~/.local/share/applications/ (and ~/Desktop/ if requested)
6. Mark desktop file executable and trusted via gio in user session (never elevated)
7. Record all created file paths under ~/.local/state/mintbutler/desktop-shortcut-creator/ for undo
EOF
}

dry_run() {
  plan
  printf '\n'
  cat <<'EOF'
Commands (with placeholders):
  # Custom launcher:
  cat <<'DESKTOP_EOF' > "$HOME/.local/share/applications/<sanitized-name>.desktop"
  [Desktop Entry]
  Type=Application
  Name=<Name>
  Exec=<Exec>
  Comment=Created by mintbutler desktop-shortcut-creator
  DESKTOP_EOF
  desktop-file-validate "$HOME/.local/share/applications/<sanitized-name>.desktop"
  cp "$HOME/.local/share/applications/<sanitized-name>.desktop" "$HOME/Desktop/<sanitized-name>.desktop"
  chmod +x "$HOME/Desktop/<sanitized-name>.desktop"
  gio set "$HOME/Desktop/<sanitized-name>.desktop" metadata::trusted true

  # Scan & place:
  cp "/usr/share/applications/<app>.desktop" "$HOME/Desktop/<sanitized-name>.desktop"
  chmod +x "$HOME/Desktop/<sanitized-name>.desktop"
  gio set "$HOME/Desktop/<sanitized-name>.desktop" metadata::trusted true
EOF
}

run_custom() {
  # 1. Entry type
  local type_input="1" entry_type="Application"
  type_input="$(ask_value "Launcher type: 1) Application  2) Folder  3) URL [default: 1]" "1")"
  case "${type_input}" in
    1|app|application|Application)
      entry_type="Application"
      ;;
    2|folder|Folder)
      entry_type="Folder"
      ;;
    3|url|URL)
      entry_type="URL"
      ;;
    *)
      entry_type="Application"
      ;;
  esac

  # 2. Target
  local target="" target_url=""
  while true; do
    if [[ "${entry_type}" == "Application" ]]; then
      target="$(ask_value "Command to execute (e.g. /usr/bin/app)")"
      if [[ -z "${target}" ]]; then
        printf 'Error: Command is required.\n' >&2
        continue
      fi
      if ! desktop_validate_exec "${target}"; then
        continue
      fi
      break
    elif [[ "${entry_type}" == "Folder" ]]; then
      target="$(ask_value "Target folder path (existing absolute path)")"
      if [[ -z "${target}" ]]; then
        printf 'Error: Folder path is required.\n' >&2
        continue
      fi
      if [[ "${target}" != /* ]] || [[ ! -d "${target}" ]]; then
        printf 'Error: target folder must be an existing absolute path.\n' >&2
        continue
      fi
      target_url="file://${target}"
      break
    else # URL
      target="$(ask_value "Target URL (e.g. https://example.com/)")"
      if [[ -z "${target}" ]]; then
        printf 'Error: URL is required.\n' >&2
        continue
      fi
      if [[ ! "${target}" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
        printf 'Error: URL must begin with a scheme (e.g. https://).\n' >&2
        continue
      fi
      target_url="${target}"
      break
    fi
  done

  # 3. Name (required)
  local name="" slug=""
  while true; do
    name="$(ask_value "Shortcut name")"
    if [[ -z "${name}" ]]; then
      printf 'Error: Name is required.\n' >&2
      continue
    fi
    if ! slug="$(desktop_sanitize_name "${name}")"; then
      continue
    fi
    break
  done

  # 4. Icon (optional)
  local icon=""
  icon="$(ask_value "Icon (file path or theme icon name, Enter to skip)" "")"
  if [[ -n "${icon}" && "${icon}" == *"/"* ]]; then
    if [[ ! -f "${icon}" ]]; then
      printf 'advisory: icon file "%s" does not exist; entry will be created anyway\n' "${icon}" >&2
    fi
  fi

  # 5. Apps only: terminal and workdir
  local terminal="false" workdir=""
  if [[ "${entry_type}" == "Application" ]]; then
    if ask_yn "Run in terminal?"; then
      terminal="true"
    fi
    workdir="$(ask_value "Working directory (Enter to skip)" "")"
  fi

  # 6. Desktop copy?
  local desktop_copy="false"
  if ask_yn "Create desktop copy?"; then
    desktop_copy="true"
  fi

  # Check shadowing of system application
  desktop_check_shadowing "${slug}"

  # Build .desktop content
  local tmp_desktop
  tmp_desktop="$(mktemp)"
  if [[ "${entry_type}" == "Application" ]]; then
    desktop_build_content "Application" "${name}" "${target}" "${icon}" "${terminal}" "${workdir}" > "${tmp_desktop}"
  else
    desktop_build_content "Link" "${name}" "${target_url}" "${icon}" > "${tmp_desktop}"
  fi

  # Validate .desktop content
  if ! desktop_validate_file "${tmp_desktop}"; then
    rm -f "${tmp_desktop}"
    return 1
  fi

  # Target in ~/.local/share/applications
  local app_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  mkdir -p "${app_dir}"

  local resolve_info target_file status
  resolve_info="$(desktop_resolve_target "${app_dir}" "${slug}" "${tmp_desktop}")"
  target_file="$(echo "${resolve_info}" | cut -d' ' -f1)"
  status="$(echo "${resolve_info}" | cut -d' ' -f2)"

  if [[ "${status}" == "already-done" ]]; then
    printf 'Already exists: %s (identical content, kept)\n' "${target_file}"
  else
    cp "${tmp_desktop}" "${target_file}"
    chmod +x "${target_file}"
    desktop_record_path "desktop-shortcut-creator" "$(basename "${target_file}" .desktop)" "${target_file}"
    if [[ "${status}" == "versioned" ]]; then
      printf 'Created %s; existing %s.desktop was kept.\n' "$(basename "${target_file}")" "${slug}"
    else
      printf 'Created %s\n' "$(basename "${target_file}")"
    fi
  fi

  local desk_file=""
  if [[ "${desktop_copy}" == "true" ]]; then
    local desk_dir="${HOME}/Desktop"
    mkdir -p "${desk_dir}"
    local desk_slug desk_resolve desk_status
    desk_slug="$(basename "${target_file}" .desktop)"
    desk_resolve="$(desktop_resolve_target "${desk_dir}" "${desk_slug}" "${tmp_desktop}")"
    desk_file="$(echo "${desk_resolve}" | cut -d' ' -f1)"
    desk_status="$(echo "${desk_resolve}" | cut -d' ' -f2)"

    if [[ "${desk_status}" == "already-done" ]]; then
      printf 'Already exists: %s (identical content, kept)\n' "${desk_file}"
    else
      cp "${tmp_desktop}" "${desk_file}"
      desktop_trust_and_exec "${desk_file}"
      desktop_record_path "desktop-shortcut-creator" "$(basename "${desk_file}" .desktop)" "${desk_file}"
      if [[ "${desk_status}" == "versioned" ]]; then
        printf 'Created %s on Desktop; existing file was kept.\n' "$(basename "${desk_file}")"
      else
        printf 'Created %s on Desktop\n' "$(basename "${desk_file}")"
      fi
    fi
  fi

  # Transparency close-out: print final content of every entry file created
  printf '\nEntry file content (%s):\n' "${target_file}"
  cat "${target_file}"
  printf '\n'
  if [[ "${desktop_copy}" == "true" && -n "${desk_file}" ]]; then
    printf 'Desktop copy placed at %s\n' "${desk_file}"
  fi

  # Test launch offer for Custom app entries only
  if [[ "${entry_type}" == "Application" ]]; then
    if ask_yn "test-launch it now?"; then
      printf 'Test-launching %s...\n' "${target}"
      if command -v setsid >/dev/null 2>&1; then
        local launch_cmd="${target}"
        if [[ "${launch_cmd}" =~ ^\"(.*)\"$ ]]; then
          launch_cmd="${BASH_REMATCH[1]}"
        elif [[ "${launch_cmd}" =~ ^\'(.*)\'$ ]]; then
          launch_cmd="${BASH_REMATCH[1]}"
        fi
        setsid ${launch_cmd} </dev/null >/dev/null 2>&1 &
      else
        printf 'advisory: setsid not found; test-launch skipped\n'
      fi
    fi
  fi

  rm -f "${tmp_desktop}"
  return 0
}

run_scan_and_place() {
  local user_app_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  local system_dirs="${MINTBUTLER_TEST_APP_DIRS-/usr/share/applications}"

  local -a dir_list=()
  if [[ -d "${user_app_dir}" ]]; then
    dir_list+=("${user_app_dir}")
  fi
  local -a sys_arr=()
  IFS=':' read -r -a sys_arr <<< "${system_dirs}" || true
  local d
  for d in "${sys_arr[@]}"; do
    if [[ -n "${d}" && -d "${d}" ]]; then
      dir_list+=("${d}")
    fi
  done

  # Collect applications; prefer user-dir copies on duplicate names
  local -a app_names=()
  local -a app_files=()
  local -A seen_names=()

  local dir file name line base
  for dir in "${dir_list[@]}"; do
    for file in "${dir}"/*.desktop; do
      if [[ ! -f "${file}" || ! -r "${file}" ]]; then
        continue
      fi
      name=""
      local cr=$'\r'
      while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line%"$cr"}"
        if [[ "${line}" == Name=* ]]; then
          name="${line#Name=}"
          break
        fi
      done < "${file}"
      if [[ -z "${name}" ]]; then
        base="$(basename "${file}" .desktop)"
        name="${base}"
      fi
      if [[ -z "${name}" ]]; then
        continue
      fi
      if [[ -z "${seen_names["${name}"]:-}" ]]; then
        seen_names["${name}"]="${file}"
        app_names+=("${name}")
      fi
    done
  done

  if [[ "${#app_names[@]}" -eq 0 ]]; then
    printf 'No installed applications found to place.\n'
    return 0
  fi

  # Sort application names case-insensitively
  local sorted_names_str
  sorted_names_str="$(printf '%s\n' "${app_names[@]}" | sort -f)"
  local -a sorted_names=()
  local -a sorted_srcs=()
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ -n "${line}" ]]; then
      sorted_names+=("${line}")
      sorted_srcs+=("${seen_names["${line}"]}")
    fi
  done <<< "${sorted_names_str}"

  # Run multi-select picker
  if ! picker_multi_select "Scan & place — Select applications to add to Desktop:" "${sorted_names[@]}"; then
    printf 'Cancelled.\n'
    return 0
  fi

  if [[ "${#PICKER_SELECTED_INDICES[@]}" -eq 0 ]]; then
    printf 'No applications selected.\n'
    return 0
  fi

  # Confirmation listing (strictly <= 23 lines)
  local total_sel="${#PICKER_SELECTED_INDICES[@]}"
  printf 'Creating desktop shortcuts (%d selected):\n' "${total_sel}"
  local max_list=18 list_count=0 idx c_name
  for idx in "${PICKER_SELECTED_INDICES[@]}"; do
    list_count=$(( list_count + 1 ))
    c_name="${sorted_names[idx]}"
    if (( list_count <= max_list )); then
      printf '  - %s\n' "${c_name}"
    fi
  done
  if (( total_sel > max_list )); then
    printf '  …and %d more\n' "$(( total_sel - max_list ))"
  fi
  printf '\n'

  # Copy and trust each selected application
  local desk_dir="${HOME}/Desktop"
  mkdir -p "${desk_dir}"

  local c_src c_slug resolve_info target_file status
  for idx in "${PICKER_SELECTED_INDICES[@]}"; do
    c_name="${sorted_names[idx]}"
    c_src="${sorted_srcs[idx]}"
    if ! c_slug="$(desktop_sanitize_name "${c_name}")"; then
      continue
    fi

    resolve_info="$(desktop_resolve_target "${desk_dir}" "${c_slug}" "${c_src}")"
    target_file="$(echo "${resolve_info}" | cut -d' ' -f1)"
    status="$(echo "${resolve_info}" | cut -d' ' -f2)"

    if [[ "${status}" == "already-done" ]]; then
      printf 'Already exists: %s (identical content, kept)\n' "${target_file}"
    else
      cp "${c_src}" "${target_file}"
      desktop_trust_and_exec "${target_file}"
      desktop_record_path "desktop-shortcut-creator" "$(basename "${target_file}" .desktop)" "${target_file}"
      if [[ "${status}" == "versioned" ]]; then
        printf 'Created %s on Desktop; existing %s.desktop was kept.\n' "$(basename "${target_file}")" "${c_slug}"
      else
        printf 'Created %s on Desktop\n' "$(basename "${target_file}")"
      fi

      # Verbatim entries: advisory-only validation if desktop-file-validate exists
      if command -v desktop-file-validate >/dev/null 2>&1; then
        local val_out=""
        val_out="$(desktop-file-validate "${target_file}" 2>&1 || true)"
        if [[ -n "${val_out}" ]]; then
          printf 'advisory: %s: %s\n' "$(basename "${target_file}")" "${val_out}"
        fi
      fi
    fi
  done

  return 0
}

run() {
  local mode_choice=""
  if ! mode_choice="$(ask_value "Choose mode: 1) Scan & place (pick from installed apps)  2) Create a custom shortcut" "1")"; then
    printf 'This module needs interactive input; start it from the butler menu.\n' >&2
    exit 1
  fi

  case "${mode_choice}" in
    2|custom|Custom)
      run_custom
      ;;
    *)
      run_scan_and_place
      ;;
  esac
}

undo() {
  desktop_undo "desktop-shortcut-creator"
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
