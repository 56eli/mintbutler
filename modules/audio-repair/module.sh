#!/usr/bin/env bash
set -euo pipefail

# modules/audio-repair/module.sh
# Diagnose-first sound doctor for Linux Mint 22. Every step is read-only
# except ONE recorded repair: restoring a muted or zeroed Master mixer
# control. Driver- or firmware-level evidence earns an honest
# newer-kernel/firmware verdict instead of a fake config fix (owner ruling:
# no fake fixes).
#
# Diagnosis ladder (run order):
#   1. preflight: pactl and amixer exist
#   2. pactl info                  — sound server identity
#   3. pactl list short sinks      — any real output devices?
#   4. no real sink → dmesg        — kernel-log evidence scan (the ONLY
#      elevated step; read-only; runs through lib/elevate.sh)
#   5. real sink → amixer          — first Master control: muted? volume 0%?
#   6. muted/0% → show current vs proposed, then record the state, apply,
#      verify. This module asks no safety question: the menu takes the single
#      confirmation for a run before this module launches (MODULE_SPEC §3).
#
# Kernel-log evidence rule (kept simple on purpose): a log line counts as
# driver/firmware evidence when, lowercased, it contains an audio signature
# — sof, snd_, firmware — AND a failure word — fail, timeout, missing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${MINTBUTLER_LIB_DIR:-$(cd "${SCRIPT_DIR}/../../lib" && pwd)}"

# Pass this module's slug so lib/elevate.sh can check the manifest's risk
# declaration before anything privileged runs.
export MINTBUTLER_MODULE_SLUG="${MINTBUTLER_MODULE_SLUG:-audio-repair}"

# shellcheck source=lib/elevate.sh
source "${LIB_DIR}/elevate.sh"

# The only elevated command this module ever runs (fixed, reviewed,
# read-only). The privileged prefix lives only in lib/elevate.sh.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mintbutler/audio-repair"
STATE_FILE="${STATE_DIR}/mixer.record"

describe() {
  printf 'Diagnose-first sound doctor: reads the audio stack, delivers an honest verdict, and can unmute a muted Master control (recorded, undoable).\n'
}

plan() {
  printf 'Plan for audio-repair:\n'
  printf '1. Preflight: pactl and amixer must exist (both ship on Mint); else stop.\n'
  printf '2. Identify the sound server with: pactl info\n'
  printf '3. List output devices with: pactl list short sinks\n'
  printf '4. No real device (or only a dummy one) -> scan the kernel log for\n'
  printf '   driver/firmware errors via one read-only elevated step:\n'
  printf '   %s\n' "$(elevate_command_line dmesg)"
  printf '   Evidence found -> newer-kernel/firmware verdict; nothing is changed.\n'
  printf '5. A device is present -> read the Master mixer control with: amixer\n'
  printf '   Healthy chain -> honest verdict, nothing is changed.\n'
  printf '   Muted or 0%% -> show current vs proposed, then — the menu took the one\n'
  printf '   confirmation before launch — record the Master state, apply, verify.\n'
  printf '6. Undo re-applies the recorded mute flag and volume exactly, then\n'
  printf '   deletes the state record. Every other step is read-only.\n'
}

dry_run() {
  plan
  printf '\n'
  printf 'Exact commands (nothing runs now; values as written):\n'
  printf '  pactl info\n'
  printf '  pactl list short sinks\n'
  printf '  amixer\n'
  printf '  %s   (read-only kernel-log scan; the only elevated step)\n' "$(elevate_command_line dmesg)"
  printf '  amixer -q sset Master <volume>%% unmute   (only after your confirmation)\n'
  printf '  undo: amixer -q sset Master <recorded volume>%% + the recorded mute flag\n'
  printf '  state: %s is written before the repair and removed by undo\n' "${STATE_FILE}"
}

# scan_dmesg_evidence TEXT — print the kernel-log lines matching the
# evidence rule in the header comment (at most the first 10, then a
# "+N more" marker when truncated). Prints nothing when there is no match.
scan_dmesg_evidence() {
  local text="${1:-}"
  local line lowered total=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ -z "${line}" ]]; then
      continue
    fi
    lowered="$(printf '%s' "${line}" | tr '[:upper:]' '[:lower:]')"
    case "${lowered}" in
      *sof*|*snd_*|*firmware*)
        case "${lowered}" in
          *fail*|*timeout*|*missing*)
            total=$((total + 1))
            if [[ "${total}" -le 10 ]]; then
              printf '  %s\n' "${line}"
            fi
            ;;
        esac
        ;;
    esac
  done <<< "${text}"
  if [[ "${total}" -gt 10 ]]; then
    printf '  (+ %d more evidence lines not shown)\n' "$((total - 10))"
  fi
  return 0
}

