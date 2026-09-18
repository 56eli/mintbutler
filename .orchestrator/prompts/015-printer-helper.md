# 015 — module: printer-helper

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/015-printer-helper.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "015 — module: printer-helper".

## 1. TASK TITLE AND SCOPE

Ship batch-#1 module `printer-helper` (feature kind, `risk: user` — NO
elevation anywhere in this module, `undo: true`, `needs: [lpstat, lpinfo,
lpoptions]`, `order: 60`, `asks: 1`): a diagnose-first CUPS doctor for Linux
Mint 22 — reads scheduler state, configured queues, and detected devices,
then guides setup in plain words using Mint's own tools and driverless IPP
Everywhere (NEVER vendor drivers or blobs). Its one real change is pointing
the default printer at a healthy queue when no default or a stale one is
set — recorded and restorable on undo. Complete this in ONE pull request.

## 2. REQUIRED READING ORDER

1. `docs/PROJECT_STATE.md` — §3 conventions and order table (your module is
   `order: 60`, features range), and the batch rulings.
2. `README.md` — safety contract.
3. `docs/MODULE_SPEC.md` — §2 manifest fields, §3 (user-risk modules run
   without elevation), §5 gate. Confirm the repo's risk vocabulary for
   non-elevated modules with
   `grep -n "^risk:" modules/*/module.yml` — use EXACTLY that token.
4. `modules/audio-repair/module.sh` — newest diagnose-first sibling: ladder
   structure, honest verdicts, record-before-apply + undo-from-record
   semantics (your default-printer repair mirrors them, minus elevation).
5. `modules/default-apps-editor/module.sh` — user-risk sibling: confirm its
   manifest `risk:` token and state-file conventions; mirror them.
6. `lib/ask.sh` — the question helper (`ask_yn`: Enter = NO, EOF = NO).
   This module does NOT source `lib/elevate.sh` at all.
7. `bin/modulelint` — the gate your module must pass (its sandbox runs
   `run` with stdin `/dev/null`; with the lp* tools absent from the
   sandbox, your preflight exits 1 before anything else — that is the
   passing lint path).
8. `tests/run-tests.sh` — harness pattern; the stage letter sequence ends at
   `(bc)` — your new stages continue `(bd)` onward (confirm with
   `grep -n "Stage bc" tests/run-tests.sh`; confirm, do not copy).
9. `git log --oneline -5` — Conventional Commits convention (confirm, do
   not copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22. Ten
modules are on `main` (latest: multimedia-codecs via PR #12). The
owner-approved batch names this module "printer-helper (guided printer
setup, never vendor blobs)". Owner rulings that shape it: diagnose first;
guide with Mint's OWN tools (the Printers settings app, the CUPS web
interface at localhost:631) and driverless IPP Everywhere; the module NEVER
downloads, recommends, or installs vendor drivers or blobs; the one change
it makes is recorded and restorable. Owner vision: when printing breaks or
no printer is set up, one menu entry says WHAT is actually the state of the
printing stack and what to do next, in plain words.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

1. **Manifest (exact values):** `title: Printer helper`;
   `description: >-` folding EXACTLY: "Reads the printing stack first —
   CUPS scheduler state, configured queues, and detected devices — then
   guides setup in plain words using Mint's own tools and driverless IPP
   Everywhere, never vendor drivers or blobs. The one change it makes,
   pointing the default at a healthy queue when no default or a stale one
   is set, is recorded and restorable on undo.";
   `risk:` the confirmed user-level token from §2.3 (expected `user`);
   `undo: true`; `needs: [lpstat, lpinfo, lpoptions]`; `asks: 1`;
   `order: 60`.
2. **`asks: 1` budget:** the single question is the confirmation of the
   default-printer repair (`ask_yn`, Enter defaults to NO). Every other
   step is read-only diagnosis or honest guidance.
3. **No elevation invariant:** the module does not source `lib/elevate.sh`,
   never runs anything privileged, and contains no `sudo`/`pkexec` literal
   — not even in display strings. Guidance that would need root points the
   user to Mint's own tools instead of printing privileged commands.
