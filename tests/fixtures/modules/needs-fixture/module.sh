#!/usr/bin/env bash
set -euo pipefail

# needs-fixture — a module whose manifest declares an unsatisfiable need, so
# the test suite can prove menu-side needs enforcement (MODULE_SPEC §2,
# MB-003/MB-005). It is honest everywhere: its own run reports the missing
# need and changes nothing. The REFUSAL is the menu's job, not this fixture's.

NEED="mb-test-need-does-not-exist"

action="${1:-}"
case "${action}" in
  describe)
    printf 'Needs fixture (test only): declares a need that never exists.\n'
    ;;
  plan)
    printf 'Plan for needs-fixture:\n'
    printf '1. Require %s (declared in needs:; absent by construction).\n' "${NEED}"
    printf '2. The menu refuses to launch this module while the need is missing.\n'
    ;;
  dry-run)
    printf 'Plan for needs-fixture:\n'
    printf '1. Require %s (declared in needs:; absent by construction).\n' "${NEED}"
    printf '2. The menu refuses to launch this module while the need is missing.\n'
    printf 'Commands: none — this module never launches on a host without the need.\n'
    ;;
  run)
    printf 'needs-fixture: %s is not installed; the menu should have refused to launch this module. Nothing was done.\n' "${NEED}"
    ;;
  *)
    printf 'Unknown action: %s\n' "${action}" >&2
    exit 1
    ;;
esac
