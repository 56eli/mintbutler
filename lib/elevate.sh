#!/usr/bin/env bash
set -euo pipefail

# lib/elevate.sh — the ONLY sanctioned path to root (MODULE_SPEC §3).
#
# Contract (argv form; owner ruling 2026-09-18, MB-001):
#   elevate_command_line WORD...
#     Prints the exact command line the elevated step would execute, derived
#     from the argument LIST: any word a shell would tokenize as itself
#     prints bare, every other word prints single-quoted (with the '\''
#     escape a human would type). Nothing runs. Refuses and returns 1 when
#     called with no words.
#
#   elevate_run WORD...
#     Verifies that the calling module's manifest declares `risk: elevated`,
#     prints the same derived command line, then executes the argument list
#     as `sudo "$@"` and returns its exit code. Refuses with a plain error
#     and return 126 when called with no words, when the manifest is missing,
#     unreadable, or not elevated — or when the caller did not identify
#     itself.
#
# The elevated command TRAVELS AS AN ARGV LIST from the caller all the way to
# sudo. It is never stored in a string and re-split: the old `read -r -a`
# word-splitting path is gone, so a value containing spaces, quotes, `$`, or
# `;` (a snapshot comment, a mount target) reaches sudo as exactly the words
# the caller passed — and as exactly the line the user saw. The displayed
# line is DERIVED from the list, never the other way around.
#
# Callers pass fixed, reviewed commands plus bounded values from their own
# question flows. This helper never composes a command from raw stdin, never
# evaluates shell text (`eval`), and never asks its own confirmation
# question: the menu already showed the plan and took the typed-slug
# confirmation before dispatching the `run` action (MODULE_SPEC §3, MB-004).
#
# The calling module passes its slug in MINTBUTLER_MODULE_SLUG (the menu and
# bin/modulelint both set it; a module invoked by hand sets it to its own
# slug).

_elevate_lib_dir() {
  local lib_dir="${MINTBUTLER_LIB_DIR:-}"
  if [[ -z "${lib_dir}" ]]; then
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  printf '%s\n' "${lib_dir}"
}

# _elevate_quote WORD — print WORD exactly as it must appear on a shell
# command line to read back as the same single word.
_elevate_quote() {
  local word="${1-}" escaped
  if [[ "${word}" =~ ^[a-zA-Z0-9_@%+=:,./-]+$ ]]; then
    printf '%s' "${word}"
  elif [[ -z "${word}" ]]; then
    printf "''"
  else
    # Replace each ' with the '\'' sequence, then wrap in single quotes.
    # (The substitution runs unquoted on purpose: inside quotes the backslash
    # would survive into the replacement and double it.)
    escaped=${word//"'"/"'\\''"}
    printf "'%s'" "${escaped}"
  fi
}

# _elevate_command_string WORD... — the flat display form of an argv list,
# with every word quoted exactly as _elevate_quote renders it.
_elevate_command_string() {
  local out="" word quoted
  for word in "$@"; do
    quoted="$(_elevate_quote "${word}")"
    if [[ -z "${out}" ]]; then
      out="${quoted}"
    else
      out="${out} ${quoted}"
    fi
  done
  printf '%s' "${out}"
}

elevate_command_line() {
  if [[ "$#" -eq 0 ]]; then
    printf 'elevate: no command to show (empty command list)\n' >&2
    return 1
  fi
  printf 'sudo %s\n' "$(_elevate_command_string "$@")"
}

elevate_run() {
  if [[ "$#" -eq 0 ]]; then
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

  printf 'Running elevated command: %s\n' "$(elevate_command_line "$@")"

  local elevated_code=0
  sudo "$@" || elevated_code="$?"
  return "${elevated_code}"
}