# parse_master_state TEXT — read the FIRST "Simple mixer control 'Master'"
# block of `amixer` output. Sets _MASTER_FOUND (0/1), _MASTER_MUTED (1 when
# any channel in the block is [off]) and _MASTER_VOLUME (first percentage,
# integer). Multi-card systems use the default card; documented scope.
_MASTER_FOUND=0
_MASTER_MUTED=0
_MASTER_VOLUME=0

parse_master_state() {
  local text="${1:-}"
  _MASTER_FOUND=0
  _MASTER_MUTED=0
  _MASTER_VOLUME=0
  local in_master=0 volume_seen=0 line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    case "${line}" in
      "Simple mixer control '"*)
        if [[ "${in_master}" -eq 1 ]]; then
          break
        fi
        if [[ "${line}" == *"'Master'"* ]]; then
          in_master=1
          _MASTER_FOUND=1
        fi
        ;;
    esac
    if [[ "${in_master}" -eq 1 ]]; then
      if [[ "${volume_seen}" -eq 0 && "${line}" =~ \[([0-9]+)%\] ]]; then
        _MASTER_VOLUME=$((10#${BASH_REMATCH[1]}))
        volume_seen=1
      fi
      case "${line}" in
        *"[off]"*)
          _MASTER_MUTED=1
          ;;
      esac
    fi
  done <<< "${text}"
  return 0
}

# The two small sset steps used to restore a recorded state. Separated so
# undo can check each and the verify-mismatch rollback can stay best-effort.
restore_volume() {
  amixer -q sset Master "${1}%" >/dev/null 2>&1
}

restore_mute() {
  if [[ "${1}" == "1" ]]; then
    amixer -q sset Master mute >/dev/null 2>&1
  else
    amixer -q sset Master unmute >/dev/null 2>&1
  fi
}