4. **Diagnosis ladder (read-only steps first, in this order):**
   (i) preflight: `lpstat`, `lpinfo`, `lpoptions` present (cups-client
   ships on Mint), else one plain honest stderr line naming what is missing
   and that the CUPS client tools are expected on Mint, exit 1, nothing
   else;
   (ii) scheduler state: `lpstat -r` — not running → honest verdict "the
   CUPS printing service is not running" with plain guidance (start it from
   Mint's Printers settings or reboot, then re-run), exit 0, nothing
   written, no question;
   (iii) configured queues: `lpstat -p -d` — parse queue names + states and
   the current default;
   (iv) no queues at all → guided-setup verdict: add a printer with Mint's
   Printers settings app or the CUPS web interface at
   `http://localhost:631`; most modern printers work driverless via IPP
   Everywhere; EXPLICIT statement that mintbutler never downloads or
   installs vendor drivers or blobs; exit 0, nothing written;
   (v) device scan (best-effort, failure tolerated): `lpinfo -v` — include
   a short device summary in the report when it works; on failure/timeout
   say plainly that the device scan was unavailable and continue;
   (vi) default repair offer — ONLY when (a) no default is set and at least
   one queue is idle/enabled, or (b) the current default names a queue that
   no longer exists AND a healthy alternative exists: show current state vs
   proposed default, ask the ONE confirmation; NO/EOF → "Nothing changed."
   exit 0; YES → record the prior default (`prev_default=<queue>` or
   `prev_default=none`) to
   `$XDG_STATE_HOME-or-~/.local/state/mintbutler/printer-helper/default.record`
   BEFORE applying; apply with `lpoptions -d <queue>`; verify with
   `lpstat -d`; mismatch/apply-failure → DELETE the record, plain stderr
   error, exit 1 (nothing changed, nothing to undo); success → report and
   mention undo restores the previous default;
   (vii) otherwise (queues present, default sane — including a default
   whose queue is disabled/paused): honest status verdict naming each
   queue's state; for a disabled/paused queue say plainly that it can be
   re-enabled in Mint's Printers settings (NO privileged command is
   printed), exit 0, nothing written.
5. **Undo:** state file present → restore the recorded default exactly
   (`lpoptions -d <prev>` or `lpoptions -x` when the record says `none`),
   verify with `lpstat -d`, delete the record, report; the report states
   that the diagnosis steps are read-only and never needed undoing; state
   file absent → "Nothing to undo." exit 0. Undo of a missing `lpoptions`
   is an honest refusal (one plain stderr line, record kept, exit 1).
6. **Actions:** `describe` one line; `plan` the ladder in plain numbered
   steps; `dry-run` = plan + the exact commands it would run with zero
   execution. `plan` and `dry-run` render in ≤ 23 lines.
7. **Non-interactive behavior (modulelint compatibility):** modulelint runs
   `run` with stdin `/dev/null`. In sandboxes without the lp* tools the
   preflight exits 1 before anything else — the passing lint outcome.
   Where the tools exist, every path either exits before the confirmation
   or stops at `ask_yn` EOF (= NO) → "Nothing changed." with zero writes.
8. **Forbidden-pattern compliance:** `module.sh` contains no
   `sudo`/`pkexec`/`eval`/`curl|bash` literal anywhere, display strings
   included; quote every expansion.
9. **Owner acceptance ruling (2026-09-16, binding):** acceptance commands
   are non-destructive: `./butler --list`, `./butler --scan`,
   `./butler --run printer-helper --dry-run`, menu navigation. Tests never
   touch the real printing stack — PATH stubs with canned outputs only; a
   stub `lpoptions` NEVER changes real CUPS state.
10. **Branch-pinning rule:** if your runner pins your session to a branch
    and forbids creating another, use the pinned branch as the target (base
    stays `main`), substitute its name in §8/§9, and record it under
    `#### Session Irregularities`. Never push to
    `arena/01a0abf2-mintbutler`.

**Scope boundaries:** NO printer/queue creation or deletion; NO driver or
PPD download/install (zero network activity); NO service management
(`systemctl`/`service` of any kind); NO `cupsenable`/`cupsaccept`/
`lpadmin` execution; NO config-file edits outside the one user-level state
record; NO changes to `butler`, `bin/*`, `lib/*`, other modules, or docs
other than the tracker edit in §6.

**Expected-absent at delivery:** no new module folder other than
`printer-helper`; no new or modified files under `lib/`; no
`lib/elevate.sh` sourcing in the module. If any appears, HALT and report.

## 5. CORE OBJECTIVE

`printer-helper` passes `bin/modulelint`; the menu shows it WITHOUT an
elevated badge at its order-60 position; the ladder covers all outcomes
(missing tools, scheduler down, no queues + guided setup, repair offer with
confirm-yes/confirm-no, healthy/sane-default status); the only write
anywhere is the recorded, undoable default-printer change; vendor blobs are
never downloaded, recommended, or installed.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exit 0 including new stages; `bin/modulelint` exit 0; `./butler --scan`
exit 0; `bash -n` clean; shellcheck clean if installed; worktree clean;
everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `modules/printer-helper/module.yml` — per §4 fact 1.
2. `modules/printer-helper/module.sh` — executable (git mode 755), per §4
   facts 2–8.

Modify:

