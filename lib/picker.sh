#!/usr/bin/env bash
set -euo pipefail

# lib/picker.sh — shared paginated number picker for single and multi-select.
# Ensures all rendered screens conform to the 23-line law (header + entries + footer <= 23).
# Non-interactive stdin (EOF) returns failure (1), never hangs.

PICKER_DEFAULT_PAGE_SIZE=10
PICKER_MAX_SCREEN_LINES=23

_picker_trim() {
  local s="${1:-}"
  # shellcheck disable=SC2295
  s="${s#"${s%%[![:space:]]*}"}"
  # shellcheck disable=SC2295
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

picker_compute_page_size() {
  local header_lines="${1:-2}"
  local footer_lines="${2:-2}"
  local max_budget=$(( PICKER_MAX_SCREEN_LINES - header_lines - footer_lines ))
  local page_size="${PICKER_DEFAULT_PAGE_SIZE}"
  if (( page_size > max_budget )); then
    page_size="${max_budget}"
  fi
  if (( page_size < 1 )); then
    page_size=1
  fi
  printf '%s\n' "${page_size}"
}

picker_compute_total_pages() {
  local total_items="${1:-0}"
  local page_size="${2:-10}"
  if (( total_items <= 0 )); then
    printf '1\n'
    return 0
  fi
  local pages=$(( (total_items + page_size - 1) / page_size ))
  if (( pages < 1 )); then
    pages=1
  fi
  printf '%s\n' "${pages}"
}

picker_page_bounds() {
  local page="${1:-1}"
  local page_size="${2:-10}"
  local total_items="${3:-0}"

  local total_pages
  total_pages="$(picker_compute_total_pages "${total_items}" "${page_size}")"
  if (( page > total_pages )); then
    page="${total_pages}"
  fi
  if (( page < 1 )); then
    page=1
  fi

  local start_idx=$(( (page - 1) * page_size ))
  local end_idx=$(( start_idx + page_size ))
  if (( end_idx > total_items )); then
    end_idx="${total_items}"
  fi
  printf '%d %d %d %d\n' "${start_idx}" "${end_idx}" "${page}" "${total_pages}"
}

# Multi-select picker over an array of display labels.
# Sourced callers inspect PICKER_SELECTED_INDICES (0-based indices).
# Returns 0 on confirm ('d'), 1 on cancel ('q' or EOF).
PICKER_SELECTED_INDICES=()

picker_multi_select() {
  local header="${1:-Select items:}"
  shift
  local -a items=("$@")
  local total_items="${#items[@]}"

  PICKER_SELECTED_INDICES=()

  local -a selected=()
  local i
  for (( i=0; i<total_items; i++ )); do
    selected+=(0)
  done

  local page_size
  page_size="$(picker_compute_page_size 2 2)"
  local page=1
  local filter=""
  local msg=""

  while true; do
    local -a filtered_indices=()
    local lower_filter
    lower_filter="$(printf '%s' "${filter}" | tr '[:upper:]' '[:lower:]')"

    for (( i=0; i<total_items; i++ )); do
      if [[ -z "${filter}" ]]; then
        filtered_indices+=("${i}")
      else
        local lower_item
        lower_item="$(printf '%s' "${items[i]}" | tr '[:upper:]' '[:lower:]')"
        if [[ "${lower_item}" == *"${lower_filter}"* ]]; then
          filtered_indices+=("${i}")
        fi
      fi
    done

    local count="${#filtered_indices[@]}"
    local total_pages
    total_pages="$(picker_compute_total_pages "${count}" "${page_size}")"
    if (( page > total_pages )); then
      page="${total_pages}"
    fi
    if (( page < 1 )); then
      page=1
    fi

    # Render screen (strictly <= 23 lines)
    if [[ -t 1 ]]; then
      if command -v clear >/dev/null 2>&1; then
        clear
      else
        printf '\033[2J\033[H'
      fi
    fi

    if command -v ui_heading >/dev/null 2>&1; then
      ui_heading "${header}"
    else
      printf '%s\n' "${header}"
    fi
    printf '\n'

    local start_idx=$(( (page - 1) * page_size ))
    local end_idx=$(( start_idx + page_size ))
    if (( end_idx > count )); then
      end_idx="${count}"
    fi

    if (( count == 0 )); then
      if [[ -n "${filter}" ]]; then
        printf '  (no matches)\n'
      else
        printf '  (no items available)\n'
      fi
    else
      local num=0 k orig_idx mark
      for (( k=start_idx; k<end_idx; k++ )); do
        num=$(( num + 1 ))
        orig_idx="${filtered_indices[k]}"
        if [[ "${selected[orig_idx]}" == "1" ]]; then
          mark="[*]"
        else
          mark="[ ]"
        fi
        printf '  %2d) %s %s\n' "${num}" "${mark}" "${items[orig_idx]}"
      done
    fi

    if [[ -n "${msg}" ]]; then
      printf '%s\n' "${msg}"
      msg=""
    fi

    printf '\n'
    printf 'Select number to toggle (or: n next  p prev  /search  d place  q back): '

    local input="" cr=$'\r'
    if ! IFS= read -r input; then
      printf '\n'
      return 1
    fi

    input="${input%"$cr"}"
    input="$(_picker_trim "${input}")"

    if [[ -z "${input}" ]]; then
      continue
    fi

    if [[ "${input}" == "q" || "${input}" == "Q" ]]; then
      return 1
    fi

    if [[ "${input}" == "d" || "${input}" == "D" ]]; then
      PICKER_SELECTED_INDICES=()
      for (( i=0; i<total_items; i++ )); do
        if [[ "${selected[i]}" == "1" ]]; then
          PICKER_SELECTED_INDICES+=("${i}")
        fi
      done
      printf '\n'
      return 0
    fi

    if [[ "${input}" == "n" || "${input}" == "N" ]]; then
      if (( page < total_pages )); then
        page=$(( page + 1 ))
      fi
      continue
    fi

    if [[ "${input}" == "p" || "${input}" == "P" ]]; then
      if (( page > 1 )); then
        page=$(( page - 1 ))
      fi
      continue
    fi

    if [[ "${input}" == "/" ]]; then
      filter=""
      page=1
      continue
    fi

    if [[ "${input}" == "/"* ]]; then
      filter="$(_picker_trim "${input#/}")"
      page=1
      continue
    fi

    if [[ "${input}" == "s" || "${input}" == "S" ]]; then
      filter=""
      page=1
      continue
    fi

    if [[ "${input}" == "s "* || "${input}" == "S "* ]]; then
      filter="$(_picker_trim "${input:2}")"
      page=1
      continue
    fi

    if [[ "${input}" =~ ^[0-9]+$ ]]; then
      local page_items=$(( end_idx - start_idx ))
      if (( input >= 1 && input <= page_items )); then
        local chosen_filtered_idx=$(( start_idx + input - 1 ))
        local chosen_orig_idx="${filtered_indices[chosen_filtered_idx]}"
        if [[ "${selected[chosen_orig_idx]}" == "1" ]]; then
          selected[chosen_orig_idx]=0
        else
          selected[chosen_orig_idx]=1
        fi
      else
        msg="Invalid selection '${input}' on this page."
      fi
      continue
    fi

    msg="Unknown command '${input}'. Use numbers to toggle, n, p, /search, d, or q."
  done
}

# Single-select picker over an array of display labels.
# Sourced callers inspect PICKER_SELECTED_INDEX (0-based index into original items).
# Returns 0 on select, 1 on cancel ('q' or EOF).
PICKER_SELECTED_INDEX=-1

picker_single_select() {
  local header="${1:-Select an item:}"
  local prompt_text="${2:-Select a number (or: n next  p prev  /search  q quit): }"
  shift 2
  local -a items=("$@")
  local total_items="${#items[@]}"

  PICKER_SELECTED_INDEX=-1

  local page_size
  page_size="$(picker_compute_page_size 2 2)"
  local page=1
  local filter=""
  local msg=""

  while true; do
    local -a filtered_indices=()
    local lower_filter
    lower_filter="$(printf '%s' "${filter}" | tr '[:upper:]' '[:lower:]')"

    local i
    for (( i=0; i<total_items; i++ )); do
      if [[ -z "${filter}" ]]; then
        filtered_indices+=("${i}")
      else
        local lower_item
        lower_item="$(printf '%s' "${items[i]}" | tr '[:upper:]' '[:lower:]')"
        if [[ "${lower_item}" == *"${lower_filter}"* ]]; then
          filtered_indices+=("${i}")
        fi
      fi
    done

    local count="${#filtered_indices[@]}"
    local total_pages
    total_pages="$(picker_compute_total_pages "${count}" "${page_size}")"
    if (( page > total_pages )); then
      page="${total_pages}"
    fi
    if (( page < 1 )); then
      page=1
    fi

    if [[ -t 1 ]]; then
      if command -v clear >/dev/null 2>&1; then
        clear
      else
        printf '\033[2J\033[H'
      fi
    fi

    if command -v ui_heading >/dev/null 2>&1; then
      ui_heading "${header}"
    else
      printf '%s\n' "${header}"
    fi
    printf '\n'

    local start_idx=$(( (page - 1) * page_size ))
    local end_idx=$(( start_idx + page_size ))
    if (( end_idx > count )); then
      end_idx="${count}"
    fi

    if (( count == 0 )); then
      if [[ -n "${filter}" ]]; then
        printf '  (no matches)\n'
      else
        printf '  (no items available)\n'
      fi
    else
      local num=0 k orig_idx
      for (( k=start_idx; k<end_idx; k++ )); do
        num=$(( num + 1 ))
        orig_idx="${filtered_indices[k]}"
        printf '  %2d) %s\n' "${num}" "${items[orig_idx]}"
      done
    fi

    if [[ -n "${msg}" ]]; then
      printf '%s\n' "${msg}"
      msg=""
    fi

    printf '\n'
    printf '%s' "${prompt_text}"

    local input="" cr=$'\r'
    if ! IFS= read -r input; then
      printf '\n'
      return 1
    fi

    input="${input%"$cr"}"
    input="$(_picker_trim "${input}")"

    if [[ -z "${input}" ]]; then
      continue
    fi

    if [[ "${input}" == "q" || "${input}" == "Q" ]]; then
      return 1
    fi

    if [[ "${input}" == "n" || "${input}" == "N" ]]; then
      if (( page < total_pages )); then
        page=$(( page + 1 ))
      fi
      continue
    fi

    if [[ "${input}" == "p" || "${input}" == "P" ]]; then
      if (( page > 1 )); then
        page=$(( page - 1 ))
      fi
      continue
    fi

    if [[ "${input}" == "/" ]]; then
      filter=""
      page=1
      continue
    fi

    if [[ "${input}" == "/"* ]]; then
      filter="$(_picker_trim "${input#/}")"
      page=1
      continue
    fi

    if [[ "${input}" == "s" || "${input}" == "S" ]]; then
      filter=""
      page=1
      continue
    fi

    if [[ "${input}" == "s "* || "${input}" == "S "* ]]; then
      filter="$(_picker_trim "${input:2}")"
      page=1
      continue
    fi

    if [[ "${input}" =~ ^[0-9]+$ ]]; then
      local page_items=$(( end_idx - start_idx ))
      if (( input >= 1 && input <= page_items )); then
        local chosen_filtered_idx=$(( start_idx + input - 1 ))
        PICKER_SELECTED_INDEX="${filtered_indices[chosen_filtered_idx]}"
        printf '\n'
        return 0
      else
        msg="Invalid selection '${input}' on this page."
      fi
      continue
    fi

    msg="Unknown command '${input}'. Use a number, n, p, /search, or q."
  done
}
