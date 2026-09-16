#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
case "${action}" in
  describe)
    printf 'Broken fixture should never run.\n'
    ;;
  plan)
    printf 'Plan for broken-fixture (should never run).\n'
    ;;
  dry-run)
    printf 'Dry-run for broken-fixture (should never run).\n'
    ;;
  run)
    printf 'Broken fixture should never run.\n' >&2
    exit 1
    ;;
  *)
    printf 'Unknown action: %s\n' "${action}" >&2
    exit 1
    ;;
esac
