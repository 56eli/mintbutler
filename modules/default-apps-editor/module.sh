#!/usr/bin/env bash
set -euo pipefail

# modules/default-apps-editor/module.sh
# Changes the user's default application for a chosen MIME category (or a
# custom MIME type) through xdg-mime. Before anything is written, the module
# shows the current default versus the new one for every type in the
# category, then backs up mimeapps.list byte for byte and applies the change
# (the menu takes the single confirmation for the run); undo restores that
# backup exactly. User-level only: xdg-mime writes the per-user mimeapps.list
# state and nothing else; nothing outside $HOME is ever touched.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${MINTBUTLER_LIB_DIR:-$(cd "${SCRIPT_DIR}/../../lib" && pwd)}"

# shellcheck source=lib/ask.sh
source "${LIB_DIR}/ask.sh"
# shellcheck source=lib/picker.sh
source "${LIB_DIR}/picker.sh"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mintbutler/default-apps-editor"
BACKUP_FILE="${STATE_DIR}/mimeapps.list.backup"
RECORD_FILE="${STATE_DIR}/changes.record"

# The fixed category list. Entry 9 (custom) is handled separately in run().
CATEGORY_LABELS=(
  "Web browser"
  "E-mail"
  "Image viewer"
  "Video player"
  "Audio player"
  "PDF viewer"
  "Text editor"
  "Archive manager"
)

CATEGORY_TYPES=(
  "text/html x-scheme-handler/http x-scheme-handler/https"
  "x-scheme-handler/mailto"
  "image/png image/jpeg"
  "video/mp4"
  "audio/mpeg"
  "application/pdf"
  "text/plain"
  "application/zip"
)

describe() {
  printf 'Changes default applications per MIME type via xdg-mime; shows current versus new, backs up mimeapps.list, undo restores byte for byte.\n'
}

plan() {
  printf 'Plan for default-apps-editor:\n'
  printf '1. Ask which category (or custom MIME type) to change\n'
  printf '2. Scan .desktop entries that claim those MIME types; pick one application\n'
  printf '3. Show the current default versus the new one for every type in the category\n'
  printf '4. Back up %s and apply the change (the menu already took the single confirmation)\n' "${CONFIG_FILE}"
  printf '   (BACKUP_MISSING is recorded when the file does not exist yet)\n'
  printf '5. Run xdg-mime default <chosen>.desktop <mime> for each type, then verify\n'
  printf '   each with xdg-mime query default; any mismatch restores the backup\n'
  printf '6. Undo restores the backup byte for byte (or removes the file it replaced)\n'
}

dry_run() {
  plan
  printf '\n'
  printf 'Exact commands (placeholders; the app id is chosen interactively):\n'
  printf '  xdg-mime query default <mime>            (read; once per type in the category)\n'
  printf '  xdg-mime default <chosen-app>.desktop %s\n' "${CATEGORY_TYPES[0]}"
  printf '  xdg-mime query default <mime>            (verify; once per type in the category)\n'
  printf 'Backup: %s\n' "${BACKUP_FILE}"
  printf 'Undo:   restore that backup over mimeapps.list byte for byte\n'
  printf '        (when the file did not exist before, undo removes it again)\n'
}

print_category_menu() {
  printf 'Default apps editor — choose what to change:\n'
  local i
  for i in "${!CATEGORY_LABELS[@]}"; do
    printf '  %d) %s (%s)\n' "$(( i + 1 ))" "${CATEGORY_LABELS[i]}" "${CATEGORY_TYPES[i]}"
  done
  printf '  9) Custom MIME type (type the exact type/subtype)\n'
}

