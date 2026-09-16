#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
case "${action}" in
  describe)
    printf 'Beta fixture does nothing safely.\n'
    ;;
  plan)
    printf 'Plan for beta-fixture:\n'
    printf '1. Do nothing\n'
    printf '2. Report done\n'
    ;;
  dry-run)
    printf 'Plan for beta-fixture:\n'
    printf '1. Do nothing\n'
    printf 'Commands:\n'
    printf '  echo hello\n'
    ;;
  run)
    printf 'Ran beta-fixture (did nothing).\n'
    ;;
  *)
    printf 'Unknown action: %s\n' "${action}" >&2
    exit 1
    ;;
esac
