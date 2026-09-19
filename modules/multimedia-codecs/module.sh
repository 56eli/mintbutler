#!/usr/bin/env bash
set -euo pipefail

# modules/multimedia-codecs/module.sh
# Diagnose-first installer for the curated multimedia codec bundle on
# Linux Mint 22. Every step is read-only until ONE confirmation; the only
# action is a single elevated apt-get install of exactly the missing
# curated packages, followed by per-package verification.
#
# Honest no-undo (owner ruling): package installs are NOT undone by this
# module, and it writes NO state file anywhere. describe, plan, and the
# post-install report all say so plainly; after a successful install the
# exact manual removal command is printed (displayed through
# lib/elevate.sh, never as a literal here) instead of a fake undo.
#
# No apt-get update is run: the install works against the cached package
# lists; if a package is unknown to them the honest mixed/failed report
# names it and hints at refreshing the software sources.
#
# Diagnosis ladder (run order):
#   1. preflight: dpkg and apt-get exist (both ship on Mint)
#   2. read-only status: dpkg -s per curated package -> installed/missing
#   3. nothing missing -> honest "already installed" verdict, exit 0
#   4. some missing -> lists + exact elevated command + no-undo notice, then
#      install immediately — the menu took the single confirmation for this
#      run before launch; this module asks nothing itself (MODULE_SPEC §3)
#   5. the single elevated apt-get install step (lib/elevate.sh)
#   6. verify per package -> full success report (with the manual removal
#      command display + no-undo reminder) or honest mixed report

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${MINTBUTLER_LIB_DIR:-$(cd "${SCRIPT_DIR}/../../lib" && pwd)}"

# Pass this module's slug so lib/elevate.sh can check the manifest's risk
# declaration before anything privileged runs.
export MINTBUTLER_MODULE_SLUG="${MINTBUTLER_MODULE_SLUG:-multimedia-codecs}"

# shellcheck source=lib/elevate.sh
source "${LIB_DIR}/elevate.sh"

# Curated codec package list for the base system (Linux Mint 22 / Ubuntu
# 24.04): the GStreamer bad and ugly plugin sets, the GStreamer libav
# plugin set, and the extended FFmpeg codec library. Fixed and reviewed —
# this module installs ONLY packages from this list, and only the ones
# dpkg reports as not installed.
CODEC_PACKAGES=(
  "gstreamer1.0-plugins-bad"
  "gstreamer1.0-plugins-ugly"
  "gstreamer1.0-libav"
  "libavcodec-extra"
)

# join_comma ITEMS... — render "a, b, c" for human-facing lists.
join_comma() {
  local out="" item
  for item in "$@"; do
    if [[ -z "${out}" ]]; then
      out="${item}"
    else
      out="${out}, ${item}"
    fi
  done
  printf '%s' "${out}"
}

# contains_item NEEDLE HAYSTACK... — true when NEEDLE is one of the items.
contains_item() {
  local needle="${1:-}" item
  shift
  for item in "$@"; do
    if [[ "${item}" == "${needle}" ]]; then
      return 0
    fi
  done
  return 1
}

describe() {
  printf 'Diagnose-first codec installer: reports which curated codec packages are missing and, after ONE confirmation, installs exactly those — installs are not undone; the manual removal command is printed instead.\n'
}

plan() {
  printf 'Plan for multimedia-codecs:\n'
  printf '1. Preflight: dpkg and apt-get must exist (both ship on Mint); else stop.\n'
  printf '2. Read-only status: dpkg -s <package> for each curated codec package:\n'
  printf '   gstreamer1.0-plugins-bad, gstreamer1.0-plugins-ugly,\n'
  printf '   gstreamer1.0-libav, libavcodec-extra.\n'
  printf '3. Nothing missing -> honest verdict: already installed, nothing to do.\n'
  printf '4. Some missing -> show installed vs missing and the exact elevated command:\n'
  printf '   %s\n' "$(elevate_command_line apt-get install -y "<missing...>")"
  printf '   plus the no-undo notice, then install immediately — the menu took the one\n'
  printf '   confirmation for this run before launch; this module asks nothing.\n'
  printf '5. Verify every installed package again with dpkg -s; report per-package\n'
  printf '   success or an honest mixed result with a plain retry hint.\n'
  printf '6. No apt-get update runs: a package unknown to the cached package lists\n'
  printf '   gets the honest mixed report (refresh software sources, then re-run).\n'
  printf '7. No-undo: installs are not undone by this module; after success the\n'
  printf '   exact manual removal command is printed instead of a fake undo.\n'
}

dry_run() {
  plan
  printf '\n'
  printf 'Exact commands (nothing runs now; <missing...> = what dpkg -s reports missing):\n'
  printf '  dpkg -s <package>   (read-only status check; repeated to verify)\n'
  printf '  %s   (the only elevated step; the menu confirmed this run)\n' "$(elevate_command_line apt-get install -y "<missing...>")"
  printf '  removal display after success: %s   (never run here)\n' "$(elevate_command_line apt-get remove "<installed...>")"
  printf '  undo: none — package installs are not undone by this module\n'
}

