#!/usr/bin/env bash
set -euo pipefail

# modules/system-report-pack/module.sh
# A strictly read-only system report for Linux Mint 22: one menu entry
# prints a clean, copy-pasteable snapshot of this machine — distro,
# kernel, hostname, uptime, CPU model and load, memory, disk usage of
# /, and session type — gathered ONLY from the tools a stock Mint ships
# (uname, uptime, free, df, the optional lscpu, /etc/os-release, and the
# session environment). It installs NOTHING — never inxi, never
# anything — and writes nothing anywhere: no state file, no config, no
# network, no elevation, no questions. There is no undo action because
# there is nothing to undo: nothing is ever changed. The module sources
# no shared helper at all — no elevation helper, no question helper.
#
# Report ladder (run order):
#   1. preflight: df, free, uname, uptime exist (all ship on Mint); else
#      ONE plain stderr line, exit 1, nothing printed to stdout
#   2. System:  hostname (uname -n), distro pretty-name (/etc/os-release
#               PRETTY_NAME), kernel (uname -r), architecture (uname -m),
#               uptime (uptime -p)
#   3. CPU:     model + count (lscpu — OPTIONAL; degrades to
#               (unavailable) when missing or failing) + load average
#               (uptime)
#   4. Memory:  free -h, the Mem line (total/used/available)
#   5. Disk /:  df -h /, the single data line (size/used/avail/use%)
#   6. Session: XDG_SESSION_TYPE / XDG_CURRENT_DESKTOP from the
#               environment ((not set) when absent)
#
# Honest degradation: any single section whose gather fails or times out
# renders its header with (unavailable) and the report still exits 0 —
# a report with gaps beats no report. The four needs tools are the only
# hard gate; they are never installed or substituted by this module.
#
# Test seam: the os-release path is read from MINTBUTLER_OS_RELEASE_FILE
# (default /etc/os-release) so the harness can point the gather at a
# canned file; every other gather is stubbable via PATH. The seam is a
# read — the module never writes that file or any other.

# os-release file the distro pretty-name is read from. Overridable by the
# test harness; the default is the real system file (read, never written).
OS_RELEASE_FILE="${MINTBUTLER_OS_RELEASE_FILE:-/etc/os-release}"

# with_timeout SECS CMD [ARGS...] — run CMD under a timeout wrapper when
# the timeout binary is on PATH; passes through the command's stdout and
# exit code. Without it, the command runs directly.
with_timeout() {
  local secs="${1:-10}"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "${secs}" "$@"
  else
    "$@"
  fi
}

# trim_ws S — strip leading/trailing whitespace using builtins only.
trim_ws() {
  local s="${1:-}"
  # shellcheck disable=SC2295
  s="${s#"${s%%[![:space:]]*}"}"
  # shellcheck disable=SC2295
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

# read_pretty_name FILE — print the PRETTY_NAME value (surrounding quotes
# stripped) from an os-release file; prints nothing when the file is
# missing/unreadable or carries no PRETTY_NAME line. Read-only.
read_pretty_name() {
  local file="${1:-}"
  local line value=""
  if [[ ! -r "${file}" ]]; then
    return 0
  fi
  while IFS= read -r line || [[ -n "${line}" ]]; do
    case "${line}" in
      PRETTY_NAME=*)
        value="${line#PRETTY_NAME=}"
        ;;
    esac
  done < "${file}"
  value="${value%\"}"
  value="${value#\"}"
  printf '%s' "$(trim_ws "${value}")"
}

# parse_cpu_lscpu TEXT — print "<model> (<n> CPU(s))" from lscpu output
# when both a model line (Model name:, falling back to Model:) and a
# CPU(s): line parse; the model alone when only it parses; nothing
# otherwise.
parse_cpu_lscpu() {
  local text="${1:-}"
  local line model="" count=""
  while IFS= read -r line || [[ -n "${line}" ]]; do
    case "${line}" in
      "Model name:"*)
        model="$(trim_ws "${line#Model name:}")"
        ;;
      "Model:"*)
        if [[ -z "${model}" ]]; then
          model="$(trim_ws "${line#Model:}")"
        fi
        ;;
      "CPU(s):"*)
        if [[ -z "${count}" ]]; then
          count="$(trim_ws "${line#CPU(s):}")"
        fi
        ;;
    esac
  done <<< "${text}"
  if [[ -n "${model}" && -n "${count}" ]]; then
    printf '%s (%s CPU(s))' "${model}" "${count}"
  elif [[ -n "${model}" ]]; then
    printf '%s' "${model}"
  fi
  return 0
}

