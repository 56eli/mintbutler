#!/usr/bin/env bash
set -euo pipefail

# lib/confirm.sh — y/N and typed-slug confirmation helpers.
# Callers own TTY policy; these helpers only read one line from stdin.

_confirm_trim() {
  local s="${1:-}"
  # shellcheck disable=SC2295
  s="${s#"${s%%[![:space:]]*}"}"
  # shellcheck disable=SC2295
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

confirm_yn() {
  local prompt="${1:-Proceed?}"
  local answer="" lowered=""
  printf '%s [y/N]: ' "${prompt}"
  if ! IFS= read -r answer; then
    printf '\n'
    return 1
  fi
  answer="$(_confirm_trim "${answer}")"
  lowered="$(printf '%s' "${answer}" | tr '[:upper:]' '[:lower:]')"
  if [[ "${lowered}" == "y" || "${lowered}" == "yes" ]]; then
    return 0
  fi
  return 1
}

confirm_typed_slug() {
  local slug="${1:-}"
  local prompt="${2:-}"
  local answer="" cr=""
  cr=$'\r'
  if [[ -z "${slug}" ]]; then
    return 1
  fi
  if [[ -z "${prompt}" ]]; then
    prompt="Type the module slug '${slug}' to confirm"
  fi
  printf '%s: ' "${prompt}"
  if ! IFS= read -r answer; then
    printf '\n'
    return 1
  fi
  answer="${answer%"$cr"}"
  if [[ "${answer}" == "${slug}" ]]; then
    return 0
  fi
  return 1
}
