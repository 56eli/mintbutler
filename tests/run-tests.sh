#!/usr/bin/env bash
set -euo pipefail

# tests/run-tests.sh — zero-dependency harness.
# Copies butler + lib/ + fixture modules into a temp dir and runs
# the real script there. No production hooks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TMPBASE="$(mktemp -d)"
trap 'rm -rf "${TMPBASE}"' EXIT

STAGE="${TMPBASE}/stage"
mkdir -p "${STAGE}"
cp -a "${REPO_ROOT}/butler" "${STAGE}/"
cp -a "${REPO_ROOT}/lib" "${STAGE}/"
mkdir -p "${STAGE}/modules"
cp -a "${REPO_ROOT}/tests/fixtures/modules/." "${STAGE}/modules/"
chmod +x "${STAGE}/butler"

PASS_COUNT="0"
FAIL_COUNT="0"

pass() {
  printf 'PASS: %s\n' "${1:-}"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf 'FAIL: %s\n' "${1:-}" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

printf 'Staging in %s\n' "${STAGE}"

# Stage (a): --list order + broken flag.
printf 'Stage a: --list order and broken flag\n'
output_a=""
code_a="0"
output_a="$(cd "${STAGE}" && ./butler --list 2>&1)" || code_a="$?"
if [[ "${code_a}" -ne 0 ]]; then
  fail "--list exits 0 (got ${code_a})"
else
  beta_line="$(printf '%s\n' "${output_a}" | grep -n "beta-fixture" | head -n 1 | cut -d: -f1 || true)"
  alpha_line="$(printf '%s\n' "${output_a}" | grep -n "alpha-fixture" | head -n 1 | cut -d: -f1 || true)"
  gamma_line="$(printf '%s\n' "${output_a}" | grep -n "gamma-fixture" | head -n 1 | cut -d: -f1 || true)"
  if [[ -z "${beta_line}" || -z "${alpha_line}" || -z "${gamma_line}" ]]; then
    fail "--list contains beta, alpha, gamma slugs"
  elif [[ "${beta_line}" -lt "${alpha_line}" && "${alpha_line}" -lt "${gamma_line}" ]]; then
    pass "--list order beta, alpha, gamma"
  else
    fail "--list order is beta, alpha, gamma (got ${beta_line},${alpha_line},${gamma_line})"
  fi
  if printf '%s\n' "${output_a}" | grep "broken-fixture" | grep -qi "broken"; then
    if printf '%s\n' "${output_a}" | grep "broken-fixture" | grep -qi "excluded"; then
      pass "--list flags broken-fixture as broken/excluded"
    else
      fail "--list broken line missing excluded"
    fi
  else
    fail "--list flags broken-fixture as broken"
  fi
fi

# Stage (b): --run dry-run prints plan, no writes.
printf 'Stage b: --run dry-run no writes\n'
FAKEHOME="${TMPBASE}/home"
mkdir -p "${FAKEHOME}/.local/share"
printf 'sentinel\n' > "${FAKEHOME}/sentinel.txt"
printf 'data\n' > "${FAKEHOME}/.local/share/data.txt"
cp -a "${FAKEHOME}" "${TMPBASE}/home-before"
output_b=""
code_b="0"
output_b="$(cd "${STAGE}" && HOME="${FAKEHOME}" ./butler --run alpha-fixture --dry-run 2>&1)" || code_b="$?"
if [[ "${code_b}" -ne 0 ]]; then
  fail "--run alpha-fixture --dry-run exits 0 (got ${code_b})"
elif printf '%s\n' "${output_b}" | grep -q "Plan for alpha-fixture"; then
  pass "--run dry-run prints plan"
else
  fail "--run dry-run prints plan"
fi
if diff -r "${FAKEHOME}" "${TMPBASE}/home-before" >/dev/null 2>&1; then
  pass "--run dry-run writes nothing to HOME"
else
  fail "--run dry-run modified HOME"
fi

# Stage (c): piped menu has no ANSI escapes.
printf 'Stage c: piped output has no ANSI\n'
menu_out="${TMPBASE}/menu.out"
printf 'q\n' | (cd "${STAGE}" && ./butler) > "${menu_out}" 2>&1 || true
if grep -q $'\033' "${menu_out}"; then
  fail "piped menu output contains no ANSI"
else
  pass "piped menu output contains no ANSI"
fi

# Stage (d): printf q exits 0.
printf 'Stage d: quit exits 0\n'
code_d="0"
printf 'q\n' | (cd "${STAGE}" && ./butler) >/dev/null 2>&1 || code_d="$?"
if [[ "${code_d}" -ne 0 ]]; then
  fail "printf q exits 0 (got ${code_d})"
else
  pass "printf q exits 0"
fi

# Stage (e): --scan missing modulelint.
printf 'Stage e: --scan missing\n'
output_e=""
code_e="0"
output_e="$(cd "${STAGE}" && ./butler --scan 2>&1)" || code_e="$?"
if [[ "${code_e}" -ne 1 ]]; then
  fail "--scan exits 1 (got ${code_e})"
elif printf '%s\n' "${output_e}" | grep -q "modulelint not found at bin/modulelint"; then
  pass "--scan missing line"
else
  fail "--scan missing line"
fi

# Stage (f): --help mentions flags.
printf 'Stage f: --help flags\n'
output_f=""
code_f="0"
output_f="$(cd "${STAGE}" && ./butler --help 2>&1)" || code_f="$?"
if [[ "${code_f}" -ne 0 ]]; then
  fail "--help exits 0 (got ${code_f})"
else
  missing=""
  for flag in --list --run --scan --help; do
    if ! printf '%s\n' "${output_f}" | grep -q -- "${flag}"; then
      missing="${missing} ${flag}"
    fi
  done
  if [[ -n "${missing}" ]]; then
    fail "--help mentions all flags (missing:${missing})"
  else
    pass "--help mentions all flags"
  fi
  if printf '%s\n' "${output_f}" | grep -q -- "--dry-run"; then
    pass "--help mentions --dry-run"
  else
    fail "--help mentions --dry-run"
  fi
fi

# Lint stages (g)–(j) in a separate stage directory with bin/ present.
LINT_STAGE="${TMPBASE}/lint-stage"
mkdir -p "${LINT_STAGE}"
cp -a "${REPO_ROOT}/butler" "${LINT_STAGE}/"
cp -a "${REPO_ROOT}/lib" "${LINT_STAGE}/"
cp -a "${REPO_ROOT}/bin" "${LINT_STAGE}/"
mkdir -p "${LINT_STAGE}/modules"
cp -a "${REPO_ROOT}/tests/fixtures/modules/." "${LINT_STAGE}/modules/"
chmod +x "${LINT_STAGE}/butler"
chmod +x "${LINT_STAGE}/bin/modulelint"

# Stage (g): bin/modulelint over all fixtures.
printf 'Stage g: modulelint all fixtures\n'
output_g=""
code_g="0"
output_g="$(cd "${LINT_STAGE}" && bin/modulelint 2>&1)" || code_g="$?"
if [[ "${code_g}" -ne 1 ]]; then
  fail "bin/modulelint exits 1 on fixtures (got ${code_g})"
else
  pass "bin/modulelint exits 1 on fixtures"
fi
for slug in alpha-fixture beta-fixture gamma-fixture; do
  if printf '%s\n' "${output_g}" | grep -q "PASS ${slug}"; then
    pass "bin/modulelint contains PASS ${slug}"
  else
    fail "bin/modulelint contains PASS ${slug}"
  fi
done
if printf '%s\n' "${output_g}" | grep -q "FAIL broken-fixture"; then
  pass "bin/modulelint contains FAIL broken-fixture"
else
  fail "bin/modulelint contains FAIL broken-fixture"
fi

# Stage (h): bin/modulelint alpha-fixture.
printf 'Stage h: modulelint alpha-fixture\n'
output_h=""
code_h="0"
output_h="$(cd "${LINT_STAGE}" && bin/modulelint alpha-fixture 2>&1)" || code_h="$?"
if [[ "${code_h}" -ne 0 ]]; then
  fail "bin/modulelint alpha-fixture exits 0 (got ${code_h})"
else
  pass "bin/modulelint alpha-fixture exits 0"
fi
if printf '%s\n' "${output_h}" | grep -q "PASS alpha-fixture"; then
  pass "bin/modulelint alpha-fixture contains PASS alpha-fixture"
else
  fail "bin/modulelint alpha-fixture contains PASS alpha-fixture"
fi

# Stage (i): ./butler --scan in the lint stage.
printf 'Stage i: butler --scan in lint stage\n'
output_i=""
code_i="0"
output_i="$(cd "${LINT_STAGE}" && ./butler --scan 2>&1)" || code_i="$?"
if [[ "${code_i}" -ne 1 ]]; then
  fail "butler --scan exits 1 in lint stage (got ${code_i})"
else
  pass "butler --scan exits 1 in lint stage"
fi
if printf '%s\n' "${output_i}" | grep -q "FAIL broken-fixture"; then
  pass "butler --scan output contains FAIL broken-fixture"
else
  fail "butler --scan output contains FAIL broken-fixture"
fi

# Stage (j): modulelint containment (stage directory and real HOME untouched).
printf 'Stage j: modulelint containment\n'
FAKE_REAL_HOME="${TMPBASE}/real-home"
FAKE_REAL_HOME_BEFORE="${TMPBASE}/real-home-before"
mkdir -p "${FAKE_REAL_HOME}"
printf 'real-home-sentinel\n' > "${FAKE_REAL_HOME}/sentinel.txt"
cp -a "${FAKE_REAL_HOME}" "${FAKE_REAL_HOME_BEFORE}"

LINT_STAGE_BEFORE="${TMPBASE}/lint-stage-before"
cp -a "${LINT_STAGE}" "${LINT_STAGE_BEFORE}"

(cd "${LINT_STAGE}" && HOME="${FAKE_REAL_HOME}" bin/modulelint >/dev/null 2>&1) || true

if diff -r "${LINT_STAGE}" "${LINT_STAGE_BEFORE}" >/dev/null 2>&1; then
  pass "modulelint leaves stage directory untouched"
else
  fail "modulelint modified stage directory"
fi

if diff -r "${FAKE_REAL_HOME}" "${FAKE_REAL_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "modulelint leaves real HOME untouched"
else
  fail "modulelint modified real HOME"
fi

# Stage (k): butler --scan in the real repo exits 0 and prints PASS desktop-shortcut-creator.
printf 'Stage k: butler --scan in real repo\n'
output_k=""
code_k="0"
output_k="$(cd "${REPO_ROOT}" && ./butler --scan 2>&1)" || code_k="$?"
if [[ "${code_k}" -ne 0 ]]; then
  fail "butler --scan in real repo exits 0 (got ${code_k})"
else
  pass "butler --scan in real repo exits 0"
fi
if printf '%s\n' "${output_k}" | grep -q "PASS desktop-shortcut-creator"; then
  pass "butler --scan output contains PASS desktop-shortcut-creator"
else
  fail "butler --scan output contains PASS desktop-shortcut-creator"
fi

# Stage (l): non-interactive run (stdin /dev/null): exits 1, stderr contains "interactive", fake HOME unchanged.
printf 'Stage l: non-interactive run\n'
FAKEHOME_L="${TMPBASE}/home-l"
FAKEHOME_L_BEFORE="${TMPBASE}/home-l-before"
mkdir -p "${FAKEHOME_L}"
cp -a "${FAKEHOME_L}" "${FAKEHOME_L_BEFORE}"
output_l=""
stderr_l=""
code_l="0"
stderr_l="$(cd "${REPO_ROOT}" && HOME="${FAKEHOME_L}" bash modules/desktop-shortcut-creator/module.sh run < /dev/null 2>&1 >/dev/null)" || code_l="$?"
if [[ "${code_l}" -ne 0 ]]; then
  pass "non-interactive run exits 1"
else
  fail "non-interactive run exits 1 (got ${code_l})"
fi
if printf '%s\n' "${stderr_l}" | grep -qi "interactive"; then
  pass "non-interactive run stderr mentions interactive"
else
  fail "non-interactive run stderr mentions interactive"
fi
if diff -r "${FAKEHOME_L}" "${FAKEHOME_L_BEFORE}" >/dev/null 2>&1; then
  pass "non-interactive run leaves fake HOME untouched"
else
  fail "non-interactive run modified fake HOME"
fi

# Stage (m): Custom app creation, close-out, idempotency, versioning.
printf 'Stage m: Custom app creation and versioning\n'
FAKEHOME_M="${TMPBASE}/home-m"
mkdir -p "${FAKEHOME_M}"
output_m=""
code_m="0"
output_m="$(printf '2\n1\n/usr/bin/true\nTest App\n\n\n\nn\nn\n' | HOME="${FAKEHOME_M}" bash "${REPO_ROOT}/modules/desktop-shortcut-creator/module.sh" run 2>&1)" || code_m="$?"
if [[ "${code_m}" -ne 0 ]]; then
  fail "Custom app run exits 0 (got ${code_m})"
else
  pass "Custom app run exits 0"
fi
TARGET_M="${FAKEHOME_M}/.local/share/applications/test-app.desktop"
if [[ -f "${TARGET_M}" ]]; then
  pass "Custom app creates test-app.desktop"
  if grep -q "Type=Application" "${TARGET_M}" && grep -q "Name=Test App" "${TARGET_M}" && grep -q "Exec=/usr/bin/true" "${TARGET_M}"; then
    pass "test-app.desktop has expected Type, Name, Exec"
  else
    fail "test-app.desktop missing expected Type, Name, or Exec"
  fi
else
  fail "Custom app creates test-app.desktop"
fi
if printf '%s\n' "${output_m}" | grep -q "Type=Application" && printf '%s\n' "${output_m}" | grep -q "Exec=/usr/bin/true"; then
  pass "close-out output contains entry content"
else
  fail "close-out output missing entry content"
fi
STATE_M="${FAKEHOME_M}/.local/state/mintbutler/desktop-shortcut-creator/test-app.paths"
if [[ -f "${STATE_M}" ]] && grep -q "${TARGET_M}" "${STATE_M}"; then
  pass "state records created path"
else
  fail "state records created path"
fi

# Same input again -> already-done, byte-identical
cp -a "${TARGET_M}" "${FAKEHOME_M}/test-app-before.desktop"
output_m_same=""
output_m_same="$(printf '2\n1\n/usr/bin/true\nTest App\n\n\n\nn\nn\n' | HOME="${FAKEHOME_M}" bash "${REPO_ROOT}/modules/desktop-shortcut-creator/module.sh" run 2>&1)" || true
if printf '%s\n' "${output_m_same}" | grep -qi "already exists"; then
  pass "duplicate Custom app reports already-done"
else
  fail "duplicate Custom app reports already-done"
fi
if cmp -s "${TARGET_M}" "${FAKEHOME_M}/test-app-before.desktop"; then
  pass "duplicate Custom app leaves file byte-identical"
else
  fail "duplicate Custom app modified file"
fi

# /usr/bin/false variant -> creates test-app-2.desktop, original untouched
output_m_var=""
output_m_var="$(printf '2\n1\n/usr/bin/false\nTest App\n\n\n\nn\nn\n' | HOME="${FAKEHOME_M}" bash "${REPO_ROOT}/modules/desktop-shortcut-creator/module.sh" run 2>&1)" || true
TARGET_M_2="${FAKEHOME_M}/.local/share/applications/test-app-2.desktop"
if [[ -f "${TARGET_M_2}" ]] && grep -q "Exec=/usr/bin/false" "${TARGET_M_2}"; then
  pass "variant creates test-app-2.desktop"
else
  fail "variant creates test-app-2.desktop"
fi
if cmp -s "${TARGET_M}" "${FAKEHOME_M}/test-app-before.desktop"; then
  pass "original test-app.desktop untouched by variant"
else
  fail "original test-app.desktop was modified"
fi

# Stage (n): Custom folder link and Custom URL link.
printf 'Stage n: Custom folder link and Custom URL link\n'
FAKEHOME_N="${TMPBASE}/home-n"
mkdir -p "${FAKEHOME_N}/my-test-folder"
printf '2\n2\n%s/my-test-folder\nFolder Link\n\nn\n' "${FAKEHOME_N}" | HOME="${FAKEHOME_N}" bash "${REPO_ROOT}/modules/desktop-shortcut-creator/module.sh" run >/dev/null 2>&1 || true
FOLDER_DESKTOP="${FAKEHOME_N}/.local/share/applications/folder-link.desktop"
if [[ -f "${FOLDER_DESKTOP}" ]] && grep -q "Type=Link" "${FOLDER_DESKTOP}" && grep -q "URL=file://${FAKEHOME_N}/my-test-folder" "${FOLDER_DESKTOP}"; then
  pass "Custom folder link has Type=Link and URL=file:///..."
else
  fail "Custom folder link has Type=Link and URL=file:///..."
fi

printf '2\n3\nhttps://example.com/\nWeb Link\n\nn\n' | HOME="${FAKEHOME_N}" bash "${REPO_ROOT}/modules/desktop-shortcut-creator/module.sh" run >/dev/null 2>&1 || true
URL_DESKTOP="${FAKEHOME_N}/.local/share/applications/web-link.desktop"
if [[ -f "${URL_DESKTOP}" ]] && grep -q "Type=Link" "${URL_DESKTOP}" && grep -q "URL=https://example.com/" "${URL_DESKTOP}"; then
  pass "Custom URL link has Type=Link and URL=https://example.com/"
else
  fail "Custom URL link has Type=Link and URL=https://example.com/"
fi

# Stage (o): Exec-quoting refusal.
printf 'Stage o: Exec-quoting refusal\n'
FAKEHOME_O="${TMPBASE}/home-o"
mkdir -p "${FAKEHOME_O}"
stderr_o=""
stderr_o="$(printf '2\n1\n/opt/my app/run\n\"/opt/my app/run\"\nQuoted Exec App\n\n\n\nn\nn\n' | HOME="${FAKEHOME_O}" bash "${REPO_ROOT}/modules/desktop-shortcut-creator/module.sh" run 2>&1 >/dev/null)" || true
if printf '%s\n' "${stderr_o}" | grep -q "Exec contains spaces; quote the full command"; then
  pass "unquoted Exec with spaces prints refusal line"
else
  fail "unquoted Exec with spaces prints refusal line"
fi
TARGET_O="${FAKEHOME_O}/.local/share/applications/quoted-exec-app.desktop"
if [[ -f "${TARGET_O}" ]] && grep -q 'Exec="/opt/my app/run"' "${TARGET_O}"; then
  pass "quoted Exec accepted and preserved"
else
  fail "quoted Exec accepted and preserved"
fi

# Stage (p): shadow warning.
printf 'Stage p: shadow warning\n'
FAKEHOME_P="${TMPBASE}/home-p"
FAKESYS_P="${TMPBASE}/sys-p"
mkdir -p "${FAKEHOME_P}" "${FAKESYS_P}"
touch "${FAKESYS_P}/shadowed.desktop"
output_p=""
output_p="$(printf '2\n1\n/usr/bin/true\nShadowed\n\n\n\nn\nn\n' | MINTBUTLER_TEST_APP_DIRS="${FAKESYS_P}" HOME="${FAKEHOME_P}" bash "${REPO_ROOT}/modules/desktop-shortcut-creator/module.sh" run 2>&1)" || true
if printf '%s\n' "${output_p}" | grep -qi "shadow"; then
  pass "shadowing warning appears"
else
  fail "shadowing warning appears"
fi
TARGET_P="${FAKEHOME_P}/.local/share/applications/shadowed.desktop"
STATE_P="${FAKEHOME_P}/.local/state/mintbutler/desktop-shortcut-creator/shadowed.paths"
if [[ -f "${TARGET_P}" ]]; then
  pass "shadowed entry created"
else
  fail "shadowed entry created"
fi
if [[ -f "${STATE_P}" ]] && grep -q "${TARGET_P}" "${STATE_P}"; then
  pass "shadowed entry recorded in state"
else
  fail "shadowed entry recorded in state"
fi

# Stage (q): Scan & place.
printf 'Stage q: Scan & place\n'
FAKEHOME_Q="${TMPBASE}/home-q"
FAKESYS_Q="${TMPBASE}/sys-q"
mkdir -p "${FAKEHOME_Q}/.local/share/applications" "${FAKESYS_Q}"

cat <<'EOF' > "${FAKEHOME_Q}/.local/share/applications/app-alpha.desktop"
[Desktop Entry]
Type=Application
Name=App Alpha
Exec=/usr/bin/true
EOF

cat <<'EOF' > "${FAKEHOME_Q}/.local/share/applications/app-beta.desktop"
[Desktop Entry]
Type=Application
Name=App Beta
Exec=/usr/bin/true
EOF

output_q=""
output_q="$(printf '1\n1\n2\nd\n' | MINTBUTLER_TEST_APP_DIRS="${FAKESYS_Q}" HOME="${FAKEHOME_Q}" bash "${REPO_ROOT}/modules/desktop-shortcut-creator/module.sh" run 2>&1)" || true
if printf '%s\n' "${output_q}" | grep -q "Creating desktop shortcuts"; then
  pass "confirmation listing shown"
else
  fail "confirmation listing shown"
fi
DESK_ALPHA="${FAKEHOME_Q}/Desktop/app-alpha.desktop"
DESK_BETA="${FAKEHOME_Q}/Desktop/app-beta.desktop"
if [[ -f "${DESK_ALPHA}" && -x "${DESK_ALPHA}" ]] && [[ -f "${DESK_BETA}" && -x "${DESK_BETA}" ]]; then
  pass "desktop copies exist and are executable"
else
  fail "desktop copies exist and are executable"
fi
STATE_DIR_Q="${FAKEHOME_Q}/.local/state/mintbutler/desktop-shortcut-creator"
if [[ -f "${STATE_DIR_Q}/app-alpha.paths" ]] && [[ -f "${STATE_DIR_Q}/app-beta.paths" ]]; then
  pass "desktop copies recorded in state"
else
  fail "desktop copies recorded in state"
fi

# Undo removes both copies and state
output_q_undo=""
output_q_undo="$(HOME="${FAKEHOME_Q}" bash "${REPO_ROOT}/modules/desktop-shortcut-creator/module.sh" undo 2>&1)" || true
if [[ ! -f "${DESK_ALPHA}" ]] && [[ ! -f "${DESK_BETA}" ]]; then
  pass "undo removes both desktop copies"
else
  fail "undo removes both desktop copies"
fi
if [[ ! -d "${STATE_DIR_Q}" || -z "$(ls -A "${STATE_DIR_Q}" 2>/dev/null)" ]]; then
  pass "undo removes state records"
else
  fail "undo removes state records"
fi

# Second undo -> Nothing to undo.
output_q_undo2=""
output_q_undo2="$(HOME="${FAKEHOME_Q}" bash "${REPO_ROOT}/modules/desktop-shortcut-creator/module.sh" undo 2>&1)" || true
if printf '%s\n' "${output_q_undo2}" | grep -qi "nothing to undo"; then
  pass "second undo reports Nothing to undo"
else
  fail "second undo reports Nothing to undo"
fi

# Stage (r): picker & 23-line law.
printf 'Stage r: picker & 23-line law\n'
PAG_STAGE="${TMPBASE}/pag-stage"
mkdir -p "${PAG_STAGE}"
cp -a "${REPO_ROOT}/butler" "${PAG_STAGE}/"
cp -a "${REPO_ROOT}/lib" "${PAG_STAGE}/"
mkdir -p "${PAG_STAGE}/modules"
chmod +x "${PAG_STAGE}/butler"

for i in $(seq -w 1 30); do
  synth_mod="${PAG_STAGE}/modules/synth-${i}"
  mkdir -p "${synth_mod}"
  cat <<EOF > "${synth_mod}/module.yml"
title: Synthetic Module ${i}
description: >-
  Synthetic test module description for testing pagination.
risk: low
undo: true
needs: []
order: $((100 + 10#${i}))
EOF
  cat <<'EOF' > "${synth_mod}/module.sh"
#!/usr/bin/env bash
set -euo pipefail
describe() { echo "Synthetic"; }
plan() { echo "Plan"; }
dry_run() { plan; }
run() { echo "Run"; }
undo() { echo "Undo"; }
action="${1:-describe}"
"${action}"
EOF
  chmod +x "${synth_mod}/module.sh"
done

output_r_butler="$(printf 'n\nn\nq\n' | (cd "${PAG_STAGE}" && ./butler) 2>&1)" || true

# Assert every screen between prompts is <= 23 lines and page 2 differs from page 1
butler_prompt="Select a task number (or: n next  p prev  /search  r refresh  q quit): "
butler_screens_pass=1
butler_p1=""
butler_p2=""
screen_idx=0

awk_script='
BEGIN { plen = length(prompt) }
{
  if (buf == "") buf = $0; else buf = buf "\n" $0
  idx = index(buf, prompt)
  while (idx > 0) {
    screen = substr(buf, 1, idx - 1)
    buf = substr(buf, idx + plen)
    print "===SCREEN_START==="
    print screen
    print "===SCREEN_END==="
    idx = index(buf, prompt)
  }
}
'

current_screen=""
in_screen=0
while IFS= read -r rline; do
  if [[ "${rline}" == "===SCREEN_START===" ]]; then
    in_screen=1
    current_screen=""
    continue
  fi
  if [[ "${rline}" == "===SCREEN_END===" ]]; then
    in_screen=0
    screen_idx=$(( screen_idx + 1 ))
    line_cnt="$(printf '%s\n' "${current_screen}" | wc -l)"
    if (( line_cnt > 23 )); then
      butler_screens_pass=0
      fail "Butler screen ${screen_idx} exceeded 23 lines (${line_cnt})"
    fi
    if (( screen_idx == 1 )); then butler_p1="${current_screen}"; fi
    if (( screen_idx == 2 )); then butler_p2="${current_screen}"; fi
    continue
  fi
  if [[ "${in_screen}" -eq 1 ]]; then
    if [[ -z "${current_screen}" ]]; then
      current_screen="${rline}"
    else
      current_screen="${current_screen}"$'\n'"${rline}"
    fi
  fi
done < <(awk -v prompt="${butler_prompt}" "${awk_script}" <<< "${output_r_butler}")

if [[ "${butler_screens_pass}" -eq 1 && "${screen_idx}" -ge 2 ]]; then
  pass "Butler menu screens are <= 23 lines (asserted across ${screen_idx} screens)"
else
  fail "Butler menu screens <= 23 lines"
fi

if [[ -n "${butler_p1}" && -n "${butler_p2}" && "${butler_p1}" != "${butler_p2}" ]]; then
  pass "Butler menu page 2 differs from page 1"
else
  fail "Butler menu page 2 differs from page 1"
fi

# Same bound asserted on scan-picker screen with 30 seeded entries
FAKEHOME_R="${TMPBASE}/home-r"
FAKESYS_R="${TMPBASE}/sys-r"
mkdir -p "${FAKEHOME_R}/.local/share/applications" "${FAKESYS_R}"

for i in $(seq -w 1 30); do
  cat <<EOF > "${FAKEHOME_R}/.local/share/applications/seeded-${i}.desktop"
[Desktop Entry]
Type=Application
Name=Seeded App ${i}
Exec=/usr/bin/true
EOF
done

output_r_scan="$(printf '1\nn\nn\nq\n' | MINTBUTLER_TEST_APP_DIRS="${FAKESYS_R}" HOME="${FAKEHOME_R}" bash "${REPO_ROOT}/modules/desktop-shortcut-creator/module.sh" run 2>&1)" || true

scan_prompt="Select number to toggle (or: n next  p prev  /search  d place  q back): "
scan_screens_pass=1
scan_p1=""
scan_p2=""
scan_screen_idx=0

current_screen=""
in_screen=0
while IFS= read -r rline; do
  if [[ "${rline}" == "===SCREEN_START===" ]]; then
    in_screen=1
    current_screen=""
    continue
  fi
  if [[ "${rline}" == "===SCREEN_END===" ]]; then
    in_screen=0
    scan_screen_idx=$(( scan_screen_idx + 1 ))
    line_cnt="$(printf '%s\n' "${current_screen}" | wc -l)"
    if (( line_cnt > 23 )); then
      scan_screens_pass=0
      fail "Scan picker screen ${scan_screen_idx} exceeded 23 lines (${line_cnt})"
    fi
    if (( scan_screen_idx == 1 )); then scan_p1="${current_screen}"; fi
    if (( scan_screen_idx == 2 )); then scan_p2="${current_screen}"; fi
    continue
  fi
  if [[ "${in_screen}" -eq 1 ]]; then
    if [[ -z "${current_screen}" ]]; then
      current_screen="${rline}"
    else
      current_screen="${current_screen}"$'\n'"${rline}"
    fi
  fi
done < <(awk -v prompt="${scan_prompt}" "${awk_script}" <<< "${output_r_scan}")

if [[ "${scan_screens_pass}" -eq 1 && "${scan_screen_idx}" -ge 2 ]]; then
  pass "Scan picker screens are <= 23 lines (asserted across ${scan_screen_idx} screens)"
else
  fail "Scan picker screens <= 23 lines"
fi

if [[ -n "${scan_p1}" && -n "${scan_p2}" && "${scan_p1}" != "${scan_p2}" ]]; then
  pass "Scan picker page 2 differs from page 1"
else
  fail "Scan picker page 2 differs from page 1"
fi

# ---------------------------------------------------------------------------
# Stages (s)-(y): screenshot-studio (elevated) — stub-only verification.
# Every stage runs the module with a controlled PATH (stub binaries plus
# symlinks to the few coreutils the module needs) and a fake HOME under
# mktemp. No stage ever calls real sudo, real apt-get, or real dconf, and no
# stage touches the real settings store.
# ---------------------------------------------------------------------------

SS_MODULE="${REPO_ROOT}/modules/screenshot-studio/module.sh"
SS_STUB_ROOT="${TMPBASE}/ss-stubs"
SS_SLOT="/org/cinnamon/keybindings/custom/mintbutler-flameshot"
SS_BUILTIN="/org/cinnamon/keybindings/screenshot"
SS_LIST="/org/cinnamon/keybindings/custom-list"
SS_STATE_REL=".local/state/mintbutler/screenshot-studio/binding.paths"

SS_BASH_BIN="${BASH:-}"
if [[ -z "${SS_BASH_BIN}" ]]; then
  SS_BASH_BIN="$(command -v bash)"
fi

mkdir -p "${SS_STUB_ROOT}"

# Stub: file-backed dconf store (path<TAB>value lines under the stage dir).
cat <<'SS_DCONF_STUB' > "${SS_STUB_ROOT}/dconf"
#!/usr/bin/env bash
set -euo pipefail
STORE="${DCONF_STUB_STORE:-}"
if [[ -z "${STORE}" ]]; then
  printf 'dconf-stub: DCONF_STUB_STORE is not set\n' >&2
  exit 2
fi

store_normalize() {
  local key="${1:-}"
  while [[ "${key}" == */ ]]; do
    key="${key%/}"
  done
  printf '%s' "${key}"
}

# Rewrite the store without the entry whose path equals "$1".
store_without() {
  local skip="${1:-}"
  local out="${STORE}.tmp.$$"
  : > "${out}"
  local p v
  if [[ -f "${STORE}" ]]; then
    while IFS=$'\t' read -r p v || [[ -n "${p}" ]]; do
      if [[ -z "${p}" || "${p}" == "${skip}" ]]; then
        continue
      fi
      printf '%s\t%s\n' "${p}" "${v}" >> "${out}"
    done < "${STORE}"
  fi
  mv "${out}" "${STORE}"
}

# Rewrite the store without any entry under "$1" (reset -f).
store_without_tree() {
  local prefix="${1:-}"
  local out="${STORE}.tmp.$$"
  : > "${out}"
  local p v
  if [[ -f "${STORE}" ]]; then
    while IFS=$'\t' read -r p v || [[ -n "${p}" ]]; do
      if [[ -z "${p}" ]]; then
        continue
      fi
      if [[ "${p}" == "${prefix}" || "${p}" == "${prefix}/"* ]]; then
        continue
      fi
      printf '%s\t%s\n' "${p}" "${v}" >> "${out}"
    done < "${STORE}"
  fi
  mv "${out}" "${STORE}"
}

operation="${1:-}"
case "${operation}" in
  read)
    key="$(store_normalize "${2:-}")"
    if [[ -f "${STORE}" ]]; then
      while IFS=$'\t' read -r p v || [[ -n "${p}" ]]; do
        if [[ "${p}" == "${key}" ]]; then
          printf '%s\n' "${v}"
          exit 0
        fi
      done < "${STORE}"
    fi
    exit 0
    ;;
  write)
    if [[ "${DCONF_STUB_READONLY:-0}" == "1" ]]; then
      exit 0
    fi
    key="$(store_normalize "${2:-}")"
    value="${3:-}"
    if [[ -z "${key}" ]]; then
      printf 'dconf-stub: write needs a key\n' >&2
      exit 2
    fi
    store_without "${key}"
    printf '%s\t%s\n' "${key}" "${value}" >> "${STORE}"
    exit 0
    ;;
  reset)
    if [[ "${DCONF_STUB_READONLY:-0}" == "1" ]]; then
      exit 0
    fi
    if [[ "${2:-}" == "-f" ]]; then
      store_without_tree "$(store_normalize "${3:-}")"
      exit 0
    fi
    store_without "$(store_normalize "${2:-}")"
    exit 0
    ;;
  list)
    if [[ -f "${STORE}" ]]; then
      while IFS=$'\t' read -r p v || [[ -n "${p}" ]]; do
        if [[ -n "${p}" ]]; then
          printf '%s\n' "${p}"
        fi
      done < "${STORE}"
    fi
    exit 0
    ;;
  *)
    printf 'dconf-stub: unsupported operation: %s\n' "${operation}" >&2
    exit 2
    ;;
