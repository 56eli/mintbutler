#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
case "${action}" in
  describe)
    printf 'Gamma fixture does nothing safely.\n'
    ;;
  plan)
    printf 'Plan for gamma-fixture:\n'
    printf '1. Do nothing\n'
    printf '2. Report done\n'
    ;;
  dry-run)
    printf 'Plan for gamma-fixture:\n'
    printf '1. Do nothing\n'
    printf 'Commands:\n'
    printf '  echo hello\n'
    ;;
  run)
    printf 'Ran gamma-fixture (did nothing).\n'
    ;;
  undo)
    printf 'Undid gamma-fixture (did nothing).\n'
    ;;
  *)
    printf 'Unknown action: %s\n' "${action}" >&2
    exit 1
    ;;
esac
