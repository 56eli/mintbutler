#!/usr/bin/env bash
set -euo pipefail

# lib/ui.sh — TTY color detection, headings, risk badge, plain errors.
# Colors appear only when stdout is a TTY (SSH/pipe-safe).

_UI_COLOR_CACHED=""
_UI_COLOR_ENABLED="0"

ui_has_color() {
  if [[ -z "${_UI_COLOR_CACHED}" ]]; then
    if [[ -n "${NO_COLOR:-}" ]]; then
      _UI_COLOR_ENABLED="0"
    elif [[ "${TERM:-}" == "dumb" ]]; then
      _UI_COLOR_ENABLED="0"
    elif [[ -t 1 ]]; then
      _UI_COLOR_ENABLED="1"
    else
      _UI_COLOR_ENABLED="0"
    fi
    _UI_COLOR_CACHED="1"
  fi
  [[ "${_UI_COLOR_ENABLED}" == "1" ]]
}

# Prime the TTY cache while stdout is still the outer stdout,
# so later calls inside $(...) keep the right answer.
ui_has_color || true

_ui_wrap() {
  local code="${1:-}"
  local text="${2:-}"
  if ui_has_color; then
    printf '\033[%sm%s\033[0m' "${code}" "${text}"
  else
    printf '%s' "${text}"
  fi
}

ui_bold() {
  local text="${1:-}"
  _ui_wrap "1" "${text}"
}

ui_red() {
  local text="${1:-}"
  _ui_wrap "31" "${text}"
}

ui_green() {
  local text="${1:-}"
  _ui_wrap "32" "${text}"
}

ui_yellow() {
  local text="${1:-}"
  _ui_wrap "33" "${text}"
}

ui_heading() {
  local text="${1:-}"
  if ui_has_color; then
    printf '\033[1m%s\033[0m\n' "${text}"
  else
    printf '%s\n' "${text}"
  fi
}

ui_risk_badge() {
  local risk="${1:-}"
  if [[ "${risk}" == "elevated" ]]; then
    if ui_has_color; then
      printf '\033[33m%s\033[0m' "⚠ elevated"
    else
      printf '%s' "⚠ elevated"
    fi
  fi
}

ui_error() {
  local msg="${1:-}"
  printf 'Error: %s\n' "${msg}" >&2
}

ui_info() {
  local msg="${1:-}"
  printf '%s\n' "${msg}"
}
