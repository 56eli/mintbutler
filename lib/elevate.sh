#!/usr/bin/env bash
set -euo pipefail

# lib/elevate.sh — the ONLY sanctioned path to root (MODULE_SPEC §3).
#
# Contract:
#   elevate_command_line "<command string>"
#     Prints the exact command line that the elevated step would execute, for
#     plan/dry-run display. Nothing runs. Returns 1 on an empty command.
#
#   elevate_run "<command string>"
#     Verifies that the calling module's manifest declares `risk: elevated`,
#     prints the exact command line, executes it, and returns its exit code.
#     Refuses with a plain error and return 126 when the manifest is missing,
#     unreadable, or not elevated — or when the caller did not identify itself.
#
# Callers pass fixed, reviewed command strings. This helper never composes a
# command from user input, never evaluates shell text (`eval`), and never asks
# its own confirmation question: the menu already showed the plan and took the
# typed-slug confirmation before dispatching the `run` action.
#
# The calling module passes its slug in MINTBUTLER_MODULE_SLUG (the menu and
# bin/modulelint both set it; a module invoked by hand sets it to its own slug).

_elevate_lib_dir() {
  local lib_dir="${MINTBUTLER_LIB_DIR:-}"
  if [[ -z "${lib_dir}" ]]; then
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  printf '%s\n' "${lib_dir}"
}

elevate_command_line() {
  local command_str="${1:-}"
  if [[ -z "${command_str}" ]]; then
    printf 'elevate: no command to show (empty command string)\n' >&2
    return 1
  fi
  printf 'sudo %s\n' "${command_str}"
}

elevate_run() {
  local command_str="${1:-}"
  if [[ -z "${command_str}" ]]; then
    printf 'elevate: refusing to run an empty elevated command\n' >&2
    return 126
  fi

  local lib_dir repo_root slug manifest_file
  lib_dir="$(_elevate_lib_dir)"
  repo_root="$(cd "${lib_dir}/.." && pwd)"

  slug="${MINTBUTLER_MODULE_SLUG:-}"
  if [[ -z "${slug}" ]]; then
    printf 'elevate: the calling module did not identify itself; refusing to run an elevated command\n' >&2
    return 126
  fi

  if ! command -v manifest_parse >/dev/null 2>&1; then
    if [[ ! -f "${lib_dir}/manifest.sh" ]]; then
      printf 'elevate: missing %s/manifest.sh; refusing to run an elevated command\n' "${lib_dir}" >&2
      return 126
    fi
    # shellcheck source=lib/manifest.sh
    source "${lib_dir}/manifest.sh"
  fi

  manifest_file="${repo_root}/modules/${slug}/module.yml"
  if [[ ! -f "${manifest_file}" ]]; then
    printf 'elevate: module %s has no manifest; refusing to run an elevated command\n' "${slug}" >&2
    return 126
  fi

  if ! manifest_parse "${manifest_file}"; then
    printf 'elevate: cannot read the manifest of module %s (%s); refusing to run an elevated command\n' \
      "${slug}" "${MANIFEST_ERROR}" >&2
    return 126
  fi

  if [[ "${MANIFEST_RISK}" != "elevated" ]]; then
    printf 'elevate: module %s is declared risk: %s; refusing to run an elevated command\n' \
      "${slug}" "${MANIFEST_RISK}" >&2
    return 126
  fi

  printf 'Running elevated command: %s\n' "$(elevate_command_line "${command_str}")"

  local -a command_words=()
  read -r -a command_words <<< "${command_str}"
  if [[ "${#command_words[@]}" -eq 0 ]]; then
    printf 'elevate: the elevated command is empty\n' >&2
    return 126
  fi

  local elevated_code=0
  sudo "${command_words[@]}" || elevated_code="$?"
  return "${elevated_code}"
}