esac
SS_DCONF_STUB

# Stub: flameshot present.
cat <<'SS_FLAMESHOT_STUB' > "${SS_STUB_ROOT}/flameshot"
#!/usr/bin/env bash
set -euo pipefail
exit 0
SS_FLAMESHOT_STUB

# Stub: privileged step. One stderr line; fails unless SUDO_STUB_EXIT says 0.
cat <<'SS_SUDO_STUB' > "${SS_STUB_ROOT}/sudo"
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo-stub: refused %s\n' "$*" >&2
exit "${SUDO_STUB_EXIT:-1}"
SS_SUDO_STUB

chmod +x "${SS_STUB_ROOT}/dconf" "${SS_STUB_ROOT}/flameshot" "${SS_STUB_ROOT}/sudo"

# Build a controlled PATH directory: symlinks to the coreutils the module
# needs, then only the stubs a stage wants present.
ss_make_bin() {
  local dir="${1:-}"
  mkdir -p "${dir}"
  local tool tool_path
  for tool in dirname sed mkdir rm rmdir mv bash; do
    tool_path="$(command -v "${tool}" || true)"
    if [[ -n "${tool_path}" ]]; then
      ln -sf "${tool_path}" "${dir}/${tool}"
    fi
  done
  printf '%s\n' "${dir}"
}

ss_store_get() {
  local store="${1:-}"
  local key="${2:-}"
  awk -F'\t' -v k="${key}" '$1 == k { print $2; exit }' "${store}"
}

ss_store_contains() {
  local store="${1:-}"
  local needle="${2:-}"
  grep -q -- "${needle}" "${store}"
}

ss_make_bin "${SS_STUB_ROOT}/bin-rebind" >/dev/null
cp "${SS_STUB_ROOT}/dconf" "${SS_STUB_ROOT}/flameshot" "${SS_STUB_ROOT}/sudo" "${SS_STUB_ROOT}/bin-rebind/"

ss_make_bin "${SS_STUB_ROOT}/bin-install-fail" >/dev/null
cp "${SS_STUB_ROOT}/sudo" "${SS_STUB_ROOT}/bin-install-fail/"

ss_make_bin "${SS_STUB_ROOT}/bin-no-dconf" >/dev/null
cp "${SS_STUB_ROOT}/flameshot" "${SS_STUB_ROOT}/bin-no-dconf/"

SS_BIN_REBIND="${SS_STUB_ROOT}/bin-rebind"
SS_BIN_INSTALL_FAIL="${SS_STUB_ROOT}/bin-install-fail"
SS_BIN_NO_DCONF="${SS_STUB_ROOT}/bin-no-dconf"

# Stage (s): gate pass, scan, list badge in the real repo.
printf 'Stage s: screenshot-studio gate, scan, list badge\n'
output_s_scan=""
code_s_scan="0"
output_s_scan="$(cd "${REPO_ROOT}" && ./butler --scan 2>&1)" || code_s_scan="$?"
if [[ "${code_s_scan}" -ne 0 ]]; then
  fail "butler --scan exits 0 with screenshot-studio present (got ${code_s_scan})"
else
  pass "butler --scan exits 0 with screenshot-studio present"
fi
if printf '%s\n' "${output_s_scan}" | grep -q "PASS screenshot-studio"; then
  pass "butler --scan reports PASS screenshot-studio"
else
  fail "butler --scan reports PASS screenshot-studio"
fi

output_s_lint=""
code_s_lint="0"
output_s_lint="$(cd "${REPO_ROOT}" && bin/modulelint 2>&1)" || code_s_lint="$?"
if [[ "${code_s_lint}" -ne 0 ]]; then
  fail "bin/modulelint exits 0 over all modules (got ${code_s_lint})"
else
  pass "bin/modulelint exits 0 over all modules"
fi
if printf '%s\n' "${output_s_lint}" | grep -q "PASS screenshot-studio"; then
  pass "bin/modulelint reports PASS screenshot-studio"
else
  fail "bin/modulelint reports PASS screenshot-studio"
fi

output_s_list=""
code_s_list="0"
output_s_list="$(cd "${REPO_ROOT}" && ./butler --list 2>&1)" || code_s_list="$?"
if [[ "${code_s_list}" -ne 0 ]]; then
  fail "butler --list exits 0 (got ${code_s_list})"
else
  pass "butler --list exits 0"
fi
ss_list_line="$(printf '%s\n' "${output_s_list}" | grep -- "screenshot-studio: Screenshot studio" || true)"
if [[ -n "${ss_list_line}" ]]; then
  pass "butler --list shows screenshot-studio: Screenshot studio"
else
  fail "butler --list shows screenshot-studio: Screenshot studio"
fi
if [[ "${ss_list_line}" == *"⚠ elevated"* ]]; then
  pass "butler --list shows the elevated badge on screenshot-studio"
else
  fail "butler --list shows the elevated badge on screenshot-studio"
fi
if printf '%s\n' "${output_s_list}" | grep -q "desktop-shortcut-creator"; then
  pass "butler --list still shows desktop-shortcut-creator"
else
  fail "butler --list still shows desktop-shortcut-creator"
fi

# Stage (t): rebind path against the stub store.
printf 'Stage t: screenshot-studio rebind\n'
SS_T_HOME="${TMPBASE}/ss-home-t"
SS_T_STORE="${TMPBASE}/ss-store-t.txt"
mkdir -p "${SS_T_HOME}"
printf '%s\t%s\n' "${SS_BUILTIN}" "['Print']" > "${SS_T_STORE}"
cp "${SS_T_STORE}" "${SS_T_STORE}.seeded"
output_t=""
code_t="0"
output_t="$(PATH="${SS_BIN_REBIND}" HOME="${SS_T_HOME}" DCONF_STUB_STORE="${SS_T_STORE}" \
  "${SS_BASH_BIN}" "${SS_MODULE}" run < /dev/null 2>&1)" || code_t="$?"
if [[ "${code_t}" -ne 0 ]]; then
  fail "rebind run exits 0 (got ${code_t})"
else
  pass "rebind run exits 0"
fi
ss_t_command="$(ss_store_get "${SS_T_STORE}" "${SS_SLOT}/command")"
ss_t_binding="$(ss_store_get "${SS_T_STORE}" "${SS_SLOT}/binding")"
ss_t_name="$(ss_store_get "${SS_T_STORE}" "${SS_SLOT}/name")"
ss_t_list="$(ss_store_get "${SS_T_STORE}" "${SS_LIST}")"
ss_t_builtin="$(ss_store_get "${SS_T_STORE}" "${SS_BUILTIN}")"
if [[ "${ss_t_command}" == *flameshot* ]]; then
  pass "stub store: slot command points at flameshot (${ss_t_command})"
else
  fail "stub store: slot command points at flameshot (got '${ss_t_command}')"
fi
if [[ "${ss_t_binding}" == *Print* ]]; then
  pass "stub store: slot binding holds Print (${ss_t_binding})"
else
  fail "stub store: slot binding holds Print (got '${ss_t_binding}')"
fi
if [[ "${ss_t_name}" == *"Flameshot (mintbutler)"* ]]; then
  pass "stub store: slot name recorded"
else
  fail "stub store: slot name recorded (got '${ss_t_name}')"
fi
if [[ "${ss_t_list}" == *"${SS_SLOT}"* ]]; then
  pass "stub store: custom-list contains the slot path"
else
  fail "stub store: custom-list contains the slot path (got '${ss_t_list}')"
fi
if [[ "${ss_t_builtin}" == "@as []" ]]; then
  pass "stub store: built-in screenshot key cleared"
else
  fail "stub store: built-in screenshot key cleared (got '${ss_t_builtin}')"
fi
SS_T_STATE="${SS_T_HOME}/${SS_STATE_REL}"
if [[ -f "${SS_T_STATE}" ]] && grep -q "screenshot=\['Print'\]" "${SS_T_STATE}" && grep -q "custom_list=UNSET" "${SS_T_STATE}"; then
  pass "state file records the previous values"
else
  fail "state file records the previous values"
fi
if printf '%s\n' "${output_t}" | grep -q "package installs don't cleanly undo"; then
  pass "rebind output states the mixed undo story"
else
  fail "rebind output states the mixed undo story"
fi
if printf '%s\n' "${output_t}" | grep -q -- "\[u\]ndo"; then
  pass "rebind output points at undo for the key binding"
else
  fail "rebind output points at undo for the key binding"
fi

# Stage (u): undo restores the recorded binding.
printf 'Stage u: screenshot-studio undo\n'
output_u=""
code_u="0"
output_u="$(PATH="${SS_BIN_REBIND}" HOME="${SS_T_HOME}" DCONF_STUB_STORE="${SS_T_STORE}" \
  "${SS_BASH_BIN}" "${SS_MODULE}" undo < /dev/null 2>&1)" || code_u="$?"
if [[ "${code_u}" -ne 0 ]]; then
  fail "undo exits 0 (got ${code_u})"
else
  pass "undo exits 0"
fi
ss_u_builtin="$(ss_store_get "${SS_T_STORE}" "${SS_BUILTIN}")"
if [[ "${ss_u_builtin}" == "['Print']" ]]; then
  pass "undo restores the built-in binding to ['Print']"
else
  fail "undo restores the built-in binding to ['Print'] (got '${ss_u_builtin}')"
fi
if ss_store_contains "${SS_T_STORE}" "${SS_SLOT}"; then
  fail "undo removes the slot from the stub store"
else
  pass "undo removes the slot from the stub store"
fi
ss_u_list="$(ss_store_get "${SS_T_STORE}" "${SS_LIST}")"
if [[ "${ss_u_list}" != *"${SS_SLOT}"* ]]; then
  pass "undo removes the slot from custom-list"
else
  fail "undo removes the slot from custom-list (got '${ss_u_list}')"
fi
if [[ ! -f "${SS_T_STATE}" ]]; then
  pass "undo deletes the state file"
else
  fail "undo deletes the state file"
fi
if printf '%s\n' "${output_u}" | grep -qi "flameshot stays installed"; then
  pass "undo output says flameshot remains installed"
else
  fail "undo output says flameshot remains installed"
fi
output_u2=""
code_u2="0"
output_u2="$(PATH="${SS_BIN_REBIND}" HOME="${SS_T_HOME}" DCONF_STUB_STORE="${SS_T_STORE}" \
  "${SS_BASH_BIN}" "${SS_MODULE}" undo < /dev/null 2>&1)" || code_u2="$?"
if [[ "${code_u2}" -eq 0 ]] && printf '%s\n' "${output_u2}" | grep -qi "nothing to undo"; then
  pass "second undo reports Nothing to undo and exits 0"
else
  fail "second undo reports Nothing to undo and exits 0 (got ${code_u2})"
fi

# Stage (v): missing flameshot + failing privileged step.
printf 'Stage v: screenshot-studio install failure\n'
SS_V_HOME="${TMPBASE}/ss-home-v"
SS_V_STORE="${TMPBASE}/ss-store-v.txt"
mkdir -p "${SS_V_HOME}"
printf '%s\t%s\n' "${SS_BUILTIN}" "['Print']" > "${SS_V_STORE}"
cp "${SS_V_STORE}" "${SS_V_STORE}.seeded"
USED_V_STDERR="${TMPBASE}/ss-v.stderr"
output_v=""
code_v="0"
output_v="$(PATH="${SS_BIN_INSTALL_FAIL}" HOME="${SS_V_HOME}" DCONF_STUB_STORE="${SS_V_STORE}" SUDO_STUB_EXIT=1 \
  "${SS_BASH_BIN}" "${SS_MODULE}" run < /dev/null 2>"${USED_V_STDERR}")" || code_v="$?"
if [[ "${code_v}" -eq 1 ]]; then
  pass "install failure exits 1"
else
  fail "install failure exits 1 (got ${code_v})"
fi
ss_v_stderr="$(cat "${USED_V_STDERR}")"
ss_v_module_lines="$(printf '%s\n' "${ss_v_stderr}" | grep -v '^sudo-stub:' | grep -c . || true)"
if [[ "${ss_v_module_lines}" == "1" ]] && printf '%s\n' "${ss_v_stderr}" | grep -qi "install"; then
  pass "install failure prints one plain stderr line mentioning the install"
else
  fail "install failure prints one plain stderr line mentioning the install (got ${ss_v_module_lines} lines)"
fi
if printf '%s\n' "${output_v}" | grep -q -- "sudo apt-get install -y flameshot"; then
  pass "install failure shows the exact elevated command on stdout"
else
  fail "install failure shows the exact elevated command on stdout"
fi
if cmp -s "${SS_V_STORE}" "${SS_V_STORE}.seeded"; then
  pass "install failure leaves the stub store byte-identical"
else
  fail "install failure leaves the stub store byte-identical"
fi
if [[ ! -e "${SS_V_HOME}/${SS_STATE_REL}" ]]; then
  pass "install failure records no state"
else
  fail "install failure records no state"
fi

# Stage (w): idempotency.
printf 'Stage w: screenshot-studio idempotency\n'
SS_W_HOME="${TMPBASE}/ss-home-w"
SS_W_STORE="${TMPBASE}/ss-store-w.txt"
mkdir -p "${SS_W_HOME}"
printf '%s\t%s\n' "${SS_BUILTIN}" "['Print']" > "${SS_W_STORE}"
code_w1="0"
PATH="${SS_BIN_REBIND}" HOME="${SS_W_HOME}" DCONF_STUB_STORE="${SS_W_STORE}" \
  "${SS_BASH_BIN}" "${SS_MODULE}" run < /dev/null >"${TMPBASE}/ss-w1.stdout" 2>&1 || code_w1="$?"
if [[ "${code_w1}" -eq 0 ]]; then
  pass "first idempotency run exits 0"
else
  fail "first idempotency run exits 0 (got ${code_w1})"
fi
cp "${SS_W_STORE}" "${SS_W_STORE}.after-first"
SS_W_STATE="${SS_W_HOME}/${SS_STATE_REL}"
cp "${SS_W_STATE}" "${SS_W_STATE}.after-first"
output_w2=""
code_w2="0"
output_w2="$(PATH="${SS_BIN_REBIND}" HOME="${SS_W_HOME}" DCONF_STUB_STORE="${SS_W_STORE}" \
  "${SS_BASH_BIN}" "${SS_MODULE}" run < /dev/null 2>&1)" || code_w2="$?"
if [[ "${code_w2}" -eq 0 ]]; then
  pass "second idempotency run exits 0"
else
  fail "second idempotency run exits 0 (got ${code_w2})"
fi
if printf '%s\n' "${output_w2}" | grep -qi "already configured"; then
  pass "second run reports already-configured"
else
  fail "second run reports already-configured"
fi
if cmp -s "${SS_W_STORE}" "${SS_W_STORE}.after-first"; then
  pass "second run leaves the stub store byte-identical"
else
  fail "second run leaves the stub store byte-identical"
fi
if cmp -s "${SS_W_STATE}" "${SS_W_STATE}.after-first"; then
  pass "second run leaves the state file byte-identical"
else
  fail "second run leaves the state file byte-identical"
fi

# Stage (x): dconf absent.
printf 'Stage x: screenshot-studio without dconf\n'
SS_X_HOME="${TMPBASE}/ss-home-x"
mkdir -p "${SS_X_HOME}"
USED_X_STDERR="${TMPBASE}/ss-x.stderr"
code_x="0"
PATH="${SS_BIN_NO_DCONF}" HOME="${SS_X_HOME}" "${SS_BASH_BIN}" "${SS_MODULE}" run < /dev/null \
  >"${TMPBASE}/ss-x.stdout" 2>"${USED_X_STDERR}" || code_x="$?"
if [[ "${code_x}" -eq 1 ]]; then
  pass "missing dconf exits 1"
else
  fail "missing dconf exits 1 (got ${code_x})"
fi
if grep -q "dconf not available; keybinding changes need the Cinnamon session tools" "${USED_X_STDERR}"; then
  pass "missing dconf prints the plain dconf-missing line"
else
  fail "missing dconf prints the plain dconf-missing line"
fi
if [[ ! -e "${SS_X_HOME}/${SS_STATE_REL}" ]]; then
  pass "missing dconf records nothing"
else
  fail "missing dconf records nothing"
fi

# Stage (y): plan and dry-run screens.
printf 'Stage y: screenshot-studio plan and dry-run\n'
output_y_plan=""
code_y_plan="0"
output_y_plan="$(PATH="${SS_BIN_NO_DCONF}" "${SS_BASH_BIN}" "${SS_MODULE}" plan < /dev/null 2>&1)" || code_y_plan="$?"
ss_y_plan_lines="$(printf '%s\n' "${output_y_plan}" | wc -l)"
if [[ "${code_y_plan}" -eq 0 && -n "${output_y_plan}" ]]; then
  pass "plan exits 0 with output"
else
  fail "plan exits 0 with output (got ${code_y_plan})"
fi
if [[ "${ss_y_plan_lines}" -le 23 ]]; then
  pass "plan fits the 23-line law (${ss_y_plan_lines} lines)"
else
  fail "plan fits the 23-line law (${ss_y_plan_lines} lines)"
fi
if printf '%s\n' "${output_y_plan}" | grep -q -- "sudo apt-get install -y flameshot"; then
  pass "plan shows the exact elevated install command"
else
  fail "plan shows the exact elevated install command"
fi
if printf '%s\n' "${output_y_plan}" | grep -q -- "/org/cinnamon/keybindings/"; then
  pass "plan names the dconf paths it will touch"
else
  fail "plan names the dconf paths it will touch"
fi

SS_Y_HOME="${TMPBASE}/ss-home-y"
SS_Y_STORE="${TMPBASE}/ss-store-y.txt"
mkdir -p "${SS_Y_HOME}"
printf '%s\t%s\n' "${SS_BUILTIN}" "['Print']" > "${SS_Y_STORE}"
cp "${SS_Y_STORE}" "${SS_Y_STORE}.seeded"
output_y_dry=""
code_y_dry="0"
output_y_dry="$(PATH="${SS_BIN_REBIND}" HOME="${SS_Y_HOME}" DCONF_STUB_STORE="${SS_Y_STORE}" \
  "${SS_BASH_BIN}" "${SS_MODULE}" dry-run < /dev/null 2>&1)" || code_y_dry="$?"
ss_y_dry_lines="$(printf '%s\n' "${output_y_dry}" | wc -l)"
if [[ "${code_y_dry}" -eq 0 && -n "${output_y_dry}" ]]; then
  pass "dry-run exits 0 with output"
else
  fail "dry-run exits 0 with output (got ${code_y_dry})"
fi
if [[ "${ss_y_dry_lines}" -le 23 ]]; then
  pass "dry-run fits the 23-line law (${ss_y_dry_lines} lines)"
else
  fail "dry-run fits the 23-line law (${ss_y_dry_lines} lines)"
fi
if printf '%s\n' "${output_y_dry}" | grep -q -- "sudo apt-get install -y flameshot"; then
  pass "dry-run shows the exact elevated install command"
else
  fail "dry-run shows the exact elevated install command"
fi
if printf '%s\n' "${output_y_dry}" | grep -q -- "${SS_SLOT}"; then
  pass "dry-run shows the custom slot path"
else
  fail "dry-run shows the custom slot path"
fi
if cmp -s "${SS_Y_STORE}" "${SS_Y_STORE}.seeded"; then
  pass "dry-run leaves the stub store byte-identical"
else
  fail "dry-run leaves the stub store byte-identical"
fi
if [[ ! -e "${SS_Y_HOME}/${SS_STATE_REL}" ]]; then
  pass "dry-run records no state"
else
  fail "dry-run records no state"
fi

# Stage (z): verify-mismatch path and unset built-in key.
printf 'Stage z: screenshot-studio verify mismatch and unset built-in\n'
SS_Z_HOME="${TMPBASE}/ss-home-z"
SS_Z_STORE="${TMPBASE}/ss-store-z.txt"
mkdir -p "${SS_Z_HOME}"
: > "${SS_Z_STORE}"
cp "${SS_Z_STORE}" "${SS_Z_STORE}.seeded"
USED_Z_STDERR="${TMPBASE}/ss-z.stderr"
code_z="0"
PATH="${SS_BIN_REBIND}" HOME="${SS_Z_HOME}" DCONF_STUB_STORE="${SS_Z_STORE}" DCONF_STUB_READONLY=1 \
  "${SS_BASH_BIN}" "${SS_MODULE}" run < /dev/null >"${TMPBASE}/ss-z.stdout" 2>"${USED_Z_STDERR}" || code_z="$?"
if [[ "${code_z}" -eq 1 ]]; then
  pass "verify mismatch exits 1"
else
  fail "verify mismatch exits 1 (got ${code_z})"
fi
if grep -q "Verification failed" "${USED_Z_STDERR}"; then
  pass "verify mismatch prints a plain error"
else
  fail "verify mismatch prints a plain error"
fi
if cmp -s "${SS_Z_STORE}" "${SS_Z_STORE}.seeded"; then
  pass "verify mismatch leaves the stub store byte-identical"
else
  fail "verify mismatch leaves the stub store byte-identical"
fi
SS_Z_STATE="${SS_Z_HOME}/${SS_STATE_REL}"
if [[ -f "${SS_Z_STATE}" ]] && grep -q "screenshot=UNSET" "${SS_Z_STATE}"; then
  pass "verify mismatch keeps the recorded state for undo"
else
  fail "verify mismatch keeps the recorded state for undo"
fi

SS_Z2_HOME="${TMPBASE}/ss-home-z2"
SS_Z2_STORE="${TMPBASE}/ss-store-z2.txt"
mkdir -p "${SS_Z2_HOME}"
: > "${SS_Z2_STORE}"
code_z2="0"
PATH="${SS_BIN_REBIND}" HOME="${SS_Z2_HOME}" DCONF_STUB_STORE="${SS_Z2_STORE}" \
  "${SS_BASH_BIN}" "${SS_MODULE}" run < /dev/null >"${TMPBASE}/ss-z2.stdout" 2>&1 || code_z2="$?"
if [[ "${code_z2}" -eq 0 ]]; then
  pass "unset built-in run exits 0"
else
  fail "unset built-in run exits 0 (got ${code_z2})"
fi
ss_z2_builtin="$(ss_store_get "${SS_Z2_STORE}" "${SS_BUILTIN}")"
if [[ -z "${ss_z2_builtin}" ]]; then
  pass "unset built-in key is left alone (not created)"
else
  fail "unset built-in key is left alone (not created, got '${ss_z2_builtin}')"
fi
code_z2_undo="0"
PATH="${SS_BIN_REBIND}" HOME="${SS_Z2_HOME}" DCONF_STUB_STORE="${SS_Z2_STORE}" \
  "${SS_BASH_BIN}" "${SS_MODULE}" undo < /dev/null >"${TMPBASE}/ss-z2-undo.stdout" 2>&1 || code_z2_undo="$?"
if [[ "${code_z2_undo}" -eq 0 ]]; then
  pass "unset built-in undo exits 0"
else
  fail "unset built-in undo exits 0 (got ${code_z2_undo})"
fi
if [[ ! -s "${SS_Z2_STORE}" ]]; then
  pass "unset built-in undo leaves the stub store empty"
else
  fail "unset built-in undo leaves the stub store empty"
fi

# Stage (aa): bin/orchestrator-check fixture matrix (z1–z8).
# Prompt 008 designates this "stage (z)", but (z) is already used above by
# screenshot-studio, so the matrix lands here as (aa). Fixtures are
# throwaway git repos under mktemp -d — never the real repo, never the
# network, never real credentials.
printf 'Stage aa: orchestrator-check fixtures\n'

ORCH_CHECK="${REPO_ROOT}/bin/orchestrator-check"
ZBASE="${TMPBASE}/orch-fixtures"
mkdir -p "${ZBASE}/nohome"
Z_CODE="0"
Z_OUT=""

# z_git DIR ARGS... — git with deterministic identity and isolated config
# (no system/global gitconfig, no signing hooks leak into fixtures).
z_git() {
  local d="${1}"
  shift
  (
    export GIT_AUTHOR_NAME="Fixture" GIT_AUTHOR_EMAIL="fixture@example.invalid"
    export GIT_COMMITTER_NAME="Fixture" GIT_COMMITTER_EMAIL="fixture@example.invalid"
    export GIT_AUTHOR_DATE="2026-09-17T00:00:00+00:00" GIT_COMMITTER_DATE="2026-09-17T00:00:00+00:00"
    export GIT_CONFIG_NOSYSTEM="1" HOME="${ZBASE}/nohome"
    git -C "${d}" "$@"
  )
}

# z_fixture_build DIR — conforming fixture: an epoch commit (dummy spec,
# tracker anchored to its sha256, pre-adoption prompt 000), then a
# conforming publish commit (prompt 001 only), a canned origin remote that
# is never fetched (makes the stub header derive to "mintbutler agent"),
# and a state file with Run Log + Compliance Epoch sections.
z_fixture_build() {
  local fix="${1}"
  local spec_rel=".orchestrator/ORCHESTRATOR CORE v4.5 — GENERAL PURPOSE.md"
  mkdir -p "${fix}/.orchestrator/prompts" "${fix}/docs"
  z_git "${fix}" init -q -b orch
  z_git "${fix}" remote add origin "https://github.com/example/mintbutler.git"
  printf 'dummy governing spec bytes (fixture)\n' > "${fix}/${spec_rel}"
  local fix_sha
  fix_sha="$(sha256sum -- "${fix}/${spec_rel}" | cut -d' ' -f1)"
  printf '%s\n' \
    '# Project State (fixture)' \
    '' \
    '## 2. Architectural Invariants' \
    "- **Governing spec anchor (owner ruling 2026-09-17):** orchestrator governing prompt pinned byte-faithful at \`${spec_rel}\` — sha256 \`${fix_sha}\` — verified by \`bin/orchestrator-check\` (spec-anchor check). Pre-adoption orchestrator drift audited and filed 2026-09-17." \
    > "${fix}/docs/PROJECT_STATE.md"
  printf 'baseline pre-adoption prompt\n' > "${fix}/.orchestrator/prompts/000-baseline.md"
  z_git "${fix}" add -A
  z_git "${fix}" commit -qm "chore: fixture baseline"
  local epoch
  epoch="$(z_git "${fix}" rev-parse HEAD)"
  cat > "${fix}/.fixture-state.md" <<EOF
# Fixture Orchestrator State

## Run Log
- 2026-09-17 | publish | 000-baseline published on orchestrator branch (pre-adoption)
- 2026-09-17 | dispatch | 000 handed to operator; stub first line: n/a (pre-adoption, prose dispatch)
- 2026-09-17 | publish | 001-fixture-task published (first conforming publish)
- 2026-09-17 | dispatch | 001 handed to operator; stub first line: mintbutler agent

## Compliance Epoch
Epoch: ${epoch}
Enforcement of bin/orchestrator-check publish-form/run-log-coverage begins
at the epoch's first child commit; commits at or before the epoch are
pre-adoption (fixture text).
EOF
  printf 'fixture task prompt\n' > "${fix}/.orchestrator/prompts/001-fixture-task.md"
  z_git "${fix}" add -- .orchestrator/prompts/001-fixture-task.md
  z_git "${fix}" commit -qm "chore: publish 001-fixture-task"
}

# z_run DIR — run the tool against fixture DIR; sets Z_CODE and Z_OUT.
z_run() {
  Z_CODE="0"
  Z_OUT="$("${ORCH_CHECK}" --repo-root "${1}" --ref refs/heads/orch --state "${1}/.fixture-state.md" 2>&1)" || Z_CODE="$?"
}

ZGOOD="${ZBASE}/good"
z_fixture_build "${ZGOOD}"

# (z1) conforming fixture: exit 0, exactly five PASS lines, no FAIL.
z_run "${ZGOOD}"
if [[ "${Z_CODE}" -eq 0 ]] \
  && [[ "$(printf '%s\n' "${Z_OUT}" | grep -c '^PASS ')" == "5" ]] \
  && ! printf '%s\n' "${Z_OUT}" | grep -q '^FAIL '; then
  pass "z1: good fixture exits 0 with five PASS lines"
else
  fail "z1: good fixture exits 0 with five PASS lines (code ${Z_CODE})"
fi

# (z2) dispatch run-log line missing the stub first line field.
FIX2="${ZBASE}/z2"
cp -a "${ZGOOD}" "${FIX2}"
sed -i 's/; stub first line: mintbutler agent//' "${FIX2}/.fixture-state.md"
z_run "${FIX2}"
if [[ "${Z_CODE}" -eq 1 ]] && printf '%s\n' "${Z_OUT}" | grep -q '^FAIL stub-first-line'; then
  pass "z2: dispatch line without stub first line fails stub-first-line"
else
  fail "z2: dispatch line without stub first line fails stub-first-line (code ${Z_CODE})"
fi

# (z3) publish commit also touching README.md.
FIX3="${ZBASE}/z3"
cp -a "${ZGOOD}" "${FIX3}"
printf 'readme\n' > "${FIX3}/README.md"
printf 'bad touch prompt\n' > "${FIX3}/.orchestrator/prompts/002-bad-touch.md"
z_git "${FIX3}" add -- README.md .orchestrator/prompts/002-bad-touch.md
z_git "${FIX3}" commit -qm "chore: publish 002-bad-touch"
z_run "${FIX3}"
if [[ "${Z_CODE}" -eq 1 ]] \
  && printf '%s\n' "${Z_OUT}" | grep '^FAIL publish-form' | grep -qF 'README.md'; then
  pass "z3: publish commit touching README.md fails publish-form"
else
  fail "z3: publish commit touching README.md fails publish-form (code ${Z_CODE})"
fi

