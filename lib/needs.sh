#!/usr/bin/env bash
set -euo pipefail

# lib/needs.sh — enforcement helpers for the manifest `needs:` field
# (MODULE_SPEC §2; owner ruling 2026-09-18, MB-003/MB-005).
#
# A declared need names a command that must exist BEFORE a module's run/undo
# launches. Two resolutions count as present, in order:
#   1. the command resolves on PATH (`command -v`), or
#   2. a dpkg package of that exact name is installed (`dpkg -s`) — covers
#      needs declared by package name when the binary lives outside PATH
#      contexts callers sanitise.
#
# needs_present CMD          — exit 0 when CMD is present by the rules above.
# needs_missing_list FIELD   — FIELD is the raw manifest needs value ("[]" or
#                              "[a, b]"); prints the missing entries as a
#                              comma-space-joined list, nothing when empty.
#
# The menu uses this to print one plain refusal line and never launch; a
# module NEVER installs its own needs (that is the user's explicit choice via
# Mint's Software Manager), and needs are launch-time requirements — never a
# shopping list for the module to fetch.

_needs_trim() {
  local s="${1:-}"
  # shellcheck disable=SC2295
  s="${s#"${s%%[![:space:]]*}"}"
  # shellcheck disable=SC2295
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

needs_present() {
  local cmd="${1:-}"
  if [[ -z "${cmd}" ]]; then
    return 1
  fi
  if command -v "${cmd}" >/dev/null 2>&1; then
    return 0
  fi
  if command -v dpkg >/dev/null 2>&1; then
    if dpkg -s "${cmd}" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

needs_missing_list() {
  local field="${1:-}"
  local inner part
  local -a parts=() missing=()
  inner="${field#\[}"
  inner="${inner%\]}"
  IFS=',' read -r -a parts <<< "${inner}" || true
  for part in "${parts[@]}"; do
    part="$(_needs_trim "${part}")"
    if [[ -z "${part}" ]]; then
      continue
    fi
    if ! needs_present "${part}"; then
      missing+=("${part}")
    fi
  done
  local joined="" m
  if [[ "${#missing[@]}" -gt 0 ]]; then
    for m in "${missing[@]}"; do
      if [[ -z "${joined}" ]]; then
        joined="${m}"
      else
        joined="${joined}, ${m}"
      fi
    done
  fi
  printf '%s' "${joined}"
}