# Collect candidate .desktop entries for the given MIME types (union: a file
# qualifies when its MimeType= line lists at least one of the types).
# Scans ${XDG_DATA_HOME:-$HOME/.local/share}/applications first (it shadows
# the system entries), then every ${XDG_DATA_DIRS:-...}/applications directory.
# Sets CAND_NAMES and CAND_IDS (display name / desktop file id), sorted
# case-insensitively by name. Duplicate desktop file ids are kept once.
collect_candidates() {
  CAND_NAMES=()
  CAND_IDS=()
  local -a types=("$@")
  if [[ "${#types[@]}" -eq 0 ]]; then
    return 0
  fi

  local -a dirs=()
  local user_app_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  if [[ -d "${user_app_dir}" ]]; then
    dirs+=("${user_app_dir}")
  fi
  local -a data_dirs=()
  IFS=':' read -r -a data_dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" || true
  local d
  for d in "${data_dirs[@]}"; do
    if [[ -n "${d}" && -d "${d}/applications" ]]; then
      dirs+=("${d}/applications")
    fi
  done

  local -A seen_ids=()
  local -a found_lines=()
  local dir file base name mimes line in_entry t type match
  local cr=$'\r'
  for dir in "${dirs[@]}"; do
    for file in "${dir}"/*.desktop; do
      if [[ ! -f "${file}" || ! -r "${file}" ]]; then
        continue
      fi
      base="$(basename "${file}")"
      if [[ -n "${seen_ids[${base}]:-}" ]]; then
        continue
      fi
      name=""
      mimes=""
      in_entry=0
      while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line%"$cr"}"
        if [[ "${line}" == "[Desktop Entry]" ]]; then
          in_entry=1
          continue
        fi
        if [[ "${in_entry}" == "1" && "${line}" == "["*"]" ]]; then
          break
        fi
        if [[ "${in_entry}" != "1" ]]; then
          continue
        fi
        if [[ "${line}" == "Name="* && -z "${name}" ]]; then
          name="${line#Name=}"
        elif [[ "${line}" == "MimeType="* && -z "${mimes}" ]]; then
          mimes="${line#MimeType=}"
        fi
        if [[ -n "${name}" && -n "${mimes}" ]]; then
          break
        fi
      done < "${file}"
      if [[ -z "${mimes}" ]]; then
        continue
      fi
      local -a mime_tokens=()
      IFS=';' read -r -a mime_tokens <<< "${mimes}" || true
      match=0
      for t in "${mime_tokens[@]}"; do
        for type in "${types[@]}"; do
          if [[ "${t}" == "${type}" ]]; then
            match=1
            break
          fi
        done
        if [[ "${match}" == "1" ]]; then
          break
        fi
      done
      if [[ "${match}" != "1" ]]; then
        continue
      fi
      seen_ids["${base}"]="1"
      if [[ -z "${name}" ]]; then
        name="${base%.desktop}"
      fi
      found_lines+=("$(printf '%s\t%s' "${name}" "${base}")")
    done
  done

  local sorted=""
  if [[ "${#found_lines[@]}" -gt 0 ]]; then
    sorted="$(printf '%s\n' "${found_lines[@]}" | sort -f)"
  fi
  local ln
  while IFS= read -r ln || [[ -n "${ln}" ]]; do
    if [[ -z "${ln}" ]]; then
      continue
    fi
    CAND_NAMES+=("${ln%%$'\t'*}")
    CAND_IDS+=("${ln#*$'\t'}")
  done <<< "${sorted}"
  return 0
}

# Restore mimeapps.list from the recorded backup state. Returns 0 when the
# file is back to its pre-run bytes (or removed again), 1 when the restore
# itself failed (the backup is kept for manual recovery).
rollback_to_backup() {
  local backup_missing="${1:-no}"
  if [[ "${backup_missing}" == "yes" ]]; then
    rm -f "${CONFIG_FILE}"
    return 0
  fi
  if [[ ! -f "${BACKUP_FILE}" ]]; then
    return 1
  fi
  cp -p "${BACKUP_FILE}" "${CONFIG_FILE}" || return 1
  return 0
}

run() {
  if ! command -v xdg-mime >/dev/null 2>&1; then
    printf 'xdg-mime not found; default-application changes need the xdg-utils tools\n' >&2
    exit 1
  fi

  # Question 1 of 3: the category. A category is required — Enter does not
  # skip; the question repeats until a valid choice (or q to cancel).
  local choice=""
  while true; do
    print_category_menu
    if ! choice="$(ask_value "Choose a category (1-9, q to cancel)")"; then
      printf 'This module needs interactive input; start it from the butler menu.\n' >&2
      exit 1
    fi
    if [[ "${choice}" == "q" || "${choice}" == "Q" ]]; then
      printf 'Nothing changed.\n'
      return 0
    fi
    if [[ "${choice}" =~ ^[1-9]$ || "${choice}" == "custom" || "${choice}" == "Custom" ]]; then
      break
    fi
    printf 'Choose a number 1-9, or q to cancel.\n' >&2
  done

  local category_label=""
  local -a mime_types=()
  if [[ "${choice}" == "9" || "${choice}" == "custom" || "${choice}" == "Custom" ]]; then
    # Question 2 of 3: the custom MIME type — only asked for entry 9.
    local custom_mime=""
    while true; do
      if ! custom_mime="$(ask_value "MIME type to change (e.g. image/webp, q to cancel)")"; then
        printf 'This module needs interactive input; start it from the butler menu.\n' >&2
        exit 1
      fi
      if [[ "${custom_mime}" == "q" || "${custom_mime}" == "Q" ]]; then
        printf 'Nothing changed.\n'
        return 0
      fi
      if [[ "${custom_mime}" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
        break
      fi
      printf 'That does not look like a MIME type (expected form: type/subtype).\n' >&2
    done
    category_label="${custom_mime}"
    mime_types+=("${custom_mime}")
  else
    local idx=$(( choice - 1 ))
    category_label="${CATEGORY_LABELS[idx]}"
    local -a parsed=()
    read -r -a parsed <<< "${CATEGORY_TYPES[idx]}" || true
    local p
    for p in "${parsed[@]}"; do
      mime_types+=("${p}")
    done
  fi

  collect_candidates "${mime_types[@]}"
  if [[ "${#CAND_NAMES[@]}" -eq 0 ]]; then
    local listed="${mime_types[0]}"
    local mi
    for (( mi = 1; mi < ${#mime_types[@]}; mi++ )); do
      listed="${listed}, ${mime_types[mi]}"
    done
    printf 'No installed application claims %s; nothing was changed.\n' "${listed}" >&2
    exit 1
  fi

  # Question 3 of 3: which application takes over (paginated picker).
  local -a labels=()
  local ci
  for ci in "${!CAND_NAMES[@]}"; do
    labels+=("${CAND_NAMES[ci]} (${CAND_IDS[ci]})")
  done
  if ! picker_single_select "Choose the application for: ${category_label}" \
    "Select a number (or: n next  p prev  /search  q quit): " "${labels[@]}"; then
    printf 'Nothing changed.\n'
    return 0
  fi
  local pick="${PICKER_SELECTED_INDEX}"
  if [[ "${pick}" -lt 0 ]]; then
    printf 'Nothing changed.\n'
    return 0
  fi
  local chosen_id="${CAND_IDS[pick]}"
  local chosen_name="${CAND_NAMES[pick]}"

  local -a currents=()
  local m cur
  for m in "${mime_types[@]}"; do
    cur="$(xdg-mime query default "${m}" 2>/dev/null)" || cur=""
    currents+=("${cur}")
  done

  # Idempotency: when the chosen app already handles every type, say so.
  local all_set=1
  local ti
  for ti in "${!mime_types[@]}"; do
    if [[ "${currents[ti]}" != "${chosen_id}" ]]; then
      all_set=0
    fi
  done
  if [[ "${all_set}" == "1" ]]; then
    printf 'Already the default: %s (%s) handles every type in this category. Nothing to do.\n' \
      "${chosen_name}" "${chosen_id}"
    return 0
  fi

  # Current versus new, for every type, before anything is written.
  printf 'About to change the default application (%s):\n' "${category_label}"
  for ti in "${!mime_types[@]}"; do
    printf '  %s\n' "${mime_types[ti]}"
    printf '    current: %s\n' "${currents[ti]:-(none)}"
    printf '    new: %s (%s)\n' "${chosen_name}" "${chosen_id}"
  done

  # No apply confirmation here (MB-004): the menu already took the single
  # confirmation for this run; the current-vs-new listing above is the
  # informational output immediately before the change proceeds.
  mkdir -p "${STATE_DIR}"
  local backup_missing="no"
  if [[ -f "${CONFIG_FILE}" ]]; then
    cp -p "${CONFIG_FILE}" "${BACKUP_FILE}"
  else
    backup_missing="yes"
  fi
  {
    if [[ "${backup_missing}" == "yes" ]]; then
      printf 'BACKUP_MISSING=yes\n'
    fi
    for m in "${mime_types[@]}"; do
      printf 'ASSIGNED %s=%s\n' "${m}" "${chosen_id}"
    done
  } > "${RECORD_FILE}"

  for m in "${mime_types[@]}"; do
    if ! xdg-mime default "${chosen_id}" "${m}"; then
      if rollback_to_backup "${backup_missing}"; then
        rm -f "${RECORD_FILE}" "${BACKUP_FILE}"
        rmdir "${STATE_DIR}" 2>/dev/null || true
        printf 'xdg-mime failed for %s; the backup was restored and nothing was changed.\n' "${m}" >&2
      else
        printf 'xdg-mime failed for %s and the backup restore failed too; the backup is kept at %s.\n' \
          "${m}" "${BACKUP_FILE}" >&2
      fi
      exit 1
    fi
  done

  local got=""
  for m in "${mime_types[@]}"; do
    got="$(xdg-mime query default "${m}" 2>/dev/null)" || got=""
    if [[ "${got}" != "${chosen_id}" ]]; then
      if rollback_to_backup "${backup_missing}"; then
        rm -f "${RECORD_FILE}" "${BACKUP_FILE}"
        rmdir "${STATE_DIR}" 2>/dev/null || true
        printf 'Verification failed: %s reads back as %s; the backup was restored and nothing was changed.\n' \
          "${m}" "${got:-(none)}" >&2
      else
        printf 'Verification failed for %s and the backup restore failed too; the backup is kept at %s.\n' \
          "${m}" "${BACKUP_FILE}" >&2
      fi
      exit 1
    fi
  done

  printf 'Applied — the default application for this category is now:\n'
  for m in "${mime_types[@]}"; do
    printf '  %s -> %s (%s)\n' "${m}" "${chosen_name}" "${chosen_id}"
  done
  if [[ "${backup_missing}" == "yes" ]]; then
    printf 'There was no %s before; undo will remove the file this run created.\n' "${CONFIG_FILE}"
  else
    printf 'Backup: %s\n' "${BACKUP_FILE}"
  fi
  printf 'Undo: choose [u]ndo for this module to restore the previous state byte for byte.\n'
  return 0
}

undo() {
  if [[ ! -f "${RECORD_FILE}" ]]; then
    printf 'Nothing to undo.\n'
    return 0
  fi

  local -a record_lines=()
  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    record_lines+=("${line}")
  done < "${RECORD_FILE}"

  local backup_missing="no"
  local -a assigned=()
  local entry
  for entry in "${record_lines[@]}"; do
    case "${entry}" in
      BACKUP_MISSING=*)
        backup_missing="${entry#BACKUP_MISSING=}"
        ;;
      ASSIGNED\ *)
        assigned+=("${entry#ASSIGNED }")
        ;;
    esac
  done

  if [[ "${backup_missing}" == "yes" ]]; then
    rm -f "${CONFIG_FILE}"
    printf 'Removed %s (it did not exist before this module changed anything).\n' "${CONFIG_FILE}"
  else
    if [[ ! -f "${BACKUP_FILE}" ]]; then
      printf 'Undo failed: the backup %s is missing; nothing was restored.\n' "${BACKUP_FILE}" >&2
      return 1
    fi
    cp -p "${BACKUP_FILE}" "${CONFIG_FILE}"
    printf 'Restored %s byte for byte from the backup.\n' "${CONFIG_FILE}"
  fi

  if [[ "${#assigned[@]}" -gt 0 ]]; then
    local i
    printf 'Assignments reversed:\n'
    for (( i = ${#assigned[@]} - 1; i >= 0; i-- )); do
      printf '  %s\n' "${assigned[i]}"
    done
  fi

  rm -f "${RECORD_FILE}" "${BACKUP_FILE}"
  rmdir "${STATE_DIR}" 2>/dev/null || true
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
