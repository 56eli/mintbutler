#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
case "${action}" in
  describe)
    printf 'Alpha fixture does nothing safely.\n'
    ;;
  plan)
    printf 'Plan for alpha-fixture:\n'
    printf '1. Do nothing\n'
    printf '2. Report done\n'
    ;;
  dry-run)
    printf 'Plan for alpha-fixture:\n'
    printf '1. Do nothing\n'
    printf 'Commands:\n'
    printf '  echo hello\n'
    ;;
  run)
    printf 'Ran alpha-fixture (did nothing).\n'
    ;;
  undo)
    printf 'Undid alpha-fixture (did nothing).\n'
    ;;
  *)
    printf 'Unknown action: %s\n' "${action}" >&2
    exit 1
    ;;
esac