run() {
  # (i) preflight — one plain honest line when the user tools are missing.
  local missing=""
  if ! command -v pactl >/dev/null 2>&1; then
    missing="pactl"
  fi
  if ! command -v amixer >/dev/null 2>&1; then
    if [[ -n "${missing}" ]]; then
      missing="${missing}, amixer"
    else
      missing="amixer"
    fi
  fi
  if [[ -n "${missing}" ]]; then
    printf 'Audio tools missing: %s — the PulseAudio/ALSA user tools are expected on Mint; nothing was changed.\n' "${missing}" >&2
    exit 1
  fi

  printf 'Audio diagnosis — every step is read-only until you confirm a repair.\n'

  # (ii) sound server identity.
  local pactl_info="" info_code=0
  pactl_info="$(pactl info 2>/dev/null)" || info_code="$?"
  if [[ "${info_code}" -ne 0 ]]; then
    printf 'Verdict: the sound server is not responding — pactl could not reach it.\n'
    printf 'Reboot the machine, or log out and back in to restart the session, then re-run. No changes were made.\n'
    exit 0
  fi
  local server_name="" info_line
  while IFS= read -r info_line || [[ -n "${info_line}" ]]; do
    case "${info_line}" in
      "Server Name:"*|"Server name:"*)
        server_name="${info_line#*:}"
        # shellcheck disable=SC2295
        server_name="${server_name#"${server_name%%[![:space:]]*}"}"
        break
        ;;
    esac
  done <<< "${pactl_info}"
  printf '  Sound server: %s\n' "${server_name:-unknown}"

  # (iii) output devices.
  local sinks_out="" sinks_code=0
  sinks_out="$(pactl list short sinks 2>/dev/null)" || sinks_code="$?"
  if [[ "${sinks_code}" -ne 0 ]]; then
    printf 'Verdict: the sound server is not responding — the output-device query failed.\n'
    printf 'Reboot the machine, or log out and back in to restart the session, then re-run. No changes were made.\n'
    exit 0
  fi
  local -a sink_names=() dummy_names=()
  local sink_line sink_name
  while IFS= read -r sink_line || [[ -n "${sink_line}" ]]; do
    if [[ ! "${sink_line}" =~ [^[:space:]] ]]; then
      continue
    fi
    sink_name="$(printf '%s\n' "${sink_line}" | cut -f2)"
    if [[ -z "${sink_name}" ]]; then
      continue
    fi
    if printf '%s' "${sink_name}" | grep -qi dummy; then
      dummy_names+=("${sink_name}")
    else
      sink_names+=("${sink_name}")
    fi
  done <<< "${sinks_out}"

  # (v) no real sink -> the single elevated, read-only dmesg evidence scan.
  if [[ "${#sink_names[@]}" -eq 0 ]]; then
    if [[ "${#dummy_names[@]}" -gt 0 ]]; then
      printf '  Output devices: only a dummy device (%s); no real output.\n' "${dummy_names[0]}"
    else
      printf '  Output devices: none found.\n'
    fi
    printf '  Checking the kernel log for driver or firmware errors.\n'
    printf '  Read-only elevated step: %s\n' "$(elevate_command_line dmesg)"
    local dmesg_out="" dmesg_code=0
    dmesg_out="$(elevate_run dmesg)" || dmesg_code="$?"
    if [[ "${dmesg_code}" -ne 0 ]]; then
      printf 'Could not read the kernel log: the elevated dmesg step failed (exit %d); no changes were made and nothing was written.\n' "${dmesg_code}" >&2
      exit 1
    fi
    local evidence=""
    evidence="$(scan_dmesg_evidence "${dmesg_out}")"
    if [[ -n "${evidence}" ]]; then
      printf 'Verdict: this looks like a driver/firmware problem. Kernel-log evidence:\n'
      printf '%s\n' "${evidence}"
      printf 'Config changes will not fix it — this hardware may need a newer kernel or firmware than this system ships.\n'
      printf 'No changes were made.\n'
      exit 0
    fi
    printf 'Verdict: no output device was found and the kernel log shows no clear driver error.\n'
    printf 'Check the BIOS audio setting and any external devices (headphones, HDMI, USB), then re-run. No changes were made.\n'
    exit 0
  fi

  local sink_list="" sink_item
  for sink_item in "${sink_names[@]}"; do
    if [[ -z "${sink_list}" ]]; then
      sink_list="${sink_item}"
    else
      sink_list="${sink_list}, ${sink_item}"
    fi
  done
  printf '  Output devices: %s\n' "${sink_list}"

  # (iv) sinks exist -> Master mixer check.
  local mixer_out="" mixer_code=0
  mixer_out="$(amixer 2>/dev/null)" || mixer_code="$?"
  if [[ "${mixer_code}" -ne 0 ]]; then
    printf 'Verdict: the mixer state could not be read (amixer failed); nothing was changed. Try logging out and back in, then re-run.\n'
    exit 0
  fi
  parse_master_state "${mixer_out}"
  if [[ "${_MASTER_FOUND}" -ne 1 ]]; then
    printf 'Verdict: the default device has no Master mixer control; nothing here to repair. Check Sound Settings for per-device controls. No changes were made.\n'
    exit 0
  fi

  local rec_muted="${_MASTER_MUTED}" rec_volume="${_MASTER_VOLUME}"
  local state_word="unmuted"
  if [[ "${rec_muted}" -eq 1 ]]; then
    state_word="muted"
  fi

  # Healthy chain -> honest verdict, nothing written.
  if [[ "${rec_muted}" -eq 0 && "${rec_volume}" -gt 0 ]]; then
    printf '  Master control: unmuted, volume %s%%.\n' "${rec_volume}"
    printf 'Verdict: the output chain looks healthy — server reachable, a real output device exists, Master unmuted at %s%%.\n' "${rec_volume}"
    printf 'If you still hear nothing: check the per-app volume in Sound Settings, the cable or device, and the test-sound button; logging out and back in can reset a stuck session. No changes were made.\n'
    exit 0
  fi

  # (vi) repair: current vs proposed, then apply (no in-module question — the
  # menu took the single confirmation for this run; MODULE_SPEC §3, MB-004).
  local target_volume="${rec_volume}"
  local proposed_note="your volume is preserved"
  if [[ "${rec_volume}" -eq 0 ]]; then
    target_volume=100
    proposed_note="volume restored to 100% because it was 0%"
  fi
  printf 'The Master mixer control is the repairable culprit here:\n'
  printf '  current:  %s, %s%%\n' "${state_word}" "${rec_volume}"
  printf '  proposed: unmuted, %s%% (%s)\n' "${target_volume}" "${proposed_note}"
  printf '  command:  amixer -q sset Master %s%% unmute\n' "${target_volume}"

  # No in-module safety question (MODULE_SPEC §3): the menu took the single
  # confirmation for this run before this module launched.
  # Record the exact prior state BEFORE applying anything.
  mkdir -p "${STATE_DIR}"
  {
    printf 'muted=%s\n' "${rec_muted}"
    printf 'volume=%s\n' "${rec_volume}"
  } > "${STATE_FILE}"
  printf 'Recorded the previous Master state in %s\n' "${STATE_FILE}"

  local apply_code=0
  amixer -q sset Master "${target_volume}%" unmute || apply_code="$?"
  if [[ "${apply_code}" -ne 0 ]]; then
    printf 'The repair command failed (amixer exited %d); the recorded state is kept at %s — undo can restore it.\n' "${apply_code}" "${STATE_FILE}" >&2
    exit 1
  fi

  # Verify by re-reading the mixer; on mismatch re-apply the recorded state.
  local verify_out="" verify_code=0
  verify_out="$(amixer 2>/dev/null)" || verify_code="$?"
  if [[ "${verify_code}" -ne 0 ]]; then
    printf 'The repair could not be verified (amixer failed on re-read); the recorded state is kept at %s for undo.\n' "${STATE_FILE}" >&2
    exit 1
  fi
  parse_master_state "${verify_out}"
  if [[ "${_MASTER_FOUND}" -ne 1 || "${_MASTER_MUTED}" -ne 0 || "${_MASTER_VOLUME}" -ne "${target_volume}" ]]; then
    restore_volume "${rec_volume}" || true
    restore_mute "${rec_muted}" || true
    printf 'The repair did not take (the mixer re-check did not match); the recorded state was re-applied and the record is kept at %s.\n' "${STATE_FILE}" >&2
    exit 1
  fi

  printf 'Repaired: Master is now unmuted at %s%%.\n' "${target_volume}"
  printf 'The previous state (%s, %s%%) is recorded; [u]ndo in the menu restores it exactly.\n' "${state_word}" "${rec_volume}"
  exit 0
}