# (z4) prompt commit with a non-publish subject.
FIX4="${ZBASE}/z4"
cp -a "${ZGOOD}" "${FIX4}"
printf 'wip prompt\n' > "${FIX4}/.orchestrator/prompts/003-wip.md"
z_git "${FIX4}" add -- .orchestrator/prompts/003-wip.md
z_git "${FIX4}" commit -qm "wip: prompt"
z_run "${FIX4}"
if [[ "${Z_CODE}" -eq 1 ]] && printf '%s\n' "${Z_OUT}" | grep -q '^FAIL publish-form'; then
  pass "z4: prompt commit with wip subject fails publish-form"
else
  fail "z4: prompt commit with wip subject fails publish-form (code ${Z_CODE})"
fi

# (z5) merge commit on the orchestrator branch.
FIX5="${ZBASE}/z5"
cp -a "${ZGOOD}" "${FIX5}"
z_git "${FIX5}" checkout -q -b side
printf 'side notes\n' > "${FIX5}/NOTES.md"
z_git "${FIX5}" add -- NOTES.md
z_git "${FIX5}" commit -qm "chore: side notes"
z_git "${FIX5}" checkout -q orch
z_git "${FIX5}" merge -q --no-ff -m "Merge branch 'side'" side
z_run "${FIX5}"
if [[ "${Z_CODE}" -eq 1 ]] && printf '%s\n' "${Z_OUT}" | grep -q '^FAIL no-merge-into-orchestrator'; then
  pass "z5: merge commit on orch fails no-merge-into-orchestrator"
else
  fail "z5: merge commit on orch fails no-merge-into-orchestrator (code ${Z_CODE})"
fi

# (z6) tracker anchor sha no longer matches the spec bytes.
FIX6="${ZBASE}/z6"
cp -a "${ZGOOD}" "${FIX6}"
printf 'tampered\n' >> "${FIX6}/.orchestrator/ORCHESTRATOR CORE v4.5 — GENERAL PURPOSE.md"
z_run "${FIX6}"
if [[ "${Z_CODE}" -eq 1 ]] && printf '%s\n' "${Z_OUT}" | grep -q '^FAIL spec-anchor'; then
  pass "z6: tracker sha differing from spec file fails spec-anchor"
else
  fail "z6: tracker sha differing from spec file fails spec-anchor (code ${Z_CODE})"
fi

# (z7) prompt sequence absent from the Run Log.
FIX7="${ZBASE}/z7"
cp -a "${ZGOOD}" "${FIX7}"
sed -i '/| 001/d' "${FIX7}/.fixture-state.md"
z_run "${FIX7}"
if [[ "${Z_CODE}" -eq 1 ]] && printf '%s\n' "${Z_OUT}" | grep -q '^FAIL run-log-coverage'; then
  pass "z7: prompt seq absent from Run Log fails run-log-coverage"
else
  fail "z7: prompt seq absent from Run Log fails run-log-coverage (code ${Z_CODE})"
fi

# (z8) state file without a Compliance Epoch section.
FIX8="${ZBASE}/z8"
cp -a "${ZGOOD}" "${FIX8}"
sed -i '/^## Compliance Epoch/,$d' "${FIX8}/.fixture-state.md"
z_run "${FIX8}"
if [[ "${Z_CODE}" -eq 1 ]] \
  && printf '%s\n' "${Z_OUT}" | grep -q '^FAIL publish-form' \
  && printf '%s\n' "${Z_OUT}" | grep -q '^FAIL run-log-coverage'; then
  pass "z8: missing Compliance Epoch fails publish-form and run-log-coverage"
else
  fail "z8: missing Compliance Epoch fails publish-form and run-log-coverage (code ${Z_CODE})"
fi

rm -rf "${ZBASE}"

# ---------------------------------------------------------------------------
# Stages (ab)-(af): default-apps-editor — stub xdg-mime, fake HOME, fake
# XDG_DATA_DIRS tree of small .desktop files. No stage touches the real
# ~/.config/mimeapps.list, the real application directories, or a real
# xdg-mime; the stub below stands in for xdg-mime on PATH.
# ---------------------------------------------------------------------------

DA_MODULE="${REPO_ROOT}/modules/default-apps-editor/module.sh"
DA_STUB_ROOT="${TMPBASE}/da-stubs"
DA_DATA="${TMPBASE}/da-data"
DA_STATE_REL=".local/state/mintbutler/default-apps-editor"
mkdir -p "${DA_STUB_ROOT}" "${DA_DATA}/applications"

# Stub: xdg-mime with the same user-level config file the real tool uses
# (${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list). "default <id> <mime>"
# assigns, "query default <mime>" reports. Simplification, honest for a
# stub: <mime>= lines are matched anywhere in the file. Setting
# XDG_MIME_STUB_QUERY_ALWAYS=<id> makes every query report <id> instead —
# used to exercise the verify-mismatch rollback.
cat <<'DA_XDG_MIME_STUB' > "${DA_STUB_ROOT}/xdg-mime"
#!/usr/bin/env bash
set -euo pipefail
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
op="${1:-}"
case "${op}" in
  default)
    app_id="${2:-}"
    mime="${3:-}"
    if [[ -z "${app_id}" || -z "${mime}" ]]; then
      printf 'xdg-mime-stub: default needs <app>.desktop and <mime>\n' >&2
      exit 2
    fi
    mkdir -p "$(dirname "${CONFIG}")"
    [[ -f "${CONFIG}" ]] || : > "${CONFIG}"
    tmpout="${CONFIG}.stub-tmp.$$"
    keep=0
    : > "${tmpout}"
    while IFS= read -r ln || [[ -n "${ln}" ]]; do
      if [[ "${ln}" == "["*"]" ]]; then
        keep=0
        if [[ "${ln}" == "[Default Applications]" ]]; then
          keep=1
        fi
      fi
      if [[ "${keep}" == "1" && "${ln}" == "${mime}="* ]]; then
        continue
      fi
      printf '%s\n' "${ln}" >> "${tmpout}"
    done < "${CONFIG}"
    printf '%s=%s\n' "${mime}" "${app_id}" >> "${tmpout}"
    mv "${tmpout}" "${CONFIG}"
    exit 0
    ;;
  query)
    sub="${2:-}"
    mime="${3:-}"
    if [[ "${sub}" != "default" || -z "${mime}" ]]; then
      exit 0
    fi
    if [[ -n "${XDG_MIME_STUB_QUERY_ALWAYS:-}" ]]; then
      printf '%s\n' "${XDG_MIME_STUB_QUERY_ALWAYS}"
      exit 0
    fi
    found=""
    if [[ -f "${CONFIG}" ]]; then
      while IFS= read -r ln || [[ -n "${ln}" ]]; do
        if [[ "${ln}" == "${mime}="* ]]; then
          found="${ln#*=}"
        fi
      done < "${CONFIG}"
    fi
    if [[ -n "${found}" ]]; then
      printf '%s\n' "${found}"
    fi
    exit 0
    ;;
  *)
    printf 'xdg-mime-stub: unsupported operation: %s\n' "${op}" >&2
    exit 2
    ;;
esac
DA_XDG_MIME_STUB
chmod +x "${DA_STUB_ROOT}/xdg-mime"

# Fake XDG_DATA_DIRS tree of small .desktop files. No file claims
# application/zip — stage (ae) relies on that.
cat <<'EOF' > "${DA_DATA}/applications/firefox.desktop"
[Desktop Entry]
Type=Application
Name=Firefox Web Browser
Exec=firefox %u
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
EOF
cat <<'EOF' > "${DA_DATA}/applications/web-epiphany.desktop"
[Desktop Entry]
Type=Application
Name=Web
Exec=epiphany %u
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
EOF
cat <<'EOF' > "${DA_DATA}/applications/image-viewer.desktop"
[Desktop Entry]
Type=Application
Name=Image Viewer
Exec=eog %f
MimeType=image/png;image/jpeg;
EOF
cat <<'EOF' > "${DA_DATA}/applications/video-player.desktop"
[Desktop Entry]
Type=Application
Name=Video Player
Exec=mpv %f
MimeType=video/mp4;
EOF
cat <<'EOF' > "${DA_DATA}/applications/no-mime.desktop"
[Desktop Entry]
Type=Application
Name=No Mime App
Exec=/usr/bin/true
EOF

# Stage (ab): gate, scan, list, plan/dry-run screens, non-interactive run.
printf 'Stage ab: default-apps-editor gate, scan, list, plan, non-interactive\n'
output_ab_scan=""
code_ab_scan="0"
output_ab_scan="$(cd "${REPO_ROOT}" && ./butler --scan 2>&1)" || code_ab_scan="$?"
if [[ "${code_ab_scan}" -ne 0 ]]; then
  fail "butler --scan exits 0 with default-apps-editor present (got ${code_ab_scan})"
else
  pass "butler --scan exits 0 with default-apps-editor present"
fi
if printf '%s\n' "${output_ab_scan}" | grep -q "PASS default-apps-editor"; then
  pass "butler --scan reports PASS default-apps-editor"
else
  fail "butler --scan reports PASS default-apps-editor"
fi

output_ab_lint=""
code_ab_lint="0"
output_ab_lint="$(cd "${REPO_ROOT}" && bin/modulelint 2>&1)" || code_ab_lint="$?"
if [[ "${code_ab_lint}" -ne 0 ]]; then
  fail "bin/modulelint exits 0 with default-apps-editor present (got ${code_ab_lint})"
else
  pass "bin/modulelint exits 0 with default-apps-editor present"
fi
if printf '%s\n' "${output_ab_lint}" | grep -q "PASS default-apps-editor"; then
  pass "bin/modulelint reports PASS default-apps-editor"
else
  fail "bin/modulelint reports PASS default-apps-editor"
fi

output_ab_list=""
code_ab_list="0"
output_ab_list="$(cd "${REPO_ROOT}" && ./butler --list 2>&1)" || code_ab_list="$?"
if [[ "${code_ab_list}" -ne 0 ]]; then
  fail "butler --list exits 0 (got ${code_ab_list})"
else
  pass "butler --list exits 0"
fi
if printf '%s\n' "${output_ab_list}" | grep -q "default-apps-editor: Default apps editor"; then
  pass "butler --list shows default-apps-editor: Default apps editor"
else
  fail "butler --list shows default-apps-editor: Default apps editor"
fi
if printf '%s\n' "${output_ab_list}" | grep -q "desktop-shortcut-creator" \
  && printf '%s\n' "${output_ab_list}" | grep -q "screenshot-studio"; then
  pass "butler --list still shows the earlier modules"
else
  fail "butler --list still shows the earlier modules"
fi

DA_AB_HOME="${TMPBASE}/da-home-ab"
mkdir -p "${DA_AB_HOME}"
output_ab_plan=""
code_ab_plan="0"
output_ab_plan="$(PATH="${DA_STUB_ROOT}:${PATH}" HOME="${DA_AB_HOME}" XDG_DATA_DIRS="${DA_DATA}" \
  bash "${DA_MODULE}" plan < /dev/null 2>&1)" || code_ab_plan="$?"
da_ab_plan_lines="$(printf '%s\n' "${output_ab_plan}" | wc -l)"
if [[ "${code_ab_plan}" -eq 0 && -n "${output_ab_plan}" ]]; then
  pass "plan exits 0 with output"
else
  fail "plan exits 0 with output (got ${code_ab_plan})"
fi
if [[ "${da_ab_plan_lines}" -le 23 ]]; then
  pass "plan fits the 23-line law (${da_ab_plan_lines} lines)"
else
  fail "plan fits the 23-line law (${da_ab_plan_lines} lines)"
fi

output_ab_dry=""
code_ab_dry="0"
output_ab_dry="$(PATH="${DA_STUB_ROOT}:${PATH}" HOME="${DA_AB_HOME}" XDG_DATA_DIRS="${DA_DATA}" \
  bash "${DA_MODULE}" dry-run < /dev/null 2>&1)" || code_ab_dry="$?"
da_ab_dry_lines="$(printf '%s\n' "${output_ab_dry}" | wc -l)"
if [[ "${code_ab_dry}" -eq 0 && -n "${output_ab_dry}" ]]; then
  pass "dry-run exits 0 with output"
else
  fail "dry-run exits 0 with output (got ${code_ab_dry})"
fi
if [[ "${da_ab_dry_lines}" -le 23 ]]; then
  pass "dry-run fits the 23-line law (${da_ab_dry_lines} lines)"
else
  fail "dry-run fits the 23-line law (${da_ab_dry_lines} lines)"
fi
if printf '%s\n' "${output_ab_dry}" | grep -q "xdg-mime query default" \
  && printf '%s\n' "${output_ab_dry}" | grep -q "xdg-mime default"; then
  pass "dry-run shows the exact xdg-mime commands in query form"
else
  fail "dry-run shows the exact xdg-mime commands in query form"
fi
if printf '%s\n' "${output_ab_dry}" | grep -q "mimeapps.list.backup"; then
  pass "dry-run shows the backup path"
else
  fail "dry-run shows the backup path"
fi

DA_AB_HOME2="${TMPBASE}/da-home-ab2"
DA_AB_HOME2_BEFORE="${TMPBASE}/da-home-ab2-before"
mkdir -p "${DA_AB_HOME2}"
cp -a "${DA_AB_HOME2}" "${DA_AB_HOME2_BEFORE}"
stderr_ab=""
code_ab_run="0"
stderr_ab="$(cd "${REPO_ROOT}" && PATH="${DA_STUB_ROOT}:${PATH}" HOME="${DA_AB_HOME2}" XDG_DATA_DIRS="${DA_DATA}" \
  bash modules/default-apps-editor/module.sh run < /dev/null 2>&1 >/dev/null)" || code_ab_run="$?"
if [[ "${code_ab_run}" -eq 1 ]]; then
  pass "non-interactive run exits 1"
else
  fail "non-interactive run exits 1 (got ${code_ab_run})"
fi
da_ab_err_lines="$(printf '%s\n' "${stderr_ab}" | grep -c . || true)"
if [[ "${da_ab_err_lines}" == "1" ]] && printf '%s\n' "${stderr_ab}" | grep -qi "interactive"; then
  pass "non-interactive run prints one plain stderr line"
else
  fail "non-interactive run prints one plain stderr line (got ${da_ab_err_lines} lines)"
fi
if diff -r "${DA_AB_HOME2}" "${DA_AB_HOME2_BEFORE}" >/dev/null 2>&1; then
  pass "non-interactive run writes nothing to the fake HOME"
else
  fail "non-interactive run modified the fake HOME"
fi

# Stage (ac): happy path — category 1, app 1, confirm y.
printf 'Stage ac: default-apps-editor happy path\n'
DA_AC_HOME="${TMPBASE}/da-home-ac"
mkdir -p "${DA_AC_HOME}/.config"
DA_AC_CONFIG="${DA_AC_HOME}/.config/mimeapps.list"
DA_AC_PRERUN="${TMPBASE}/da-ac-prerun.mimeapps"
cat <<'EOF' > "${DA_AC_CONFIG}"
[Default Applications]
text/plain=org.gnome.gedit.desktop
EOF
cp "${DA_AC_CONFIG}" "${DA_AC_PRERUN}"
output_ac=""
code_ac="0"
output_ac="$(printf '1\n1\ny\n' | PATH="${DA_STUB_ROOT}:${PATH}" HOME="${DA_AC_HOME}" XDG_DATA_DIRS="${DA_DATA}" \
  bash "${DA_MODULE}" run 2>&1)" || code_ac="$?"
if [[ "${code_ac}" -eq 0 ]]; then
  pass "happy path run exits 0"
else
  fail "happy path run exits 0 (got ${code_ac})"
fi
if printf '%s\n' "${output_ac}" | grep -q "current:" && printf '%s\n' "${output_ac}" | grep -q "new:"; then
  pass "happy path output shows current-versus-new"
else
  fail "happy path output shows current-versus-new"
fi
for da_type in text/html x-scheme-handler/http x-scheme-handler/https; do
  if grep -q "^${da_type}=firefox.desktop$" "${DA_AC_CONFIG}"; then
    pass "mimeapps.list assigns firefox.desktop to ${da_type}"
  else
    fail "mimeapps.list assigns firefox.desktop to ${da_type}"
  fi
done
if grep -q "^text/plain=org.gnome.gedit.desktop$" "${DA_AC_CONFIG}"; then
  pass "mimeapps.list keeps the pre-existing assignment"
else
  fail "mimeapps.list lost the pre-existing assignment"
fi
DA_AC_STATE="${DA_AC_HOME}/${DA_STATE_REL}"
if [[ -f "${DA_AC_STATE}/mimeapps.list.backup" ]] \
  && cmp -s "${DA_AC_STATE}/mimeapps.list.backup" "${DA_AC_PRERUN}"; then
  pass "state dir holds the backup byte-equal to the pre-run file"
else
  fail "state dir holds the backup byte-equal to the pre-run file"
fi
if [[ -f "${DA_AC_STATE}/changes.record" ]] \
  && grep -q "ASSIGNED text/html=firefox.desktop" "${DA_AC_STATE}/changes.record"; then
  pass "state dir holds a changes record"
else
  fail "state dir holds a changes record"
fi

# Stage (ad): undo after (ac) restores the pre-run file exactly.
printf 'Stage ad: default-apps-editor undo\n'
output_ad=""
code_ad="0"
output_ad="$(HOME="${DA_AC_HOME}" bash "${DA_MODULE}" undo < /dev/null 2>&1)" || code_ad="$?"
if [[ "${code_ad}" -eq 0 ]]; then
  pass "undo exits 0"
else
  fail "undo exits 0 (got ${code_ad})"
fi
if cmp -s "${DA_AC_CONFIG}" "${DA_AC_PRERUN}"; then
  pass "undo restores mimeapps.list byte-identical to the pre-run file"
else
  fail "undo did not restore mimeapps.list byte-identically"
fi
if [[ ! -d "${DA_AC_STATE}" ]]; then
  pass "undo deletes the state dir"
else
  fail "undo left the state dir behind"
fi
if printf '%s\n' "${output_ad}" | grep -q "x-scheme-handler/https=firefox.desktop" \
  && printf '%s\n' "${output_ad}" | grep -q "x-scheme-handler/http=firefox.desktop" \
  && printf '%s\n' "${output_ad}" | grep -q "text/html=firefox.desktop"; then
  if [[ "$(printf '%s\n' "${output_ad}" | grep -n "x-scheme-handler/https=firefox.desktop" | cut -d: -f1)" -lt "$(printf '%s\n' "${output_ad}" | grep -n "text/html=firefox.desktop" | cut -d: -f1)" ]]; then
    pass "undo prints the recorded assignments reversed"
  else
    fail "undo printed assignments in forward order"
  fi
else
  fail "undo prints the recorded assignments reversed"
fi
output_ad2=""
code_ad2="0"
output_ad2="$(HOME="${DA_AC_HOME}" bash "${DA_MODULE}" undo < /dev/null 2>&1)" || code_ad2="$?"
if [[ "${code_ad2}" -eq 0 ]] && printf '%s\n' "${output_ad2}" | grep -qi "nothing to undo"; then
  pass "second undo reports Nothing to undo and exits 0"
else
  fail "second undo reports Nothing to undo and exits 0 (got ${code_ad2})"
fi

# Stage (ae): no-candidate path — nothing claims application/zip.
printf 'Stage ae: default-apps-editor no-candidate path\n'
DA_AE_HOME="${TMPBASE}/da-home-ae"
DA_AE_HOME_BEFORE="${TMPBASE}/da-home-ae-before"
mkdir -p "${DA_AE_HOME}"
cp -a "${DA_AE_HOME}" "${DA_AE_HOME_BEFORE}"
stderr_ae=""
code_ae="0"
stderr_ae="$(printf '8\n' | PATH="${DA_STUB_ROOT}:${PATH}" HOME="${DA_AE_HOME}" XDG_DATA_DIRS="${DA_DATA}" \
  bash "${DA_MODULE}" run 2>&1 >/dev/null)" || code_ae="$?"
if [[ "${code_ae}" -eq 1 ]]; then
  pass "no-candidate run exits 1"
else
  fail "no-candidate run exits 1 (got ${code_ae})"
fi
if printf '%s\n' "${stderr_ae}" | grep -q "application/zip"; then
  pass "no-candidate line names the type searched"
else
  fail "no-candidate line names the type searched"
fi
if diff -r "${DA_AE_HOME}" "${DA_AE_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "no-candidate run writes nothing (no state dir)"
else
  fail "no-candidate run modified the fake HOME"
fi

# Stage (af): verification-failure path — the stub accepts writes but every
# query reports a different app; the module must roll the file back.
printf 'Stage af: default-apps-editor verify-failure rollback\n'
DA_AF_HOME="${TMPBASE}/da-home-af"
mkdir -p "${DA_AF_HOME}/.config"
DA_AF_CONFIG="${DA_AF_HOME}/.config/mimeapps.list"
DA_AF_PRERUN="${TMPBASE}/da-af-prerun.mimeapps"
cat <<'EOF' > "${DA_AF_CONFIG}"
[Default Applications]
video/mp4=old-player.desktop
EOF
cp "${DA_AF_CONFIG}" "${DA_AF_PRERUN}"
stderr_af=""
code_af="0"
stderr_af="$(printf '4\n1\ny\n' | PATH="${DA_STUB_ROOT}:${PATH}" HOME="${DA_AF_HOME}" XDG_DATA_DIRS="${DA_DATA}" \
  XDG_MIME_STUB_QUERY_ALWAYS=someone-else.desktop bash "${DA_MODULE}" run 2>&1 >/dev/null)" || code_af="$?"
if [[ "${code_af}" -eq 1 ]]; then
  pass "verify-failure run exits 1"
else
  fail "verify-failure run exits 1 (got ${code_af})"
fi
if printf '%s\n' "${stderr_af}" | grep -qi "verification failed"; then
  pass "verify-failure prints a plain error"
else
  fail "verify-failure prints a plain error"
fi
if cmp -s "${DA_AF_CONFIG}" "${DA_AF_PRERUN}"; then
  pass "verify-failure auto-restores the file byte-equal to the pre-run state"
else
  fail "verify-failure did not restore the file byte-for-byte"
fi
if [[ ! -d "${DA_AF_HOME}/${DA_STATE_REL}" ]]; then
  pass "verify-failure leaves no state dir"
else
  fail "verify-failure left a state dir behind"
fi

# ---------------------------------------------------------------------------
# Stages (ag)-(al): appimage-installer — fake HOMEs and temp .AppImage
# fixture files (a few bytes) only; never real HOME state. Entry writing
# and state recording go through the shared lib/desktop-entry.sh, so the
# assertions mirror that library's layout.
# ---------------------------------------------------------------------------

AI_MODULE="${REPO_ROOT}/modules/appimage-installer/module.sh"
AI_FIXTURES="${TMPBASE}/ai-fixtures"
AI_SYS_EMPTY="${TMPBASE}/ai-sys-empty"
mkdir -p "${AI_FIXTURES}" "${AI_SYS_EMPTY}"
printf '#!/bin/sh\necho mintbutler appimage fixture\n' > "${AI_FIXTURES}/My_App-v1.AppImage"
cp -a "${AI_FIXTURES}/My_App-v1.AppImage" "${AI_FIXTURES}/My_App-v1.orig"
printf 'just a small text file, not an AppImage\n' > "${AI_FIXTURES}/notes.txt"
AI_INSTALL_REL=".local/share/mintbutler-appimages"
AI_APPS_REL=".local/share/applications"
AI_STATE_REL=".local/state/mintbutler/appimage-installer"

# Stage (ag): gate, scan, --list position, plan/dry-run screens,
# non-interactive run.
printf 'Stage ag: appimage-installer gate, scan, list, plan, non-interactive\n'
output_ag_scan=""
code_ag_scan="0"
output_ag_scan="$(cd "${REPO_ROOT}" && ./butler --scan 2>&1)" || code_ag_scan="$?"
if [[ "${code_ag_scan}" -ne 0 ]]; then
  fail "butler --scan exits 0 with appimage-installer present (got ${code_ag_scan})"
else
  pass "butler --scan exits 0 with appimage-installer present"
fi
if printf '%s\n' "${output_ag_scan}" | grep -q "PASS appimage-installer"; then
  pass "butler --scan reports PASS appimage-installer"
else
  fail "butler --scan reports PASS appimage-installer"
fi

output_ag_lint=""
code_ag_lint="0"
output_ag_lint="$(cd "${REPO_ROOT}" && bin/modulelint 2>&1)" || code_ag_lint="$?"
if [[ "${code_ag_lint}" -ne 0 ]]; then
  fail "bin/modulelint exits 0 with appimage-installer present (got ${code_ag_lint})"
else
  pass "bin/modulelint exits 0 with appimage-installer present"
fi
if printf '%s\n' "${output_ag_lint}" | grep -q "PASS appimage-installer"; then
  pass "bin/modulelint reports PASS appimage-installer"
else
  fail "bin/modulelint reports PASS appimage-installer"
fi

output_ag_list=""
code_ag_list="0"
output_ag_list="$(cd "${REPO_ROOT}" && ./butler --list 2>&1)" || code_ag_list="$?"
if [[ "${code_ag_list}" -ne 0 ]]; then
  fail "butler --list exits 0 (got ${code_ag_list})"
else
  pass "butler --list exits 0"
fi
if [[ "$(printf '%s\n' "${output_ag_list}" | head -n 1)" == "appimage-installer: AppImage installer" ]]; then
  pass "butler --list shows appimage-installer first (order 10)"
else
  fail "butler --list shows appimage-installer first (order 10)"
fi
if printf '%s\n' "${output_ag_list}" | grep -q "desktop-shortcut-creator" \
  && printf '%s\n' "${output_ag_list}" | grep -q "default-apps-editor" \
  && printf '%s\n' "${output_ag_list}" | grep -q "screenshot-studio"; then
  pass "butler --list still shows the earlier modules"
else
  fail "butler --list still shows the earlier modules"
fi

AI_AG_HOME="${TMPBASE}/ai-home-ag"
AI_AG_HOME_BEFORE="${TMPBASE}/ai-home-ag-before"
mkdir -p "${AI_AG_HOME}"
cp -a "${AI_AG_HOME}" "${AI_AG_HOME_BEFORE}"
output_ag_plan=""
code_ag_plan="0"
output_ag_plan="$(HOME="${AI_AG_HOME}" bash "${AI_MODULE}" plan < /dev/null 2>&1)" || code_ag_plan="$?"
ai_ag_plan_lines="$(printf '%s\n' "${output_ag_plan}" | wc -l)"
if [[ "${code_ag_plan}" -eq 0 && -n "${output_ag_plan}" ]]; then
  pass "plan exits 0 with output"
else
  fail "plan exits 0 with output (got ${code_ag_plan})"
fi
if [[ "${ai_ag_plan_lines}" -le 23 ]]; then
  pass "plan fits the 23-line law (${ai_ag_plan_lines} lines)"
else
  fail "plan fits the 23-line law (${ai_ag_plan_lines} lines)"
fi
output_ag_dry=""
code_ag_dry="0"
output_ag_dry="$(HOME="${AI_AG_HOME}" bash "${AI_MODULE}" dry-run < /dev/null 2>&1)" || code_ag_dry="$?"
ai_ag_dry_lines="$(printf '%s\n' "${output_ag_dry}" | wc -l)"
if [[ "${code_ag_dry}" -eq 0 && -n "${output_ag_dry}" ]]; then
  pass "dry-run exits 0 with output"
else
  fail "dry-run exits 0 with output (got ${code_ag_dry})"
fi
if [[ "${ai_ag_dry_lines}" -le 23 ]]; then
  pass "dry-run fits the 23-line law (${ai_ag_dry_lines} lines)"
else
  fail "dry-run fits the 23-line law (${ai_ag_dry_lines} lines)"
fi
if printf '%s\n' "${output_ag_dry}" | grep -q "mintbutler-appimages" \
  && printf '%s\n' "${output_ag_dry}" | grep -q "/applications"; then
  pass "dry-run names the install dir and the applications dir"
else
  fail "dry-run names the install dir and the applications dir"
fi
if diff -r "${AI_AG_HOME}" "${AI_AG_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "plan and dry-run write nothing to the fake HOME"
else
  fail "plan and dry-run modified the fake HOME"
fi

AI_AG_XDG_DATA="${TMPBASE}/ai-xdg-data"
mkdir -p "${AI_AG_XDG_DATA}"
output_ag_xdg=""
code_ag_xdg="0"
output_ag_xdg="$(HOME="${AI_AG_HOME}" XDG_DATA_HOME="${AI_AG_XDG_DATA}" bash "${AI_MODULE}" dry-run < /dev/null 2>&1)" || code_ag_xdg="$?"
if [[ "${code_ag_xdg}" -eq 0 ]] \
  && printf '%s\n' "${output_ag_xdg}" | grep -Fq "install dir:      ${AI_AG_HOME}/.local/share/mintbutler-appimages" \
  && printf '%s\n' "${output_ag_xdg}" | grep -Fq "applications dir: ${AI_AG_XDG_DATA}/applications"; then
  pass "dry-run keeps the managed copy under HOME and follows XDG for applications"
else
  fail "dry-run keeps the managed copy under HOME and follows XDG for applications"
fi

AI_AG_Q_HOME="${TMPBASE}/ai-home-ag-q"
AI_AG_Q_BEFORE="${TMPBASE}/ai-home-ag-q-before"
mkdir -p "${AI_AG_Q_HOME}"
cp -a "${AI_AG_Q_HOME}" "${AI_AG_Q_BEFORE}"
output_ag_q=""
code_ag_q="0"
output_ag_q="$(printf 'q\n' | HOME="${AI_AG_Q_HOME}" bash "${AI_MODULE}" run 2>&1)" || code_ag_q="$?"
if [[ "${code_ag_q}" -eq 0 ]] && printf '%s\n' "${output_ag_q}" | grep -q "Nothing changed."; then
  pass "q at the first question aborts cleanly"
else
  fail "q at the first question aborts cleanly"
fi
if diff -r "${AI_AG_Q_HOME}" "${AI_AG_Q_BEFORE}" >/dev/null 2>&1; then
  pass "q at the first question writes nothing"
else
  fail "q at the first question modified the fake HOME"
fi

AI_AG_HOME2="${TMPBASE}/ai-home-ag2"
AI_AG_HOME2_BEFORE="${TMPBASE}/ai-home-ag2-before"
mkdir -p "${AI_AG_HOME2}"
cp -a "${AI_AG_HOME2}" "${AI_AG_HOME2_BEFORE}"
stderr_ag=""
code_ag_run="0"
stderr_ag="$(HOME="${AI_AG_HOME2}" bash "${AI_MODULE}" run < /dev/null 2>&1 >/dev/null)" || code_ag_run="$?"
if [[ "${code_ag_run}" -eq 1 ]]; then
  pass "non-interactive run exits 1"
else
  fail "non-interactive run exits 1 (got ${code_ag_run})"
fi
ai_ag_err_lines="$(printf '%s\n' "${stderr_ag}" | grep -c . || true)"
if [[ "${ai_ag_err_lines}" == "1" ]] && printf '%s\n' "${stderr_ag}" | grep -qi "interactive"; then
  pass "non-interactive run prints one plain stderr line"
else
  fail "non-interactive run prints one plain stderr line (got ${ai_ag_err_lines} lines)"
fi
if diff -r "${AI_AG_HOME2}" "${AI_AG_HOME2_BEFORE}" >/dev/null 2>&1; then
  pass "non-interactive run writes nothing to the fake HOME"
else
  fail "non-interactive run modified the fake HOME"
fi

