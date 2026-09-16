#!/usr/bin/env bash
set -euo pipefail

# lib/ask.sh — module-facing interactive question helpers.
# ask_value prints prompt to stderr, reads one line from stdin, trims it,
# and prints value to stdout. EOF returns 1 printing nothing.
# ask_yn appends [y/N] and returns 0 for y/yes, 1 for anything else or EOF.

_ask_trim() {
  local s="${1:-}"
  # shellcheck disable=SC2295
  s="${s#"${s%%[![:space:]]*}"}"
  # shellcheck disable=SC2295
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

ask_value() {
  local prompt="${1:-}"
  local default="${2:-}"
  local input="" cr=$'\r'

  if [[ "${prompt}" != *": " && "${prompt}" != *":" ]]; then
    printf '%s: ' "${prompt}" >&2
  elif [[ "${prompt}" == *":" ]]; then
    printf '%s ' "${prompt}" >&2
  else
    printf '%s' "${prompt}" >&2
  fi

  if ! IFS= read -r input; then
    return 1
  fi

  input="${input%"$cr"}"
  input="$(_ask_trim "${input}")"

  if [[ -z "${input}" && -n "${default}" ]]; then
    input="${default}"
  fi

  printf '%s\n' "${input}"
  return 0
}

ask_yn() {
  local prompt="${1:-Proceed?}"
  local answer="" lowered="" cr=$'\r'

  if [[ "${prompt}" =~ \[y/N\] ]]; then
    if [[ "${prompt}" != *" " ]]; then
      printf '%s ' "${prompt}" >&2
    else
      printf '%s' "${prompt}" >&2
    fi
  else
    printf '%s [y/N]: ' "${prompt}" >&2
  fi

  if ! IFS= read -r answer; then
    printf '\n' >&2
    return 1
  fi

  answer="${answer%"$cr"}"
  answer="$(_ask_trim "${answer}")"
  lowered="$(printf '%s' "${answer}" | tr '[:upper:]' '[:lower:]')"

  if [[ "${lowered}" == "y" || "${lowered}" == "yes" ]]; then
    return 0
  fi
  return 1
}