3. `tests/run-tests.sh` — keep all existing stages passing; add stages
   `(bd)`–`(bi)` (letters confirmed from the harness per §2.8) using
   PATH-prefix stubs (`lpstat`, `lpinfo`, `lpoptions` with env-controlled
   canned modes and call logs) ; NEVER real printing-stack tools. Where the
   module's interactive confirmation matters, drive the module binary
   directly with piped stdin (document in stage comments):
   - (bd) gate + read-only smokes: `./butler --scan` exit 0;
     `bin/modulelint` exit 0 with `PASS printer-helper`; `./butler --list`
     shows the module WITHOUT an elevated badge; `plan`/`dry-run` exit 0,
     non-empty, ≤ 23 lines, dry-run contains the exact strings `lpstat -r`
     and `lpoptions -d`; `run` with stdin `/dev/null` and no lp* stubs →
     exit 1, one plain stderr line, fake HOME byte-identical; module source
     grep asserts zero `sudo`/`pkexec` literals and no `lib/elevate.sh`
     sourcing;
   - (be) healthy chain: stubs report scheduler running, one idle queue,
     default set to it, device scan returns one USB device → exit 0,
     verdict says the printing stack looks healthy, device summary shown,
     no state file, no question asked, no `lpoptions` write in the stub
     log;
   - (bf) scheduler down: stub `lpstat -r` failing → exit 0, honest
     verdict naming the CUPS service with the Printers-settings/reboot
     guidance, nothing written;
   - (bg) no queues: stubs report scheduler running, zero queues → exit 0,
     guided-setup verdict names the Printers settings app, `localhost:631`,
     and driverless IPP Everywhere, AND contains the explicit
     never-vendor-blobs statement; nothing written;
   - (bh) default repair + undo: stubs report scheduler running, one idle
     queue, NO default; scripted stdin `y` → exit 0; state file records
     `prev_default=none`; stub log shows exactly one `lpoptions -d <queue>`
     call; output shows current-vs-proposed before confirming; then `undo`
     → stub log shows `lpoptions -x`, state deleted, exit 0; second undo →
     "Nothing to undo." exit 0;
   - (bi) confirm-no + apply-failure: same fixture, stdin `n` → exit 0,
     "Nothing changed.", no `lpoptions` write, no state; separately, stdin
     `y` with a stub `lpoptions` that fails on `-d` → exit 1, one plain
     stderr line, NO leftover state file.
4. `docs/PROJECT_STATE.md` — replace the `## 4. Active Milestone & Current
   State` section with EXACTLY (verify the old text first with
   `grep -n "Immediate Next Task" docs/PROJECT_STATE.md`; confirm, do not
   copy):

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** Module batch #1 (owner-approved 2026-09-16): nine modules — seven features, two fixes — one reviewed PR at a time on the v0.1 core.
- **Current State:** v0.1 core complete; batch #1 in progress — screenshot-studio (PR #5), orchestrator spec + `bin/orchestrator-check` gate (PR #6), default-apps-editor (PR #7), appimage-installer (PRs #8/#9), timeshift-guardian (PR #10), audio-repair (PR #11), multimedia-codecs (PR #12) landed.
- **Immediate Next Task:** task 016 — module `system-report-pack` (honest system report, never installs inxi), eighth in the owner's revised build order.
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

1. `modules/printer-helper/module.yml` + read-only actions
   (describe/plan/dry-run, ≤23-line screens) → commit + push
2. `module.sh` diagnosis ladder (preflight → scheduler → queues → no-queue
   guided verdict → device scan → sane-default status) → commit + push
3. `module.sh` the one recorded default-printer repair + undo → commit +
   push
4. Harness stages (bd)–(bi), full suite green → commit + push
5. Tracker edit → commit + push
6. Final pass: `bash -n` touched scripts, shellcheck if installed,
   `bin/modulelint` green, `./butler --scan` exit 0, `--list` check (no
   elevated badge), full harness, §14 smokes, clean tree → commit + push,
   then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/printer-helper` — EXCEPT the §4 fact 10
  substitution if your runner pins you.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/printer-helper:refs/remotes/origin/_resume
git checkout -B feature/printer-helper refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/printer-helper origin/main
```

Do not commit on `main`. "couldn't find remote ref" here is not an
environment failure.

## 9. WORK PERSISTENCE AND PUSH CADENCE

Checkpoint after each sub-task in §7, before any long or risky operation,
and at the end. Your session can expire without warning; unpushed work is
lost. There is no time-based rule — §7 is your push schedule.

A checkpoint is ONE command:

```bash
git add -A && (git diff --cached --quiet || git commit -qm "chore: wip <sub-task>") && git push -qu origin <target-branch>
```

Open ONE pull request at the end, when quality checks pass. Do not open a
draft PR first. Checkpoint commits may be broken — that is expected. Never
commit secrets. Never push to the orchestrator branch.

Sync rule: rebase onto origin/main ONLY before your first push. After the
first push, use:

