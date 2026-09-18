#!/usr/bin/env bash
set -euo pipefail

# modules/printer-helper/module.sh
# Diagnose-first CUPS doctor for Linux Mint 22. Reads the printing stack
# first — scheduler state, configured queues, detected devices — then guides
# setup in plain words with Mint's OWN tools and driverless IPP Everywhere.
# It never downloads, recommends, or installs vendor drivers or blobs, and it
# never prints a privileged command: re-enabling a queue or restarting the
# service is pointed back at Mint, not done here. This module does not
# source lib/elevate.sh and runs nothing elevated.
#
# The ONE change it makes: when no default is set and a queue is idle, or the
# default names a queue that no longer exists and a healthy one does, it
# points the default at that queue with lpoptions -d. The previous default is
# recorded BEFORE the change (prev_default=<queue> or prev_default=none) and
# undo restores it exactly. This module asks no safety question: the menu
# takes the single confirmation for a run before this module launches
# (MODULE_SPEC §3, MB-004).
#
# Diagnosis ladder (run order):
#   1. preflight: lpstat, lpinfo, lpoptions exist (cups-client ships on Mint)
#   2. lpstat -r     — scheduler not running -> honest verdict, exit 0
#   3. lpstat -p -d  — queues and the current default
#   4. no queue      -> guided-setup verdict, exit 0
#   5. lpinfo -v     — device scan (best effort; failure tolerated)
#   6. default repair — current vs proposed, record, apply, verify
#                       (verify mismatch -> record deleted, exit 1)
#   7. otherwise     -> honest status verdict, exit 0

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mintbutler/printer-helper"
STATE_FILE="${STATE_DIR}/default.record"

# Parsed state of the last lpstat -p -d / lpstat -d read.
QUEUE_NAMES=()
QUEUE_STATES=()
DEFAULT_QUEUE=""
DEFAULT_PRESENT=0

trim_ws() {
  local s="${1:-}"
  # shellcheck disable=SC2295
  s="${s#"${s%%[![:space:]]*}"}"
  # shellcheck disable=SC2295
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

# queue_state TEXT — the plain state word for one `lpstat -p` printer line.
# "disabled" wins over "idle": CUPS prints a paused/disabled queue without
# the word idle, and prints both words when the queue is idle but disabled.
queue_state() {
  local lowered
  lowered="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "${lowered}" in
    *disabled*) printf 'disabled' ;;
    *paused*) printf 'paused' ;;
    *idle*) printf 'idle' ;;
    *printing*|*processing*) printf 'printing' ;;
    *stopped*) printf 'stopped' ;;
    *) printf 'unknown' ;;
  esac
}

# parse_queue_report TEXT — fills QUEUE_NAMES/QUEUE_STATES (one entry per
# queue, first occurrence wins) and DEFAULT_QUEUE/DEFAULT_PRESENT.
parse_queue_report() {
  local text="${1:-}"
  QUEUE_NAMES=()
  QUEUE_STATES=()
  DEFAULT_QUEUE=""
  DEFAULT_PRESENT=0
  local line rest name state seen=0 i
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ -z "$(trim_ws "${line}")" ]]; then
      continue
    fi
    case "${line}" in
      "system default destination:"*|"System default destination:"*)
        DEFAULT_QUEUE="$(trim_ws "${line#*:}")"
        DEFAULT_PRESENT=1
        continue
        ;;
      "no system default destination"*|"No system default destination"*)
        DEFAULT_QUEUE=""
        DEFAULT_PRESENT=0
        continue
        ;;
      printer[[:space:]]*)
        rest="$(trim_ws "${line#printer}")"
        name="${rest%%[[:space:]]*}"
        if [[ -z "${name}" ]]; then
          continue
        fi
        seen=0
        for i in "${!QUEUE_NAMES[@]}"; do
          if [[ "${QUEUE_NAMES[i]}" == "${name}" ]]; then
            seen=1
          fi
        done
        if [[ "${seen}" -eq 1 ]]; then
          continue
        fi
        state="$(queue_state "${rest}")"
        QUEUE_NAMES+=("${name}")
        QUEUE_STATES+=("${state}")
        continue
        ;;
      *)
        continue
        ;;
    esac
  done <<< "${text}"
  return 0
}