# parse_mem_line TEXT — print "total X | used Y | available Z" from the
# Mem: line of `free -h` output; prints nothing when that line is absent
# or too short to trust.
parse_mem_line() {
  local text="${1:-}"
  local line
  local -a words=()
  while IFS= read -r line || [[ -n "${line}" ]]; do
    case "${line}" in
      "Mem:"*)
        read -r -a words <<< "${line}"
        break
        ;;
    esac
  done <<< "${text}"
  if [[ "${#words[@]}" -ge 4 ]]; then
    printf 'total %s | used %s | available %s' "${words[1]}" "${words[2]}" "${words[-1]}"
  fi
  return 0
}

# parse_df_line TEXT — print "size X | used Y | avail Z | use W" from the
# single data line of `df -h /` output (the first non-empty line after
# the header); prints nothing when that line is absent or too short to
# trust.
parse_df_line() {
  local text="${1:-}"
  local line first_seen=0
  local -a words=()
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${first_seen}" -eq 0 ]]; then
      first_seen=1
      continue
    fi
    if [[ -z "$(trim_ws "${line}")" ]]; then
      continue
    fi
    read -r -a words <<< "${line}"
    break
  done <<< "${text}"
  if [[ "${#words[@]}" -ge 5 ]]; then
    printf 'size %s | used %s | avail %s | use %s' "${words[1]}" "${words[2]}" "${words[3]}" "${words[4]}"
  fi
  return 0
}

# parse_load_average TEXT — print the load average triple from a plain
# `uptime` line (the text after "load average:"); prints nothing when no
# line carries it.
parse_load_average() {
  local text="${1:-}"
  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    case "${line}" in
      *"load average:"*)
        printf '%s' "$(trim_ws "${line#*load average:}")"
        return 0
        ;;
    esac
  done <<< "${text}"
  return 0
}

describe() {
  printf 'Read-only system report: prints a clean, copy-pasteable snapshot — distro, kernel, hostname, uptime, CPU model and load, memory, disk usage of /, and session type — from stock Mint tools only. Installs nothing, never inxi, writes nothing; there is nothing to undo because nothing is ever changed.\n'
}

plan() {
  printf 'Plan for system-report-pack:\n'
  printf '1. Preflight: df, free, uname and uptime must exist (all ship on Mint); else stop.\n'
  printf '2. Read the machine — nothing else:\n'
  printf '   - hostname, kernel, architecture with: uname -n / -r / -m\n'
  printf '   - distro name with: /etc/os-release (the PRETTY_NAME line)\n'
  printf '   - uptime with: uptime -p, and the load average with: uptime\n'
  printf '   - CPU model and count with: lscpu (optional — shown as (unavailable) when missing)\n'
  printf '   - memory with: free -h (the Mem line)\n'
  printf '   - disk usage of / with: df -h / (the single data line)\n'
  printf '   - session type with: XDG_SESSION_TYPE / XDG_CURRENT_DESKTOP from the environment\n'
  printf '3. Print the sections in order — header, System, CPU, Memory, Disk /, Session — to\n'
  printf '   stdout as one clean screen of at most 23 lines. Any section that fails or times out\n'
  printf '   renders (unavailable); the report still exits 0.\n'
  printf 'Nothing is installed — never inxi, never anything — and the report writes nothing\n'
  printf 'anywhere: no state, no config, no network, no elevation, no questions. There is no\n'
  printf 'undo because nothing is ever changed.\n'
}

dry_run() {
  plan
}