# Stage (ah): happy path — path, Enter (accept derived name), y.
printf 'Stage ah: appimage-installer happy path\n'
AI_AH_HOME="${TMPBASE}/ai-home-ah"
mkdir -p "${AI_AH_HOME}"
AI_AH_INSTALL="${AI_AH_HOME}/${AI_INSTALL_REL}"
AI_AH_APPS="${AI_AH_HOME}/${AI_APPS_REL}"
AI_AH_COPY="${AI_AH_INSTALL}/my-app-v1.AppImage"
AI_AH_ENTRY="${AI_AH_APPS}/my-app-v1.desktop"
AI_AH_STATE="${AI_AH_HOME}/${AI_STATE_REL}/my-app-v1.paths"
output_ah=""
code_ah="0"
output_ah="$(printf '%s\n\ny\n' "${AI_FIXTURES}/My_App-v1.AppImage" | \
  MINTBUTLER_TEST_APP_DIRS="${AI_SYS_EMPTY}" HOME="${AI_AH_HOME}" \
  bash "${AI_MODULE}" run 2>&1)" || code_ah="$?"
if [[ "${code_ah}" -eq 0 ]]; then
  pass "happy path run exits 0"
else
  fail "happy path run exits 0 (got ${code_ah})"
fi
if [[ -f "${AI_AH_COPY}" && -x "${AI_AH_COPY}" ]] \
  && cmp -s "${AI_AH_COPY}" "${AI_FIXTURES}/My_App-v1.AppImage"; then
  pass "installed copy exists, is executable, and is byte-equal to the fixture"
else
  fail "installed copy exists, is executable, and is byte-equal to the fixture"
fi
if [[ -f "${AI_AH_ENTRY}" ]] \
  && grep -Fq "Exec=${AI_AH_COPY}" "${AI_AH_ENTRY}"; then
  pass "menu entry exists with Exec pointing at the installed copy"
else
  fail "menu entry exists with Exec pointing at the installed copy"
fi
if [[ -f "${AI_AH_ENTRY}" ]] && grep -q "^Name=My App v1$" "${AI_AH_ENTRY}"; then
  pass "menu entry carries the derived default name"
else
  fail "menu entry carries the derived default name"
fi
if [[ -f "${AI_AH_STATE}" ]] \
  && grep -Fq "${AI_AH_ENTRY}" "${AI_AH_STATE}" \
  && grep -Fq "${AI_AH_COPY}" "${AI_AH_STATE}"; then
  pass "state records both the entry and the installed copy"
else
  fail "state records both the entry and the installed copy"
fi
if cmp -s "${AI_FIXTURES}/My_App-v1.AppImage" "${AI_FIXTURES}/My_App-v1.orig"; then
  pass "original fixture file is unchanged"
else
  fail "original fixture file was modified"
fi

# Stage (ai): idempotency — same fixture, same answers, second run.
printf 'Stage ai: appimage-installer idempotency\n'
output_ai=""
code_ai="0"
output_ai="$(printf '%s\n\ny\n' "${AI_FIXTURES}/My_App-v1.AppImage" | \
  MINTBUTLER_TEST_APP_DIRS="${AI_SYS_EMPTY}" HOME="${AI_AH_HOME}" \
  bash "${AI_MODULE}" run 2>&1)" || code_ai="$?"
if [[ "${code_ai}" -eq 0 ]]; then
  pass "second run exits 0"
else
  fail "second run exits 0 (got ${code_ai})"
fi
if printf '%s\n' "${output_ai}" | grep -qi "already"; then
  pass "second run reports already-done/reuse"
else
  fail "second run reports already-done/reuse"
fi
if [[ ! -e "${AI_AH_INSTALL}/my-app-v1-2.AppImage" ]]; then
  pass "no -2 copy is created on the identical re-run"
else
  fail "no -2 copy is created on the identical re-run"
fi
if [[ ! -e "${AI_AH_APPS}/my-app-v1-2.desktop" ]]; then
  pass "no second entry is created on the identical re-run"
else
  fail "no second entry is created on the identical re-run"
fi

# Stage (aj): undo after (ah) — entry, copy, and state all removed.
printf 'Stage aj: appimage-installer undo\n'
output_aj=""
code_aj="0"
output_aj="$(HOME="${AI_AH_HOME}" bash "${AI_MODULE}" undo < /dev/null 2>&1)" || code_aj="$?"
if [[ "${code_aj}" -eq 0 ]]; then
  pass "undo exits 0"
else
  fail "undo exits 0 (got ${code_aj})"
fi
if [[ ! -e "${AI_AH_ENTRY}" ]]; then
  pass "undo removes the menu entry"
else
  fail "undo removes the menu entry"
fi
if [[ ! -e "${AI_AH_COPY}" ]]; then
  pass "undo removes the installed copy"
else
  fail "undo removes the installed copy"
fi
if [[ ! -d "${AI_AH_HOME}/${AI_STATE_REL}" ]]; then
  pass "undo removes the state records"
else
  fail "undo removes the state records"
fi
if cmp -s "${AI_FIXTURES}/My_App-v1.AppImage" "${AI_FIXTURES}/My_App-v1.orig"; then
  pass "undo leaves the original fixture untouched"
else
  fail "undo modified the original fixture"
fi
output_aj2=""
code_aj2="0"
output_aj2="$(HOME="${AI_AH_HOME}" bash "${AI_MODULE}" undo < /dev/null 2>&1)" || code_aj2="$?"
if [[ "${code_aj2}" -eq 0 ]] && printf '%s\n' "${output_aj2}" | grep -qi "nothing to undo"; then
  pass "second undo reports Nothing to undo and exits 0"
else
  fail "second undo reports Nothing to undo and exits 0 (got ${code_aj2})"
fi

# Stage (ak): error paths — nonexistent file and wrong extension.
printf 'Stage ak: appimage-installer error paths\n'
AI_AK_HOME="${TMPBASE}/ai-home-ak"
AI_AK_HOME_BEFORE="${TMPBASE}/ai-home-ak-before"
mkdir -p "${AI_AK_HOME}"
cp -a "${AI_AK_HOME}" "${AI_AK_HOME_BEFORE}"
stderr_ak1=""
code_ak1="0"
stderr_ak1="$(printf '/definitely/not/here.AppImage\n' | \
  MINTBUTLER_TEST_APP_DIRS="${AI_SYS_EMPTY}" HOME="${AI_AK_HOME}" \
  bash "${AI_MODULE}" run 2>&1 >/dev/null)" || code_ak1="$?"
if [[ "${code_ak1}" -eq 1 ]]; then
  pass "nonexistent path exits 1"
else
  fail "nonexistent path exits 1 (got ${code_ak1})"
fi
if printf '%s\n' "${stderr_ak1}" | grep -qi "no such file"; then
  pass "nonexistent path prints a plain error"
else
  fail "nonexistent path prints a plain error"
fi
if diff -r "${AI_AK_HOME}" "${AI_AK_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "nonexistent path writes nothing"
else
  fail "nonexistent path modified the fake HOME"
fi
stderr_ak2=""
code_ak2="0"
stderr_ak2="$(printf '%s\n' "${AI_FIXTURES}/notes.txt" | \
  MINTBUTLER_TEST_APP_DIRS="${AI_SYS_EMPTY}" HOME="${AI_AK_HOME}" \
  bash "${AI_MODULE}" run 2>&1 >/dev/null)" || code_ak2="$?"
if [[ "${code_ak2}" -eq 1 ]]; then
  pass "wrong extension exits 1"
else
  fail "wrong extension exits 1 (got ${code_ak2})"
fi
if printf '%s\n' "${stderr_ak2}" | grep -qi "appimage"; then
  pass "wrong extension prints a plain error"
else
  fail "wrong extension prints a plain error"
fi
if diff -r "${AI_AK_HOME}" "${AI_AK_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "wrong extension writes nothing"
else
  fail "wrong extension modified the fake HOME"
fi

# Stage (al): copy-name collisions — different bytes version, identical
# bytes reuse.
printf 'Stage al: appimage-installer collision versioning and reuse\n'
AI_AL_HOME="${TMPBASE}/ai-home-al"
AI_AL_INSTALL="${AI_AL_HOME}/${AI_INSTALL_REL}"
AI_AL_APPS="${AI_AL_HOME}/${AI_APPS_REL}"
mkdir -p "${AI_AL_INSTALL}"
printf 'pre-existing different bytes\n' > "${AI_AL_INSTALL}/my-app-v1.AppImage"
cp -a "${AI_AL_INSTALL}/my-app-v1.AppImage" "${TMPBASE}/ai-al-seed.ref"
output_al=""
code_al="0"
output_al="$(printf '%s\n\ny\n' "${AI_FIXTURES}/My_App-v1.AppImage" | \
  MINTBUTLER_TEST_APP_DIRS="${AI_SYS_EMPTY}" HOME="${AI_AL_HOME}" \
  bash "${AI_MODULE}" run 2>&1)" || code_al="$?"
if [[ "${code_al}" -eq 0 ]]; then
  pass "collision run exits 0"
else
  fail "collision run exits 0 (got ${code_al})"
fi
if [[ -f "${AI_AL_INSTALL}/my-app-v1-2.AppImage" ]] \
  && cmp -s "${AI_AL_INSTALL}/my-app-v1-2.AppImage" "${AI_FIXTURES}/My_App-v1.AppImage"; then
  pass "different existing copy shifts the install to a -2 copy"
else
  fail "different existing copy shifts the install to a -2 copy"
fi
if cmp -s "${AI_AL_INSTALL}/my-app-v1.AppImage" "${TMPBASE}/ai-al-seed.ref"; then
  pass "pre-existing different copy is left untouched"
else
  fail "pre-existing different copy was modified"
fi
if [[ -f "${AI_AL_APPS}/my-app-v1.desktop" ]] \
  && grep -Fq "Exec=${AI_AL_INSTALL}/my-app-v1-2.AppImage" "${AI_AL_APPS}/my-app-v1.desktop"; then
  pass "entry points at the -2 copy"
else
  fail "entry points at the -2 copy"
fi

AI_AL2_HOME="${TMPBASE}/ai-home-al2"
AI_AL2_INSTALL="${AI_AL2_HOME}/${AI_INSTALL_REL}"
AI_AL2_APPS="${AI_AL2_HOME}/${AI_APPS_REL}"
mkdir -p "${AI_AL2_INSTALL}"
cp "${AI_FIXTURES}/My_App-v1.AppImage" "${AI_AL2_INSTALL}/my-app-v1.AppImage"
output_al2=""
code_al2="0"
output_al2="$(printf '%s\n\ny\n' "${AI_FIXTURES}/My_App-v1.AppImage" | \
  MINTBUTLER_TEST_APP_DIRS="${AI_SYS_EMPTY}" HOME="${AI_AL2_HOME}" \
  bash "${AI_MODULE}" run 2>&1)" || code_al2="$?"
if [[ "${code_al2}" -eq 0 ]]; then
  pass "identical-pre-copy run exits 0"
else
  fail "identical-pre-copy run exits 0 (got ${code_al2})"
fi
if printf '%s\n' "${output_al2}" | grep -qi "reused"; then
  pass "byte-identical pre-existing copy is reused"
else
  fail "byte-identical pre-existing copy is reused"
fi
if [[ ! -e "${AI_AL2_INSTALL}/my-app-v1-2.AppImage" ]]; then
  pass "no -2 copy when the pre-existing copy is byte-identical"
else
  fail "no -2 copy when the pre-existing copy is byte-identical"
fi
if [[ -x "${AI_AL2_INSTALL}/my-app-v1.AppImage" ]] \
  && [[ -f "${AI_AL2_APPS}/my-app-v1.desktop" ]] \
  && grep -Fq "Exec=${AI_AL2_INSTALL}/my-app-v1.AppImage" "${AI_AL2_APPS}/my-app-v1.desktop"; then
  pass "reused copy is executable and the entry points at it"
else
  fail "reused copy is executable and the entry points at it"
fi

# ---------------------------------------------------------------------------
# Stages (am)-(aq): timeshift-guardian (elevated) — stub-only verification.
# Every stage runs with a controlled PATH (stub timeshift and sudo plus symlinks
# to the coreutils the module needs). No stage ever invokes real sudo or real
# timeshift.
# ---------------------------------------------------------------------------

TG_MODULE="${REPO_ROOT}/modules/timeshift-guardian/module.sh"
TG_STUB_ROOT="${TMPBASE}/tg-stubs"
mkdir -p "${TG_STUB_ROOT}"

tg_make_bin() {
  local dir="${1:-}"
  mkdir -p "${dir}"
  local tool tool_path
  for tool in dirname sed mkdir rm rmdir mv bash date tr grep cut awk; do
    tool_path="$(command -v "${tool}" || true)"
    if [[ -n "${tool_path}" ]]; then
      ln -sf "${tool_path}" "${dir}/${tool}"
    fi
  done
  printf '%s\n' "${dir}"
}

# Stage (am): gate pass, scan, list badge, plan/dry-run, missing binary run.
printf 'Stage am: timeshift-guardian scan, list badge, plan/dry-run, missing preflight\n'

output_am_scan=""
code_am_scan="0"
output_am_scan="$(cd "${REPO_ROOT}" && ./butler --scan 2>&1)" || code_am_scan="$?"
if [[ "${code_am_scan}" -ne 0 ]]; then
  fail "butler --scan exits 0 with timeshift-guardian present (got ${code_am_scan})"
else
  pass "butler --scan exits 0 with timeshift-guardian present"
fi
if printf '%s\n' "${output_am_scan}" | grep -q "PASS timeshift-guardian"; then
  pass "butler --scan reports PASS timeshift-guardian"
else
  fail "butler --scan reports PASS timeshift-guardian"
fi

output_am_lint=""
code_am_lint="0"
output_am_lint="$(cd "${REPO_ROOT}" && bin/modulelint timeshift-guardian 2>&1)" || code_am_lint="$?"
if [[ "${code_am_lint}" -ne 0 ]]; then
  fail "bin/modulelint exits 0 for timeshift-guardian (got ${code_am_lint})"
else
  pass "bin/modulelint exits 0 for timeshift-guardian"
fi
if printf '%s\n' "${output_am_lint}" | grep -q "PASS timeshift-guardian"; then
  pass "bin/modulelint reports PASS timeshift-guardian"
else
  fail "bin/modulelint reports PASS timeshift-guardian"
fi

output_am_list=""
code_am_list="0"
output_am_list="$(cd "${REPO_ROOT}" && ./butler --list 2>&1)" || code_am_list="$?"
if [[ "${code_am_list}" -ne 0 ]]; then
  fail "butler --list exits 0 (got ${code_am_list})"
else
  pass "butler --list exits 0"
fi
tg_list_line="$(printf '%s\n' "${output_am_list}" | grep -- "timeshift-guardian: Timeshift guardian" || true)"
if [[ -n "${tg_list_line}" ]]; then
  pass "butler --list shows timeshift-guardian: Timeshift guardian"
else
  fail "butler --list shows timeshift-guardian: Timeshift guardian"
fi
if [[ "${tg_list_line}" == *"⚠ elevated"* ]]; then
  pass "butler --list shows the elevated badge on timeshift-guardian"
else
  fail "butler --list shows the elevated badge on timeshift-guardian"
fi

output_am_plan=""
code_am_plan="0"
output_am_plan="$("${TG_MODULE}" plan 2>&1)" || code_am_plan="$?"
if [[ "${code_am_plan}" -eq 0 && -n "${output_am_plan}" ]]; then
  pass "timeshift-guardian plan exits 0 and non-empty"
else
  fail "timeshift-guardian plan exits 0 and non-empty (got ${code_am_plan})"
fi
plan_lines="$(printf '%s\n' "${output_am_plan}" | grep -c . || true)"
if [[ "${plan_lines}" -le 23 ]]; then
  pass "timeshift-guardian plan renders in <= 23 lines (got ${plan_lines})"
else
  fail "timeshift-guardian plan renders in <= 23 lines (got ${plan_lines})"
fi
if printf '%s\n' "${output_am_plan}" | grep -Fq "timeshift --list" \
  && printf '%s\n' "${output_am_plan}" | grep -Fq "timeshift --create --comments"; then
  pass "timeshift-guardian plan contains timeshift --list and timeshift --create --comments"
else
  fail "timeshift-guardian plan contains timeshift --list and timeshift --create --comments"
fi

output_am_dry=""
code_am_dry="0"
output_am_dry="$("${TG_MODULE}" dry-run 2>&1)" || code_am_dry="$?"
if [[ "${code_am_dry}" -eq 0 && -n "${output_am_dry}" ]]; then
  pass "timeshift-guardian dry-run exits 0 and non-empty"
else
  fail "timeshift-guardian dry-run exits 0 and non-empty (got ${code_am_dry})"
fi
dry_lines="$(printf '%s\n' "${output_am_dry}" | grep -c . || true)"
if [[ "${dry_lines}" -le 23 ]]; then
  pass "timeshift-guardian dry-run renders in <= 23 lines (got ${dry_lines})"
else
  fail "timeshift-guardian dry-run renders in <= 23 lines (got ${dry_lines})"
fi

# Run with stdin /dev/null and no timeshift on PATH -> exit 1, one plain stderr line mentioning Software Manager
TG_AM_BIN="${TG_STUB_ROOT}/bin-am"
tg_make_bin "${TG_AM_BIN}" >/dev/null
AM_LOG="${TMPBASE}/tg-am.log"
rm -f "${AM_LOG}"

code_am_run="0"
stderr_am_run=""
stderr_am_run="$(PATH="${TG_AM_BIN}" bash "${TG_MODULE}" run < /dev/null 2>&1 >/dev/null)" || code_am_run="$?"
if [[ "${code_am_run}" -eq 1 ]]; then
  pass "timeshift-guardian missing-tool exits 1"
else
  fail "timeshift-guardian missing-tool exits 1 (got ${code_am_run})"
fi
am_err_lines="$(printf '%s\n' "${stderr_am_run}" | grep -c . || true)"
if [[ "${am_err_lines}" -eq 1 ]] && printf '%s\n' "${stderr_am_run}" | grep -qi "Software Manager"; then
  pass "timeshift-guardian missing-tool prints one plain stderr line mentioning Software Manager"
else
  fail "timeshift-guardian missing-tool prints one plain stderr line mentioning Software Manager (got: ${stderr_am_run})"
fi
if [[ ! -s "${AM_LOG}" ]]; then
  pass "timeshift-guardian missing-tool log is absent/empty"
else
  fail "timeshift-guardian missing-tool log is absent/empty"
fi

# Stages (an)–(aq) invoke the module directly (bash modules/timeshift-guardian/module.sh run
# with the stub PATH and piped stdin) since the menu path cannot script elevated confirmation.

# Stage (an): unconfigured variant
printf 'Stage an: timeshift-guardian unconfigured guidance\n'
TG_AN_BIN="${TG_STUB_ROOT}/bin-an"
tg_make_bin "${TG_AN_BIN}" >/dev/null
AN_LOG="${TMPBASE}/tg-an.log"
rm -f "${AN_LOG}"

cat <<'EOF_STUB_AN' > "${TG_AN_BIN}/timeshift"
#!/usr/bin/env bash
set -euo pipefail
echo "timeshift $*" >> "${AN_LOG}"
if [[ "$*" == *"--list"* ]]; then
  echo "Device not found"
  echo "Select a snapshot device in the Timeshift GUI"
  exit 0
fi
EOF_STUB_AN
chmod +x "${TG_AN_BIN}/timeshift"

cat <<'EOF_SUDO_PASS' > "${TG_AN_BIN}/sudo"
#!/usr/bin/env bash
set -euo pipefail
"$@"
EOF_SUDO_PASS
chmod +x "${TG_AN_BIN}/sudo"

output_an=""
code_an="0"
output_an="$(export AN_LOG; PATH="${TG_AN_BIN}" bash "${TG_MODULE}" run < /dev/null 2>&1)" || code_an="$?"
if [[ "${code_an}" -eq 0 ]]; then
  pass "timeshift-guardian unconfigured exits 0"
else
  fail "timeshift-guardian unconfigured exits 0 (got ${code_an})"
fi
if printf '%s\n' "${output_an}" | grep -qi "open the timeshift gui once" \
  || printf '%s\n' "${output_an}" | grep -qi "not yet configured"; then
  pass "timeshift-guardian unconfigured displays guidance paragraph"
else
  fail "timeshift-guardian unconfigured displays guidance paragraph"
fi
if grep -q -- "--list" "${AN_LOG}" && ! grep -q -- "--create" "${AN_LOG}"; then
  pass "timeshift-guardian unconfigured log contains --list but NO --create"
else
  fail "timeshift-guardian unconfigured log contains --list but NO --create"
fi

# Stage (ao): configured happy path
printf 'Stage ao: timeshift-guardian configured happy path\n'
TG_AO_BIN="${TG_STUB_ROOT}/bin-ao"
tg_make_bin "${TG_AO_BIN}" >/dev/null
AO_LOG="${TMPBASE}/tg-ao.log"
rm -f "${AO_LOG}"

cat <<'EOF_STUB_AO' > "${TG_AO_BIN}/timeshift"
#!/usr/bin/env bash
set -euo pipefail
echo "timeshift $*" >> "${AO_LOG}"
if [[ "$*" == *"--list"* ]]; then
  echo "Mounted at : /run/timeshift/backup"
  echo "Device     : /dev/sda1"
  echo "Mode       : RSYNC"
  echo "Device is OK"
  echo "------------------------------------------------------------------------------"
  echo "Num     Name                 Tags  Description"
  echo "------------------------------------------------------------------------------"
  echo "0    >  2026-09-16_12-00-00  O D   Initial"
  exit 0
fi
if [[ "$*" == *"--create"* ]]; then
  echo "Creating new snapshot..."
  echo "Done"
  exit 0
fi
EOF_STUB_AO
chmod +x "${TG_AO_BIN}/timeshift"
cp "${TG_AN_BIN}/sudo" "${TG_AO_BIN}/sudo"

output_ao=""
code_ao="0"
# Scripted stdin = Enter (accept default comment) then y (confirm)
output_ao="$(export AO_LOG; printf '\ny\n' | PATH="${TG_AO_BIN}" bash "${TG_MODULE}" run 2>&1)" || code_ao="$?"
if [[ "${code_ao}" -eq 0 ]]; then
  pass "timeshift-guardian configured happy path exits 0"
else
  fail "timeshift-guardian configured happy path exits 0 (got ${code_ao})"
fi
if grep -q -- "--list" "${AO_LOG}" \
  && grep -E "timeshift --create --comments 'mintbutler guard" "${AO_LOG}" >/dev/null; then
  pass "timeshift-guardian happy path log shows --list, --create with default comment, and --list again"
else
  fail "timeshift-guardian happy path log shows --list, --create with default comment, and --list again"
fi
list_count_ao="$(grep -c -- "--list" "${AO_LOG}" || true)"
if [[ "${list_count_ao}" -ge 2 ]]; then
  pass "timeshift-guardian happy path verified snapshot with second --list"
else
  fail "timeshift-guardian happy path verified snapshot with second --list"
fi
if printf '%s\n' "${output_ao}" | grep -q "sudo timeshift --create --comments"; then
  pass "timeshift-guardian happy path shows exact elevated command display"
else
  fail "timeshift-guardian happy path shows exact elevated command display"
fi
if printf '%s\n' "${output_ao}" | grep -qi "snapshots are additive" \
  && printf '%s\n' "${output_ao}" | grep -qi "never deletes snapshots"; then
  pass "timeshift-guardian happy path shows additive statement"
else
  fail "timeshift-guardian happy path shows additive statement"
fi

# Stage (ap): confirm-no
printf 'Stage ap: timeshift-guardian confirm-no\n'
AP_LOG="${TMPBASE}/tg-ap.log"
rm -f "${AP_LOG}"
output_ap=""
code_ap="0"
# Scripted stdin = Enter then n
output_ap="$(export AO_LOG="${AP_LOG}"; printf '\nn\n' | PATH="${TG_AO_BIN}" bash "${TG_MODULE}" run 2>&1)" || code_ap="$?"
if [[ "${code_ap}" -eq 0 ]]; then
  pass "timeshift-guardian confirm-no exits 0"
else
  fail "timeshift-guardian confirm-no exits 0 (got ${code_ap})"
fi
if printf '%s\n' "${output_ap}" | grep -qi "Nothing changed"; then
  pass "timeshift-guardian confirm-no outputs 'Nothing changed.'"
else
  fail "timeshift-guardian confirm-no outputs 'Nothing changed.'"
fi
if grep -q -- "--list" "${AP_LOG}" && ! grep -q -- "--create" "${AP_LOG}"; then
  pass "timeshift-guardian confirm-no log contains --list but NO --create"
else
  fail "timeshift-guardian confirm-no log contains --list but NO --create"
fi

# Stage (aq): elevated-failure path
printf 'Stage aq: timeshift-guardian elevated-failure path\n'
TG_AQ_BIN="${TG_STUB_ROOT}/bin-aq"
tg_make_bin "${TG_AQ_BIN}" >/dev/null
AQ_LOG="${TMPBASE}/tg-aq.log"
rm -f "${AQ_LOG}"

cp "${TG_AO_BIN}/timeshift" "${TG_AQ_BIN}/timeshift"
cat <<'EOF_SUDO_FAIL' > "${TG_AQ_BIN}/sudo"
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo-stub: refused %s\n' "$*" >&2
exit 1
EOF_SUDO_FAIL
chmod +x "${TG_AQ_BIN}/sudo"

output_aq=""
stderr_aq=""
code_aq="0"
USED_AQ_STDERR="${TMPBASE}/tg-aq.stderr"
output_aq="$(export AO_LOG="${AQ_LOG}"; printf '\ny\n' | PATH="${TG_AQ_BIN}" bash "${TG_MODULE}" run 2>"${USED_AQ_STDERR}")" || code_aq="$?"
if [[ "${code_aq}" -ne 0 ]]; then
  pass "timeshift-guardian elevated-failure exits non-zero (got ${code_aq})"
else
  fail "timeshift-guardian elevated-failure exits non-zero"
fi
stderr_aq="$(cat "${USED_AQ_STDERR}")"
aq_module_lines="$(printf '%s\n' "${stderr_aq}" | grep -v '^sudo-stub:' | grep -c . || true)"
if [[ "${aq_module_lines}" -eq 1 ]]; then
  pass "timeshift-guardian elevated-failure prints one plain stderr line"
else
  fail "timeshift-guardian elevated-failure prints one plain stderr line (got ${aq_module_lines} lines: ${stderr_aq})"
fi
if ! grep -q -- "--create" "${AQ_LOG}" 2>/dev/null; then
  pass "timeshift-guardian elevated-failure log contains NO --create"
else
  fail "timeshift-guardian elevated-failure log contains NO --create"
fi

# ---------------------------------------------------------------------------
# Stages (ar)-(aw): audio-repair (elevated, diagnose-first) — stub-only
# verification. Every stage runs with a controlled PATH (stub pactl/amixer/
# dmesg/sudo plus symlinks to the coreutils the module needs) and a fake
# HOME under mktemp. No stage ever invokes real pactl, amixer, dmesg, or
# sudo: the elevated dmesg path goes through a stub sudo that runs the stub
# dmesg (stage (aw) uses a refusing sudo instead). Where the module's
# interactive confirmation matters, stages drive the module binary directly
# with piped stdin (the menu path cannot script elevated confirmation).
# ---------------------------------------------------------------------------

AR_MODULE="${REPO_ROOT}/modules/audio-repair/module.sh"
AR_STUB_ROOT="${TMPBASE}/ar-stubs"
AR_STATE_REL=".local/state/mintbutler/audio-repair/mixer.record"
mkdir -p "${AR_STUB_ROOT}"

# Controlled-PATH builder: symlink the coreutils the module (and the lib
# helpers it sources) needs from the host; each stage's bin dir then gets
# only the stubs that stage wants present.
ar_make_bin() {
  local dir="${1:-}"
  mkdir -p "${dir}"
  local tool tool_path
  for tool in dirname sed mkdir rm rmdir mv bash date tr grep cut awk; do
    tool_path="$(command -v "${tool}" || true)"
    if [[ -n "${tool_path}" ]]; then
      ln -sf "${tool_path}" "${dir}/${tool}"
    fi
  done
  printf '%s\n' "${dir}"
}

# Stub pactl: logs each call to PACTL_STUB_LOG (when set). `pactl info`
# reports a PipeWire-backed server; `pactl list short sinks` reports one
# real sink, or only a dummy sink when PACTL_STUB_SINKS_MODE=dummy.
cat <<'AR_PACTL_STUB' > "${AR_STUB_ROOT}/pactl"
#!/usr/bin/env bash
set -euo pipefail
LOG="${PACTL_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'pactl%s\n' "${*:+ $*}" >> "${LOG}"
fi
case "${1:-} ${2:-} ${3:-}" in
  'info  ')
    printf 'Server String: /run/user/1000/pulse/native\n'
    printf 'Server Name: PulseAudio (on PipeWire 1.0.5)\n'
    printf 'Server Version: 16.0.0\n'
    ;;
  'list short sinks')
    if [[ "${PACTL_STUB_SINKS_MODE:-real}" == "dummy" ]]; then
      printf '42\tdummy-sink\tmodule-null-sink.c\ts16le 2ch 44100Hz\tSUSPENDED\n'
    else
      printf '0\talsa_output.pci-0000_00_1f.3.analog-stereo\tmodule-alsa-card.c\ts16le 2ch 44100Hz\tSUSPENDED\n'
    fi
    ;;
  *)
    printf 'pactl-stub: unsupported invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
AR_PACTL_STUB

# Stub amixer: file-backed Master mixer. AMIXER_STUB_STATE names a
# muted=/volume= key-value file; AMIXER_STUB_LOG (when set) records every
# invocation. Bare `amixer` renders a realistic Master block;
# `amixer -q sset Master <N>% [mute|unmute] ...` mutates the fake state.
cat <<'AR_AMIXER_STUB' > "${AR_STUB_ROOT}/amixer"
#!/usr/bin/env bash
set -euo pipefail
LOG="${AMIXER_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'amixer%s\n' "${*:+ $*}" >> "${LOG}"
fi
STATE="${AMIXER_STUB_STATE:?amixer-stub: AMIXER_STUB_STATE is not set}"
stub_muted=0
stub_volume=0
if [[ -f "${STATE}" ]]; then
  while IFS='=' read -r k v; do
    case "${k}" in
      muted) stub_muted="${v}" ;;
      volume) stub_volume="${v}" ;;
    esac
  done < "${STATE}"
fi
if [[ "${1:-}" == "-q" && "${2:-}" == "sset" && "${3:-}" == "Master" ]]; then
  shift 3
  arg=""
  for arg in "$@"; do
    case "${arg}" in
      *%) stub_volume="${arg%\%}" ;;
      mute) stub_muted=1 ;;
      unmute) stub_muted=0 ;;
      *)
        printf 'amixer-stub: unsupported sset value: %s\n' "${arg}" >&2
        exit 2
        ;;
    esac
  done
  printf 'muted=%s\nvolume=%s\n' "${stub_muted}" "${stub_volume}" > "${STATE}"
  exit 0
fi
if [[ "$#" -eq 0 ]]; then
  word=on
  if [[ "${stub_muted}" == "1" ]]; then
    word=off
  fi
  printf "Simple mixer control 'Master',0\n"
  printf '  Capabilities: pvolume pswitch pswitch-joined\n'
  printf '  Playback channels: Front Left - Front Right\n'
  printf '  Limits: Playback 0 - 65536\n'
  printf '  Mono:\n'
  printf '  Front Left: Playback 65536 [%s%%] [%s]\n' "${stub_volume}" "${word}"
  printf '  Front Right: Playback 65536 [%s%%] [%s]\n' "${stub_volume}" "${word}"
  exit 0
fi
printf 'amixer-stub: unsupported invocation: %s\n' "$*" >&2
exit 2
AR_AMIXER_STUB