# read_default_queue TEXT — fills DEFAULT_QUEUE/DEFAULT_PRESENT from an
# `lpstat -d` reply.
read_default_queue() {
  local text="${1:-}"
  local line
  DEFAULT_QUEUE=""
  DEFAULT_PRESENT=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ -z "$(trim_ws "${line}")" ]]; then
      continue
    fi
    case "${line}" in
      "system default destination:"*|"System default destination:"*)
        DEFAULT_QUEUE="$(trim_ws "${line#*:}")"
        DEFAULT_PRESENT=1
        return 0
        ;;
      "no system default destination"*|"No system default destination"*)
        DEFAULT_QUEUE=""
        DEFAULT_PRESENT=0
        return 0
        ;;
    esac
  done <<< "${text}"
  return 0
}

# queue_index NAME — prints the index of NAME in QUEUE_NAMES, 1 when absent.
queue_index() {
  local want="${1:-}"
  local i
  for i in "${!QUEUE_NAMES[@]}"; do
    if [[ "${QUEUE_NAMES[i]}" == "${want}" ]]; then
      printf '%s\n' "${i}"
      return 0
    fi
  done
  return 1
}

# first_healthy_queue — prints the first queue whose state is idle.
first_healthy_queue() {
  local i
  for i in "${!QUEUE_NAMES[@]}"; do
    if [[ "${QUEUE_STATES[i]}" == "idle" ]]; then
      printf '%s\n' "${QUEUE_NAMES[i]}"
      return 0
    fi
  done
  return 1
}

# print_device_summary TEXT — a short device summary from `lpinfo -v`.
print_device_summary() {
  local text="${1:-}"
  local -a devices=()
  local line i
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ -n "$(trim_ws "${line}")" ]]; then
      devices+=("$(trim_ws "${line}")")
    fi
  done <<< "${text}"
  if [[ "${#devices[@]}" -eq 0 ]]; then
    printf '  Device scan: no devices reported.\n'
    return 0
  fi
  printf '  Device scan: %d device(s) reported.\n' "${#devices[@]}"
  for i in "${!devices[@]}"; do
    if [[ "${i}" -lt 3 ]]; then
      printf '    - %s\n' "${devices[i]}"
    fi
  done
  if [[ "${#devices[@]}" -gt 3 ]]; then
    printf '    (+ %d more not shown)\n' "$((${#devices[@]} - 3))"
  fi
  return 0
}

describe() {
  printf "Diagnose-first CUPS doctor: reads the scheduler, the queues and the devices, then guides setup with Mint's own tools and driverless IPP Everywhere. The one repair it makes, pointing the default at a healthy queue, is recorded and undoable.\n"
}

plan() {
  printf 'Plan for printer-helper:\n'
  printf '1. Preflight: lpstat, lpinfo and lpoptions must exist (cups-client ships on Mint); else stop.\n'
  printf '2. Scheduler state with: lpstat -r — not running -> honest verdict plus guidance; nothing changed.\n'
  printf '3. Queues and the current default with: lpstat -p -d\n'
  printf '4. No queue at all -> guided setup: add a printer with Mint'"'"'s Printers settings app or\n'
  printf '   the CUPS web interface at http://localhost:631, driverless with IPP Everywhere;\n'
  printf '   mintbutler never downloads or installs vendor drivers or blobs.\n'
  printf '5. Device scan with: lpinfo -v (best effort; a failure is reported, not fatal)\n'
  printf '6. Default repair, only when no default is set and a queue is idle, or the default names\n'
  printf '   a missing queue and a healthy one exists: show current versus proposed, then (the menu\n'
  printf '   took the one confirmation) record the previous default, apply lpoptions -d <queue>, verify with lpstat -d.\n'
  printf '7. Otherwise: honest status verdict naming every queue and its state; a disabled or paused\n'
  printf '   queue is re-enabled in Mint'"'"'s Printers settings, never here. Undo restores the recorded default.\n'
}

