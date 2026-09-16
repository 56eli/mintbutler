#!/usr/bin/env bash
set -euo pipefail

# lib/menu.sh — module scan, light validation, (order, slug) sort,
# numbered rendering incl. broken section; search-filter support.
# Expects lib/ui.sh and lib/manifest.sh to be sourced first.

MENU_SLUGS=()
MENU_TITLES=()
MENU_RISKS=()
MENU_UNDOS=()
MENU_ORDERS=()
MENU_DESCS=()
MENU_BROKEN_SLUGS=()
MENU_MODULES_DIR=""
MENU_FILTER=""

menu_set_filter() {
  MENU_FILTER="${1:-}"
}

menu_clear_filter() {
  MENU_FILTER=""
}

_menu_matches_filter() {
  local slug="${1:-}"
  local title="${2:-}"
  local filter="${MENU_FILTER:-}"
  local lower_filter lower_slug lower_title
  if [[ -z "${filter}" ]]; then
    return 0
  fi
  lower_filter="$(printf '%s' "${filter}" | tr '[:upper:]' '[:lower:]')"
  lower_slug="$(printf '%s' "${slug}" | tr '[:upper:]' '[:lower:]')"
  lower_title="$(printf '%s' "${title}" | tr '[:upper:]' '[:lower:]')"
  if [[ "${lower_slug}" == *"${lower_filter}"* ]]; then
    return 0
  fi
  if [[ "${lower_title}" == *"${lower_filter}"* ]]; then
    return 0
  fi
  return 1
}

