#!/usr/bin/env bash
set -euo pipefail

# lib/desktop-entry.sh — shared core for .desktop entry creation,
# validation, versioning, trust, recording, and undo.
# Cinnamon picks entries up automatically; no cache pokes or daemon restarts.

desktop_sanitize_name() {
  local name="${1:-}"
  local slug
  slug="$(printf '%s' "${name}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+//; s/-+$//')"
  if [[ -z "${slug}" ]]; then
    printf 'Name produces an empty filename slug.\n' >&2
    return 1
  fi
  printf '%s\n' "${slug}"
  return 0
}

desktop_check_shadowing() {
  local slug="${1:-}"
  local system_dirs="${MINTBUTLER_TEST_APP_DIRS-/usr/share/applications}"
  local -a dirs=()
  IFS=':' read -r -a dirs <<< "${system_dirs}" || true
  local dir
  for dir in "${dirs[@]}"; do
    if [[ -z "${dir}" ]]; then
      continue
    fi
    if [[ -f "${dir}/${slug}.desktop" ]]; then
      printf 'Warning: new entry shadows system-provided application in %s/%s.desktop\n' "${dir}" "${slug}"
      return 0
    fi
  done
  return 0
}

desktop_validate_exec() {
  local exec_val="${1:-}"
  if [[ "${exec_val}" =~ [[:space:]] ]]; then
    if [[ ! "${exec_val}" =~ ^\"[^\"]*\"$ && ! "${exec_val}" =~ ^\'[^\']*\'$ ]]; then
      printf 'Exec contains spaces; quote the full command, e.g. "/opt/my app/run"\n' >&2
      return 1
    fi
  fi
  return 0
}

desktop_build_content() {
  local entry_type="${1:-Application}" # Application or Link
  local name="${2:-}"
  local target="${3:-}"               # Exec command or URL
  local icon="${4:-}"
  local terminal="${5:-false}"
  local workdir="${6:-}"

  cat <<EOF
[Desktop Entry]
Type=${entry_type}
Name=${name}
EOF

  if [[ "${entry_type}" == "Application" ]]; then
    cat <<EOF
Exec=${target}
EOF
    if [[ "${terminal}" == "true" ]]; then
      cat <<EOF
Terminal=true
EOF
    fi
    if [[ -n "${workdir}" ]]; then
      cat <<EOF
Path=${workdir}
EOF
    fi
  else
    cat <<EOF
URL=${target}
EOF
  fi

  if [[ -n "${icon}" ]]; then
    cat <<EOF
Icon=${icon}
EOF
  fi

  cat <<EOF
Comment=Created by mintbutler desktop-shortcut-creator
EOF
}

desktop_validate_file() {
  local file_path="${1:-}"
  if command -v desktop-file-validate >/dev/null 2>&1; then
    local val_out="" val_code=0
    val_out="$(desktop-file-validate "${file_path}" 2>&1)" || val_code="$?"
    if [[ "${val_code}" -ne 0 ]]; then
      printf 'desktop-file-validate failed for %s:\n%s\n' "${file_path}" "${val_out}" >&2
      return 1
    fi
  else
    printf 'advisory: desktop-file-validate not found; validation skipped\n'
  fi
  return 0
}

desktop_resolve_target() {
  local target_dir="${1:-}"
  local slug="${2:-}"
  local temp_file="${3:-}"

  local base_file="${target_dir}/${slug}.desktop"
  if [[ ! -f "${base_file}" ]]; then
    printf '%s new\n' "${base_file}"
    return 0
  fi

  if cmp -s "${base_file}" "${temp_file}"; then
    printf '%s already-done\n' "${base_file}"
    return 0
  fi

  local n=2
  while true; do
    local candidate="${target_dir}/${slug}-${n}.desktop"
    if [[ ! -f "${candidate}" ]]; then
      printf '%s versioned\n' "${candidate}"
      return 0
    fi
    if cmp -s "${candidate}" "${temp_file}"; then
      printf '%s already-done\n' "${candidate}"
      return 0
    fi
    n=$(( n + 1 ))
  done
}

desktop_trust_and_exec() {
  local target_path="${1:-}"
  chmod +x "${target_path}"
  if command -v gio >/dev/null 2>&1; then
    gio set "${target_path}" metadata::trusted true 2>/dev/null || true
  else
    printf 'advisory: gio not found; trusted flag could not be set (Cinnamon may prompt until trusted manually)\n'
  fi
}

desktop_record_path() {
  local module_slug="${1:-desktop-shortcut-creator}"
  local entry_slug="${2:-default}"
  local path_to_record="${3:-}"

  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/mintbutler/${module_slug}"
  mkdir -p "${state_dir}"
  local state_file="${state_dir}/${entry_slug}.paths"

  if [[ -f "${state_file}" ]]; then
    if ! grep -Fxq "${path_to_record}" "${state_file}"; then
      printf '%s\n' "${path_to_record}" >> "${state_file}"
    fi
  else
    printf '%s\n' "${path_to_record}" > "${state_file}"
  fi
}

desktop_undo() {
  local module_slug="${1:-desktop-shortcut-creator}"
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/mintbutler/${module_slug}"

  if [[ ! -d "${state_dir}" ]]; then
    printf 'Nothing to undo.\n'
    return 0
  fi

  local -a state_files=()
  local f
  for f in "${state_dir}"/*.paths; do
    if [[ -f "${f}" ]]; then
      state_files+=("${f}")
    fi
  done

  if [[ "${#state_files[@]}" -eq 0 ]]; then
    printf 'Nothing to undo.\n'
    return 0
  fi

  local line path_to_remove removed_count=0
  for f in "${state_files[@]}"; do
    while IFS= read -r line || [[ -n "${line}" ]]; do
      line="$(printf '%s' "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      if [[ -z "${line}" ]]; then
        continue
      fi
      path_to_remove="${line}"
      if [[ -f "${path_to_remove}" || -L "${path_to_remove}" ]]; then
        rm -f "${path_to_remove}"
        printf 'Removed: %s\n' "${path_to_remove}"
        removed_count=$(( removed_count + 1 ))
      fi
    done < "${f}"
    rm -f "${f}"
  done

  rmdir "${state_dir}" 2>/dev/null || true

  if [[ "${removed_count}" -eq 0 ]]; then
    printf 'Nothing to undo.\n'
  else
    printf 'Undo complete (%d file(s) removed).\n' "${removed_count}"
  fi
  return 0
}