# Stub dmesg: canned kernel log with three audio driver/firmware failure
# lines (sof + snd_ signatures) and one non-audio noise line.
cat <<'AR_DMESG_STUB' > "${AR_STUB_ROOT}/dmesg"
#!/usr/bin/env bash
set -euo pipefail
printf '[   12.345678] sof-audio-pci-intel-tgl 0000:00:1f.3: firmware: failed to load intel/sof/sof-tgl.ri (-2)\n'
printf '[   12.346901] sof-audio-pci-intel-tgl 0000:00:1f.3: error: sof_probe_work failed err: -2\n'
printf '[   13.300002] snd_hda_intel 0000:00:1f.3: no codecs initialized (timeout)\n'
printf '[   14.000003] usb 1-2: device descriptor read/64, error -71\n'
AR_DMESG_STUB

# Stub sudo (passthrough): logs to ELEVATED_STUB_LOG, then runs its command
# — the dmesg path executes the stub dmesg through this, mirroring the real
# elevate flow without any privilege.
cat <<'AR_SUDO_PASS_STUB' > "${AR_STUB_ROOT}/sudo-pass"
#!/usr/bin/env bash
set -euo pipefail
LOG="${ELEVATED_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'sudo%s\n' "${*:+ $*}" >> "${LOG}"
fi
exec "$@"
AR_SUDO_PASS_STUB

# Stub sudo (refusing): one stderr line and a non-zero exit, like a sudo
# that cannot authenticate with stdin closed.
cat <<'AR_SUDO_REFUSE_STUB' > "${AR_STUB_ROOT}/sudo-refuse"
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo-stub: refused %s\n' "$*" >&2
exit 1
AR_SUDO_REFUSE_STUB

chmod +x "${AR_STUB_ROOT}/pactl" "${AR_STUB_ROOT}/amixer" "${AR_STUB_ROOT}/dmesg" \
  "${AR_STUB_ROOT}/sudo-pass" "${AR_STUB_ROOT}/sudo-refuse"

# Bin dir with only coreutils: no pactl/amixer at all (stage ar preflight).
AR_BIN_EMPTY="${AR_STUB_ROOT}/bin-empty"
ar_make_bin "${AR_BIN_EMPTY}" >/dev/null

# Bin dir for the sink-preserving paths: pactl + amixer + passthrough sudo.
AR_BIN_MAIN="${AR_STUB_ROOT}/bin-main"
ar_make_bin "${AR_BIN_MAIN}" >/dev/null
cp "${AR_STUB_ROOT}/pactl" "${AR_STUB_ROOT}/amixer" "${AR_BIN_MAIN}/"
cp "${AR_STUB_ROOT}/sudo-pass" "${AR_BIN_MAIN}/sudo"

# Bin dir for the dmesg-evidence path: adds the stub dmesg.
AR_BIN_DMESG="${AR_STUB_ROOT}/bin-dmesg"
ar_make_bin "${AR_BIN_DMESG}" >/dev/null
cp "${AR_STUB_ROOT}/pactl" "${AR_STUB_ROOT}/amixer" "${AR_STUB_ROOT}/dmesg" "${AR_BIN_DMESG}/"
cp "${AR_STUB_ROOT}/sudo-pass" "${AR_BIN_DMESG}/sudo"

# Bin dir for the elevated-failure path: sudo refuses.
AR_BIN_FAIL="${AR_STUB_ROOT}/bin-fail"
ar_make_bin "${AR_BIN_FAIL}" >/dev/null
cp "${AR_STUB_ROOT}/pactl" "${AR_STUB_ROOT}/amixer" "${AR_STUB_ROOT}/dmesg" "${AR_BIN_FAIL}/"
cp "${AR_STUB_ROOT}/sudo-refuse" "${AR_BIN_FAIL}/sudo"

# Stage (ar): gate + read-only smokes in the real repo.
printf 'Stage ar: audio-repair gate, scan, list badge, plan/dry-run, missing preflight\n'

output_ar_scan=""
code_ar_scan="0"
output_ar_scan="$(cd "${REPO_ROOT}" && ./butler --scan 2>&1)" || code_ar_scan="$?"
if [[ "${code_ar_scan}" -ne 0 ]]; then
  fail "butler --scan exits 0 with audio-repair present (got ${code_ar_scan})"
else
  pass "butler --scan exits 0 with audio-repair present"
fi
if printf '%s\n' "${output_ar_scan}" | grep -q "PASS audio-repair"; then
  pass "butler --scan reports PASS audio-repair"
else
  fail "butler --scan reports PASS audio-repair"
fi

output_ar_lint=""
code_ar_lint="0"
output_ar_lint="$(cd "${REPO_ROOT}" && bin/modulelint 2>&1)" || code_ar_lint="$?"
if [[ "${code_ar_lint}" -ne 0 ]]; then
  fail "bin/modulelint exits 0 over all modules with audio-repair present (got ${code_ar_lint})"
else
  pass "bin/modulelint exits 0 over all modules with audio-repair present"
fi
if printf '%s\n' "${output_ar_lint}" | grep -q "PASS audio-repair"; then
  pass "bin/modulelint reports PASS audio-repair"
else
  fail "bin/modulelint reports PASS audio-repair"
fi

output_ar_list=""
code_ar_list="0"
output_ar_list="$(cd "${REPO_ROOT}" && ./butler --list 2>&1)" || code_ar_list="$?"
if [[ "${code_ar_list}" -ne 0 ]]; then
  fail "butler --list exits 0 (got ${code_ar_list})"
else
  pass "butler --list exits 0"
fi
ar_list_line="$(printf '%s\n' "${output_ar_list}" | grep -- "audio-repair: Audio repair" || true)"
if [[ -n "${ar_list_line}" ]]; then
  pass "butler --list shows audio-repair: Audio repair"
else
  fail "butler --list shows audio-repair: Audio repair"
fi
if [[ "${ar_list_line}" == *"⚠ elevated"* ]]; then
  pass "butler --list shows the elevated badge on audio-repair"
else
  fail "butler --list shows the elevated badge on audio-repair"
fi
if printf '%s\n' "${output_ar_list}" | grep -q "timeshift-guardian" \
  && printf '%s\n' "${output_ar_list}" | grep -q "desktop-shortcut-creator"; then
  pass "butler --list still shows the earlier modules"
else
  fail "butler --list still shows the earlier modules"
fi

AR_AR_HOME="${TMPBASE}/ar-home-ar"
AR_AR_HOME_BEFORE="${TMPBASE}/ar-home-ar-before"
mkdir -p "${AR_AR_HOME}"
cp -a "${AR_AR_HOME}" "${AR_AR_HOME_BEFORE}"

output_ar_plan=""
code_ar_plan="0"
output_ar_plan="$(HOME="${AR_AR_HOME}" bash "${AR_MODULE}" plan < /dev/null 2>&1)" || code_ar_plan="$?"
ar_plan_lines="$(printf '%s\n' "${output_ar_plan}" | grep -c . || true)"
if [[ "${code_ar_plan}" -eq 0 && -n "${output_ar_plan}" ]]; then
  pass "audio-repair plan exits 0 and non-empty"
else
  fail "audio-repair plan exits 0 and non-empty (got ${code_ar_plan})"
fi
if [[ "${ar_plan_lines}" -le 23 ]]; then
  pass "audio-repair plan renders in <= 23 lines (got ${ar_plan_lines})"
else
  fail "audio-repair plan renders in <= 23 lines (got ${ar_plan_lines})"
fi

output_ar_dry=""
code_ar_dry="0"
output_ar_dry="$(HOME="${AR_AR_HOME}" bash "${AR_MODULE}" dry-run < /dev/null 2>&1)" || code_ar_dry="$?"
ar_dry_lines="$(printf '%s\n' "${output_ar_dry}" | grep -c . || true)"
if [[ "${code_ar_dry}" -eq 0 && -n "${output_ar_dry}" ]]; then
  pass "audio-repair dry-run exits 0 and non-empty"
else
  fail "audio-repair dry-run exits 0 and non-empty (got ${code_ar_dry})"
fi
if [[ "${ar_dry_lines}" -le 23 ]]; then
  pass "audio-repair dry-run renders in <= 23 lines (got ${ar_dry_lines})"
else
  fail "audio-repair dry-run renders in <= 23 lines (got ${ar_dry_lines})"
fi
if printf '%s\n' "${output_ar_dry}" | grep -Fq "pactl info"; then
  pass "audio-repair dry-run contains the exact string 'pactl info'"
else
  fail "audio-repair dry-run contains the exact string 'pactl info'"
fi
if printf '%s\n' "${output_ar_dry}" | grep -q "sudo dmesg"; then
  pass "audio-repair dry-run shows dmesg as the elevated line via the helper display"
else
  fail "audio-repair dry-run shows dmesg as the elevated line via the helper display"
fi
if diff -r "${AR_AR_HOME}" "${AR_AR_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "audio-repair plan and dry-run write nothing to the fake HOME"
else
  fail "audio-repair plan and dry-run modified the fake HOME"
fi

# Menu-flag smoke: --run <slug> --dry-run is non-destructive.
code_ar_menudry="0"
HOME="${AR_AR_HOME}" bash -c 'cd "'"${REPO_ROOT}"'" && ./butler --run audio-repair --dry-run' >/dev/null 2>&1 || code_ar_menudry="$?"
if [[ "${code_ar_menudry}" -eq 0 ]]; then
  pass "butler --run audio-repair --dry-run exits 0"
else
  fail "butler --run audio-repair --dry-run exits 0 (got ${code_ar_menudry})"
fi
if diff -r "${AR_AR_HOME}" "${AR_AR_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "butler --run audio-repair --dry-run leaves the fake HOME untouched"
else
  fail "butler --run audio-repair --dry-run modified the fake HOME"
fi

# Run with stdin /dev/null and no pactl on PATH: preflight must stop first.
AR_AR2_HOME="${TMPBASE}/ar-home-ar2"
AR_AR2_HOME_BEFORE="${TMPBASE}/ar-home-ar2-before"
mkdir -p "${AR_AR2_HOME}"
cp -a "${AR_AR2_HOME}" "${AR_AR2_HOME_BEFORE}"
code_ar_run="0"
stderr_ar_run=""
AR_AR2_STDERR="${TMPBASE}/ar-ar2.stderr"
PATH="${AR_BIN_EMPTY}" HOME="${AR_AR2_HOME}" bash "${AR_MODULE}" run < /dev/null >/dev/null 2>"${AR_AR2_STDERR}" || code_ar_run="$?"
stderr_ar_run="$(cat "${AR_AR2_STDERR}")"
if [[ "${code_ar_run}" -eq 1 ]]; then
  pass "audio-repair missing-tool run exits 1"
else
  fail "audio-repair missing-tool run exits 1 (got ${code_ar_run})"
fi
ar_err_lines="$(printf '%s\n' "${stderr_ar_run}" | grep -c . || true)"
if [[ "${ar_err_lines}" -eq 1 ]] && printf '%s\n' "${stderr_ar_run}" | grep -qi "pactl" \
  && printf '%s\n' "${stderr_ar_run}" | grep -qi "Mint"; then
  pass "audio-repair missing-tool prints one plain stderr line naming pactl and Mint"
else
  fail "audio-repair missing-tool prints one plain stderr line naming pactl and Mint (got ${ar_err_lines} lines: ${stderr_ar_run})"
fi
if diff -r "${AR_AR2_HOME}" "${AR_AR2_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "audio-repair missing-tool writes nothing to the fake HOME"
else
  fail "audio-repair missing-tool modified the fake HOME"
fi

# Stage (as): healthy chain — real sink, Master unmuted at 74%.
printf 'Stage as: audio-repair healthy chain verdict\n'
AR_AS_HOME="${TMPBASE}/ar-home-as"
AR_AS_MIXER="${TMPBASE}/ar-mixer-as.txt"
mkdir -p "${AR_AS_HOME}"
printf 'muted=0\nvolume=74\n' > "${AR_AS_MIXER}"
AS_ELEV="${TMPBASE}/ar-as-elevated.log"
AS_AMIXER_LOG="${TMPBASE}/ar-as-amixer.log"
output_as=""
code_as="0"
output_as="$(PATH="${AR_BIN_MAIN}" HOME="${AR_AS_HOME}" \
  PACTL_STUB_LOG="${TMPBASE}/ar-as-pactl.log" \
  AMIXER_STUB_STATE="${AR_AS_MIXER}" AMIXER_STUB_LOG="${AS_AMIXER_LOG}" \
  ELEVATED_STUB_LOG="${AS_ELEV}" \
  bash "${AR_MODULE}" run < /dev/null 2>&1)" || code_as="$?"
if [[ "${code_as}" -eq 0 ]]; then
  pass "audio-repair healthy chain exits 0"
else
  fail "audio-repair healthy chain exits 0 (got ${code_as})"
fi
if printf '%s\n' "${output_as}" | grep -q "the output chain looks healthy"; then
  pass "audio-repair healthy chain verdict says the output chain looks healthy"
else
  fail "audio-repair healthy chain verdict says the output chain looks healthy"
fi
if [[ ! -e "${AR_AS_HOME}/${AR_STATE_REL}" ]]; then
  pass "audio-repair healthy chain writes no state file"
else
  fail "audio-repair healthy chain writes no state file"
fi
if [[ ! -s "${AS_ELEV}" ]]; then
  pass "audio-repair healthy chain makes no elevated call"
else
  fail "audio-repair healthy chain makes no elevated call"
fi
if [[ ! -f "${AS_AMIXER_LOG}" ]] || ! grep -q "sset" "${AS_AMIXER_LOG}"; then
  pass "audio-repair healthy chain never writes to the mixer"
else
  fail "audio-repair healthy chain never writes to the mixer"
fi

# Stage (at): dummy sink only + kernel-log driver evidence.
printf 'Stage at: audio-repair driver/firmware verdict\n'
AR_AT_HOME="${TMPBASE}/ar-home-at"
AR_AT_MIXER="${TMPBASE}/ar-mixer-at.txt"
mkdir -p "${AR_AT_HOME}"
printf 'muted=0\nvolume=74\n' > "${AR_AT_MIXER}"
AT_ELEV="${TMPBASE}/ar-at-elevated.log"
AT_AMIXER_LOG="${TMPBASE}/ar-at-amixer.log"
output_at=""
code_at="0"
output_at="$(PATH="${AR_BIN_DMESG}" HOME="${AR_AT_HOME}" \
  PACTL_STUB_SINKS_MODE=dummy \
  AMIXER_STUB_STATE="${AR_AT_MIXER}" AMIXER_STUB_LOG="${AT_AMIXER_LOG}" \
  ELEVATED_STUB_LOG="${AT_ELEV}" \
  bash "${AR_MODULE}" run < /dev/null 2>&1)" || code_at="$?"
if [[ "${code_at}" -eq 0 ]]; then
  pass "audio-repair driver/firmware path exits 0 (verdict delivered)"
else
  fail "audio-repair driver/firmware path exits 0 (got ${code_at})"
fi
if printf '%s\n' "${output_at}" | grep -qi "newer kernel" \
  && printf '%s\n' "${output_at}" | grep -qi "firmware"; then
  pass "audio-repair driver/firmware verdict names the newer-kernel/firmware fix"
else
  fail "audio-repair driver/firmware verdict names the newer-kernel/firmware fix"
fi
if printf '%s\n' "${output_at}" | grep -q "sof-audio"; then
  pass "audio-repair driver/firmware output shows at least one evidence line"
else
  fail "audio-repair driver/firmware output shows at least one evidence line"
fi
if [[ ! -e "${AR_AT_HOME}/${AR_STATE_REL}" ]]; then
  pass "audio-repair driver/firmware path writes no state file"
else
  fail "audio-repair driver/firmware path writes no state file"
fi
if grep -q "sudo dmesg" "${AT_ELEV}"; then
  pass "audio-repair driver/firmware path went through the elevated dmesg call"
else
  fail "audio-repair driver/firmware path went through the elevated dmesg call"
fi
if [[ ! -f "${AT_AMIXER_LOG}" ]] || ! grep -q "sset" "${AT_AMIXER_LOG}"; then
  pass "audio-repair driver/firmware path never writes to the mixer"
else
  fail "audio-repair driver/firmware path never writes to the mixer"
fi

# Stage (au): muted Master at 0% — scripted stdin y accepts the repair.
printf 'Stage au: audio-repair muted Master repair (confirm yes)\n'
AR_AU_HOME="${TMPBASE}/ar-home-au"
AR_AU_MIXER="${TMPBASE}/ar-mixer-au.txt"
mkdir -p "${AR_AU_HOME}"
printf 'muted=1\nvolume=0\n' > "${AR_AU_MIXER}"
AU_AMIXER_LOG="${TMPBASE}/ar-au-amixer.log"
output_au=""
code_au="0"
output_au="$(printf 'y\n' | PATH="${AR_BIN_MAIN}" HOME="${AR_AU_HOME}" \
  PACTL_STUB_LOG="${TMPBASE}/ar-au-pactl.log" \
  AMIXER_STUB_STATE="${AR_AU_MIXER}" AMIXER_STUB_LOG="${AU_AMIXER_LOG}" \
  ELEVATED_STUB_LOG="${TMPBASE}/ar-au-elevated.log" \
  bash "${AR_MODULE}" run 2>&1)" || code_au="$?"
if [[ "${code_au}" -eq 0 ]]; then
  pass "audio-repair muted repair exits 0"
else
  fail "audio-repair muted repair exits 0 (got ${code_au})"
fi
if printf '%s\n' "${output_au}" | grep -q "current:" \
  && printf '%s\n' "${output_au}" | grep -q "proposed:"; then
  pass "audio-repair repair offer shows current-vs-proposed before confirming"
else
  fail "audio-repair repair offer shows current-vs-proposed before confirming"
fi
AU_STATE="${AR_AU_HOME}/${AR_STATE_REL}"
if [[ -f "${AU_STATE}" ]] \
  && grep -q "^muted=1$" "${AU_STATE}" \
  && grep -q "^volume=0$" "${AU_STATE}"; then
  pass "audio-repair repair records the prior muted=1 volume=0 state"
else
  fail "audio-repair repair records the prior muted=1 volume=0 state"
fi
if grep -q "sset Master 100% unmute" "${AU_AMIXER_LOG}"; then
  pass "audio-repair repair applies amixer -q sset Master 100% unmute"
else
  fail "audio-repair repair applies amixer -q sset Master 100% unmute"
fi
if grep -q "^muted=0$" "${AR_AU_MIXER}" && grep -q "^volume=100$" "${AR_AU_MIXER}"; then
  pass "audio-repair repair leaves the stub mixer unmuted at 100%"
else
  fail "audio-repair repair leaves the stub mixer unmuted at 100%"
fi
if printf '%s\n' "${output_au}" | grep -qi "undo"; then
  pass "audio-repair repair output points at undo for the recorded state"
else
  fail "audio-repair repair output points at undo for the recorded state"
fi

# Stage (av): undo after (au). The stub mixer is flipped back to muted/0
# first (something else changed it after the repair), so the undo must
# restore strictly from the RECORDED values, not from a fresh read.
printf 'Stage av: audio-repair undo restores the recorded state\n'
printf 'muted=1\nvolume=0\n' > "${AR_AU_MIXER}"
AV_AMIXER_LOG="${TMPBASE}/ar-av-amixer.log"
output_av=""
code_av="0"
output_av="$(PATH="${AR_BIN_MAIN}" HOME="${AR_AU_HOME}" \
  AMIXER_STUB_STATE="${AR_AU_MIXER}" AMIXER_STUB_LOG="${AV_AMIXER_LOG}" \
  bash "${AR_MODULE}" undo < /dev/null 2>&1)" || code_av="$?"
if [[ "${code_av}" -eq 0 ]]; then
  pass "audio-repair undo exits 0"
else
  fail "audio-repair undo exits 0 (got ${code_av})"
fi
if grep -q "sset Master 0%" "${AV_AMIXER_LOG}"; then
  pass "audio-repair undo re-applies the recorded volume (0%)"
else
  fail "audio-repair undo re-applies the recorded volume (0%)"
fi
if grep -q "sset Master mute" "${AV_AMIXER_LOG}"; then
  pass "audio-repair undo re-applies the recorded mute flag"
else
  fail "audio-repair undo re-applies the recorded mute flag"
fi
if [[ ! -e "${AU_STATE}" ]]; then
  pass "audio-repair undo deletes the state record"
else
  fail "audio-repair undo deletes the state record"
fi
output_av2=""
code_av2="0"
output_av2="$(PATH="${AR_BIN_MAIN}" HOME="${AR_AU_HOME}" \
  AMIXER_STUB_STATE="${AR_AU_MIXER}" \
  bash "${AR_MODULE}" undo < /dev/null 2>&1)" || code_av2="$?"
if [[ "${code_av2}" -eq 0 ]] && printf '%s\n' "${output_av2}" | grep -qi "Nothing to undo."; then
  pass "audio-repair second undo reports Nothing to undo and exits 0"
else
  fail "audio-repair second undo reports Nothing to undo and exits 0 (got ${code_av2})"
fi

# Stage (aw): confirm-no on the muted fixture, then the elevated-failure
# path with a refusing sudo.
printf 'Stage aw: audio-repair confirm-no and elevated failure\n'
AR_AW_HOME="${TMPBASE}/ar-home-aw"
AR_AW_MIXER="${TMPBASE}/ar-mixer-aw.txt"
mkdir -p "${AR_AW_HOME}"
printf 'muted=1\nvolume=0\n' > "${AR_AW_MIXER}"
AW_AMIXER_LOG="${TMPBASE}/ar-aw-amixer.log"
output_aw=""
code_aw="0"
output_aw="$(printf 'n\n' | PATH="${AR_BIN_MAIN}" HOME="${AR_AW_HOME}" \
  AMIXER_STUB_STATE="${AR_AW_MIXER}" AMIXER_STUB_LOG="${AW_AMIXER_LOG}" \
  bash "${AR_MODULE}" run 2>&1)" || code_aw="$?"
if [[ "${code_aw}" -eq 0 ]]; then
  pass "audio-repair confirm-no exits 0"
else
  fail "audio-repair confirm-no exits 0 (got ${code_aw})"
fi
if printf '%s\n' "${output_aw}" | grep -q "Nothing changed."; then
  pass "audio-repair confirm-no prints Nothing changed."
else
  fail "audio-repair confirm-no prints Nothing changed."
fi
if [[ ! -e "${AR_AW_HOME}/${AR_STATE_REL}" ]]; then
  pass "audio-repair confirm-no writes no state"
else
  fail "audio-repair confirm-no writes no state"
fi
if [[ ! -f "${AW_AMIXER_LOG}" ]] || ! grep -q "sset" "${AW_AMIXER_LOG}"; then
  pass "audio-repair confirm-no never touches the mixer"
else
  fail "audio-repair confirm-no never touches the mixer"
fi

AR_AW2_HOME="${TMPBASE}/ar-home-aw2"
AR_AW2_HOME_BEFORE="${TMPBASE}/ar-home-aw2-before"
AR_AW2_MIXER="${TMPBASE}/ar-mixer-aw2.txt"
mkdir -p "${AR_AW2_HOME}"
cp -a "${AR_AW2_HOME}" "${AR_AW2_HOME_BEFORE}"
printf 'muted=0\nvolume=74\n' > "${AR_AW2_MIXER}"
code_aw2="0"
AR_AW2_STDERR="${TMPBASE}/ar-aw2.stderr"
PACTL_STUB_SINKS_MODE=dummy PATH="${AR_BIN_FAIL}" HOME="${AR_AW2_HOME}" \
  AMIXER_STUB_STATE="${AR_AW2_MIXER}" \
  bash "${AR_MODULE}" run < /dev/null >/dev/null 2>"${AR_AW2_STDERR}" || code_aw2="$?"
stderr_aw2="$(cat "${AR_AW2_STDERR}")"
if [[ "${code_aw2}" -ne 0 ]]; then
  pass "audio-repair elevated failure exits non-zero (got ${code_aw2})"
else
  fail "audio-repair elevated failure exits non-zero"
fi
aw2_module_lines="$(printf '%s\n' "${stderr_aw2}" | grep -v '^sudo-stub:' | grep -c . || true)"
if [[ "${aw2_module_lines}" -eq 1 ]]; then
  pass "audio-repair elevated failure prints one plain stderr line"
else
  fail "audio-repair elevated failure prints one plain stderr line (got ${aw2_module_lines} lines: ${stderr_aw2})"
fi
if diff -r "${AR_AW2_HOME}" "${AR_AW2_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "audio-repair elevated failure writes nothing to the fake HOME"
else
  fail "audio-repair elevated failure modified the fake HOME"
fi


# ---------------------------------------------------------------------------
# Stages (ax)-(bc): multimedia-codecs (elevated, honest no-undo) — stub-only
# verification. Every stage runs with a controlled PATH (stub dpkg, apt-get,
# and sudo plus symlinks to the coreutils the module needs) and a fake HOME
# under mktemp. No stage ever invokes real dpkg, real apt-get, or real sudo:
# the stub apt-get only appends package names to the stub dpkg state file
# (it NEVER performs a real install or removal), and the elevated path goes
# through a stub sudo that runs its command (stage (bc) uses a refusing sudo
# instead). Where the module's interactive confirmation matters, stages
# drive the module binary directly with piped stdin (the menu path cannot
# script elevated confirmation). Note: with scripted stdin, the ask prompt
# (stderr, no trailing newline) shares its line with whatever stderr writes
# next — assertions account for that.
# ---------------------------------------------------------------------------

MC_MODULE="${REPO_ROOT}/modules/multimedia-codecs/module.sh"
MC_STUB_ROOT="${TMPBASE}/mc-stubs"
MC_PKG_BAD="gstreamer1.0-plugins-bad"
MC_PKG_UGLY="gstreamer1.0-plugins-ugly"
MC_PKG_LIBAV="gstreamer1.0-libav"
MC_PKG_EXTRA="libavcodec-extra"
mkdir -p "${MC_STUB_ROOT}"

# Controlled-PATH builder: symlink the coreutils the module (and the lib
# helpers it sources) needs from the host; each stage's bin dir then gets
# only the stubs that stage wants present.
mc_make_bin() {
  local dir="${1:-}"
  mkdir -p "${dir}"
  local tool tool_path
  for tool in dirname sed mkdir rm rmdir mv bash date tr grep cut awk; do
    tool_path="$(command -v "${tool}" || true)"
    if [[ -n "${tool_path}" ]]; then
      ln -sf "${tool_path}" "${dir}/${tool}"
    fi
  done
  printf '%s\n' "${dir}"
}

# Stub dpkg: file-backed package database. DPKG_STUB_STATE names a file
# holding one installed package name per line; `dpkg -s <pkg>` exits 0 with
# a canned status block when <pkg> is listed, and exits 1 like a real dpkg
# for a package that is not installed. DPKG_STUB_LOG (when set) records
# every invocation. Read-only: the stub never modifies the state file.
cat <<'MC_DPKG_STUB' > "${MC_STUB_ROOT}/dpkg"
#!/usr/bin/env bash
set -euo pipefail
LOG="${DPKG_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'dpkg%s\n' "${*:+ $*}" >> "${LOG}"
fi
if [[ "${1:-}" != "-s" || -z "${2:-}" ]]; then
  printf 'dpkg-stub: unsupported invocation: %s\n' "$*" >&2
  exit 2
fi
pkg="${2}"
STATE="${DPKG_STUB_STATE:-}"
if [[ -n "${STATE}" && -f "${STATE}" ]]; then
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" == "${pkg}" ]]; then
      printf 'Package: %s\n' "${pkg}"
      printf 'Status: install ok installed\n'
      exit 0
    fi
  done < "${STATE}"
fi
printf "dpkg-query: package '%s' is not installed\n" "${pkg}" >&2
exit 1
MC_DPKG_STUB

# Stub apt-get: logs every invocation to APTGET_STUB_LOG, then handles
# `install -y <pkgs...>` by appending each package name to DPKG_STUB_STATE
# — except packages named in APTGET_STUB_SKIP (space-separated), which stay
# missing so the module's honest mixed path can be exercised. It NEVER
# performs a real install or removal; it only edits the stub state file.
cat <<'MC_APTGET_STUB' > "${MC_STUB_ROOT}/apt-get"
#!/usr/bin/env bash
set -euo pipefail
LOG="${APTGET_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'apt-get%s\n' "${*:+ $*}" >> "${LOG}"
fi
if [[ "${1:-}" != "install" || "${2:-}" != "-y" ]]; then
  printf 'apt-get-stub: unsupported invocation: %s\n' "$*" >&2
  exit 2
fi
STATE="${DPKG_STUB_STATE:?apt-get-stub: DPKG_STUB_STATE is not set}"
shift 2
read -r -a skip_list <<< "${APTGET_STUB_SKIP:-}"
for pkg in "$@"; do
  skip="0"
  for s in "${skip_list[@]}"; do
    if [[ "${pkg}" == "${s}" ]]; then
      skip="1"
    fi
  done
  if [[ "${skip}" == "1" ]]; then
    continue
  fi
  printf '%s\n' "${pkg}" >> "${STATE}"
done
exit "${APTGET_STUB_EXIT:-0}"
MC_APTGET_STUB

# Stub sudo (passthrough): logs to ELEVATED_STUB_LOG, then runs its command
# — the install path executes the stub apt-get through this, mirroring the
# real elevate flow without any privilege.
cat <<'MC_SUDO_PASS_STUB' > "${MC_STUB_ROOT}/sudo-pass"
#!/usr/bin/env bash
set -euo pipefail
LOG="${ELEVATED_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'sudo%s\n' "${*:+ $*}" >> "${LOG}"
fi
exec "$@"
MC_SUDO_PASS_STUB

# Stub sudo (refusing): one stderr line and a non-zero exit, like a sudo
# that cannot authenticate with stdin closed.
cat <<'MC_SUDO_REFUSE_STUB' > "${MC_STUB_ROOT}/sudo-refuse"
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo-stub: refused %s\n' "$*" >&2
exit 1
MC_SUDO_REFUSE_STUB

chmod +x "${MC_STUB_ROOT}/dpkg" "${MC_STUB_ROOT}/apt-get" \
  "${MC_STUB_ROOT}/sudo-pass" "${MC_STUB_ROOT}/sudo-refuse"

# Bin dir for the passing paths: stub dpkg + stub apt-get + passthrough sudo.
MC_BIN_PASS="${MC_STUB_ROOT}/bin-pass"
mc_make_bin "${MC_BIN_PASS}" >/dev/null
cp "${MC_STUB_ROOT}/dpkg" "${MC_STUB_ROOT}/apt-get" "${MC_BIN_PASS}/"
cp "${MC_STUB_ROOT}/sudo-pass" "${MC_BIN_PASS}/sudo"

# Bin dir for the elevated-failure path: sudo refuses.
MC_BIN_FAIL="${MC_STUB_ROOT}/bin-fail"
mc_make_bin "${MC_BIN_FAIL}" >/dev/null
cp "${MC_STUB_ROOT}/dpkg" "${MC_STUB_ROOT}/apt-get" "${MC_BIN_FAIL}/"
cp "${MC_STUB_ROOT}/sudo-refuse" "${MC_BIN_FAIL}/sudo"

# mc_seed_state FILE PKGS... — write a stub dpkg state file listing PKGS as
# the installed packages.
mc_seed_state() {
  local file="${1}"
  shift
  : > "${file}"
  local pkg
  for pkg in "$@"; do
    printf '%s\n' "${pkg}" >> "${file}"
  done
}

# Stage (ax): gate + read-only smokes in the real repo.
printf 'Stage ax: multimedia-codecs gate, scan, list badge, plan/dry-run, non-interactive\n'

output_ax_scan=""
code_ax_scan="0"
output_ax_scan="$(cd "${REPO_ROOT}" && ./butler --scan 2>&1)" || code_ax_scan="$?"
if [[ "${code_ax_scan}" -ne 0 ]]; then
  fail "butler --scan exits 0 with multimedia-codecs present (got ${code_ax_scan})"
