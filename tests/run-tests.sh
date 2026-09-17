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
output_w1=""
code_w1="0"
output_w1="$(PATH="${SS_BIN_REBIND}" HOME="${SS_W_HOME}" DCONF_STUB_STORE="${SS_W_STORE}" \
  "${SS_BASH_BIN}" "${SS_MODULE}" run < /dev/null 2>&1)" || code_w1="$?"
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

printf 'Passed: %s, Failed: %s\n' "${PASS_COUNT}" "${FAIL_COUNT}"
if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi
printf 'All tests passed.\n'
exit 0
