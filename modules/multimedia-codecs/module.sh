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
#   4. some missing -> lists + exact elevated command + no-undo notice,
#      then ONE ask_yn confirmation (Enter = NO, EOF = NO)
#   5. yes -> the single elevated apt-get install step (lib/elevate.sh)
#   6. verify per package -> full success report (with the manual removal
#      command display + no-undo reminder) or honest mixed report

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${MINTBUTLER_LIB_DIR:-$(cd "${SCRIPT_DIR}/../../lib" && pwd)}"

# Pass this module's slug so lib/elevate.sh can check the manifest's risk
# declaration before anything privileged runs.
export MINTBUTLER_MODULE_SLUG="${MINTBUTLER_MODULE_SLUG:-multimedia-codecs}"

# shellcheck source=lib/elevate.sh
source "${LIB_DIR}/elevate.sh"
# shellcheck source=lib/ask.sh
source "${LIB_DIR}/ask.sh"

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
  printf '4. Some missing -> show installed vs missing, the exact elevated command:\n'
  printf '   %s\n' "$(elevate_command_line "apt-get install -y <missing...>")"
  printf '   plus the no-undo notice; then ONE confirmation (Enter = no).\n'
  printf '5. On yes only: run that single elevated apt-get install step.\n'
  printf '6. Verify every installed package again with dpkg -s; report per-package\n'
  printf '   success or an honest mixed result with a plain retry hint.\n'
  printf '7. No apt-get update runs: a package unknown to the cached package lists\n'
  printf '   gets the honest mixed report (refresh software sources, then re-run).\n'
  printf '8. No-undo: installs are not undone by this module; after success the\n'
  printf '   exact manual removal command is printed instead of a fake undo.\n'
}

dry_run() {
  plan
  printf '\n'
  printf 'Exact commands (nothing runs now; <missing...> = what dpkg -s reports missing):\n'
  printf '  dpkg -s <package>   (read-only status check; repeated to verify)\n'
  printf '  %s   (the only elevated step, after confirmation)\n' "$(elevate_command_line "apt-get install -y <missing...>")"
  printf '  removal display after success: %s   (never run here)\n' "$(elevate_command_line "apt-get remove <installed...>")"
  printf '  undo: none — package installs are not undone by this module\n'
}

run() {
  printf 'run is not implemented yet (work in progress).\n' >&2
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