else
  pass "butler --scan exits 0 with multimedia-codecs present"
fi
if printf '%s\n' "${output_ax_scan}" | grep -q "PASS multimedia-codecs"; then
  pass "butler --scan reports PASS multimedia-codecs"
else
  fail "butler --scan reports PASS multimedia-codecs"
fi

output_ax_lint1=""
code_ax_lint1="0"
output_ax_lint1="$(cd "${REPO_ROOT}" && bin/modulelint multimedia-codecs 2>&1)" || code_ax_lint1="$?"
if [[ "${code_ax_lint1}" -ne 0 ]]; then
  fail "bin/modulelint multimedia-codecs exits 0 (got ${code_ax_lint1})"
else
  pass "bin/modulelint multimedia-codecs exits 0"
fi
if printf '%s\n' "${output_ax_lint1}" | grep -q "PASS multimedia-codecs"; then
  pass "bin/modulelint reports PASS multimedia-codecs"
else
  fail "bin/modulelint reports PASS multimedia-codecs"
fi

output_ax_lint=""
code_ax_lint="0"
output_ax_lint="$(cd "${REPO_ROOT}" && bin/modulelint 2>&1)" || code_ax_lint="$?"
if [[ "${code_ax_lint}" -ne 0 ]]; then
  fail "bin/modulelint exits 0 over all modules with multimedia-codecs present (got ${code_ax_lint})"
else
  pass "bin/modulelint exits 0 over all modules with multimedia-codecs present"
fi

output_ax_list=""
code_ax_list="0"
output_ax_list="$(cd "${REPO_ROOT}" && ./butler --list 2>&1)" || code_ax_list="$?"
if [[ "${code_ax_list}" -ne 0 ]]; then
  fail "butler --list exits 0 (got ${code_ax_list})"
else
  pass "butler --list exits 0"
fi
mc_ax_list_line="$(printf '%s\n' "${output_ax_list}" | grep -- "multimedia-codecs: Multimedia codecs" || true)"
if [[ -n "${mc_ax_list_line}" ]]; then
  pass "butler --list shows multimedia-codecs: Multimedia codecs"
else
  fail "butler --list shows multimedia-codecs: Multimedia codecs"
fi
if [[ "${mc_ax_list_line}" == *"⚠ elevated"* ]]; then
  pass "butler --list shows the elevated badge on multimedia-codecs"
else
  fail "butler --list shows the elevated badge on multimedia-codecs"
fi
if printf '%s\n' "${output_ax_list}" | grep -q "audio-repair" \
  && printf '%s\n' "${output_ax_list}" | grep -q "timeshift-guardian" \
  && printf '%s\n' "${output_ax_list}" | grep -q "desktop-shortcut-creator"; then
  pass "butler --list still shows the earlier modules"
else
  fail "butler --list still shows the earlier modules"
fi

# Menu position smoke: with the current module set, order 40 renders as
# entry 4 on page 1 (positions are recomputed at scan time).
output_ax_menu=""
code_ax_menu="0"
output_ax_menu="$(printf 'q\n' | (cd "${REPO_ROOT}" && ./butler) 2>&1)" || code_ax_menu="$?"
mc_ax_menu_line="$(printf '%s\n' "${output_ax_menu}" | grep -F "4) Multimedia codecs" || true)"
if [[ "${code_ax_menu}" -eq 0 && -n "${mc_ax_menu_line}" && "${mc_ax_menu_line}" == *"⚠ elevated"* ]]; then
  pass "menu renders Multimedia codecs at its order-40 position with the elevated badge"
else
  fail "menu renders Multimedia codecs at its order-40 position with the elevated badge (got ${code_ax_menu}: ${mc_ax_menu_line})"
fi

# Menu navigation, no undo affordance: the detail screen of an undo: false
# module offers [d]ry-run/[r]un/[b]ack and never [u]ndo. Scripted stdin:
# /multimedia filters to the module, 1 opens its detail screen, b goes
# back, q quits.
output_ax_nav=""
code_ax_nav="0"
output_ax_nav="$(printf '/multimedia\n1\nb\nq\n' | (cd "${REPO_ROOT}" && ./butler) 2>&1)" || code_ax_nav="$?"
if [[ "${code_ax_nav}" -ne 0 ]]; then
  fail "menu navigation through the multimedia-codecs detail screen exits 0 (got ${code_ax_nav})"
else
  pass "menu navigation through the multimedia-codecs detail screen exits 0"
fi
if printf '%s\n' "${output_ax_nav}" | grep -Fq "[d]ry-run  [r]un  [b]ack"; then
  pass "detail screen offers dry-run/run/back"
else
  fail "detail screen offers dry-run/run/back"
fi
if printf '%s\n' "${output_ax_nav}" | grep -Fq "[u]ndo"; then
  fail "detail screen shows NO [u]ndo affordance (undo: false)"
else
  pass "detail screen shows NO [u]ndo affordance (undo: false)"
fi
if printf '%s\n' "${output_ax_nav}" | grep -q "Undo: not available"; then
  pass "detail screen states undo is not available"
else
  fail "detail screen states undo is not available"
fi

MC_AX_HOME="${TMPBASE}/mc-home-ax"
MC_AX_HOME_BEFORE="${TMPBASE}/mc-home-ax-before"
mkdir -p "${MC_AX_HOME}"
cp -a "${MC_AX_HOME}" "${MC_AX_HOME_BEFORE}"

output_ax_plan=""
code_ax_plan="0"
output_ax_plan="$(HOME="${MC_AX_HOME}" bash "${MC_MODULE}" plan < /dev/null 2>&1)" || code_ax_plan="$?"
mc_ax_plan_lines="$(printf '%s\n' "${output_ax_plan}" | grep -c . || true)"
if [[ "${code_ax_plan}" -eq 0 && -n "${output_ax_plan}" ]]; then
  pass "multimedia-codecs plan exits 0 and non-empty"
else
  fail "multimedia-codecs plan exits 0 and non-empty (got ${code_ax_plan})"
fi
if [[ "${mc_ax_plan_lines}" -le 23 ]]; then
  pass "multimedia-codecs plan renders in <= 23 lines (got ${mc_ax_plan_lines})"
else
  fail "multimedia-codecs plan renders in <= 23 lines (got ${mc_ax_plan_lines})"
fi
if printf '%s\n' "${output_ax_plan}" | grep -Fq "not undone by this module"; then
  pass "multimedia-codecs plan contains the no-undo notice"
else
  fail "multimedia-codecs plan contains the no-undo notice"
fi

output_ax_dry=""
code_ax_dry="0"
output_ax_dry="$(HOME="${MC_AX_HOME}" bash "${MC_MODULE}" dry-run < /dev/null 2>&1)" || code_ax_dry="$?"
mc_ax_dry_lines="$(printf '%s\n' "${output_ax_dry}" | grep -c . || true)"
if [[ "${code_ax_dry}" -eq 0 && -n "${output_ax_dry}" ]]; then
  pass "multimedia-codecs dry-run exits 0 and non-empty"
else
  fail "multimedia-codecs dry-run exits 0 and non-empty (got ${code_ax_dry})"
fi
if [[ "${mc_ax_dry_lines}" -le 23 ]]; then
  pass "multimedia-codecs dry-run renders in <= 23 lines (got ${mc_ax_dry_lines})"
else
  fail "multimedia-codecs dry-run renders in <= 23 lines (got ${mc_ax_dry_lines})"
fi
if printf '%s\n' "${output_ax_dry}" | grep -Fq "dpkg -s"; then
  pass "multimedia-codecs dry-run contains the exact string 'dpkg -s'"
else
  fail "multimedia-codecs dry-run contains the exact string 'dpkg -s'"
fi
if printf '%s\n' "${output_ax_dry}" | grep -Fq "sudo apt-get install -y"; then
  pass "multimedia-codecs dry-run shows apt-get install as the elevated line via the helper display"
else
  fail "multimedia-codecs dry-run shows apt-get install as the elevated line via the helper display"
fi
if printf '%s\n' "${output_ax_dry}" | grep -Fq "not undone by this module"; then
  pass "multimedia-codecs dry-run contains the no-undo notice"
else
  fail "multimedia-codecs dry-run contains the no-undo notice"
fi
if diff -r "${MC_AX_HOME}" "${MC_AX_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "multimedia-codecs plan and dry-run write nothing to the fake HOME"
else
  fail "multimedia-codecs plan and dry-run modified the fake HOME"
fi

# Menu-flag smoke: --run <slug> --dry-run is non-destructive.
code_ax_menudry="0"
HOME="${MC_AX_HOME}" bash -c 'cd "'"${REPO_ROOT}"'" && ./butler --run multimedia-codecs --dry-run' >/dev/null 2>&1 || code_ax_menudry="$?"
if [[ "${code_ax_menudry}" -eq 0 ]]; then
  pass "butler --run multimedia-codecs --dry-run exits 0"
else
  fail "butler --run multimedia-codecs --dry-run exits 0 (got ${code_ax_menudry})"
fi
if diff -r "${MC_AX_HOME}" "${MC_AX_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "butler --run multimedia-codecs --dry-run leaves the fake HOME untouched"
else
  fail "butler --run multimedia-codecs --dry-run modified the fake HOME"
fi

# Non-interactive run (modulelint compatibility): stdin /dev/null under the
# all-installed stub set stops at the honest nothing-to-do verdict — exit 0,
# nothing written, no elevated call in the stub log.
MC_AX2_HOME="${TMPBASE}/mc-home-ax2"
MC_AX2_HOME_BEFORE="${TMPBASE}/mc-home-ax2-before"
mkdir -p "${MC_AX2_HOME}"
cp -a "${MC_AX2_HOME}" "${MC_AX2_HOME_BEFORE}"
MC_AX_STATE="${TMPBASE}/mc-ax-packages.txt"
mc_seed_state "${MC_AX_STATE}" "${MC_PKG_BAD}" "${MC_PKG_UGLY}" "${MC_PKG_LIBAV}" "${MC_PKG_EXTRA}"
AX_ELEV="${TMPBASE}/mc-ax-elevated.log"
AX_APT="${TMPBASE}/mc-ax-aptget.log"
output_ax_run=""
code_ax_run="0"
output_ax_run="$(PATH="${MC_BIN_PASS}" HOME="${MC_AX2_HOME}" \
  DPKG_STUB_STATE="${MC_AX_STATE}" APTGET_STUB_LOG="${AX_APT}" ELEVATED_STUB_LOG="${AX_ELEV}" \
  bash "${MC_MODULE}" run < /dev/null 2>&1)" || code_ax_run="$?"
if [[ "${code_ax_run}" -eq 0 ]]; then
  pass "multimedia-codecs non-interactive all-installed run exits 0"
else
  fail "multimedia-codecs non-interactive all-installed run exits 0 (got ${code_ax_run})"
fi
if printf '%s\n' "${output_ax_run}" | grep -q "nothing to do"; then
  pass "multimedia-codecs non-interactive all-installed run reports nothing to do"
else
  fail "multimedia-codecs non-interactive all-installed run reports nothing to do"
fi
if [[ ! -s "${AX_ELEV}" ]]; then
  pass "multimedia-codecs non-interactive all-installed run makes no elevated call"
else
  fail "multimedia-codecs non-interactive all-installed run makes no elevated call"
fi
if [[ ! -e "${AX_APT}" ]]; then
  pass "multimedia-codecs non-interactive all-installed run never calls apt-get"
else
  fail "multimedia-codecs non-interactive all-installed run never calls apt-get"
fi
if diff -r "${MC_AX2_HOME}" "${MC_AX2_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "multimedia-codecs non-interactive all-installed run writes nothing"
else
  fail "multimedia-codecs non-interactive all-installed run modified the fake HOME"
fi

# Stage (ay): all four installed under the stub dpkg -> honest verdict,
# exit 0, no elevated call, and no state file anywhere (fake HOME
# byte-identical; the module never writes one by design).
printf 'Stage ay: multimedia-codecs all-installed verdict\n'
MC_AY_HOME="${TMPBASE}/mc-home-ay"
MC_AY_HOME_BEFORE="${TMPBASE}/mc-home-ay-before"
mkdir -p "${MC_AY_HOME}"
cp -a "${MC_AY_HOME}" "${MC_AY_HOME_BEFORE}"
MC_AY_STATE="${TMPBASE}/mc-ay-packages.txt"
mc_seed_state "${MC_AY_STATE}" "${MC_PKG_BAD}" "${MC_PKG_UGLY}" "${MC_PKG_LIBAV}" "${MC_PKG_EXTRA}"
AY_ELEV="${TMPBASE}/mc-ay-elevated.log"
AY_DPKG="${TMPBASE}/mc-ay-dpkg.log"
output_ay=""
code_ay="0"
output_ay="$(PATH="${MC_BIN_PASS}" HOME="${MC_AY_HOME}" \
  DPKG_STUB_STATE="${MC_AY_STATE}" DPKG_STUB_LOG="${AY_DPKG}" ELEVATED_STUB_LOG="${AY_ELEV}" \
  bash "${MC_MODULE}" run < /dev/null 2>&1)" || code_ay="$?"
if [[ "${code_ay}" -eq 0 ]]; then
  pass "multimedia-codecs all-installed run exits 0"
else
  fail "multimedia-codecs all-installed run exits 0 (got ${code_ay})"
fi
if printf '%s\n' "${output_ay}" | grep -q "all four curated codec packages are already installed; nothing to do"; then
  pass "multimedia-codecs all-installed verdict says already installed, nothing to do"
else
  fail "multimedia-codecs all-installed verdict says already installed, nothing to do"
fi
if [[ -f "${AY_DPKG}" ]] && [[ "$(grep -c '^dpkg -s ' "${AY_DPKG}" || true)" -eq 4 ]]; then
  pass "multimedia-codecs all-installed run checks all four packages with dpkg -s"
else
  fail "multimedia-codecs all-installed run checks all four packages with dpkg -s"
fi
if [[ ! -s "${AY_ELEV}" ]]; then
  pass "multimedia-codecs all-installed run makes no elevated call"
else
  fail "multimedia-codecs all-installed run makes no elevated call"
fi
if diff -r "${MC_AY_HOME}" "${MC_AY_HOME_BEFORE}" >/dev/null 2>&1 \
  && [[ ! -e "${MC_AY_HOME}/.local" ]]; then
  pass "multimedia-codecs all-installed run writes no state file anywhere (fake HOME byte-identical)"
else
  fail "multimedia-codecs all-installed run wrote something (fake HOME differs or .local exists)"
fi

# Stage (az): two missing + confirm-no -> exit 0, "Nothing installed.",
# no apt-get call in the stub log, nothing written. Driven with piped
# stdin 'n' (the menu path cannot script elevated confirmation).
printf 'Stage az: multimedia-codecs missing + confirm-no\n'
MC_AZ_HOME="${TMPBASE}/mc-home-az"
MC_AZ_HOME_BEFORE="${TMPBASE}/mc-home-az-before"
mkdir -p "${MC_AZ_HOME}"
cp -a "${MC_AZ_HOME}" "${MC_AZ_HOME_BEFORE}"
MC_AZ_STATE="${TMPBASE}/mc-az-packages.txt"
mc_seed_state "${MC_AZ_STATE}" "${MC_PKG_BAD}" "${MC_PKG_UGLY}"
cp "${MC_AZ_STATE}" "${MC_AZ_STATE}.seeded"
AZ_APT="${TMPBASE}/mc-az-aptget.log"
AZ_ELEV="${TMPBASE}/mc-az-elevated.log"
output_az=""
code_az="0"
output_az="$(printf 'n\n' | PATH="${MC_BIN_PASS}" HOME="${MC_AZ_HOME}" \
  DPKG_STUB_STATE="${MC_AZ_STATE}" APTGET_STUB_LOG="${AZ_APT}" ELEVATED_STUB_LOG="${AZ_ELEV}" \
  bash "${MC_MODULE}" run 2>&1)" || code_az="$?"
if [[ "${code_az}" -eq 0 ]]; then
  pass "multimedia-codecs confirm-no exits 0"
else
  fail "multimedia-codecs confirm-no exits 0 (got ${code_az})"
fi
if printf '%s\n' "${output_az}" | grep -Fq "Nothing installed."; then
  pass "multimedia-codecs confirm-no prints Nothing installed."
else
  fail "multimedia-codecs confirm-no prints Nothing installed."
fi
if printf '%s\n' "${output_az}" | grep -Fq "missing:   ${MC_PKG_LIBAV}, ${MC_PKG_EXTRA}"; then
  pass "multimedia-codecs confirm-no names the two missing packages first"
else
  fail "multimedia-codecs confirm-no names the two missing packages first"
fi
if [[ ! -e "${AZ_APT}" ]] && [[ ! -s "${AZ_ELEV}" ]]; then
  pass "multimedia-codecs confirm-no makes no apt-get and no elevated call"
else
  fail "multimedia-codecs confirm-no makes no apt-get and no elevated call"
fi
if cmp -s "${MC_AZ_STATE}" "${MC_AZ_STATE}.seeded" \
  && diff -r "${MC_AZ_HOME}" "${MC_AZ_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "multimedia-codecs confirm-no writes nothing (state and fake HOME byte-identical)"
else
  fail "multimedia-codecs confirm-no wrote something"
fi

# Stage (ba): two missing + confirm-yes + full success. Scripted stdin 'y';
# the stub apt-get exits 0 and flips the two missing packages to installed
# in the stub dpkg state, so the module's per-package verification sees
# success. Asserts the honest full report and exactly one stub apt-get
# install call naming exactly the two missing packages.
printf 'Stage ba: multimedia-codecs confirm-yes full success\n'
MC_BA_HOME="${TMPBASE}/mc-home-ba"
MC_BA_HOME_BEFORE="${TMPBASE}/mc-home-ba-before"
mkdir -p "${MC_BA_HOME}"
cp -a "${MC_BA_HOME}" "${MC_BA_HOME_BEFORE}"
MC_BA_STATE="${TMPBASE}/mc-ba-packages.txt"
mc_seed_state "${MC_BA_STATE}" "${MC_PKG_BAD}" "${MC_PKG_UGLY}"
BA_APT="${TMPBASE}/mc-ba-aptget.log"
BA_ELEV="${TMPBASE}/mc-ba-elevated.log"
output_ba=""
code_ba="0"
output_ba="$(printf 'y\n' | PATH="${MC_BIN_PASS}" HOME="${MC_BA_HOME}" \
  DPKG_STUB_STATE="${MC_BA_STATE}" APTGET_STUB_LOG="${BA_APT}" ELEVATED_STUB_LOG="${BA_ELEV}" \
  bash "${MC_MODULE}" run 2>&1)" || code_ba="$?"
if [[ "${code_ba}" -eq 0 ]]; then
  pass "multimedia-codecs full-success run exits 0"
else
  fail "multimedia-codecs full-success run exits 0 (got ${code_ba})"
fi
if printf '%s\n' "${output_ba}" | grep -Fq "installed: ${MC_PKG_BAD}, ${MC_PKG_UGLY}" \
  && printf '%s\n' "${output_ba}" | grep -Fq "missing:   ${MC_PKG_LIBAV}, ${MC_PKG_EXTRA}"; then
  pass "multimedia-codecs full success shows installed-vs-missing before confirming"
else
  fail "multimedia-codecs full success shows installed-vs-missing before confirming"
fi
mc_ba_missing_line="$(printf '%s\n' "${output_ba}" | grep -n -F "missing:" | head -n 1 | cut -d: -f1 || true)"
mc_ba_elev_line="$(printf '%s\n' "${output_ba}" | grep -n -F "Running elevated command" | head -n 1 | cut -d: -f1 || true)"
if [[ -n "${mc_ba_missing_line}" && -n "${mc_ba_elev_line}" ]] \
  && [[ "${mc_ba_missing_line}" -lt "${mc_ba_elev_line}" ]]; then
  pass "multimedia-codecs lists the missing packages before the elevated step runs"
else
  fail "multimedia-codecs lists the missing packages before the elevated step runs (got ${mc_ba_missing_line} vs ${mc_ba_elev_line})"
fi
if printf '%s\n' "${output_ba}" | grep -Fq "sudo apt-get install -y ${MC_PKG_LIBAV} ${MC_PKG_EXTRA}"; then
  pass "multimedia-codecs shows the exact elevated command via the helper display"
else
  fail "multimedia-codecs shows the exact elevated command via the helper display"
fi
if printf '%s\n' "${output_ba}" | grep -Fq "${MC_PKG_LIBAV} — installed" \
  && printf '%s\n' "${output_ba}" | grep -Fq "${MC_PKG_EXTRA} — installed"; then
  pass "multimedia-codecs reports per-package success for both packages"
else
  fail "multimedia-codecs reports per-package success for both packages"
fi
if printf '%s\n' "${output_ba}" | grep -Fq "sudo apt-get remove ${MC_PKG_LIBAV} ${MC_PKG_EXTRA}"; then
  pass "multimedia-codecs prints the manual removal command via the helper display"
else
  fail "multimedia-codecs prints the manual removal command via the helper display"
fi
if printf '%s\n' "${output_ba}" | grep -Fq "not undone by mintbutler"; then
  pass "multimedia-codecs full success ends with the no-undo reminder"
else
  fail "multimedia-codecs full success ends with the no-undo reminder"
fi
ba_apt_lines="0"
if [[ -f "${BA_APT}" ]]; then
  ba_apt_lines="$(grep -c '^apt-get install -y ' "${BA_APT}" || true)"
fi
if [[ "${ba_apt_lines}" -eq 1 ]] \
  && grep -Fxq "apt-get install -y ${MC_PKG_LIBAV} ${MC_PKG_EXTRA}" "${BA_APT}"; then
  pass "stub log shows exactly one apt-get install -y call naming exactly the two missing packages"
else
  fail "stub log shows exactly one apt-get install -y call naming exactly the two missing packages (got ${ba_apt_lines} lines)"
fi
if grep -q "^${MC_PKG_LIBAV}$" "${MC_BA_STATE}" && grep -q "^${MC_PKG_EXTRA}$" "${MC_BA_STATE}" \
  && grep -q "^${MC_PKG_BAD}$" "${MC_BA_STATE}" && grep -q "^${MC_PKG_UGLY}$" "${MC_BA_STATE}"; then
  pass "stub dpkg state flips the two missing packages to installed"
else
  fail "stub dpkg state flips the two missing packages to installed"
fi
if diff -r "${MC_BA_HOME}" "${MC_BA_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "multimedia-codecs full success writes nothing to the fake HOME (no state file)"
else
  fail "multimedia-codecs full success modified the fake HOME"
fi

# Stage (bb): confirm-yes + MIXED result. The stub apt-get exits 0 but
# APTGET_STUB_SKIP keeps libavcodec-extra missing in the stub dpkg state,
# so verification reports one installed and one failed package: exit 1,
# per-package lists and the plain retry hint on stdout, one plain stderr
# line (the ask prompt shares its stderr line under scripted stdin).
printf 'Stage bb: multimedia-codecs confirm-yes mixed result\n'
MC_BB_HOME="${TMPBASE}/mc-home-bb"
MC_BB_HOME_BEFORE="${TMPBASE}/mc-home-bb-before"
mkdir -p "${MC_BB_HOME}"
cp -a "${MC_BB_HOME}" "${MC_BB_HOME_BEFORE}"
MC_BB_STATE="${TMPBASE}/mc-bb-packages.txt"
mc_seed_state "${MC_BB_STATE}" "${MC_PKG_BAD}" "${MC_PKG_UGLY}"
BB_APT="${TMPBASE}/mc-bb-aptget.log"
BB_STDOUT="${TMPBASE}/mc-bb.stdout"
BB_STDERR="${TMPBASE}/mc-bb.stderr"
code_bb="0"
printf 'y\n' | PATH="${MC_BIN_PASS}" HOME="${MC_BB_HOME}" \
  DPKG_STUB_STATE="${MC_BB_STATE}" APTGET_STUB_SKIP="${MC_PKG_EXTRA}" \
  APTGET_STUB_LOG="${BB_APT}" \
  bash "${MC_MODULE}" run > "${BB_STDOUT}" 2> "${BB_STDERR}" || code_bb="$?"
if [[ "${code_bb}" -eq 1 ]]; then
  pass "multimedia-codecs mixed result exits 1"
else
  fail "multimedia-codecs mixed result exits 1 (got ${code_bb})"
fi
if grep -Fq "${MC_PKG_LIBAV} — installed" "${BB_STDOUT}"; then
  pass "multimedia-codecs mixed result names the installed package"
else
  fail "multimedia-codecs mixed result names the installed package"
fi
if grep -Fq "${MC_PKG_EXTRA} — still missing" "${BB_STDOUT}"; then
  pass "multimedia-codecs mixed result names the failed package"
else
  fail "multimedia-codecs mixed result names the failed package"
fi
if grep -qi "Refresh the software sources" "${BB_STDOUT}" \
  && grep -qi "check the network" "${BB_STDOUT}" \
  && grep -qi "re-run" "${BB_STDOUT}"; then
  pass "multimedia-codecs mixed result prints the plain retry hint"
else
  fail "multimedia-codecs mixed result prints the plain retry hint"
fi
if grep -Fq "sudo apt-get remove ${MC_PKG_LIBAV}" "${BB_STDOUT}" \
  && ! grep -Fq "sudo apt-get remove ${MC_PKG_LIBAV} ${MC_PKG_EXTRA}" "${BB_STDOUT}"; then
  pass "multimedia-codecs mixed result prints the removal command for what did install only"
else
  fail "multimedia-codecs mixed result prints the removal command for what did install only"
fi
bb_err_lines="$(grep -c . "${BB_STDERR}" || true)"
if [[ "${bb_err_lines}" -eq 1 ]] && grep -q "still missing" "${BB_STDERR}"; then
  pass "multimedia-codecs mixed result prints one plain stderr line"
else
  fail "multimedia-codecs mixed result prints one plain stderr line (got ${bb_err_lines} lines)"
fi
if diff -r "${MC_BB_HOME}" "${MC_BB_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "multimedia-codecs mixed result writes nothing to the fake HOME"
else
  fail "multimedia-codecs mixed result modified the fake HOME"
fi

# Stage (bc): elevated failure. The stub sudo refuses, so the single
# elevated apt-get step fails: non-zero exit, one plain stderr line naming
# the failed elevated step (lines carrying the stub refusal are filtered;
# under scripted stdin the ask prompt shares the refusal's line), nothing
# claimed on stdout, nothing written anywhere.
printf 'Stage bc: multimedia-codecs elevated failure\n'
MC_BC_HOME="${TMPBASE}/mc-home-bc"
MC_BC_HOME_BEFORE="${TMPBASE}/mc-home-bc-before"
mkdir -p "${MC_BC_HOME}"
cp -a "${MC_BC_HOME}" "${MC_BC_HOME_BEFORE}"
MC_BC_STATE="${TMPBASE}/mc-bc-packages.txt"
mc_seed_state "${MC_BC_STATE}" "${MC_PKG_BAD}" "${MC_PKG_UGLY}"
cp "${MC_BC_STATE}" "${MC_BC_STATE}.seeded"
BC_APT="${TMPBASE}/mc-bc-aptget.log"
BC_STDOUT="${TMPBASE}/mc-bc.stdout"
BC_STDERR="${TMPBASE}/mc-bc.stderr"
code_bc="0"
printf 'y\n' | PATH="${MC_BIN_FAIL}" HOME="${MC_BC_HOME}" \
  DPKG_STUB_STATE="${MC_BC_STATE}" APTGET_STUB_LOG="${BC_APT}" \
  bash "${MC_MODULE}" run > "${BC_STDOUT}" 2> "${BC_STDERR}" || code_bc="$?"
if [[ "${code_bc}" -ne 0 ]]; then
  pass "multimedia-codecs elevated failure exits non-zero (got ${code_bc})"
else
  fail "multimedia-codecs elevated failure exits non-zero"
fi
bc_module_lines="$(grep -v 'sudo-stub:' "${BC_STDERR}" | grep -v 'Install the missing codec packages now' | grep -c . || true)"
if [[ "${bc_module_lines}" -eq 1 ]] && grep -q "elevated apt-get step failed" "${BC_STDERR}"; then
  pass "multimedia-codecs elevated failure prints one plain stderr line naming the failed elevated step"
else
  fail "multimedia-codecs elevated failure prints one plain stderr line naming the failed elevated step (got ${bc_module_lines} lines)"
fi
if ! grep -q "Verified" "${BC_STDOUT}" && ! grep -Fq "— installed" "${BC_STDOUT}"; then
  pass "multimedia-codecs elevated failure claims no result on stdout"
else
  fail "multimedia-codecs elevated failure claims no result on stdout"
fi
if [[ ! -e "${BC_APT}" ]]; then
  pass "multimedia-codecs elevated failure never reaches apt-get"
else
  fail "multimedia-codecs elevated failure never reaches apt-get"
fi
if cmp -s "${MC_BC_STATE}" "${MC_BC_STATE}.seeded" \
  && diff -r "${MC_BC_HOME}" "${MC_BC_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "multimedia-codecs elevated failure writes nothing (state and fake HOME byte-identical)"
else
  fail "multimedia-codecs elevated failure wrote something"
fi


# ---------------------------------------------------------------------------
# Stages (bd)-(bi): printer-helper (user-level, diagnose-first) — stub-only
# verification. Every stage runs with a controlled PATH (stub lpstat/lpinfo/
# lpoptions plus symlinks to the coreutils the module needs) and a fake HOME
# under mktemp. No stage ever invokes a real CUPS tool, and no stub ever
# touches the real printing stack: the stub lpoptions only rewrites a stub
# state file. Where the module's interactive confirmation matters, stages
# drive the module binary directly with piped stdin (the menu path cannot
# script a confirmation).
# ---------------------------------------------------------------------------

PH_MODULE="${REPO_ROOT}/modules/printer-helper/module.sh"
PH_STUB_ROOT="${TMPBASE}/ph-stubs"
PH_STATE_REL=".local/state/mintbutler/printer-helper/default.record"
mkdir -p "${PH_STUB_ROOT}"

# Controlled-PATH builder: symlink the coreutils the module (and the lib
# helper it sources) needs from the host; each stage's bin dir then gets only
# the stubs that stage wants present.
ph_make_bin() {
  local dir="${1:-}"
  mkdir -p "${dir}"
  local tool tool_path
  for tool in dirname sed mkdir rm rmdir mv bash date tr grep cut awk timeout head wc cat; do
    tool_path="$(command -v "${tool}" || true)"
    if [[ -n "${tool_path}" ]]; then
      ln -sf "${tool_path}" "${dir}/${tool}"
    fi
  done
  printf '%s\n' "${dir}"
}

# Stub lpstat: file-backed default printer. LPSTAT_STUB_STATE names a
# default=<queue> / default=none file that the stub lpoptions rewrites.
# LPSTAT_STUB_SCHED (running|down|fail) drives `lpstat -r`;
# LPSTAT_STUB_QUEUES holds the canned `lpstat -p` lines (%-decoded, empty
# means no queue at all). LPSTAT_STUB_LOG records every invocation.
# Note on the case patterns: "$1 $2 $3" keeps the separators, so a one-arg
# call reads "-r  " (two trailing spaces) and "-p -d " reads three args.
cat <<'PH_LPSTAT_STUB' > "${PH_STUB_ROOT}/lpstat"
#!/usr/bin/env bash
set -euo pipefail
LOG="${LPSTAT_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'lpstat%s\n' "${*:+ $*}" >> "${LOG}"
fi
STATE="${LPSTAT_STUB_STATE:?lpstat-stub: LPSTAT_STUB_STATE is not set}"
cur=none
if [[ -f "${STATE}" ]]; then
  cur="$(sed -n 's/^default=//p' "${STATE}" | head -n 1)"