```bash
git fetch --depth 50 origin +main:refs/remotes/origin/main && git merge --no-edit origin/main
git push origin HEAD
```

Never force-push unless explicitly instructed, and then only with
`--force-with-lease`. On merge conflict: halt and report. Same for a sync
that refuses with "refusing to merge unrelated histories" — never pass
`--allow-unrelated-histories`.

If a push or fetch fails with an authentication or network error, report it
plainly and keep working locally; retry at the next checkpoint. If GitHub
auth fails with HTTP 401/403 "Bad credentials", ask the operator via
`ask_user` with an option reading exactly `I reconnected GitHub — retry
now`; do not improvise credentials.

If the push is rejected non-fast-forward, halt and report the raw rejection.
Do not `git pull`. Do not force-push.

## 10. TECHNICAL REQUIREMENTS

- Language: bash 5.x, `#!/usr/bin/env bash`, `set -euo pipefail`, quote
  EVERY expansion. Reference style: `modules/audio-repair/module.sh`.
- Module I/O contract: stdout for humans, stderr for errors; exit 0
  success (verdict delivered counts as success); non-zero failure with one
  plain-language stderr line.
- TEST_COMMAND: `bash tests/run-tests.sh` (stages bd–bi: gate/smokes,
  healthy chain, scheduler down, no-queue guided setup, default repair +
  undo, confirm-no + apply-failure)
- INTEGRATION_TEST_COMMAND: stage (bd) — real `./butler --scan` and
  `--list` exercising the real menu/gate with the new module present
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — every verdict branch and the
  repair/undo path have direct harness assertions; no bash mutation tooling
  exists under the zero-dependency constraint
- LINT_COMMAND: `bash -n modules/printer-helper/module.sh butler lib/*.sh
  bin/modulelint tests/run-tests.sh` (always) plus `shellcheck` on the same
  set when installed; additionally `bin/modulelint printer-helper` must
  exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages; existing modules; menu behavior;
  `lib/manifest.sh` parsing of `needs: [lpstat, lpinfo, lpoptions]`,
  `asks: 1`, the confirmed risk token.
- The module performs ZERO privileged operations and ZERO network activity.
  The ONLY write anywhere is the user-level recorded default-printer
  change. No queue creation/deletion, no drivers, no services.
- Owner-acceptance safety (fact 9): the non-destructive set stays
  non-destructive; tests use stubs only.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- NO queue management, NO driver/PPD handling, NO service management, NO
  network activity, NO config edits beyond the one state record, NO other
  modules, NO lib changes.
- Do NOT modify `butler`, `bin/modulelint`, `bin/orchestrator-check`,
  `lib/*.sh`, other modules, README.md, docs/VISION.md, or
  docs/MODULE_SPEC.md.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

1. `bash tests/run-tests.sh` — exit 0, every stage asserts successfully.
2. `bin/modulelint printer-helper` — exit 0 with PASS.
3. `bin/modulelint` — exit 0 (8 modules).
4. `./butler --scan` — exit 0.
5. `./butler --list` — shows `printer-helper: Printer helper` WITHOUT an
   elevated badge; all existing modules still listed.
6. `./butler --run printer-helper --dry-run` — exit 0, side-effect-free.
7. `bash -n` clean over all changed/new scripts; shellcheck clean if
   installed (record absence otherwise).
8. Worktree clean, all work pushed, no extra module folders, no lib changes.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: printer-helper — diagnose-first CUPS doctor with one recorded
default-printer repair`. Description: summary; design rationale (the ladder
and why each exit path is honest; why the default-printer repair is the one
write shipped in v1; why disabled/paused queues get guidance instead of an
action — re-enabling needs privileges this module refuses to touch; the
never-vendor-blobs ruling and how guidance stays with Mint's own tools and
IPP Everywhere; the zero-elevation design; the stub test strategy and its
honest limit — real CUPS/printer behavior on Mint is owner acceptance);
test results per §10 layer with exact commands and outcomes; safety
statement "the module performs zero privileged operations and zero network
activity; the only write is the recorded user-level default-printer change;
all tests run against stub binaries that never touch the real printing
stack"; what the owner should try on Mint (`./butler` → Printer helper →
read the verdict; on a machine with several printers and no/stale default,
accept the default repair, print something, then `[u]ndo`); breaking
changes (none); migration notes (none). Describe only this PR's own
changes. Include `#### Session Irregularities` per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only (interfered with following this prompt AND
cost >~10 min / blocked progress / required a workaround / reveals a
recurring blind spot). If none significant, write exactly
`None significant`. If significant: Category | Symptom | Impact | Workaround
| Hardening candidate, 3–6 lines total. If you used the branch-substitution
rule (§4 fact 10), one line noting it belongs here. This report does not
affect the MERGE/REVISE verdict unless it reveals a missing deliverable.