run() {
  # (i) preflight — one plain honest line when any needs tool is missing;
  # the four tools ship on Mint and are never installed by this module.
  local missing="" tool
  for tool in df free uname uptime; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      if [[ -z "${missing}" ]]; then
        missing="${tool}"
      else
        missing="${missing}, ${tool}"
      fi
    fi
  done
  if [[ -n "${missing}" ]]; then
    printf 'Report tools missing: %s — all four report tools (df, free, uname, uptime) ship on Mint; nothing was installed and nothing was changed.\n' "${missing}" >&2
    exit 1
  fi

  printf 'System report pack — read-only snapshot of this machine, generated by mintbutler\n'

  # (ii) System: hostname, distro, kernel, architecture, uptime — all
  # five gathers must answer; otherwise the section degrades honestly.
  local hostname_v="" distro_v="" kernel_v="" arch_v="" up_p_v=""
  local sys_bad=0
  hostname_v="$(with_timeout 10 uname -n 2>/dev/null)" || sys_bad=1
  kernel_v="$(with_timeout 10 uname -r 2>/dev/null)" || sys_bad=1
  arch_v="$(with_timeout 10 uname -m 2>/dev/null)" || sys_bad=1
  up_p_v="$(with_timeout 10 uptime -p 2>/dev/null)" || sys_bad=1
  distro_v="$(read_pretty_name "${OS_RELEASE_FILE}")"
  if [[ -z "${hostname_v}" || -z "${distro_v}" || -z "${kernel_v}" || -z "${arch_v}" || -z "${up_p_v}" ]]; then
    sys_bad=1
  fi
  if [[ "${sys_bad}" -eq 1 ]]; then
    printf 'System:  (unavailable)\n'
  else
    printf 'System:  %s | %s | %s | %s | %s\n' "${hostname_v}" "${distro_v}" "${kernel_v}" "${arch_v}" "${up_p_v}"
  fi

  # (iii) CPU: model + count from the OPTIONAL lscpu, load from uptime.
  # Each part degrades to (unavailable) independently; both missing
  # degrades the whole section.
  local cpu_v="" load_v="" lscpu_out="" up_out=""
  if command -v lscpu >/dev/null 2>&1; then
    lscpu_out="$(with_timeout 10 lscpu 2>/dev/null)" || lscpu_out=""
    if [[ -n "${lscpu_out}" ]]; then
      cpu_v="$(parse_cpu_lscpu "${lscpu_out}")"
    fi
  fi
  up_out="$(with_timeout 10 uptime 2>/dev/null)" || up_out=""
  load_v="$(parse_load_average "${up_out}")"
  if [[ -z "${cpu_v}" && -z "${load_v}" ]]; then
    printf 'CPU:     (unavailable)\n'
  else
    if [[ -z "${cpu_v}" ]]; then
      cpu_v="(unavailable)"
    fi
    if [[ -z "${load_v}" ]]; then
      load_v="(unavailable)"
    fi
    printf 'CPU:     %s | load %s\n' "${cpu_v}" "${load_v}"
  fi

  # (iv) Memory: free -h, the Mem line (total/used/available).
  local mem_out="" mem_v=""
  mem_out="$(with_timeout 10 free -h 2>/dev/null)" || mem_out=""
  mem_v="$(parse_mem_line "${mem_out}")"
  if [[ -z "${mem_v}" ]]; then
    printf 'Memory:  (unavailable)\n'
  else
    printf 'Memory:  %s\n' "${mem_v}"
  fi

  # (v) Disk /: df -h /, the single data line (size/used/avail/use%).
  local df_out="" disk_v=""
  df_out="$(with_timeout 10 df -h / 2>/dev/null)" || df_out=""
  disk_v="$(parse_df_line "${df_out}")"
  if [[ -z "${disk_v}" ]]; then
    printf 'Disk /:  (unavailable)\n'
  else
    printf 'Disk /:  %s\n' "${disk_v}"
  fi

  # (vi) Session: the environment only — (not set) when a variable is
  # absent (an honest answer, not a failure).
  local sess_type="${XDG_SESSION_TYPE:-}" sess_desktop="${XDG_CURRENT_DESKTOP:-}"
  if [[ -z "${sess_type}" ]]; then
    sess_type="(not set)"
  fi
  if [[ -z "${sess_desktop}" ]]; then
    sess_desktop="(not set)"
  fi
  printf 'Session: type %s | desktop %s\n' "${sess_type}" "${sess_desktop}"

  printf 'No changes were made — nothing was installed, nothing was written, nothing was asked.\n'
  exit 0
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