fi
case "${1:-} ${2:-} ${3:-}" in
  "-r  ")
    case "${LPSTAT_STUB_SCHED:-running}" in
      down)
        printf 'scheduler is not running\n'
        ;;
      fail)
        exit 1
        ;;
      *)
        printf 'scheduler is running\n'
        ;;
    esac
    ;;
  "-p -d ")
    if [[ "${cur}" == "none" || -z "${cur}" ]]; then
      printf 'no system default destination\n'
    else
      printf 'system default destination: %s\n' "${cur}"
    fi
    if [[ -n "${LPSTAT_STUB_QUEUES:-}" ]]; then
      printf '%b\n' "${LPSTAT_STUB_QUEUES}"
    fi
    ;;
  "-d  ")
    if [[ "${cur}" == "none" || -z "${cur}" ]]; then
      printf 'no system default destination\n'
    else
      printf 'system default destination: %s\n' "${cur}"
    fi
    ;;
  *)
    printf 'lpstat-stub: unsupported invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
PH_LPSTAT_STUB

# Stub lpinfo: LPINFO_STUB_MODE (usb|many|empty|fail) drives the -v scan.
cat <<'PH_LPINFO_STUB' > "${PH_STUB_ROOT}/lpinfo"
#!/usr/bin/env bash
set -euo pipefail
LOG="${LPINFO_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'lpinfo%s\n' "${*:+ $*}" >> "${LOG}"
fi
if [[ "${1:-}" != "-v" ]]; then
  printf 'lpinfo-stub: unsupported invocation: %s\n' "$*" >&2
  exit 2
fi
case "${LPINFO_STUB_MODE:-usb}" in
  usb)
    printf 'direct usb://HP/OfficeJet%%205200%%20series?serial=CN123\n'
    ;;
  many)
    printf 'direct usb://HP/OfficeJet%%205200%%20series?serial=CN123\n'
    printf 'network ipps://BRW1234567890AB._ipps._tcp.local/\n'
    printf 'network socket://192.168.1.20\n'
    printf 'network lpd://192.168.1.21/L1\n'
    ;;
  empty)
    :
    ;;
  fail)
    printf 'lpinfo-stub: scan refused\n' >&2
    exit 1
    ;;
  *)
    printf 'lpinfo-stub: unsupported mode: %s\n' "${LPINFO_STUB_MODE}" >&2
    exit 2
    ;;
esac
PH_LPINFO_STUB

# Stub lpoptions: logs every call to LPOPTIONS_STUB_LOG, then rewrites the
# stub state file — `lpoptions -d <queue>` records default=<queue>,
# `lpoptions -x` records default=none. LPOPTIONS_STUB_FAIL=1 makes -d fail.
# It never touches anything outside the stub state file.
cat <<'PH_LPOPTIONS_STUB' > "${PH_STUB_ROOT}/lpoptions"
#!/usr/bin/env bash
set -euo pipefail
LOG="${LPOPTIONS_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'lpoptions%s\n' "${*:+ $*}" >> "${LOG}"
fi
STATE="${LPSTAT_STUB_STATE:?lpoptions-stub: LPSTAT_STUB_STATE is not set}"
if [[ "${1:-}" == "-d" && -n "${2:-}" ]]; then
  if [[ "${LPOPTIONS_STUB_FAIL:-0}" == "1" ]]; then
    printf 'lpoptions-stub: refused\n' >&2
    exit 1
  fi
  printf 'default=%s\n' "${2}" > "${STATE}"
  exit 0
fi
if [[ "${1:-}" == "-x" ]]; then
  printf 'default=none\n' > "${STATE}"
  exit 0
fi
printf 'lpoptions-stub: unsupported invocation: %s\n' "$*" >&2
exit 2
PH_LPOPTIONS_STUB

chmod +x "${PH_STUB_ROOT}/lpstat" "${PH_STUB_ROOT}/lpinfo" "${PH_STUB_ROOT}/lpoptions"

# Bin dir with only coreutils: no lpstat/lpinfo/lpoptions at all — the
# preflight path every lint sandbox takes.
PH_BIN_EMPTY="${PH_STUB_ROOT}/bin-empty"
ph_make_bin "${PH_BIN_EMPTY}" >/dev/null

# Bin dir for every diagnosis path: all three stub tools present.
PH_BIN_MAIN="${PH_STUB_ROOT}/bin-main"
ph_make_bin "${PH_BIN_MAIN}" >/dev/null
cp "${PH_STUB_ROOT}/lpstat" "${PH_STUB_ROOT}/lpinfo" "${PH_STUB_ROOT}/lpoptions" "${PH_BIN_MAIN}/"

# One idle, enabled queue — the healthy fixture used across the stages.
PH_QUEUE_IDLE='printer OfficeJet-5200 is idle.  enabled since Thu 18 Sep 2025 10:00:00 AM'

# Stage (bd): gate + read-only smokes.
printf 'Stage bd: printer-helper gate, scan, list, plan/dry-run, missing preflight\n'

output_bd_scan=""
code_bd_scan="0"
output_bd_scan="$(cd "${REPO_ROOT}" && ./butler --scan 2>&1)" || code_bd_scan="$?"
if [[ "${code_bd_scan}" -ne 0 ]]; then
  fail "butler --scan exits 0 with printer-helper present (got ${code_bd_scan})"
else
  pass "butler --scan exits 0 with printer-helper present"
fi
if printf '%s\n' "${output_bd_scan}" | grep -q "PASS printer-helper"; then
  pass "butler --scan reports PASS printer-helper"
else
  fail "butler --scan reports PASS printer-helper"
fi

output_bd_lint1=""
code_bd_lint1="0"
output_bd_lint1="$(cd "${REPO_ROOT}" && bin/modulelint printer-helper 2>&1)" || code_bd_lint1="$?"
if [[ "${code_bd_lint1}" -ne 0 ]]; then
  fail "bin/modulelint printer-helper exits 0 (got ${code_bd_lint1})"
else
  pass "bin/modulelint printer-helper exits 0"
fi
if printf '%s\n' "${output_bd_lint1}" | grep -q "PASS printer-helper"; then
  pass "bin/modulelint reports PASS printer-helper"
else
  fail "bin/modulelint reports PASS printer-helper"
fi

code_bd_lint="0"
(cd "${REPO_ROOT}" && bin/modulelint >/dev/null 2>&1) || code_bd_lint="$?"
if [[ "${code_bd_lint}" -ne 0 ]]; then
  fail "bin/modulelint exits 0 over all modules with printer-helper present (got ${code_bd_lint})"
else
  pass "bin/modulelint exits 0 over all modules with printer-helper present"
fi

output_bd_list=""
code_bd_list="0"
output_bd_list="$(cd "${REPO_ROOT}" && ./butler --list 2>&1)" || code_bd_list="$?"
if [[ "${code_bd_list}" -ne 0 ]]; then
  fail "butler --list exits 0 (got ${code_bd_list})"
else
  pass "butler --list exits 0"
fi
ph_bd_list_line="$(printf '%s\n' "${output_bd_list}" | grep -- "printer-helper: Printer helper" || true)"
if [[ -n "${ph_bd_list_line}" ]]; then
  pass "butler --list shows printer-helper: Printer helper"
else
  fail "butler --list shows printer-helper: Printer helper"
fi
if [[ "${ph_bd_list_line}" == *"⚠ elevated"* ]]; then
  fail "butler --list shows NO elevated badge on printer-helper"
else
  pass "butler --list shows NO elevated badge on printer-helper"
fi
if printf '%s\n' "${output_bd_list}" | grep -q "multimedia-codecs" \
  && printf '%s\n' "${output_bd_list}" | grep -q "audio-repair" \
  && printf '%s\n' "${output_bd_list}" | grep -q "desktop-shortcut-creator"; then
  pass "butler --list still shows the earlier modules"
else
  fail "butler --list still shows the earlier modules"
fi

# Menu position smoke: with the current module set, order 60 renders as
# entry 6 on page 1 (positions are recomputed at scan time), and a
# user-level module carries no elevated badge.
output_bd_menu=""
code_bd_menu="0"
output_bd_menu="$(printf 'q\n' | (cd "${REPO_ROOT}" && ./butler) 2>&1)" || code_bd_menu="$?"
ph_bd_menu_line="$(printf '%s\n' "${output_bd_menu}" | grep -F "6) Printer helper" || true)"
if [[ "${code_bd_menu}" -eq 0 && -n "${ph_bd_menu_line}" && "${ph_bd_menu_line}" != *"⚠ elevated"* ]]; then
  pass "menu renders Printer helper at its order-60 position without an elevated badge"
else
  fail "menu renders Printer helper at its order-60 position without an elevated badge (got ${code_bd_menu}: ${ph_bd_menu_line})"
fi

PH_BD_HOME="${TMPBASE}/ph-home-bd"
PH_BD_HOME_BEFORE="${TMPBASE}/ph-home-bd-before"
mkdir -p "${PH_BD_HOME}"
cp -a "${PH_BD_HOME}" "${PH_BD_HOME_BEFORE}"

output_bd_plan=""
code_bd_plan="0"
output_bd_plan="$(HOME="${PH_BD_HOME}" XDG_STATE_HOME="" bash "${PH_MODULE}" plan < /dev/null 2>&1)" || code_bd_plan="$?"
ph_bd_plan_lines="$(printf '%s\n' "${output_bd_plan}" | grep -c . || true)"
if [[ "${code_bd_plan}" -eq 0 && -n "${output_bd_plan}" ]]; then
  pass "printer-helper plan exits 0 and non-empty"
else
  fail "printer-helper plan exits 0 and non-empty (got ${code_bd_plan})"
fi
if [[ "${ph_bd_plan_lines}" -le 23 ]]; then
  pass "printer-helper plan renders in <= 23 lines (got ${ph_bd_plan_lines})"
else
  fail "printer-helper plan renders in <= 23 lines (got ${ph_bd_plan_lines})"
fi

output_bd_dry=""
code_bd_dry="0"
output_bd_dry="$(HOME="${PH_BD_HOME}" XDG_STATE_HOME="" bash "${PH_MODULE}" dry-run < /dev/null 2>&1)" || code_bd_dry="$?"
ph_bd_dry_lines="$(printf '%s\n' "${output_bd_dry}" | grep -c . || true)"
if [[ "${code_bd_dry}" -eq 0 && -n "${output_bd_dry}" ]]; then
  pass "printer-helper dry-run exits 0 and non-empty"
else
  fail "printer-helper dry-run exits 0 and non-empty (got ${code_bd_dry})"
fi
if [[ "${ph_bd_dry_lines}" -le 23 ]]; then
  pass "printer-helper dry-run renders in <= 23 lines (got ${ph_bd_dry_lines})"
else
  fail "printer-helper dry-run renders in <= 23 lines (got ${ph_bd_dry_lines})"
fi
if printf '%s\n' "${output_bd_dry}" | grep -Fq "lpstat -r"; then
  pass "printer-helper dry-run contains the exact string 'lpstat -r'"
else
  fail "printer-helper dry-run contains the exact string 'lpstat -r'"
fi
if printf '%s\n' "${output_bd_dry}" | grep -Fq "lpoptions -d"; then
  pass "printer-helper dry-run contains the exact string 'lpoptions -d'"
else
  fail "printer-helper dry-run contains the exact string 'lpoptions -d'"
fi
if diff -r "${PH_BD_HOME}" "${PH_BD_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "printer-helper plan and dry-run write nothing to the fake HOME"
else
  fail "printer-helper plan and dry-run modified the fake HOME"
fi

# Menu-flag smoke (owner acceptance command): --run <slug> --dry-run is
# non-destructive.
code_bd_menudry="0"
HOME="${PH_BD_HOME}" XDG_STATE_HOME="" bash -c 'cd "'"${REPO_ROOT}"'" && ./butler --run printer-helper --dry-run' >/dev/null 2>&1 || code_bd_menudry="$?"
if [[ "${code_bd_menudry}" -eq 0 ]]; then
  pass "butler --run printer-helper --dry-run exits 0"
else
  fail "butler --run printer-helper --dry-run exits 0 (got ${code_bd_menudry})"
fi
if diff -r "${PH_BD_HOME}" "${PH_BD_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "butler --run printer-helper --dry-run leaves the fake HOME untouched"
else
  fail "butler --run printer-helper --dry-run modified the fake HOME"
fi

# Missing-tools preflight (modulelint compatibility): stdin /dev/null and no
# lp* tool on PATH -> exit 1, one plain stderr line, fake HOME unchanged.
PH_BD2_HOME="${TMPBASE}/ph-home-bd2"
PH_BD2_HOME_BEFORE="${TMPBASE}/ph-home-bd2-before"
PH_BD2_STDERR="${TMPBASE}/ph-bd2.stderr"
mkdir -p "${PH_BD2_HOME}"
cp -a "${PH_BD2_HOME}" "${PH_BD2_HOME_BEFORE}"
code_bd_run="0"
PATH="${PH_BIN_EMPTY}" HOME="${PH_BD2_HOME}" XDG_STATE_HOME="" \
  bash "${PH_MODULE}" run < /dev/null >/dev/null 2>"${PH_BD2_STDERR}" || code_bd_run="$?"
if [[ "${code_bd_run}" -eq 1 ]]; then
  pass "printer-helper missing-tools preflight exits 1 (got ${code_bd_run})"
else
  fail "printer-helper missing-tools preflight exits 1 (got ${code_bd_run})"
fi
bd2_stderr_lines="$(grep -c . "${PH_BD2_STDERR}" || true)"
if [[ "${bd2_stderr_lines}" -eq 1 ]] && grep -q "Printing tools missing" "${PH_BD2_STDERR}"; then
  pass "printer-helper missing-tools preflight prints one plain stderr line"
else
  fail "printer-helper missing-tools preflight prints one plain stderr line (got ${bd2_stderr_lines}: $(cat "${PH_BD2_STDERR}"))"
fi
if diff -r "${PH_BD2_HOME}" "${PH_BD2_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "printer-helper missing-tools preflight writes nothing to the fake HOME"
else
  fail "printer-helper missing-tools preflight modified the fake HOME"
fi

# Zero-elevation source assertions: no sudo/pkexec literal anywhere
# (display strings included) and no lib/elevate.sh sourcing.
if grep -w -E -q 'sudo|pkexec' "${PH_MODULE}"; then
  fail "printer-helper source contains no sudo/pkexec literal"
else
  pass "printer-helper source contains no sudo/pkexec literal"
fi
ph_elevate_source="source \"\${LIB_DIR}/elevate.sh\""
if grep -F -q "${ph_elevate_source}" "${PH_MODULE}"; then
  fail "printer-helper never sources lib/elevate.sh"
else
  pass "printer-helper never sources lib/elevate.sh"
fi

# Stage (be): healthy chain — scheduler running, one idle queue, the default
# already pointing at it, one USB device on the scan.
printf 'Stage be: printer-helper healthy chain\n'
PH_BE_HOME="${TMPBASE}/ph-home-be"
PH_BE_HOME_BEFORE="${TMPBASE}/ph-home-be-before"
PH_BE_STATE="${TMPBASE}/ph-be-default.txt"
mkdir -p "${PH_BE_HOME}"
cp -a "${PH_BE_HOME}" "${PH_BE_HOME_BEFORE}"
printf 'default=OfficeJet-5200\n' > "${PH_BE_STATE}"
BE_OPT="${TMPBASE}/ph-be-lpoptions.log"
output_be=""
code_be="0"
output_be="$(PATH="${PH_BIN_MAIN}" HOME="${PH_BE_HOME}" XDG_STATE_HOME="" \
  LPSTAT_STUB_STATE="${PH_BE_STATE}" LPSTAT_STUB_QUEUES="${PH_QUEUE_IDLE}" \
  LPINFO_STUB_MODE=usb LPOPTIONS_STUB_LOG="${BE_OPT}" \
  bash "${PH_MODULE}" run < /dev/null 2>&1)" || code_be="$?"
if [[ "${code_be}" -eq 0 ]]; then
  pass "printer-helper healthy chain exits 0"
else
  fail "printer-helper healthy chain exits 0 (got ${code_be})"
fi
if printf '%s\n' "${output_be}" | grep -q "the printing stack looks healthy"; then
  pass "printer-helper healthy chain verdict says the printing stack looks healthy"
else
  fail "printer-helper healthy chain verdict says the printing stack looks healthy"
fi
if printf '%s\n' "${output_be}" | grep -q "Device scan: 1 device(s) reported" \
  && printf '%s\n' "${output_be}" | grep -q "usb://HP/OfficeJet"; then
  pass "printer-helper healthy chain shows the device summary"
else
  fail "printer-helper healthy chain shows the device summary"
fi
if [[ ! -e "${PH_BE_HOME}/${PH_STATE_REL}" ]]; then
  pass "printer-helper healthy chain writes no state file"
else
  fail "printer-helper healthy chain writes no state file"
fi
if printf '%s\n' "${output_be}" | grep -Fq "[y/N]"; then
  fail "printer-helper healthy chain asks no question"
else
  pass "printer-helper healthy chain asks no question"
fi
if [[ ! -e "${BE_OPT}" ]]; then
  pass "printer-helper healthy chain never calls lpoptions"
else
  fail "printer-helper healthy chain never calls lpoptions"
fi
if diff -r "${PH_BE_HOME}" "${PH_BE_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "printer-helper healthy chain writes nothing to the fake HOME"
else
  fail "printer-helper healthy chain modified the fake HOME"
fi

# Stage (bf): scheduler down — both the "not running" reply and a failing
# lpstat -r exit 0 with the honest verdict and nothing written.
printf 'Stage bf: printer-helper scheduler-down verdict\n'
PH_BF_HOME="${TMPBASE}/ph-home-bf"
PH_BF_HOME_BEFORE="${TMPBASE}/ph-home-bf-before"
PH_BF_STATE="${TMPBASE}/ph-bf-default.txt"
mkdir -p "${PH_BF_HOME}"
cp -a "${PH_BF_HOME}" "${PH_BF_HOME_BEFORE}"
printf 'default=none\n' > "${PH_BF_STATE}"
output_bf=""
code_bf="0"
output_bf="$(PATH="${PH_BIN_MAIN}" HOME="${PH_BF_HOME}" XDG_STATE_HOME="" \
  LPSTAT_STUB_STATE="${PH_BF_STATE}" LPSTAT_STUB_QUEUES="${PH_QUEUE_IDLE}" \
  LPSTAT_STUB_SCHED=down LPOPTIONS_STUB_LOG="${TMPBASE}/ph-bf-lpoptions.log" \
  bash "${PH_MODULE}" run < /dev/null 2>&1)" || code_bf="$?"
if [[ "${code_bf}" -eq 0 ]]; then
  pass "printer-helper scheduler-down exits 0 (verdict delivered)"
else
  fail "printer-helper scheduler-down exits 0 (got ${code_bf})"
fi
if printf '%s\n' "${output_bf}" | grep -q "the CUPS printing service is not running"; then
  pass "printer-helper scheduler-down verdict names the CUPS printing service"
else
  fail "printer-helper scheduler-down verdict names the CUPS printing service"
fi
if printf '%s\n' "${output_bf}" | grep -q "Printers settings" \
  && printf '%s\n' "${output_bf}" | grep -qi "reboot"; then
  pass "printer-helper scheduler-down guidance names Printers settings and a reboot"
else
  fail "printer-helper scheduler-down guidance names Printers settings and a reboot"
fi
if [[ ! -e "${PH_BF_HOME}/${PH_STATE_REL}" ]]; then
  pass "printer-helper scheduler-down writes no state file"
else
  fail "printer-helper scheduler-down writes no state file"
fi
if diff -r "${PH_BF_HOME}" "${PH_BF_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "printer-helper scheduler-down writes nothing to the fake HOME"
else
  fail "printer-helper scheduler-down modified the fake HOME"
fi
output_bf2=""
code_bf2="0"
output_bf2="$(PATH="${PH_BIN_MAIN}" HOME="${PH_BF_HOME}" XDG_STATE_HOME="" \
  LPSTAT_STUB_STATE="${PH_BF_STATE}" LPSTAT_STUB_QUEUES="${PH_QUEUE_IDLE}" \
  LPSTAT_STUB_SCHED=fail \
  bash "${PH_MODULE}" run < /dev/null 2>&1)" || code_bf2="$?"
if [[ "${code_bf2}" -eq 0 ]] \
  && printf '%s\n' "${output_bf2}" | grep -q "the CUPS printing service is not running"; then
  pass "printer-helper reports the same verdict when lpstat -r fails outright"
else
  fail "printer-helper reports the same verdict when lpstat -r fails outright (got ${code_bf2})"
fi

# Stage (bg): no queues at all -> guided setup, never vendor blobs.
printf 'Stage bg: printer-helper no-queue guided setup\n'
PH_BG_HOME="${TMPBASE}/ph-home-bg"
PH_BG_HOME_BEFORE="${TMPBASE}/ph-home-bg-before"
PH_BG_STATE="${TMPBASE}/ph-bg-default.txt"
mkdir -p "${PH_BG_HOME}"
cp -a "${PH_BG_HOME}" "${PH_BG_HOME_BEFORE}"
printf 'default=none\n' > "${PH_BG_STATE}"
output_bg=""
code_bg="0"
output_bg="$(PATH="${PH_BIN_MAIN}" HOME="${PH_BG_HOME}" XDG_STATE_HOME="" \
  LPSTAT_STUB_STATE="${PH_BG_STATE}" LPSTAT_STUB_QUEUES="" \
  LPINFO_STUB_MODE=usb LPOPTIONS_STUB_LOG="${TMPBASE}/ph-bg-lpoptions.log" \
  bash "${PH_MODULE}" run < /dev/null 2>&1)" || code_bg="$?"
if [[ "${code_bg}" -eq 0 ]]; then
  pass "printer-helper no-queue path exits 0"
else
  fail "printer-helper no-queue path exits 0 (got ${code_bg})"
fi
if printf '%s\n' "${output_bg}" | grep -q "Printers settings"; then
  pass "printer-helper no-queue verdict names Mint's Printers settings app"
else
  fail "printer-helper no-queue verdict names Mint's Printers settings app"
fi
if printf '%s\n' "${output_bg}" | grep -q "localhost:631"; then
  pass "printer-helper no-queue verdict names the CUPS web interface at localhost:631"
else
  fail "printer-helper no-queue verdict names the CUPS web interface at localhost:631"
fi
if printf '%s\n' "${output_bg}" | grep -q "IPP Everywhere"; then
  pass "printer-helper no-queue verdict names driverless IPP Everywhere"
else
  fail "printer-helper no-queue verdict names driverless IPP Everywhere"
fi
if printf '%s\n' "${output_bg}" | grep -q "never downloads, recommends, or installs vendor drivers or blobs"; then
  pass "printer-helper no-queue verdict contains the never-vendor-blobs statement"
else
  fail "printer-helper no-queue verdict contains the never-vendor-blobs statement"
fi
if [[ ! -e "${PH_BG_HOME}/${PH_STATE_REL}" ]]; then
  pass "printer-helper no-queue path writes no state file"
else
  fail "printer-helper no-queue path writes no state file"
fi
if diff -r "${PH_BG_HOME}" "${PH_BG_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "printer-helper no-queue path writes nothing to the fake HOME"
else
  fail "printer-helper no-queue path modified the fake HOME"
fi

# Stage (bh): default repair + undo. One idle queue and NO default; scripted
# stdin 'y' accepts the repair, then undo restores "no default" again.
printf 'Stage bh: printer-helper default repair and undo\n'
PH_BH_HOME="${TMPBASE}/ph-home-bh"
PH_BH_STATE="${TMPBASE}/ph-bh-default.txt"
mkdir -p "${PH_BH_HOME}"
printf 'default=none\n' > "${PH_BH_STATE}"
BH_OPT="${TMPBASE}/ph-bh-lpoptions.log"
output_bh=""
code_bh="0"
output_bh="$(printf 'y\n' | PATH="${PH_BIN_MAIN}" HOME="${PH_BH_HOME}" XDG_STATE_HOME="" \
  LPSTAT_STUB_STATE="${PH_BH_STATE}" LPSTAT_STUB_QUEUES="${PH_QUEUE_IDLE}" \
  LPINFO_STUB_MODE=usb LPOPTIONS_STUB_LOG="${BH_OPT}" \
  bash "${PH_MODULE}" run 2>&1)" || code_bh="$?"
if [[ "${code_bh}" -eq 0 ]]; then
  pass "printer-helper default repair exits 0"
else
  fail "printer-helper default repair exits 0 (got ${code_bh})"
fi
if printf '%s\n' "${output_bh}" | grep -q "current:" \
  && printf '%s\n' "${output_bh}" | grep -q "proposed:"; then
  pass "printer-helper repair offer shows current-vs-proposed before confirming"
else
  fail "printer-helper repair offer shows current-vs-proposed before confirming"
fi
PH_BH_RECORD="${PH_BH_HOME}/${PH_STATE_REL}"
if [[ -f "${PH_BH_RECORD}" ]] && grep -q "^prev_default=none$" "${PH_BH_RECORD}"; then
  pass "printer-helper repair records prev_default=none before applying"
else
  fail "printer-helper repair records prev_default=none before applying"
fi
bh_apply_calls="$(grep -c '^lpoptions -d OfficeJet-5200$' "${BH_OPT}" || true)"
if [[ "${bh_apply_calls}" -eq 1 ]]; then
  pass "printer-helper repair calls lpoptions -d <queue> exactly once"
else
  fail "printer-helper repair calls lpoptions -d <queue> exactly once (got ${bh_apply_calls})"
fi
if grep -q "^default=OfficeJet-5200$" "${PH_BH_STATE}"; then
  pass "printer-helper repair leaves the stub stack pointing at the new default"
else
  fail "printer-helper repair leaves the stub stack pointing at the new default"
fi
if printf '%s\n' "${output_bh}" | grep -qi "undo"; then
  pass "printer-helper repair output points at undo for the recorded default"
else
  fail "printer-helper repair output points at undo for the recorded default"
fi

output_bhu=""
code_bhu="0"
output_bhu="$(PATH="${PH_BIN_MAIN}" HOME="${PH_BH_HOME}" XDG_STATE_HOME="" \
  LPSTAT_STUB_STATE="${PH_BH_STATE}" LPOPTIONS_STUB_LOG="${BH_OPT}" \
  bash "${PH_MODULE}" undo < /dev/null 2>&1)" || code_bhu="$?"
if [[ "${code_bhu}" -eq 0 ]]; then
  pass "printer-helper undo exits 0"
else
  fail "printer-helper undo exits 0 (got ${code_bhu})"
fi
bh_undo_calls="$(grep -c '^lpoptions -x$' "${BH_OPT}" || true)"
if [[ "${bh_undo_calls}" -eq 1 ]]; then
  pass "printer-helper undo calls lpoptions -x for a prev_default=none record"
else
  fail "printer-helper undo calls lpoptions -x for a prev_default=none record (got ${bh_undo_calls})"
fi
if grep -q "^default=none$" "${PH_BH_STATE}"; then
  pass "printer-helper undo restores no-default state in the stub stack"
else
  fail "printer-helper undo restores no-default state in the stub stack"
fi
if [[ ! -e "${PH_BH_RECORD}" ]]; then
  pass "printer-helper undo deletes the state record"
else
  fail "printer-helper undo deletes the state record"
fi
if printf '%s\n' "${output_bhu}" | grep -q "never needed undoing"; then
  pass "printer-helper undo states the diagnosis steps never needed undoing"
else
  fail "printer-helper undo states the diagnosis steps never needed undoing"
fi
output_bhu2=""
code_bhu2="0"
output_bhu2="$(PATH="${PH_BIN_MAIN}" HOME="${PH_BH_HOME}" XDG_STATE_HOME="" \
  LPSTAT_STUB_STATE="${PH_BH_STATE}" \
  bash "${PH_MODULE}" undo < /dev/null 2>&1)" || code_bhu2="$?"
if [[ "${code_bhu2}" -eq 0 ]] && printf '%s\n' "${output_bhu2}" | grep -q "Nothing to undo."; then
  pass "printer-helper second undo reports Nothing to undo and exits 0"
else
  fail "printer-helper second undo reports Nothing to undo and exits 0 (got ${code_bhu2})"
fi

# Undo with lpoptions missing: honest refusal, one plain stderr line, and
# the record is kept so nothing is silently lost.
PH_BH2_HOME="${TMPBASE}/ph-home-bh2"
PH_BH2_STDERR="${TMPBASE}/ph-bh2.stderr"
mkdir -p "${PH_BH2_HOME}/.local/state/mintbutler/printer-helper"
printf 'prev_default=none\n' > "${PH_BH2_HOME}/${PH_STATE_REL}"
code_bh2="0"
PATH="${PH_BIN_EMPTY}" HOME="${PH_BH2_HOME}" XDG_STATE_HOME="" \
  bash "${PH_MODULE}" undo < /dev/null >/dev/null 2>"${PH_BH2_STDERR}" || code_bh2="$?"
bh2_stderr_lines="$(grep -c . "${PH_BH2_STDERR}" || true)"
if [[ "${code_bh2}" -eq 1 && "${bh2_stderr_lines}" -eq 1 ]] \
  && grep -q "Cannot undo" "${PH_BH2_STDERR}"; then
  pass "printer-helper undo without lpoptions refuses honestly with one stderr line"
else
  fail "printer-helper undo without lpoptions refuses honestly with one stderr line (got ${code_bh2}/${bh2_stderr_lines}: $(cat "${PH_BH2_STDERR}"))"
fi
if [[ -f "${PH_BH2_HOME}/${PH_STATE_REL}" ]]; then
  pass "printer-helper undo without lpoptions keeps the record"
else
  fail "printer-helper undo without lpoptions keeps the record"
fi

# Stage (bi): confirm-no, and the apply-failure path with a stub lpoptions
# that refuses -d.
printf 'Stage bi: printer-helper confirm-no and apply failure\n'
PH_BI_HOME="${TMPBASE}/ph-home-bi"
PH_BI_HOME_BEFORE="${TMPBASE}/ph-home-bi-before"
PH_BI_STATE="${TMPBASE}/ph-bi-default.txt"
mkdir -p "${PH_BI_HOME}"
cp -a "${PH_BI_HOME}" "${PH_BI_HOME_BEFORE}"
printf 'default=none\n' > "${PH_BI_STATE}"
BI_OPT="${TMPBASE}/ph-bi-lpoptions.log"
output_bi=""
code_bi="0"
output_bi="$(printf 'n\n' | PATH="${PH_BIN_MAIN}" HOME="${PH_BI_HOME}" XDG_STATE_HOME="" \
  LPSTAT_STUB_STATE="${PH_BI_STATE}" LPSTAT_STUB_QUEUES="${PH_QUEUE_IDLE}" \
  LPINFO_STUB_MODE=usb LPOPTIONS_STUB_LOG="${BI_OPT}" \
  bash "${PH_MODULE}" run 2>&1)" || code_bi="$?"
if [[ "${code_bi}" -eq 0 ]]; then
  pass "printer-helper confirm-no exits 0"
else
  fail "printer-helper confirm-no exits 0 (got ${code_bi})"
fi
if printf '%s\n' "${output_bi}" | grep -q "Nothing changed."; then
  pass "printer-helper confirm-no prints Nothing changed."
else
  fail "printer-helper confirm-no prints Nothing changed."
fi
if [[ ! -e "${BI_OPT}" ]]; then
  pass "printer-helper confirm-no never calls lpoptions"
else
  fail "printer-helper confirm-no never calls lpoptions"
fi
if [[ ! -e "${PH_BI_HOME}/${PH_STATE_REL}" ]]; then
  pass "printer-helper confirm-no writes no state"
else
  fail "printer-helper confirm-no writes no state"