dry_run() {
  plan
  printf '\n'
  printf 'Exact commands (nothing runs now; values as read):\n'
  printf '  lpstat -r                  (scheduler state)\n'
  printf '  lpstat -p -d               (queues and the current default)\n'
  printf '  lpinfo -v                  (device scan; best effort)\n'
  printf '  lpoptions -d <queue>       (only after the menu confirmation)\n'
  printf '  lpstat -d                  (verify the new default)\n'
  printf '  undo: lpoptions -d <recorded default> | lpoptions -x   (record says none)\n'
  printf '  state: %s is written before the change and removed by undo\n' "${STATE_FILE}"
}

run() {
  # (i) preflight — one plain honest line when the CUPS client tools are gone.
  local missing="" tool
  for tool in lpstat lpinfo lpoptions; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      if [[ -z "${missing}" ]]; then
        missing="${tool}"
      else
        missing="${missing}, ${tool}"
      fi
    fi
  done
  if [[ -n "${missing}" ]]; then
    printf 'Printing tools missing: %s — the CUPS client tools are expected on Mint; nothing was changed.\n' "${missing}" >&2
    exit 1
  fi

  printf 'Printing diagnosis — every step is read-only unless you confirm the default repair.\n'

  # (ii) scheduler state.
  local sched_out="" sched_code=0
  sched_out="$(lpstat -r 2>/dev/null)" || sched_code="$?"
  if [[ "${sched_code}" -ne 0 ]] || printf '%s' "${sched_out}" | grep -qi "not running"; then
    printf '\nVerdict: the CUPS printing service is not running.\n'
    printf "Nothing here can fix that: this module never touches system services. Open Mint's Printers settings app (menu -> Preferences -> Printers) to start the printing service, or reboot the machine, then re-run this module. No changes were made.\n"
    exit 0
  fi
  printf '  Scheduler: running.\n'

  # (iii) queues and the current default.
  local queues_out="" queues_code=0
  queues_out="$(lpstat -p -d 2>/dev/null)" || queues_code="$?"
  if [[ "${queues_code}" -ne 0 ]]; then
    printf '\nVerdict: the configured queues could not be read (lpstat -p -d failed), so there is nothing safe to report yet. Check that the printing service is answering, then re-run. No changes were made.\n'
    exit 0
  fi
  parse_queue_report "${queues_out}"

  # (iv) no queue at all -> guided setup, nothing written.
  if [[ "${#QUEUE_NAMES[@]}" -eq 0 ]]; then
    printf '\nVerdict: no printer is set up on this machine — the printing service is running but no queue is configured.\n'
    printf "Add one with Mint's own tools: open the Printers settings app (menu -> Preferences -> Printers), or the CUPS web interface at http://localhost:631.\n"
    printf 'Most modern printers work driverless: choose the IPP Everywhere entry (or the ipp/ipps network entry) for your printer and let Mint do the rest.\n'
    printf 'mintbutler never downloads, recommends, or installs vendor drivers or blobs — if a printer only works with a vendor driver, that is your call to make outside this module.\n'
    printf 'No changes were made.\n'
    exit 0
  fi

  printf '  Queues: %d configured.\n' "${#QUEUE_NAMES[@]}"
  local qi
  for qi in "${!QUEUE_NAMES[@]}"; do
    printf '    - %s (%s)\n' "${QUEUE_NAMES[qi]}" "${QUEUE_STATES[qi]}"
  done
  if [[ "${DEFAULT_PRESENT}" -eq 1 && -n "${DEFAULT_QUEUE}" ]]; then
    printf '  Default: %s\n' "${DEFAULT_QUEUE}"
  else
    printf '  Default: (none set)\n'
  fi

  # (v) device scan — best effort; a failure is reported and tolerated.
  local scan_out="" scan_code=0
  if command -v timeout >/dev/null 2>&1; then
    scan_out="$(timeout 10 lpinfo -v 2>/dev/null)" || scan_code="$?"
  else
    scan_out="$(lpinfo -v 2>/dev/null)" || scan_code="$?"
  fi
  if [[ "${scan_code}" -ne 0 ]]; then
    printf '  Device scan: unavailable (lpinfo -v did not answer); continuing without it.\n'
  else
    print_device_summary "${scan_out}"
  fi

  # (vi) the default repair, only where it is genuinely needed.
  local default_idx=-1 default_state="" proposed="" need_repair=0
  if [[ "${DEFAULT_PRESENT}" -eq 1 && -n "${DEFAULT_QUEUE}" ]]; then
    if default_idx="$(queue_index "${DEFAULT_QUEUE}")"; then
      default_state="${QUEUE_STATES[default_idx]}"
    else
      default_idx=-1
    fi
  fi
  if proposed="$(first_healthy_queue)"; then
    if [[ "${DEFAULT_PRESENT}" -eq 0 || -z "${DEFAULT_QUEUE}" ]]; then
      need_repair=1
    elif [[ "${default_idx}" -lt 0 ]]; then
      need_repair=1
    fi
  fi

  if [[ "${need_repair}" -eq 1 ]]; then
    printf '\nThe default printer is not pointing at a healthy queue:\n'
    if [[ "${DEFAULT_PRESENT}" -eq 0 || -z "${DEFAULT_QUEUE}" ]]; then
      printf '  current:  no default printer is set\n'
    else
      printf '  current:  %s — that queue no longer exists\n' "${DEFAULT_QUEUE}"
    fi
    local proposed_idx
    proposed_idx="$(queue_index "${proposed}")"
    printf '  proposed: %s (%s)\n' "${proposed}" "${QUEUE_STATES[proposed_idx]}"
    printf '  command:  lpoptions -d %s\n' "${proposed}"

    # No in-module safety question (MODULE_SPEC §3): the menu took the single
    # confirmation for this run before this module launched.
    # Record the previous default BEFORE applying anything.
    mkdir -p "${STATE_DIR}"
    if [[ "${DEFAULT_PRESENT}" -eq 1 && -n "${DEFAULT_QUEUE}" ]]; then
      printf 'prev_default=%s\n' "${DEFAULT_QUEUE}" > "${STATE_FILE}"
    else
      printf 'prev_default=none\n' > "${STATE_FILE}"
    fi
    printf 'Recorded the previous default in %s\n' "${STATE_FILE}"

    local apply_code=0
    lpoptions -d "${proposed}" || apply_code="$?"
    if [[ "${apply_code}" -ne 0 ]]; then
      rm -f "${STATE_FILE}"
      rmdir "${STATE_DIR}" 2>/dev/null || true
      printf 'lpoptions could not set the default printer (exited %d); the state record was removed and nothing was changed.\n' "${apply_code}" >&2
      exit 1
    fi

    local verify_out="" verify_code=0
    verify_out="$(lpstat -d 2>/dev/null)" || verify_code="$?"
    read_default_queue "${verify_out}"
    if [[ "${verify_code}" -ne 0 || "${DEFAULT_PRESENT}" -ne 1 || "${DEFAULT_QUEUE}" != "${proposed}" ]]; then
      rm -f "${STATE_FILE}"
      rmdir "${STATE_DIR}" 2>/dev/null || true
      printf 'The default did not verify (lpstat -d reads %s instead of %s); the state record was removed and no undo is offered — check the queue in Mint'"'"'s Printers settings.\n' "${DEFAULT_QUEUE:-(none set)}" "${proposed}" >&2
      exit 1
    fi

    printf 'Default printer is now %s.\n' "${proposed}"
    printf 'The previous default is recorded; [u]ndo in the menu restores it exactly.\n'
    exit 0
  fi

  # (vii) queues present, default sane (or nothing healthy to point at):
  # honest status verdict, guidance for stalled queues, nothing written.
  printf '\n'
  if [[ "${default_idx}" -ge 0 && "${default_state}" == "idle" ]]; then
    printf 'Verdict: the printing stack looks healthy — the scheduler is running, %d queue(s) are configured, and the default printer is %s (idle).\n' "${#QUEUE_NAMES[@]}" "${DEFAULT_QUEUE}"
  else
    printf 'Verdict: the printing stack is up but the default printer is not a healthy queue — every queue is listed above with its state.\n'
  fi
  local stalled=0
  for qi in "${!QUEUE_STATES[@]}"; do
    case "${QUEUE_STATES[qi]}" in
      disabled|paused|stopped|unknown)
        stalled=1
        ;;
    esac
  done
  if [[ "${stalled}" -eq 1 ]]; then
    printf "A queue that is disabled, paused or stopped can be re-enabled in Mint's Printers settings app (right-click the printer -> Enabled, or use its Resume/Enable controls); this module only reports it — enabling queues is not a change it makes.\n"
  fi
  printf 'No changes were made.\n'
  exit 0
}