menu_scan() {
  local modules_dir="${1:-}"
  MENU_SLUGS=()
  MENU_TITLES=()
  MENU_RISKS=()
  MENU_UNDOS=()
  MENU_ORDERS=()
  MENU_DESCS=()
  MENU_BROKEN_SLUGS=()
  MENU_MODULES_DIR="${modules_dir}"

  if [[ -z "${modules_dir}" ]]; then
    return 0
  fi
  if [[ ! -d "${modules_dir}" ]]; then
    return 0
  fi

  local -a slugs=()
  local -a titles=()
  local -a risks=()
  local -a undos=()
  local -a orders=()
  local -a descs=()
  local -a broken=()

  local entry slug manifest module_sh
  for entry in "${modules_dir}"/*; do
    if [[ ! -e "${entry}" ]]; then
      continue
    fi
    if [[ ! -d "${entry}" ]]; then
      continue
    fi
    slug="$(basename "${entry}")"
    if [[ ! "${slug}" =~ ^[a-z0-9-]+$ ]]; then
      broken+=("${slug}")
      continue
    fi
    manifest="${entry}/module.yml"
    module_sh="${entry}/module.sh"
    if [[ ! -f "${module_sh}" ]]; then
      broken+=("${slug}")
      continue
    fi
    if manifest_parse "${manifest}"; then
      slugs+=("${slug}")
      titles+=("${MANIFEST_TITLE}")
      risks+=("${MANIFEST_RISK}")
      undos+=("${MANIFEST_UNDO}")
      orders+=("${MANIFEST_ORDER}")
      descs+=("${MANIFEST_DESCRIPTION}")
    else
      broken+=("${slug}")
      continue
    fi
  done

  if [[ "${#slugs[@]}" -gt 0 ]]; then
    local sort_input="" i has_order order_val
    for i in "${!slugs[@]}"; do
      if [[ -n "${orders[${i}]}" ]]; then
        has_order="0"
        order_val="${orders[${i}]}"
      else
        has_order="1"
        order_val="0"
      fi
      sort_input+="${has_order}|${order_val}|${slugs[${i}]}|${i}"$'\n'
    done
    local sorted=""
    sorted="$(printf '%s' "${sort_input}" | sort -t'|' -k1,1n -k2,2n -k3,3)"
    local h o s idx
    while IFS='|' read -r h o s idx || [[ -n "${h}" ]]; do
      if [[ -z "${idx}" ]]; then
        continue
      fi
      MENU_SLUGS+=("${slugs[${idx}]}")
      MENU_TITLES+=("${titles[${idx}]}")
      MENU_RISKS+=("${risks[${idx}]}")
      MENU_UNDOS+=("${undos[${idx}]}")
      MENU_ORDERS+=("${orders[${idx}]}")
      MENU_DESCS+=("${descs[${idx}]}")
    done <<< "${sorted}"
  fi

  if [[ "${#broken[@]}" -gt 0 ]]; then
    local sorted_broken=""
    sorted_broken="$(printf '%s\n' "${broken[@]}" | sort)"
    local b
    while IFS= read -r b || [[ -n "${b}" ]]; do
      if [[ -z "${b}" ]]; then
        continue
      fi
      MENU_BROKEN_SLUGS+=("${b}")
    done <<< "${sorted_broken}"
  fi
  return 0
}

menu_count() {
  local count="0" i
  for i in "${!MENU_SLUGS[@]}"; do
    if _menu_matches_filter "${MENU_SLUGS[${i}]}" "${MENU_TITLES[${i}]}"; then
      count=$((count + 1))
    fi
  done
  printf '%s\n' "${count}"
}

menu_slug_for_number() {
  local want="${1:-}"
  local count="0" i
  if [[ ! "${want}" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  if [[ "${want}" -lt 1 ]]; then
    return 1
  fi
  for i in "${!MENU_SLUGS[@]}"; do
    if _menu_matches_filter "${MENU_SLUGS[${i}]}" "${MENU_TITLES[${i}]}"; then
      count=$((count + 1))
      if [[ "${count}" == "${want}" ]]; then
        printf '%s\n' "${MENU_SLUGS[${i}]}"
        return 0
      fi
    fi
  done
  return 1
}

menu_title_for_slug() {
  local want="${1:-}" i
  for i in "${!MENU_SLUGS[@]}"; do
    if [[ "${MENU_SLUGS[${i}]}" == "${want}" ]]; then
      printf '%s\n' "${MENU_TITLES[${i}]}"
      return 0
    fi
  done
  return 1
}

menu_risk_for_slug() {
  local want="${1:-}" i
  for i in "${!MENU_SLUGS[@]}"; do
    if [[ "${MENU_SLUGS[${i}]}" == "${want}" ]]; then
      printf '%s\n' "${MENU_RISKS[${i}]}"
      return 0
    fi
  done
  return 1
}

menu_undo_for_slug() {
  local want="${1:-}" i
  for i in "${!MENU_SLUGS[@]}"; do
    if [[ "${MENU_SLUGS[${i}]}" == "${want}" ]]; then
      printf '%s\n' "${MENU_UNDOS[${i}]}"
      return 0
    fi
  done
  return 1
}

menu_render() {
  ui_heading "mintbutler — Tasks:"
  printf '\n'
  local num="0" i shown="0"
  for i in "${!MENU_SLUGS[@]}"; do
    if ! _menu_matches_filter "${MENU_SLUGS[${i}]}" "${MENU_TITLES[${i}]}"; then
      continue
    fi
    num=$((num + 1))
    shown="1"
    printf '  %s) %s' "${num}" "${MENU_TITLES[${i}]}"
    if [[ "${MENU_RISKS[${i}]}" == "elevated" ]]; then
      printf '  '
      ui_risk_badge "elevated"
    fi
    printf '\n'
  done
  if [[ "${shown}" == "0" ]]; then
    if [[ -n "${MENU_FILTER}" ]]; then
      printf '  (no matches)\n'
    elif [[ "${#MENU_BROKEN_SLUGS[@]}" -eq 0 ]]; then
      printf '  (no modules found)\n'
    fi
  fi
  if [[ "${#MENU_BROKEN_SLUGS[@]}" -gt 0 ]]; then
    if [[ "${shown}" == "1" ]]; then
      printf '\n'
    fi
    local b
    for b in "${MENU_BROKEN_SLUGS[@]}"; do
      printf '  %s (broken — excluded)\n' "${b}"
    done
  fi
  printf '\n'
}