undo() {
  if [[ ! -f "${STATE_FILE}" ]]; then
    printf 'Nothing to undo.\n'
    printf 'Note: the diagnosis steps and verdicts are read-only and never needed undoing.\n'
    return 0
  fi
  if ! command -v amixer >/dev/null 2>&1; then
    printf 'Cannot undo: amixer is missing, so the recorded Master state cannot be re-applied.\n' >&2
    return 1
  fi

  local rec_muted="" rec_volume="" record_line
  while IFS= read -r record_line || [[ -n "${record_line}" ]]; do
    case "${record_line}" in
      muted=*)
        rec_muted="${record_line#muted=}"
        ;;
      volume=*)
        rec_volume="${record_line#volume=}"
        ;;
    esac
  done < "${STATE_FILE}"

  if [[ "${rec_muted}" != "0" && "${rec_muted}" != "1" ]]; then
    printf 'Cannot undo: the record at %s is unreadable; refusing to guess.\n' "${STATE_FILE}" >&2
    return 1
  fi
  if [[ ! "${rec_volume}" =~ ^[0-9]+$ ]]; then
    printf 'Cannot undo: the record at %s is unreadable; refusing to guess.\n' "${STATE_FILE}" >&2
    return 1
  fi
  rec_volume=$((10#${rec_volume}))

  local undo_code=0
  restore_volume "${rec_volume}" || undo_code="$?"
  restore_mute "${rec_muted}" || undo_code="$?"
  if [[ "${undo_code}" -ne 0 ]]; then
    printf 'Could not restore the Master state (amixer failed); the record is kept at %s.\n' "${STATE_FILE}" >&2
    return 1
  fi

  rm -f "${STATE_FILE}"
  rmdir "${STATE_DIR}" 2>/dev/null || true

  local state_word="unmuted"
  if [[ "${rec_muted}" == "1" ]]; then
    state_word="muted"
  fi
  printf 'Restored: Master is back to %s, %s%%.\n' "${state_word}" "${rec_volume}"
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