run() {
  # (i) preflight — one plain honest line when the package tools are missing.
  local missing_tools=""
  if ! command -v dpkg >/dev/null 2>&1; then
    missing_tools="dpkg"
  fi
  if ! command -v apt-get >/dev/null 2>&1; then
    if [[ -n "${missing_tools}" ]]; then
      missing_tools="${missing_tools}, apt-get"
    else
      missing_tools="apt-get"
    fi
  fi
  if [[ -n "${missing_tools}" ]]; then
    printf 'Package tools missing: %s — dpkg and apt-get ship on Mint; nothing was changed.\n' "${missing_tools}" >&2
    exit 1
  fi

  printf 'Multimedia codec check — every step is read-only until you confirm the install.\n'

  # (ii) read-only status: dpkg -s per curated package -> two lists.
  local -a installed=() missing=()
  local pkg
  for pkg in "${CODEC_PACKAGES[@]}"; do
    if dpkg -s "${pkg}" >/dev/null 2>&1; then
      installed+=("${pkg}")
    else
      missing+=("${pkg}")
    fi
  done

  # (iii) nothing missing -> honest verdict, no elevated call, no writes.
  if [[ "${#missing[@]}" -eq 0 ]]; then
    printf 'Verdict: all four curated codec packages are already installed; nothing to do.\n'
    printf '  installed: %s\n' "$(join_comma "${installed[@]}")"
    printf 'No elevated call was made and nothing was written.\n'
    exit 0
  fi

  # (iv) show installed vs missing, the exact elevated command via the helper
  # display, and the honest no-undo notice — then install. No in-module safety
  # question (MODULE_SPEC §3): the menu took the single confirmation for this
  # run before this module launched.
  if [[ "${#installed[@]}" -gt 0 ]]; then
    printf '  installed: %s\n' "$(join_comma "${installed[@]}")"
  else
    printf '  installed: none of the curated packages\n'
  fi
  printf '  missing:   %s\n' "$(join_comma "${missing[@]}")"
  printf '  the single elevated step runs now: %s\n' "$(elevate_command_line apt-get install -y "${missing[@]}")"
  printf '  Notice: these installs are not undone by mintbutler; the removal command is printed after a successful install.\n'

  # (v) the ONE elevated step: install exactly the missing curated packages.
  # Each name travels as ONE argv word to sudo (MB-001); the display above is
  # derived from the same list.
  local install_code=0
  elevate_run apt-get install -y "${missing[@]}" || install_code="$?"
  if [[ "${install_code}" -ne 0 ]]; then
    printf 'The elevated apt-get step failed (exit %d); no result is claimed.\n' "${install_code}" >&2
    exit 1
  fi

  # (vi) verification: re-check every package that was missing.
  local -a now_installed=() still_missing=()
  for pkg in "${missing[@]}"; do
    if dpkg -s "${pkg}" >/dev/null 2>&1; then
      now_installed+=("${pkg}")
    else
      still_missing+=("${pkg}")
    fi
  done

  if [[ "${#still_missing[@]}" -eq 0 ]]; then
    printf 'Verified — per-package result:\n'
    for pkg in "${now_installed[@]}"; do
      printf '  %s — installed\n' "${pkg}"
    done
    printf 'Manual removal (never run by this module): %s\n' "$(elevate_command_line apt-get remove "${now_installed[@]}")"
    printf 'Reminder: package installs are not undone by mintbutler — the removal command above is the honest way back.\n'
    exit 0
  fi

  # Honest mixed report: per-package lists, plain hint, the removal command
  # for what DID install, exit 1 with one plain stderr line.
  printf 'Mixed result — per-package status:\n'
  for pkg in "${missing[@]}"; do
    if contains_item "${pkg}" "${now_installed[@]}"; then
      printf '  %s — installed\n' "${pkg}"
    else
      printf '  %s — still missing (the install did not take)\n' "${pkg}"
    fi
  done
  printf 'Hint: no apt-get update runs — the install used the cached package lists.\n'
  printf 'Refresh the software sources (Update Manager), check the network, then re-run this module.\n'
  if [[ "${#now_installed[@]}" -gt 0 ]]; then
    printf 'Manual removal for what did install (never run by this module): %s\n' "$(elevate_command_line apt-get remove "${now_installed[@]}")"
    printf 'Reminder: package installs are not undone by mintbutler.\n'
  fi
  printf 'Some curated codec packages are still missing after the elevated install.\n' >&2
  exit 1
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
    *)
      printf 'Unknown action: %s\n' "${action}" >&2
      exit 1
      ;;
  esac
}

main "$@"
