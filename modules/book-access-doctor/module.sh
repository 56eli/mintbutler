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

trim_ws() {
  local s="${1:-}"
  # shellcheck disable=SC2295
  s="${s#"${s%%[![:space:]]*}"}"
  # shellcheck disable=SC2295
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

# has_option OPTIONS OPTION — true when OPTION is one of the comma-separated
# mount options in OPTIONS. This is an exact token match on purpose: ext4 rows
# carry errors=remount-ro, which must never be read as a read-only mount.
has_option() {
  local options="${1:-}" want="${2:-}" part
  local -a parts=()
  IFS=',' read -r -a parts <<< "${options}" || true
  for part in "${parts[@]}"; do
    if [[ "${part}" == "${want}" ]]; then
      return 0
    fi
  done
  return 1
}

# fstype_is_remountable FSTYPE — true when FSTYPE (case-insensitive) is one of
# the types a read-write remount can genuinely help.
fstype_is_remountable() {
  local fstype entry
  fstype="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  for entry in "${REMOUNTABLE_FSTYPES[@]}"; do
    if [[ "${fstype}" == "${entry}" ]]; then
      return 0
    fi
  done
  return 1
}

# Parsed rows of the last discovery read — one entry per removable mount, in
# discovery order.
MOUNT_TARGETS=()
MOUNT_SOURCES=()
MOUNT_FSTYPES=()
MOUNT_OPTIONS=()
MOUNT_WRITABLE=()

# parse_mount_rows TEXT — fill the arrays above from `findmnt -n -o
# TARGET,SOURCE,FSTYPE,OPTIONS` output, keeping ONLY the rows whose target is
# under /media/ or /run/media/ (Mint's automount roots for removable devices).
#
# Parsing note: findmnt pads its columns and, in its default tree view, prefixes
# child targets with decoration such as "| |-". OPTIONS, FSTYPE and SOURCE are
# single whitespace-free tokens, so they are taken from the right of the row and
# the target keeps the remainder — a mount point may legitimately contain
# spaces, and the decoration is dropped before the /media prefix filter runs.
parse_mount_rows() {
  local text="${1:-}"
  MOUNT_TARGETS=()
  MOUNT_SOURCES=()
  MOUNT_FSTYPES=()
  MOUNT_OPTIONS=()
  MOUNT_WRITABLE=()

  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ -z "$(trim_ws "${line}")" ]]; then
      continue
    fi
    local -a words=()
    read -r -a words <<< "${line}" || true
    if [[ "${#words[@]}" -lt 4 ]]; then
      continue
    fi
    local options="${words[-1]}"
    local fstype="${words[-2]}"
    local source="${words[-3]}"
    local target="" i
    for (( i = 0; i < ${#words[@]} - 3; i++ )); do
      if [[ -z "${target}" ]]; then
        target="${words[i]}"
      else
        target="${target} ${words[i]}"
      fi
    done
    case "${target}" in
      /*)
        ;;
      */*)
        target="/${target#*/}"
        ;;
      *)
        continue
        ;;
    esac
    case "${target}" in
      /media/*|/run/media/*)
        ;;
      *)
        continue
        ;;
    esac
    local writable="0"
    if [[ -w "${MOUNT_PROBE_ROOT}${target}" ]]; then
      writable="1"
    fi
    MOUNT_TARGETS+=("${target}")
    MOUNT_SOURCES+=("${source}")
    MOUNT_FSTYPES+=("${fstype}")
    MOUNT_OPTIONS+=("${options}")
    MOUNT_WRITABLE+=("${writable}")
  done <<< "${text}"
  return 0
}

# report_mounts — the plain-words report of every discovered mount: what it is,
# where it comes from, how it is mounted, and whether it takes writes now.
report_mounts() {
  local total="${#MOUNT_TARGETS[@]}" i mount_word access_word
  printf '  Removable mounts found under /media or /run/media: %d\n' "${total}"
  for i in "${!MOUNT_TARGETS[@]}"; do
    if has_option "${MOUNT_OPTIONS[i]}" ro; then
      mount_word="mounted read-only (ro)"
    elif has_option "${MOUNT_OPTIONS[i]}" rw; then
      mount_word="mounted read-write (rw)"
    else
      mount_word="mount options name neither ro nor rw"
    fi
    if [[ "${MOUNT_WRITABLE[i]}" == "1" ]]; then
      access_word="writable right now"
    else
      access_word="not writable right now"
    fi
    printf '  Mount %d of %d: %s\n' "$((i + 1))" "${total}" "${MOUNT_TARGETS[i]}"
    printf '    source: %s | filesystem: %s | %s | %s\n' \
      "${MOUNT_SOURCES[i]}" "${MOUNT_FSTYPES[i]}" "${mount_word}" "${access_word}"
    printf '    options: %s\n' "${MOUNT_OPTIONS[i]}"
  done
  return 0
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

run() {
  # (i) preflight — one plain honest line when the util-linux tools are missing.
  local missing="" tool
  for tool in findmnt mount; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      if [[ -z "${missing}" ]]; then
        missing="${tool}"
      else
        missing="${missing}, ${tool}"
      fi
    fi
  done
  if [[ -n "${missing}" ]]; then
    printf 'Mount tools missing: %s — findmnt and mount ship with util-linux on Mint; nothing was changed.\n' "${missing}" >&2
    exit 1
  fi

  printf 'Book device diagnosis — every step is read-only unless you confirm the one remount.\n'

  # (ii) discover the removable mounts (read-only).
  local rows="" rows_code=0
  rows="$(findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null)" || rows_code="$?"
  if [[ "${rows_code}" -ne 0 ]]; then
    printf 'Verdict: the mount table could not be read (findmnt exited %d), so there is nothing safe to report yet.\n' "${rows_code}"
    printf 'Give the file manager a moment to settle, or reboot, then re-run this doctor. No changes were made.\n'
    exit 0
  fi
  parse_mount_rows "${rows}"

  # (iii) nothing removable mounted -> plug-it-in guidance; nothing is written
  # and nothing is asked.
  if [[ "${#MOUNT_TARGETS[@]}" -eq 0 ]]; then
    printf 'Verdict: no removable mount found under /media or /run/media — no book device is mounted right now.\n'
    printf 'Plug the reader in and unlock it (many devices stay locked until you allow the connection on their screen),\n'
    printf "wait for Mint's file manager to mount it — or click the device there — then re-run this doctor.\n"
    printf "For automatic mounts use Mint's Disks app: mintbutler never writes /etc/fstab.\n"
    printf 'No changes were made.\n'
    exit 0
  fi

  # (iv) the plain-words report of everything discovered.
  report_mounts

  # (v) the repair candidate is the FIRST read-only mount in discovery order —
  # read-only by its options, or simply not writable.
  local candidate=-1 i
  for i in "${!MOUNT_TARGETS[@]}"; do
    if has_option "${MOUNT_OPTIONS[i]}" ro || [[ "${MOUNT_WRITABLE[i]}" == "0" ]]; then
      candidate="${i}"
      break
    fi
  done

  # (vi) every mount read-write and writable -> healthy verdict, no question,
  # no elevated call, nothing written.
  if [[ "${candidate}" -lt 0 ]]; then
    printf 'Verdict: every book-device mount is read-write and writable — the mounts look healthy.\n'
    printf 'If a book app still cannot see its files, unplug and replug the device, unlock its screen, then re-run.\n'
    printf 'No changes were made.\n'
    exit 0
  fi

  printf 'A read-only mount was found; the repair path is not implemented yet.\n' >&2
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
