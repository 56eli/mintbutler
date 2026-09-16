#!/usr/bin/env bash
set -euo pipefail

# lib/manifest.sh — strict parser for the MODULE_SPEC §2 manifest subset.
# Supports EXACTLY: title, description (>- folded), risk, undo, needs,
# order (optional), platform (optional), asks (optional). Unknown field or unparseable
# value => broken (return 1, MANIFEST_BROKEN=1), never crashes.

MANIFEST_TITLE=""
MANIFEST_DESCRIPTION=""
MANIFEST_RISK=""
MANIFEST_UNDO=""
MANIFEST_NEEDS="[]"
MANIFEST_ORDER=""
MANIFEST_PLATFORM="mint-22"
MANIFEST_ASKS=""
MANIFEST_BROKEN="0"
MANIFEST_ERROR=""
export MANIFEST_ASKS

_manifest_trim() {
  local s="${1:-}"
  # shellcheck disable=SC2295
  s="${s#"${s%%[![:space:]]*}"}"
  # shellcheck disable=SC2295
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

_manifest_strip_comment() {
  local s="${1:-}"
  printf '%s' "${s}" | sed 's/[[:space:]]#.*$//'
}

_manifest_valid_needs() {
  local value="${1:-}"
  local inner trimmed part
  local -a parts
  if [[ "${value}" != "["*"]" ]]; then
    return 1
  fi
  # Must be exactly [...] with nothing outside (already trimmed).
  if [[ "${value}" != "["* ]]; then
    return 1
  fi
  if [[ "${value}" != *"]" ]]; then
    return 1
  fi
  inner="$(printf '%s' "${value}" | sed 's/^\[//; s/\]$//')"
  trimmed="$(_manifest_trim "${inner}")"
  if [[ -z "${trimmed}" ]]; then
    return 0
  fi
  IFS=',' read -r -a parts <<< "${inner}" || true
  for part in "${parts[@]}"; do
    part="$(_manifest_trim "${part}")"
    if [[ -z "${part}" ]]; then
      return 1
    fi
    if [[ ! "${part}" =~ ^[A-Za-z0-9.+_:-]+$ ]]; then
      return 1
    fi
  done
  return 0
}

manifest_parse() {
  local file="${1:-}"
  MANIFEST_TITLE=""
  MANIFEST_DESCRIPTION=""
  MANIFEST_RISK=""
  MANIFEST_UNDO=""
  MANIFEST_NEEDS="[]"
  MANIFEST_ORDER=""
  MANIFEST_PLATFORM="mint-22"
  MANIFEST_ASKS=""
  MANIFEST_BROKEN="0"
  MANIFEST_ERROR=""

  if [[ -z "${file}" ]]; then
    MANIFEST_BROKEN="1"
    MANIFEST_ERROR="missing manifest path"
    return 1
  fi
  if [[ ! -f "${file}" ]]; then
    MANIFEST_BROKEN="1"
    MANIFEST_ERROR="missing manifest"
    return 1
  fi
  if [[ ! -r "${file}" ]]; then
    MANIFEST_BROKEN="1"
    MANIFEST_ERROR="unreadable manifest"
    return 1
  fi

  local title="" risk="" undo="" needs="" order="" platform="" asks="" desc_text=""
  local seen_title="0" seen_desc="0" seen_risk="0" seen_undo="0"
  local seen_needs="0" seen_order="0" seen_platform="0" seen_asks="0"
  local in_desc="0"
  local broken="0" err=""
  local line trimmed key raw_value value stripped
  local cr
  cr=$'\r'

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%"$cr"}"
    if [[ "${in_desc}" == "1" ]]; then
      trimmed="$(_manifest_trim "${line}")"
      if [[ -z "${trimmed}" ]]; then
        continue
      fi
      if [[ "${line}" == [[:space:]]* ]]; then
        trimmed="$(_manifest_trim "${line}")"
        if [[ -z "${desc_text}" ]]; then
          desc_text="${trimmed}"
        else
          desc_text="${desc_text} ${trimmed}"
        fi
        continue
      else
        in_desc="0"
      fi
    fi

    trimmed="$(_manifest_trim "${line}")"
    if [[ -z "${trimmed}" ]]; then
      continue
    fi
    if [[ "${trimmed}" == "#"* ]]; then
      continue
    fi
    if [[ "${line}" == [[:space:]]* ]]; then
      broken="1"
      err="unexpected indented line"
      break
    fi
    if [[ "${line}" != *":"* ]]; then
      broken="1"
      err="line without colon"
      break
    fi
    key="${line%%:*}"
    raw_value="${line#*:}"
    key="$(_manifest_trim "${key}")"
    if [[ -z "${key}" ]]; then
      broken="1"
      err="empty key"
      break
    fi
    if [[ "${key}" == *" "* ]] || [[ "${key}" == *$'\t'* ]]; then
      broken="1"
      err="invalid key"
      break
    fi
    case "${key}" in
      title|description|risk|undo|needs|order|platform|asks)
        ;;
      *)
        broken="1"
        err="unknown field: ${key}"
        break
        ;;
    esac

    if [[ "${key}" == "description" ]]; then
      if [[ "${seen_desc}" == "1" ]]; then
        broken="1"
        err="duplicate description"
        break
      fi
      stripped="$(_manifest_strip_comment "${raw_value}")"
      value="$(_manifest_trim "${stripped}")"
      if [[ "${value}" != ">-" ]]; then
        broken="1"
        err="description must use >-"
        break
      fi
      seen_desc="1"
      in_desc="1"
      desc_text=""
      continue
    fi

    stripped="$(_manifest_strip_comment "${raw_value}")"
    value="$(_manifest_trim "${stripped}")"

    case "${key}" in
      title)
        if [[ "${seen_title}" == "1" ]]; then
          broken="1"
          err="duplicate title"
          break
        fi
        if [[ -z "${value}" ]]; then
          broken="1"
          err="empty title"
          break
        fi
        title="${value}"
        seen_title="1"
        ;;
      risk)
        if [[ "${seen_risk}" == "1" ]]; then
          broken="1"
          err="duplicate risk"
          break
        fi
        if [[ "${value}" != "low" && "${value}" != "elevated" ]]; then
          broken="1"
          err="invalid risk"
          break
        fi
        risk="${value}"
        seen_risk="1"
        ;;
      undo)
        if [[ "${seen_undo}" == "1" ]]; then
          broken="1"
          err="duplicate undo"
          break
        fi
        if [[ "${value}" != "true" && "${value}" != "false" ]]; then
          broken="1"
          err="invalid undo"
          break
        fi
        undo="${value}"
        seen_undo="1"
        ;;
      needs)
        if [[ "${seen_needs}" == "1" ]]; then
          broken="1"
          err="duplicate needs"
          break
        fi
        if ! _manifest_valid_needs "${value}"; then
          broken="1"
          err="invalid needs"
          break
        fi
        needs="${value}"
        seen_needs="1"
        ;;
      order)
        if [[ "${seen_order}" == "1" ]]; then
          broken="1"
          err="duplicate order"
          break
        fi
        if [[ ! "${value}" =~ ^-?[0-9]+$ ]]; then
          broken="1"
          err="invalid order"
          break
        fi
        order="${value}"
        seen_order="1"
        ;;
      platform)
        if [[ "${seen_platform}" == "1" ]]; then
          broken="1"
          err="duplicate platform"
          break
        fi
        if [[ -z "${value}" ]]; then
          broken="1"
          err="empty platform"
          break
        fi
        platform="${value}"
        seen_platform="1"
        ;;
      asks)
        if [[ "${seen_asks}" == "1" ]]; then
          broken="1"
          err="duplicate asks"
          break
        fi
        if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
          broken="1"
          err="invalid asks"
          break
        fi
        asks="${value}"
        seen_asks="1"
        ;;
    esac
  done < "${file}"

  if [[ "${broken}" == "1" ]]; then
    MANIFEST_BROKEN="1"
    MANIFEST_ERROR="${err}"
    return 1
  fi
  if [[ "${seen_title}" == "0" ]]; then
    MANIFEST_BROKEN="1"
    MANIFEST_ERROR="missing title"
    return 1
  fi
  if [[ "${seen_desc}" == "0" ]]; then
    MANIFEST_BROKEN="1"
    MANIFEST_ERROR="missing description"
    return 1
  fi
  if [[ -z "${desc_text}" ]]; then
    MANIFEST_BROKEN="1"
    MANIFEST_ERROR="empty description"
    return 1
  fi
  if [[ "${seen_risk}" == "0" ]]; then
    MANIFEST_BROKEN="1"
    MANIFEST_ERROR="missing risk"
    return 1
  fi
  if [[ "${seen_undo}" == "0" ]]; then
    MANIFEST_BROKEN="1"
    MANIFEST_ERROR="missing undo"
    return 1
  fi

  MANIFEST_TITLE="${title}"
  MANIFEST_DESCRIPTION="${desc_text}"
  MANIFEST_RISK="${risk}"
  MANIFEST_UNDO="${undo}"
  if [[ "${seen_needs}" == "1" ]]; then
    MANIFEST_NEEDS="${needs}"
  else
    MANIFEST_NEEDS="[]"
  fi
  if [[ "${seen_order}" == "1" ]]; then
    MANIFEST_ORDER="${order}"
  else
    MANIFEST_ORDER=""
  fi
  if [[ "${seen_platform}" == "1" ]]; then
    MANIFEST_PLATFORM="${platform}"
  else
    MANIFEST_PLATFORM="mint-22"
  fi
  if [[ "${seen_asks}" == "1" ]]; then
    MANIFEST_ASKS="${asks}"
  else
    MANIFEST_ASKS=""
  fi
  export MANIFEST_ASKS
  MANIFEST_BROKEN="0"
  MANIFEST_ERROR=""
  return 0
}
