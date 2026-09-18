#!/usr/bin/env bash
set -euo pipefail

# modules/book-access-doctor/module.sh
# Diagnose-first mount doctor for e-readers and book devices on Linux Mint 22.
# It reads the removable mounts Mint automounts under /media/<user> and
# /run/media/<user>, says in plain words what each one is (source, filesystem,
# mount options, writable or not), and delivers an honest verdict.
#
# The ONE repair it makes: when a discovered mount is read-only, an elevated
# `mount -o remount,rw <target>` after ONE confirmation, recorded BEFORE it runs
# and restorable on undo (undo remounts the same target read-only again).
# Owner rulings this module obeys (2026-09-16, binding):
#   - remount-as-elevated is fine; the privileged prefix lives only in
#     lib/elevate.sh, never in this file;
#   - persistent mounts are OUT of scope: the fstab line such a mount would need
#     is PRINTED as informational text and never written — Mint's own Disks app
#     is the tool named for it;
#   - no permission is ever changed by this module: no targeted grant, and never
#     a recursive grant on anything.
#
# Diagnosis ladder (run order):
#   1. preflight: findmnt and mount exist (util-linux ships on Mint)
#   2. findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS — keep only the rows whose
#      TARGET is under /media/ or /run/media/; zero rows -> plug-it-in verdict
#   3. report every discovered mount plainly (target, source, filesystem, ro/rw,
#      writable or not)
#   4. all rw and writable -> healthy verdict, nothing asked, nothing changed
#   5. first read-only mount -> fstype allowlist check (a read-only medium such
#      as iso9660 earns an honest not-applicable verdict), then current versus
#      proposed plus the exact elevated command, ONE confirmation, record,
#      remount read-write, verify, report
#   6. undo: remount the recorded target read-only, verify, delete the record
#
# Test seam: the writability probe (`test -w <target>`) can be pointed at a
# stand-in root through MINTBUTLER_MOUNT_PROBE_ROOT, because a harness cannot
# create root-owned /media/... mount points. The seam only prefixes the probe
# path; it is unset on a real system, so there the probe is exactly
# `test -w "<target>"`. Every reported path stays the real one.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${MINTBUTLER_LIB_DIR:-$(cd "${SCRIPT_DIR}/../../lib" && pwd)}"

# Pass this module's slug so lib/elevate.sh can check the manifest's risk
# declaration before anything privileged runs.
export MINTBUTLER_MODULE_SLUG="${MINTBUTLER_MODULE_SLUG:-book-access-doctor}"

# shellcheck source=lib/elevate.sh
source "${LIB_DIR}/elevate.sh"
# shellcheck source=lib/ask.sh
source "${LIB_DIR}/ask.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mintbutler/book-access-doctor"
STATE_FILE="${STATE_DIR}/remount.record"

# Filesystem types a read-write remount can genuinely help — EXACTLY this list.
# Read-only media (iso9660, squashfs, udf as pressed disc) are deliberately
# absent: remounting them rw does not apply, and the module says so.
REMOUNTABLE_FSTYPES=(vfat exfat ext4 ext3 ext2 ntfs ntfs3 f2fs)

# Test seam for the writability probe (see the header); empty on a real system.
MOUNT_PROBE_ROOT="${MINTBUTLER_MOUNT_PROBE_ROOT:-}"

describe() {
  printf 'Diagnose-first book-device doctor: reads the removable mounts Mint automounts, says plainly which one is read-only, and can remount it read-write (elevated, confirmed, recorded, undoable).\n'
}

# remountable_list — the allowlist as one comma-separated display string, built
# from the array so the plan can never drift from the code that enforces it.
remountable_list() {
  local out="" entry
  for entry in "${REMOUNTABLE_FSTYPES[@]}"; do
    if [[ -z "${out}" ]]; then
      out="${entry}"
    else
      out="${out}, ${entry}"
    fi
  done
  printf '%s' "${out}"
}

plan() {
  printf 'Plan for book-access-doctor:\n'
  printf '1. Preflight: findmnt and mount must exist (util-linux ships on Mint); else stop.\n'
  printf '2. Discover the removable mounts with: findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS\n'
  printf '   — only rows under /media/ or /run/media/, where Mint automounts book devices.\n'
  printf '3. None found -> honest verdict: plug the reader in and unlock it, let the file\n'
  printf "   manager mount it, then re-run; automatic mounts belong in Mint's Disks app.\n"
  printf '4. Report every mount plainly: target, source, filesystem, ro or rw, writable or\n'
  printf '   not. All rw and writable -> healthy verdict; nothing asked, nothing changed.\n'
  printf '5. A read-only mount -> ONE repair, and only for these filesystem types:\n'
  printf '   %s. A read-only medium such\n' "$(remountable_list)"
  printf '   as iso9660 earns an honest "remounting rw does not apply" verdict instead.\n'
  printf '   Otherwise: show current versus proposed and the exact elevated command, ask\n'
  printf '   ONE confirmation; on yes only: record, remount read-write, verify, report.\n'
  printf '6. Undo remounts the recorded target read-only again, then deletes the record.\n'
  printf '7. mintbutler never writes /etc/fstab — persistent-mount guidance is printed as\n'
  printf '   information only — and never runs chmod or chown: no permission changes.\n'
}

dry_run() {
  plan
  printf '\n'
  printf 'Exact commands (nothing runs now; values as read):\n'
  printf '  findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS   (discovery; read-only)\n'
  printf "  findmnt -n -o OPTIONS '<target>'             (re-check; read-only)\n"
  printf '  %s   (the only elevated step, after your yes)\n' \
    "$(elevate_command_line "mount -o remount,rw '<target>'")"
  printf '  undo: %s   (from the record)\n' \
    "$(elevate_command_line "mount -o remount,ro '<target>'")"
  printf '  state: %s is written before the remount and deleted by undo\n' "${STATE_FILE}"
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
      printf 'run is not implemented yet.\n' >&2
      exit 1
      ;;
    undo)
      printf 'undo is not implemented yet.\n' >&2
      exit 1
      ;;
    *)
      printf 'Unknown action: %s\n' "${action}" >&2
      exit 1
      ;;
  esac
}

main "$@"