fi
if diff -r "${PH_BI_HOME}" "${PH_BI_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "printer-helper confirm-no writes nothing to the fake HOME"
else
  fail "printer-helper confirm-no modified the fake HOME"
fi

PH_BI2_HOME="${TMPBASE}/ph-home-bi2"
PH_BI2_STATE="${TMPBASE}/ph-bi2-default.txt"
PH_BI2_STDERR="${TMPBASE}/ph-bi2.stderr"
PH_BI2_STDOUT="${TMPBASE}/ph-bi2.stdout"
mkdir -p "${PH_BI2_HOME}"
printf 'default=none\n' > "${PH_BI2_STATE}"
code_bi2="0"
printf 'y\n' | PATH="${PH_BIN_MAIN}" HOME="${PH_BI2_HOME}" XDG_STATE_HOME="" \
  LPSTAT_STUB_STATE="${PH_BI2_STATE}" LPSTAT_STUB_QUEUES="${PH_QUEUE_IDLE}" \
  LPINFO_STUB_MODE=usb LPOPTIONS_STUB_LOG="${TMPBASE}/ph-bi2-lpoptions.log" \
  LPOPTIONS_STUB_FAIL=1 \
  bash "${PH_MODULE}" run > "${PH_BI2_STDOUT}" 2> "${PH_BI2_STDERR}" || code_bi2="$?"
if [[ "${code_bi2}" -ne 0 ]]; then
  pass "printer-helper apply-failure exits non-zero (got ${code_bi2})"
else
  fail "printer-helper apply-failure exits non-zero"
fi
# The ask_yn prompt shares the first stderr line with the stub refusal;
# filter both to count the module's own lines.
bi2_module_lines="$(grep -v 'Point the default printer at' "${PH_BI2_STDERR}" | grep -v 'lpoptions-stub:' | grep -c . || true)"
if [[ "${bi2_module_lines}" -eq 1 ]]; then
  pass "printer-helper apply-failure prints one plain stderr line"
else
  fail "printer-helper apply-failure prints one plain stderr line (got ${bi2_module_lines}: $(cat "${PH_BI2_STDERR}"))"
fi
if [[ ! -e "${PH_BI2_HOME}/${PH_STATE_REL}" ]]; then
  pass "printer-helper apply-failure leaves no state file behind"
else
  fail "printer-helper apply-failure leaves no state file behind"
fi
if ! grep -q "Default printer is now" "${PH_BI2_STDOUT}"; then
  pass "printer-helper apply-failure claims no result on stdout"
else
  fail "printer-helper apply-failure claims no result on stdout"
fi
if grep -q "^default=none$" "${PH_BI2_STATE}"; then
  pass "printer-helper apply-failure leaves the stub default untouched"
else
  fail "printer-helper apply-failure leaves the stub default untouched"
fi


# ---------------------------------------------------------------------------
# Stages (bj)-(bl): system-report-pack (user-level, strictly read-only,
# never installs) — stub-only verification. Every stage runs the module
# with a controlled PATH (stub uname/uptime/free/df/lscpu plus symlinks to
# the coreutils the module needs) and a fake HOME under mktemp. No stage
# ever invokes a real report tool against the host in a way the harness
# depends on, and no stub ever writes anything but its own call log. The
# canned /etc/os-release is handled via the module's documented seam: the
# MINTBUTLER_OS_RELEASE_FILE environment override (default /etc/os-release)
# is pointed at a canned file; the real system file is never touched.
# ---------------------------------------------------------------------------

SR_MODULE="${REPO_ROOT}/modules/system-report-pack/module.sh"
SR_STUB_ROOT="${TMPBASE}/sr-stubs"
SR_OS_RELEASE="${TMPBASE}/sr-os-release"
mkdir -p "${SR_STUB_ROOT}"

# Canned os-release file for the module's MINTBUTLER_OS_RELEASE_FILE seam.
cat <<'SR_OS_RELEASE_EOF' > "${SR_OS_RELEASE}"
NAME="Linux Mint"
VERSION="22 (Wilma)"
ID=mint
ID_LIKE=ubuntu
PRETTY_NAME="Linux Mint 22"
VERSION_ID="22"
SR_OS_RELEASE_EOF

# Controlled-PATH builder: symlink the coreutils the module and its stub
# scripts need from the host; each stage's bin dir then gets only the
# stubs that stage wants present.
sr_make_bin() {
  local dir="${1:-}"
  mkdir -p "${dir}"
  local tool tool_path
  for tool in dirname sed mkdir rm rmdir mv bash; do
    tool_path="$(command -v "${tool}" || true)"
    if [[ -n "${tool_path}" ]]; then
      ln -sf "${tool_path}" "${dir}/${tool}"
    fi
  done
  printf '%s\n' "${dir}"
}

# Stub uname: canned -n / -r / -m replies; logs every invocation to
# SR_STUB_LOG (when set).
cat <<'SR_UNAME_STUB' > "${SR_STUB_ROOT}/uname"
#!/usr/bin/env bash
set -euo pipefail
LOG="${SR_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'uname%s\n' "${*:+ $*}" >> "${LOG}"
fi
case "${1:-}" in
  -n) printf 'mintbutler-lab\n' ;;
  -r) printf '6.8.0-48-generic\n' ;;
  -m) printf 'x86_64\n' ;;
  *)
    printf 'uname-stub: unsupported invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
SR_UNAME_STUB

# Stub uptime: canned -p reply and the plain load line;
# SR_UPTIME_STUB_FAIL=1 makes every invocation fail.
cat <<'SR_UPTIME_STUB' > "${SR_STUB_ROOT}/uptime"
#!/usr/bin/env bash
set -euo pipefail
LOG="${SR_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'uptime%s\n' "${*:+ $*}" >> "${LOG}"
fi
if [[ "${SR_UPTIME_STUB_FAIL:-0}" == "1" ]]; then
  printf 'uptime-stub: refused\n' >&2
  exit 1
fi
case "${1:-}" in
  -p) printf 'up 2 days, 3 hours, 41 minutes\n' ;;
  '') printf ' 14:32:01 up 2 days, 3:41, 2 users, load average: 0.52, 0.48, 0.45\n' ;;
  *)
    printf 'uptime-stub: unsupported invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
SR_UPTIME_STUB

# Stub free: canned `free -h` block; SR_FREE_STUB_FAIL=1 makes it fail.
cat <<'SR_FREE_STUB' > "${SR_STUB_ROOT}/free"
#!/usr/bin/env bash
set -euo pipefail
LOG="${SR_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'free%s\n' "${*:+ $*}" >> "${LOG}"
fi
if [[ "${1:-}" != "-h" ]]; then
  printf 'free-stub: unsupported invocation: %s\n' "$*" >&2
  exit 2
fi
if [[ "${SR_FREE_STUB_FAIL:-0}" == "1" ]]; then
  printf 'free-stub: refused\n' >&2
  exit 1
fi
printf '               total        used        free      shared  buff/cache   available\n'
printf 'Mem:           15Gi       6.2Gi       3.1Gi       120Mi       5.6Gi       9.4Gi\n'
printf 'Swap:         8.0Gi       1.2Gi       6.8Gi\n'
SR_FREE_STUB

# Stub df: canned `df -h /` block; SR_DF_STUB_FAIL=1 makes it fail.
cat <<'SR_DF_STUB' > "${SR_STUB_ROOT}/df"
#!/usr/bin/env bash
set -euo pipefail
LOG="${SR_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'df%s\n' "${*:+ $*}" >> "${LOG}"
fi
if [[ "${SR_DF_STUB_FAIL:-0}" == "1" ]]; then
  printf 'df-stub: refused\n' >&2
  exit 1
fi
if [[ "$#" -eq 2 && "${1:-}" == "-h" && "${2:-}" == "/" ]]; then
  printf 'Filesystem      Size  Used Avail Use%% Mounted on\n'
  printf '/dev/nvme0n1p2  916G  234G  633G  32%% /\n'
  exit 0
fi
printf 'df-stub: unsupported invocation: %s\n' "$*" >&2
exit 2
SR_DF_STUB

# Stub lscpu: canned output with a Model name line and a CPU(s) line.
cat <<'SR_LSCPU_STUB' > "${SR_STUB_ROOT}/lscpu"
#!/usr/bin/env bash
set -euo pipefail
LOG="${SR_STUB_LOG:-}"
if [[ -n "${LOG}" ]]; then
  printf 'lscpu%s\n' "${*:+ $*}" >> "${LOG}"
fi
printf 'Architecture:                    x86_64\n'
printf 'CPU(s):                          14\n'
printf 'Thread(s) per core:              2\n'
printf 'Core(s) per socket:              8\n'
printf 'Socket(s):                       1\n'
printf 'Model name:                      13th Gen Intel(R) Core(TM) i7-1360P\n'
SR_LSCPU_STUB

chmod +x "${SR_STUB_ROOT}/uname" "${SR_STUB_ROOT}/uptime" "${SR_STUB_ROOT}/free" \
  "${SR_STUB_ROOT}/df" "${SR_STUB_ROOT}/lscpu"

# Bin dir with only coreutils: no report tool at all — the preflight path
# every lint sandbox takes when the tools are absent.
SR_BIN_EMPTY="${SR_STUB_ROOT}/bin-empty"
sr_make_bin "${SR_BIN_EMPTY}" >/dev/null

# Bin dir with every report tool stubbed, including the optional lscpu.
SR_BIN_FULL="${SR_STUB_ROOT}/bin-full"
sr_make_bin "${SR_BIN_FULL}" >/dev/null
cp "${SR_STUB_ROOT}/uname" "${SR_STUB_ROOT}/uptime" "${SR_STUB_ROOT}/free" \
  "${SR_STUB_ROOT}/df" "${SR_STUB_ROOT}/lscpu" "${SR_BIN_FULL}/"

# Bin dir for the degradation stage: lscpu ABSENT; free is present but the
# stage exports SR_FREE_STUB_FAIL=1 so it fails.
SR_BIN_DEGRADED="${SR_STUB_ROOT}/bin-degraded"
sr_make_bin "${SR_BIN_DEGRADED}" >/dev/null
cp "${SR_STUB_ROOT}/uname" "${SR_STUB_ROOT}/uptime" "${SR_STUB_ROOT}/free" \
  "${SR_STUB_ROOT}/df" "${SR_BIN_DEGRADED}/"

# Stage (bj): gate + read-only smokes.
printf 'Stage bj: system-report-pack gate, scan, list, plan/dry-run, missing preflight\n'

output_bj_scan=""
code_bj_scan="0"
output_bj_scan="$(cd "${REPO_ROOT}" && ./butler --scan 2>&1)" || code_bj_scan="$?"
if [[ "${code_bj_scan}" -ne 0 ]]; then
  fail "butler --scan exits 0 with system-report-pack present (got ${code_bj_scan})"
else
  pass "butler --scan exits 0 with system-report-pack present"
fi
if printf '%s\n' "${output_bj_scan}" | grep -q "PASS system-report-pack"; then
  pass "butler --scan reports PASS system-report-pack"
else
  fail "butler --scan reports PASS system-report-pack"
fi

output_bj_lint1=""
code_bj_lint1="0"
output_bj_lint1="$(cd "${REPO_ROOT}" && bin/modulelint system-report-pack 2>&1)" || code_bj_lint1="$?"
if [[ "${code_bj_lint1}" -ne 0 ]]; then
  fail "bin/modulelint system-report-pack exits 0 (got ${code_bj_lint1})"
else
  pass "bin/modulelint system-report-pack exits 0"
fi
if printf '%s\n' "${output_bj_lint1}" | grep -q "PASS system-report-pack"; then
  pass "bin/modulelint system-report-pack contains PASS system-report-pack"
else
  fail "bin/modulelint system-report-pack contains PASS system-report-pack"
fi

code_bj_lint="0"
(cd "${REPO_ROOT}" && bin/modulelint >/dev/null 2>&1) || code_bj_lint="$?"
if [[ "${code_bj_lint}" -ne 0 ]]; then
  fail "bin/modulelint exits 0 over all modules with system-report-pack present (got ${code_bj_lint})"
else
  pass "bin/modulelint exits 0 over all modules with system-report-pack present"
fi

output_bj_list=""
code_bj_list="0"
output_bj_list="$(cd "${REPO_ROOT}" && ./butler --list 2>&1)" || code_bj_list="$?"
if [[ "${code_bj_list}" -ne 0 ]]; then
  fail "butler --list exits 0 (got ${code_bj_list})"
else
  pass "butler --list exits 0"
fi
sr_bj_list_line="$(printf '%s\n' "${output_bj_list}" | grep -- "system-report-pack: System report pack" || true)"
if [[ -n "${sr_bj_list_line}" ]]; then
  pass "butler --list shows system-report-pack: System report pack"
else
  fail "butler --list shows system-report-pack: System report pack"
fi
if [[ "${sr_bj_list_line}" == *"⚠ elevated"* ]]; then
  fail "butler --list shows NO elevated badge on system-report-pack"
else
  pass "butler --list shows NO elevated badge on system-report-pack"
fi
if printf '%s\n' "${output_bj_list}" | grep -q "printer-helper" \
  && printf '%s\n' "${output_bj_list}" | grep -q "timeshift-guardian" \
  && printf '%s\n' "${output_bj_list}" | grep -q "desktop-shortcut-creator"; then
  pass "butler --list still shows the earlier modules"
else
  fail "butler --list still shows the earlier modules"
fi

# Menu position smoke: with the current module set, order 70 renders as
# entry 7 on page 1 (positions are recomputed at scan time), and a
# user-level module carries no elevated badge.
output_bj_menu=""
code_bj_menu="0"
output_bj_menu="$(printf 'q\n' | (cd "${REPO_ROOT}" && ./butler) 2>&1)" || code_bj_menu="$?"
sr_bj_menu_line="$(printf '%s\n' "${output_bj_menu}" | grep -F "7) System report pack" || true)"
if [[ "${code_bj_menu}" -eq 0 && -n "${sr_bj_menu_line}" && "${sr_bj_menu_line}" != *"⚠ elevated"* ]]; then
  pass "menu renders System report pack at its order-70 position without an elevated badge"
else
  fail "menu renders System report pack at its order-70 position without an elevated badge (got ${code_bj_menu}: ${sr_bj_menu_line})"
fi

# Menu navigation, no undo affordance: the detail screen of an undo: false
# module offers [d]ry-run/[r]un/[b]ack and never [u]ndo. Scripted stdin:
# /system filters to the module, 1 opens its detail screen, b goes back,
# q quits.
output_bj_nav=""
code_bj_nav="0"
output_bj_nav="$(printf '/system\n1\nb\nq\n' | (cd "${REPO_ROOT}" && ./butler) 2>&1)" || code_bj_nav="$?"
if [[ "${code_bj_nav}" -ne 0 ]]; then
  fail "menu navigation through the system-report-pack detail screen exits 0 (got ${code_bj_nav})"
else
  pass "menu navigation through the system-report-pack detail screen exits 0"
fi
if printf '%s\n' "${output_bj_nav}" | grep -Fq "[d]ry-run  [r]un  [b]ack"; then
  pass "detail screen offers dry-run/run/back"
else
  fail "detail screen offers dry-run/run/back"
fi
if printf '%s\n' "${output_bj_nav}" | grep -Fq "[u]ndo"; then
  fail "detail screen shows NO [u]ndo affordance (undo: false)"
else
  pass "detail screen shows NO [u]ndo affordance (undo: false)"
fi
if printf '%s\n' "${output_bj_nav}" | grep -q "Undo: not available"; then
  pass "detail screen states undo is not available"
else
  fail "detail screen states undo is not available"
fi

SR_BJ_HOME="${TMPBASE}/sr-home-bj"
SR_BJ_HOME_BEFORE="${TMPBASE}/sr-home-bj-before"
mkdir -p "${SR_BJ_HOME}"
cp -a "${SR_BJ_HOME}" "${SR_BJ_HOME_BEFORE}"

output_bj_plan=""
code_bj_plan="0"
output_bj_plan="$(HOME="${SR_BJ_HOME}" bash "${SR_MODULE}" plan < /dev/null 2>&1)" || code_bj_plan="$?"
sr_bj_plan_lines="$(printf '%s\n' "${output_bj_plan}" | grep -c . || true)"
if [[ "${code_bj_plan}" -eq 0 && -n "${output_bj_plan}" ]]; then
  pass "system-report-pack plan exits 0 and non-empty"
else
  fail "system-report-pack plan exits 0 and non-empty (got ${code_bj_plan})"
fi
if [[ "${sr_bj_plan_lines}" -le 23 ]]; then
  pass "system-report-pack plan renders in <= 23 lines (got ${sr_bj_plan_lines})"
else
  fail "system-report-pack plan renders in <= 23 lines (got ${sr_bj_plan_lines})"
fi
if printf '%s\n' "${output_bj_plan}" | grep -qiF "never inxi" \
  && printf '%s\n' "${output_bj_plan}" | grep -qiF "writes nothing"; then
  pass "system-report-pack plan contains the never-inxi and writes-nothing statements"
else
  fail "system-report-pack plan contains the never-inxi and writes-nothing statements"
fi

output_bj_dry=""
code_bj_dry="0"
output_bj_dry="$(HOME="${SR_BJ_HOME}" bash "${SR_MODULE}" dry-run < /dev/null 2>&1)" || code_bj_dry="$?"
sr_bj_dry_lines="$(printf '%s\n' "${output_bj_dry}" | grep -c . || true)"
if [[ "${code_bj_dry}" -eq 0 && -n "${output_bj_dry}" ]]; then
  pass "system-report-pack dry-run exits 0 and non-empty"
else
  fail "system-report-pack dry-run exits 0 and non-empty (got ${code_bj_dry})"
fi
if [[ "${sr_bj_dry_lines}" -le 23 ]]; then
  pass "system-report-pack dry-run renders in <= 23 lines (got ${sr_bj_dry_lines})"
else
  fail "system-report-pack dry-run renders in <= 23 lines (got ${sr_bj_dry_lines})"
fi
if diff -r "${SR_BJ_HOME}" "${SR_BJ_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "system-report-pack plan and dry-run write nothing to the fake HOME"
else
  fail "system-report-pack plan and dry-run modified the fake HOME"
fi

# Menu-flag smoke (owner acceptance command): --run <slug> --dry-run is
# non-destructive.
code_bj_menudry="0"
HOME="${SR_BJ_HOME}" bash -c 'cd "'"${REPO_ROOT}"'" && ./butler --run system-report-pack --dry-run' >/dev/null 2>&1 || code_bj_menudry="$?"
if [[ "${code_bj_menudry}" -eq 0 ]]; then
  pass "butler --run system-report-pack --dry-run exits 0"
else
  fail "butler --run system-report-pack --dry-run exits 0 (got ${code_bj_menudry})"
fi
if diff -r "${SR_BJ_HOME}" "${SR_BJ_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "butler --run system-report-pack --dry-run leaves the fake HOME untouched"
else
  fail "butler --run system-report-pack --dry-run modified the fake HOME"
fi

# Missing-tools preflight (modulelint compatibility): stdin /dev/null and
# no report tool on PATH -> exit 1, one plain stderr line, empty stdout,
# fake HOME byte-identical.
SR_BJ2_HOME="${TMPBASE}/sr-home-bj2"
SR_BJ2_HOME_BEFORE="${TMPBASE}/sr-home-bj2-before"
SR_BJ2_STDOUT="${TMPBASE}/sr-bj2.stdout"
SR_BJ2_STDERR="${TMPBASE}/sr-bj2.stderr"
mkdir -p "${SR_BJ2_HOME}"
cp -a "${SR_BJ2_HOME}" "${SR_BJ2_HOME_BEFORE}"
code_bj_run="0"
PATH="${SR_BIN_EMPTY}" HOME="${SR_BJ2_HOME}" \
  bash "${SR_MODULE}" run < /dev/null >"${SR_BJ2_STDOUT}" 2>"${SR_BJ2_STDERR}" || code_bj_run="$?"
if [[ "${code_bj_run}" -eq 1 ]]; then
  pass "system-report-pack missing-tools preflight exits 1 (got ${code_bj_run})"
else
  fail "system-report-pack missing-tools preflight exits 1 (got ${code_bj_run})"
fi
bj2_stderr_lines="$(grep -c . "${SR_BJ2_STDERR}" || true)"
if [[ "${bj2_stderr_lines}" -eq 1 ]] && grep -q "Report tools missing" "${SR_BJ2_STDERR}"; then
  pass "system-report-pack missing-tools preflight prints one plain stderr line"
else
  fail "system-report-pack missing-tools preflight prints one plain stderr line (got ${bj2_stderr_lines}: $(cat "${SR_BJ2_STDERR}"))"
fi
if [[ ! -s "${SR_BJ2_STDOUT}" ]]; then
  pass "system-report-pack missing-tools preflight prints nothing to stdout"
else
  fail "system-report-pack missing-tools preflight printed to stdout: $(cat "${SR_BJ2_STDOUT}")"
fi
if diff -r "${SR_BJ2_HOME}" "${SR_BJ2_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "system-report-pack missing-tools preflight writes nothing to the fake HOME"
else
  fail "system-report-pack missing-tools preflight modified the fake HOME"
fi

# Zero-elevation, zero-install source assertions: no sudo/pkexec literal
# anywhere (display strings included), no shared-helper sourcing at all,
# and no package-manager invocation of any kind.
if grep -w -E -q 'sudo|pkexec' "${SR_MODULE}"; then
  fail "system-report-pack source contains no sudo/pkexec literal"
else
  pass "system-report-pack source contains no sudo/pkexec literal"
fi
if grep -F -q "lib/elevate.sh" "${SR_MODULE}" || grep -F -q "lib/ask.sh" "${SR_MODULE}"; then
  fail "system-report-pack sources no shared helper (no elevation, no question helper)"
else
  pass "system-report-pack sources no shared helper (no elevation, no question helper)"
fi
if grep -w -E -q 'apt|apt-get|aptitude|dnf|pacman|apk|zypper' "${SR_MODULE}"; then
  fail "system-report-pack source contains no package-manager invocation"
else
  pass "system-report-pack source contains no package-manager invocation"
fi
if grep -F -q 'dpkg -i' "${SR_MODULE}"; then
  fail "system-report-pack source contains no dpkg -i invocation"
else
  pass "system-report-pack source contains no dpkg -i invocation"
fi

# Stage (bk): full report — every stub present (incl. lscpu), canned
# os-release via the seam, session env set. Asserts the exact report:
# all five section headers, every canned value, the 23-line law, a
# byte-identical fake HOME, and a stub log holding EXACTLY the eight
# documented read-only invocations (no stub reports any write-like call).
printf 'Stage bk: system-report-pack full report\n'
SR_BK_HOME="${TMPBASE}/sr-home-bk"
SR_BK_HOME_BEFORE="${TMPBASE}/sr-home-bk-before"
SR_BK_LOG="${TMPBASE}/sr-bk.stublog"
SR_BK_STDOUT="${TMPBASE}/sr-bk.stdout"
SR_BK_STDERR="${TMPBASE}/sr-bk.stderr"
mkdir -p "${SR_BK_HOME}"
cp -a "${SR_BK_HOME}" "${SR_BK_HOME_BEFORE}"
rm -f "${SR_BK_LOG}"
code_bk="0"
PATH="${SR_BIN_FULL}" HOME="${SR_BK_HOME}" \
  SR_STUB_LOG="${SR_BK_LOG}" MINTBUTLER_OS_RELEASE_FILE="${SR_OS_RELEASE}" \
  XDG_SESSION_TYPE=x11 XDG_CURRENT_DESKTOP=X-Cinnamon \
  bash "${SR_MODULE}" run < /dev/null >"${SR_BK_STDOUT}" 2>"${SR_BK_STDERR}" || code_bk="$?"
if [[ "${code_bk}" -eq 0 ]]; then
  pass "system-report-pack full report exits 0"
else
  fail "system-report-pack full report exits 0 (got ${code_bk})"
fi
sr_bk_lines="$(wc -l < "${SR_BK_STDOUT}" || true)"
if [[ "${sr_bk_lines}" -le 23 ]]; then
  pass "system-report-pack full report fits the 23-line law (${sr_bk_lines} lines)"
else
  fail "system-report-pack full report fits the 23-line law (${sr_bk_lines} lines)"
fi
for sr_header in "System:" "CPU:" "Memory:" "Disk /:" "Session:"; do
  if grep -Fq "${sr_header}" "${SR_BK_STDOUT}"; then
    pass "system-report-pack full report carries the ${sr_header} section header"
  else
    fail "system-report-pack full report carries the ${sr_header} section header"
  fi
done
if grep -Fxq "System:  mintbutler-lab | Linux Mint 22 | 6.8.0-48-generic | x86_64 | up 2 days, 3 hours, 41 minutes" "${SR_BK_STDOUT}"; then
  pass "system-report-pack System line carries hostname, PRETTY_NAME, kernel, architecture, uptime"
else
  fail "system-report-pack System line carries hostname, PRETTY_NAME, kernel, architecture, uptime"
fi
if grep -Fxq "CPU:     13th Gen Intel(R) Core(TM) i7-1360P (14 CPU(s)) | load 0.52, 0.48, 0.45" "${SR_BK_STDOUT}"; then
  pass "system-report-pack CPU line carries the CPU model, core count, and load"
else
  fail "system-report-pack CPU line carries the CPU model, core count, and load"
fi
if grep -Fxq "Memory:  total 15Gi | used 6.2Gi | available 9.4Gi" "${SR_BK_STDOUT}"; then
  pass "system-report-pack Memory line carries the canned free -h Mem values"
else
  fail "system-report-pack Memory line carries the canned free -h Mem values"
fi
if grep -Fxq "Disk /:  size 916G | used 234G | avail 633G | use 32%" "${SR_BK_STDOUT}"; then
  pass "system-report-pack Disk / line carries the canned df -h / values"
else
  fail "system-report-pack Disk / line carries the canned df -h / values"
fi
if grep -Fxq "Session: type x11 | desktop X-Cinnamon" "${SR_BK_STDOUT}"; then
  pass "system-report-pack Session line carries the canned session values"
else
  fail "system-report-pack Session line carries the canned session values"
fi
if diff -r "${SR_BK_HOME}" "${SR_BK_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "system-report-pack full report writes nothing to the fake HOME (byte-identical)"
else
  fail "system-report-pack full report modified the fake HOME"
fi
# The stub log must hold EXACTLY the eight documented read-only
# invocations — nothing more (no write-like invocation, nothing extra).
printf '%s\n' "uname -n" "uname -m" "uname -r" "uptime" "uptime -p" "df -h /" "free -h" "lscpu" | sort > "${SR_BK_LOG}.expected"
if [[ -f "${SR_BK_LOG}" ]] && sort "${SR_BK_LOG}" | cmp -s - "${SR_BK_LOG}.expected"; then
  pass "system-report-pack stub log holds exactly the eight documented read-only invocations"
else
  fail "system-report-pack stub log holds exactly the eight documented read-only invocations (got: $(cat "${SR_BK_LOG}" 2>/dev/null))"
fi

# Stage (bl): honest degradation — same stubs but lscpu ABSENT and free
# FAILING. Exit 0; the CPU section carries the unavailable marker (load
# still renders from uptime), the Memory section is unavailable, and all
# other sections still render with their canned values.
printf 'Stage bl: system-report-pack honest degradation\n'
SR_BL_HOME="${TMPBASE}/sr-home-bl"
SR_BL_HOME_BEFORE="${TMPBASE}/sr-home-bl-before"
SR_BL_LOG="${TMPBASE}/sr-bl.stublog"
SR_BL_STDOUT="${TMPBASE}/sr-bl.stdout"
SR_BL_STDERR="${TMPBASE}/sr-bl.stderr"
mkdir -p "${SR_BL_HOME}"
cp -a "${SR_BL_HOME}" "${SR_BL_HOME_BEFORE}"
rm -f "${SR_BL_LOG}"
code_bl="0"
PATH="${SR_BIN_DEGRADED}" HOME="${SR_BL_HOME}" \
  SR_STUB_LOG="${SR_BL_LOG}" SR_FREE_STUB_FAIL=1 \
  MINTBUTLER_OS_RELEASE_FILE="${SR_OS_RELEASE}" \
  XDG_SESSION_TYPE=x11 XDG_CURRENT_DESKTOP=X-Cinnamon \
  bash "${SR_MODULE}" run < /dev/null >"${SR_BL_STDOUT}" 2>"${SR_BL_STDERR}" || code_bl="$?"
if [[ "${code_bl}" -eq 0 ]]; then
  pass "system-report-pack degraded run exits 0"
else
  fail "system-report-pack degraded run exits 0 (got ${code_bl})"
fi
sr_bl_cpu_line="$(grep -F 'CPU:' "${SR_BL_STDOUT}" | head -n 1 || true)"
if [[ "${sr_bl_cpu_line}" == *" (unavailable)"* && "${sr_bl_cpu_line}" == *"load 0.52, 0.48, 0.45"* ]]; then
  pass "system-report-pack degraded CPU section shows (unavailable) and still renders the load"
else
  fail "system-report-pack degraded CPU section shows (unavailable) and still renders the load (got: ${sr_bl_cpu_line})"
fi
if grep -Fxq "Memory:  (unavailable)" "${SR_BL_STDOUT}"; then
  pass "system-report-pack degraded Memory section shows (unavailable)"
else
  fail "system-report-pack degraded Memory section shows (unavailable)"
fi
if grep -Fxq "System:  mintbutler-lab | Linux Mint 22 | 6.8.0-48-generic | x86_64 | up 2 days, 3 hours, 41 minutes" "${SR_BL_STDOUT}"; then
  pass "system-report-pack degraded System section still renders its canned values"
else
  fail "system-report-pack degraded System section still renders its canned values"
fi
if grep -Fxq "Disk /:  size 916G | used 234G | avail 633G | use 32%" "${SR_BL_STDOUT}"; then
  pass "system-report-pack degraded Disk / section still renders its canned values"
else
  fail "system-report-pack degraded Disk / section still renders its canned values"
fi
if grep -Fxq "Session: type x11 | desktop X-Cinnamon" "${SR_BL_STDOUT}"; then
  pass "system-report-pack degraded Session section still renders its canned values"
else
  fail "system-report-pack degraded Session section still renders its canned values"
fi
sr_bl_lines="$(wc -l < "${SR_BL_STDOUT}" || true)"
if [[ "${sr_bl_lines}" -le 23 ]]; then
  pass "system-report-pack degraded report fits the 23-line law (${sr_bl_lines} lines)"
else
  fail "system-report-pack degraded report fits the 23-line law (${sr_bl_lines} lines)"
fi
if diff -r "${SR_BL_HOME}" "${SR_BL_HOME_BEFORE}" >/dev/null 2>&1; then
  pass "system-report-pack degraded run writes nothing to the fake HOME (byte-identical)"
else
  fail "system-report-pack degraded run modified the fake HOME"
fi
# The stub log must hold exactly the seven documented calls the degraded
# set can make — and no lscpu call at all (the tool is absent).
printf '%s\n' "uname -n" "uname -m" "uname -r" "uptime" "uptime -p" "df -h /" "free -h" | sort > "${SR_BL_LOG}.expected"
if [[ -f "${SR_BL_LOG}" ]] && sort "${SR_BL_LOG}" | cmp -s - "${SR_BL_LOG}.expected"; then
  pass "system-report-pack degraded stub log holds exactly the seven invocations with no lscpu"
else
  fail "system-report-pack degraded stub log holds exactly the seven invocations with no lscpu (got: $(cat "${SR_BL_LOG}" 2>/dev/null))"
fi


printf 'Passed: %s, Failed: %s\n' "${PASS_COUNT}" "${FAIL_COUNT}"
if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi
printf 'All tests passed.\n'
exit 0