undo() {
  if [[ ! -f "${STATE_FILE}" ]]; then
    printf 'Nothing to undo.\n'
    printf 'Note: the diagnosis steps and verdicts are read-only and never needed undoing.\n'
    return 0
  fi

  local missing=""
  if ! command -v lpoptions >/dev/null 2>&1; then
    missing="lpoptions"
  fi
  if ! command -v lpstat >/dev/null 2>&1; then
    if [[ -z "${missing}" ]]; then
      missing="lpstat"
    else
      missing="${missing}, lpstat"
    fi
  fi
  if [[ -n "${missing}" ]]; then
    printf 'Cannot undo: %s is missing, so the recorded default printer cannot be restored and checked; the record is kept at %s.\n' "${missing}" "${STATE_FILE}" >&2
    return 1
  fi

  local prev="" record_line
  while IFS= read -r record_line || [[ -n "${record_line}" ]]; do
    case "${record_line}" in
      prev_default=*)
        prev="${record_line#prev_default=}"
        ;;
    esac
  done < "${STATE_FILE}"
  if [[ -z "${prev}" ]]; then
    printf 'Cannot undo: the record at %s is unreadable; refusing to guess.\n' "${STATE_FILE}" >&2
    return 1
  fi

  local undo_code=0
  if [[ "${prev}" == "none" ]]; then
    lpoptions -x || undo_code="$?"
  else
    lpoptions -d "${prev}" || undo_code="$?"
  fi
  if [[ "${undo_code}" -ne 0 ]]; then
    printf 'Could not restore the default printer (lpoptions exited %d); the record is kept at %s.\n' "${undo_code}" "${STATE_FILE}" >&2
    return 1
  fi

  local verify_out="" verify_code=0 restored=1
  verify_out="$(lpstat -d 2>/dev/null)" || verify_code="$?"
  read_default_queue "${verify_out}"
  if [[ "${prev}" == "none" ]]; then
    if [[ "${verify_code}" -eq 0 && ( "${DEFAULT_PRESENT}" -eq 0 || -z "${DEFAULT_QUEUE}" ) ]]; then
      restored=0
    fi
  else
    if [[ "${verify_code}" -eq 0 && "${DEFAULT_PRESENT}" -eq 1 && "${DEFAULT_QUEUE}" == "${prev}" ]]; then
      restored=0
    fi
  fi
  if [[ "${restored}" -ne 0 ]]; then
    printf 'Undo could not be verified (lpstat -d reads %s); the record is kept at %s.\n' "${DEFAULT_QUEUE:-(none set)}" "${STATE_FILE}" >&2
    return 1
  fi

  rm -f "${STATE_FILE}"
  rmdir "${STATE_DIR}" 2>/dev/null || true
  if [[ "${prev}" == "none" ]]; then
    printf 'Restored: no default printer is set again — the state before this module ran.\n'
  else
    printf 'Restored: the default printer is %s again.\n' "${prev}"
  fi
  printf 'The state record was deleted. The diagnosis steps and verdicts are read-only and never needed undoing.\n'
  return 0
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
      undo
      ;;
    *)
      printf 'Unknown action: %s\n' "${action}" >&2
      exit 1
      ;;
  esac
}

main "$@"
