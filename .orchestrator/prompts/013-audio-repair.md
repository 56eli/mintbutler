# 013 — module: audio-repair

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/013-audio-repair.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "013 — module: audio-repair".

## 1. TASK TITLE AND SCOPE

Ship batch-#1 module `audio-repair` (risk: elevated, undo: true with an
honest scope, `needs: [pactl, amixer]`, `order: 910`, `asks: 1`): a
DIAGNOSE-FIRST audio doctor for Linux Mint 22 — reads the sound stack
(PipeWire/Pulse status, sinks, mixer state, kernel log for firmware/driver
errors), prints an HONEST verdict, applies exactly one kind of repair
(unmuting/restoring the Master mixer control, recorded and undoable), and
never fakes a fix: when the evidence points at drivers/firmware that need a
newer kernel than this system ships, it says exactly that. Complete this in
ONE pull request.

## 2. REQUIRED READING ORDER

1. `docs/PROJECT_STATE.md` — §3 conventions and order table (your module is
   `order: 910`, FIXES range), and the batch rulings.
2. `README.md` — safety contract.
3. `docs/MODULE_SPEC.md` — §2 manifest fields, §3 (elevated modules use the
   shared `elevate` helper ONLY), §5 gate.
4. `modules/timeshift-guardian/module.sh` — newest elevated sibling:
   diagnose-first flow, `lib/elevate.sh` usage with helper-driven display
   (`elevate_command_line`), honest verdicts, no `sudo` literals in the
   module.
5. `modules/screenshot-studio/module.sh` — state-record/undo pattern.
6. `lib/elevate.sh`, `lib/ask.sh` — the elevated helper and the question
   helper.
7. `bin/modulelint` — the gate your module must pass (its sandbox runs
   `run` with stdin `/dev/null`).
8. `tests/run-tests.sh` — harness pattern; the stage letter sequence ends at
   `(aq)` — your new stages continue `(ar)` onward (confirm with
   `grep -n "Stage aq" tests/run-tests.sh`; confirm, do not copy).
9. `git log --oneline -5` — Conventional Commits convention (confirm, do
   not copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22. Eight
modules are on `main` (latest: timeshift-guardian via PR #10). The
owner-approved batch names this module "audio-repair (elevated, config-backup
undo, diagnose-first)". Owner rulings that shape it: diagnose FIRST; an
honest "this needs a newer kernel" verdict beats a fake config fix; the one
real repair it performs is recorded and restorable. Owner vision: when sound
breaks, one menu entry tells you WHAT is actually wrong in plain words — and
only touches anything when there is something true to fix.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

1. **Manifest (exact values):** `title: Audio repair`;
   `description: >-` folding EXACTLY: "Diagnoses the sound stack first —
   PipeWire/Pulse status, sinks, mixer state, and the kernel log for
   firmware or driver errors — then prints an honest verdict. The one repair
   it applies, restoring a muted Master control, is recorded and restorable
   on undo; driver-level problems get a plain newer-kernel verdict instead
   of a fake fix.";
   `risk: elevated`; `undo: true`; `needs: [pactl, amixer]`; `asks: 1`;
   `order: 910`.
2. **`asks: 1` budget:** the single question is the confirmation of the
   mixer repair (`ask_yn`, Enter defaults to NO). Every other step is
   read-only diagnosis or honest reporting.
3. **Diagnosis ladder (read-only steps first, in this order):**
   (i) preflight: `pactl` and `amixer` present, else one plain honest line
   (name what is missing and that the pulseaudio/alsa user tools are
   expected on Mint), exit 1, nothing else;
   (ii) `pactl info` — capture the server name (PipeWire or PulseAudio) for
   the report; failure → verdict "the sound server is not responding" plus
   the plain suggestion to reboot or check the session, exit 0 (verdict
   delivered, nothing written);
   (iii) `pactl list short sinks` — no sinks, or only a dummy sink (name
   contains `dummy`, case-insensitive) → go to step (v) driver check;
   (iv) sinks exist → `amixer` Master check (parse the first `Master`
   control: muted? volume 0?) → NOT muted and volume > 0 → verdict "the
   output chain looks healthy" with plain next steps (per-app volume in the
   sound settings, cables, the test-sound button; suggest rebooting the
   session manually), exit 0, nothing written; muted or 0% → go to step
   (vi) repair offer;
   (v) driver/firmware check — the ONLY elevated step: display and run
   `dmesg` through `elevate_run "dmesg"` and scan its output for audio
   firmware/driver signatures (e.g. `sof`, `snd_`, `firmware` lines
   mentioning fail/timeout/missing — keep the pattern list simple and
   documented in code). Evidence found → verdict: "This looks like a
   driver/firmware problem (evidence lines shown). Config changes will not
   fix it — this hardware may need a newer kernel or firmware than this
   system ships. No changes were made." exit 0. No evidence → verdict
   "No output device was found and the kernel log shows no clear driver
   error" with the honest suggestion to check BIOS/external devices, exit 0;
   (vi) repair offer: show current Master state vs proposed state
   (`unmute`, volume restored to 100% only when it is 0% — a non-zero
   volume is preserved), ask the one confirmation; NO → "Nothing changed."
   exit 0; YES → record the exact prior state (muted flag + numeric volume)
   to `$HOME/.local/state/mintbutler/audio-repair/mixer.record` BEFORE
   applying; apply with `amixer -q sset Master <volume>% unmute`; verify by
   re-reading `amixer`; mismatch → restore the recorded state, plain error,
   exit 1; success → report what changed and that undo restores it.
4. **Undo:** state file present → restore the recorded muted flag and
   volume exactly (re-record-then-apply semantics NOT allowed — apply from
   the recorded values directly, then delete the state), report; absent →
   "Nothing to undo." exit 0. Undo states plainly that verdicts and
   read-only steps never needed undoing.
5. **Actions:** `describe` one line; `plan` the diagnosis ladder in plain
   numbered steps; `dry-run` = plan + the exact commands it would run
   (every elevated one displayed via the elevate helper) with zero
   execution. `plan` and `dry-run` render in ≤ 23 lines.
6. **Non-interactive behavior (modulelint compatibility):** modulelint runs
   `run` with stdin `/dev/null`. In sandboxes without pactl the preflight
   exits 1 before any elevated call — the passing lint outcome. Where the
   tools exist but sudo fails non-interactively, the elevated `dmesg` step
   fails and the module exits non-zero with one plain stderr line, having
   written nothing. All writes are user-level and happen only after the
   confirmed repair decision.
7. **Forbidden-pattern compliance:** `sudo` appears ONLY via
   `lib/elevate.sh`; `module.sh` contains no `sudo`/`pkexec`/`eval`/
   `curl|bash` literal; EVERY elevated command display uses
   `elevate_command_line` (the revision of PR #10 exists because a previous
   module hardcoded a display string — do not repeat that); quote every
   expansion.
8. **Owner acceptance ruling (2026-09-16, binding):** acceptance commands
   are non-destructive: `./butler --list`, `./butler --scan`,
   `./butler --run audio-repair --dry-run`, menu navigation. Tests never
   invoke real `sudo`, `pactl`, `amixer`, or `dmesg` — PATH stubs with
   canned outputs only.
9. **Branch-pinning rule:** if your runner pins your session to a branch
   and forbids creating another, use the pinned branch as the target (base
   stays `main`), substitute its name in §8/§9, and record it under
   `#### Session Irregularities`. Never push to
   `arena/01a0abf2-mintbutler`.

**Scope boundaries:** NO package installation (no pipewire/alsa installs);
NO service restarts (`systemctl` of any kind); NO config-file edits
(`/etc/`, `~/.config/pipewire`, pulse configs); NO volume changes other than
the single recorded Master repair; NO per-application mixer handling; NO
changes to `butler`, `bin/*`, `lib/*`, other modules, or docs other than
the tracker edit in §6.

**Expected-absent at delivery:** no new module folder other than
`audio-repair`; no new or modified files under `lib/`. If any appears,
HALT and report.

## 5. CORE OBJECTIVE

`audio-repair` passes `bin/modulelint`; the menu shows it with the
`⚠ elevated` badge at its order-910 position; the diagnosis ladder covers
all six outcomes (missing tools, dead server, dummy/no-sink with driver
evidence, dummy/no-sink without evidence, healthy chain, muted Master); the
only write anywhere is the recorded, undoable Master repair; every verdict
is honest and plainly worded.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exit 0 including new stages; `bin/modulelint` exit 0; `./butler --scan`
exit 0; `bash -n` clean; shellcheck clean if installed; worktree clean;
everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `modules/audio-repair/module.yml` — per §4 fact 1.
2. `modules/audio-repair/module.sh` — executable (git mode 755), per §4
   facts 2–7.

Modify:

3. `tests/run-tests.sh` — keep all existing stages passing; add stages
   `(ar)`–`(aw)` (letters confirmed from the harness per §2.8) using
   PATH-prefix stubs (`pactl`, `amixer`, `dmesg`, and a stub `sudo` that
   runs its command for the dmesg path) with canned outputs; NEVER real
   tools. Where the module's interactive confirmation matters, drive the
   module binary directly with piped stdin (document in stage comments):
   - (ar) gate + read-only smokes: `./butler --scan` exit 0;
     `bin/modulelint` exit 0 with `PASS audio-repair`; `./butler --list`
     shows the elevated badge; `plan`/`dry-run` exit 0, non-empty, ≤ 23
     lines, dry-run contains the exact strings `pactl info` and `dmesg`
     (dmesg shown as the elevated line via the helper's display);
     `run` with stdin `/dev/null` and no pactl stub → exit 1, one plain
     stderr line, nothing written (fake HOME byte-identical);
   - (as) healthy chain: stub `pactl` (PipeWire server, one real sink),
     stub `amixer` (Master unmuted at 74%) → exit 0, verdict says the
     output chain looks healthy, no state file, no elevated call in the
     stub log;
   - (at) driver/firmware verdict: stub `pactl` (dummy sink only), stub
     `dmesg` printing sof-audio firmware failure lines → exit 0, output
     contains the newer-kernel/firmware verdict AND at least one evidence
     line, no state file, stub log shows the elevated dmesg call;
   - (au) muted repair: stub `pactl` (real sink), stub `amixer` (Master
     muted at 0%); scripted stdin `y` → exit 0; state file records the
     prior muted+0 values; stub log shows the `sset Master` application;
     output shows current-vs-proposed before confirming;
   - (av) undo after (au): stub `amixer` back to muted/0 after the call
     sequence — assert the undo issues the restore commands from the
     recorded values, deletes the state, exits 0; second undo → "Nothing
     to undo." exit 0;
   - (aw) confirm-no + elevated-failure: stdin `n` on the muted fixture →
     exit 0, "Nothing changed.", no state, no sset call; separately, stub
     `sudo` failing → non-zero exit, one plain stderr line, nothing
     written.
4. `docs/PROJECT_STATE.md` — replace the `## 4. Active Milestone & Current
   State` section with EXACTLY (verify the old text first with
   `grep -n "Immediate Next Task" docs/PROJECT_STATE.md`; confirm, do not
   copy):

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** Module batch #1 (owner-approved 2026-09-16): nine modules — seven features, two fixes — one reviewed PR at a time on the v0.1 core.
- **Current State:** v0.1 core complete; batch #1 in progress — screenshot-studio (PR #5), orchestrator spec + `bin/orchestrator-check` gate (PR #6), default-apps-editor (PR #7), appimage-installer (PRs #8/#9), timeshift-guardian (PR #10) landed.
- **Immediate Next Task:** task 014 — module `multimedia-codecs` (elevated install, honest no-undo), sixth in the owner's revised build order.
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

1. `modules/audio-repair/module.yml` + read-only actions
   (describe/plan/dry-run, ≤23-line screens) → commit + push
2. `module.sh` diagnosis ladder (preflight → server → sinks → mixer →
   elevated dmesg evidence scan → verdicts) → commit + push
3. `module.sh` the one recorded repair + undo → commit + push
4. Harness stages (ar)–(aw), full suite green → commit + push
5. Tracker edit → commit + push
6. Final pass: `bash -n` touched scripts, shellcheck if installed,
   `bin/modulelint` green, `./butler --scan` exit 0, `--list` badge check,
   full harness, §14 smokes, clean tree → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/audio-repair` — EXCEPT the §4 fact 9
  substitution if your runner pins you.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/audio-repair:refs/remotes/origin/_resume
git checkout -B feature/audio-repair refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/audio-repair origin/main
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
  EVERY expansion. Reference style: `modules/timeshift-guardian/module.sh`.
- Module I/O contract: stdout for humans, stderr for errors; exit 0
  success (verdict delivered counts as success); non-zero failure with one
  plain-language stderr line.
- TEST_COMMAND: `bash tests/run-tests.sh` (stages ar–aw: gate/smokes,
  healthy chain, driver verdict, muted repair, undo, confirm-no,
  elevated failure)
- INTEGRATION_TEST_COMMAND: stage (ar) — real `./butler --scan` and
  `--list` exercising the real menu/gate with the new elevated module
  present
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — every verdict branch and the
  repair/undo path have direct harness assertions; no bash mutation tooling
  exists under the zero-dependency constraint
- LINT_COMMAND: `bash -n modules/audio-repair/module.sh lib/elevate.sh
  butler lib/*.sh bin/modulelint tests/run-tests.sh` (always) plus
  `shellcheck` on the same set when installed; additionally
  `bin/modulelint audio-repair` must exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages; existing modules; menu behavior;
  `lib/manifest.sh` parsing of `needs: [pactl, amixer]`, `asks: 1`.
- The ONLY elevated operation is the read-only `dmesg` inspection via
  `lib/elevate.sh`. The ONLY write anywhere is the user-level recorded
  Master mixer repair. No config files, no services, no packages.
- Owner-acceptance safety (fact 8): the non-destructive set stays
  non-destructive; tests use stubs only.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- NO installs, NO service management, NO config-file edits, NO volume
  changes beyond the one recorded Master repair, NO per-app mixing, NO
  other modules, NO lib changes.
- Do NOT modify `butler`, `bin/modulelint`, `bin/orchestrator-check`,
  `lib/*.sh`, other modules, README.md, docs/VISION.md, or
  docs/MODULE_SPEC.md.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

1. `bash tests/run-tests.sh` — exit 0, every stage asserts successfully.
2. `bin/modulelint audio-repair` — exit 0 with PASS.
3. `bin/modulelint` — exit 0 (6 modules).
4. `./butler --scan` — exit 0.
5. `./butler --list` — shows `audio-repair: Audio repair` with the
   elevated badge; all existing modules still listed.
6. `./butler --run audio-repair --dry-run` — exit 0, side-effect-free.
7. `bash -n` clean over all changed/new scripts; shellcheck clean if
   installed (record absence otherwise).
8. Worktree clean, all work pushed, no extra module folders, no lib changes.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: audio-repair — diagnose-first sound doctor with one honest
recorded repair`. Description: summary; design rationale (the six-outcome
ladder and why each exit path is honest; why the newer-kernel verdict is
delivered WITHOUT any config change — the owner's no-fake-fix ruling; why
exactly one repair kind ships in v1; the elevated read-only `dmesg` choice;
the stub test strategy and its honest limit — real PipeWire/ALSA behavior
on Mint is owner acceptance); test results per §10 layer with exact
commands and outcomes; safety statement "the only elevated operation is the
read-only dmesg inspection via lib/elevate.sh; the only write is the
recorded user-level Master mixer repair; all tests run against stub
binaries"; what the owner should try on Mint (`./butler` → Audio repair →
read the verdict; if it offers the mixer repair, accept, then `[u]ndo`);
breaking changes (none); migration notes (none). Describe only this PR's
own changes. Include `#### Session Irregularities` per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only (interfered with following this prompt AND
cost >~10 min / blocked progress / required a workaround / reveals a
recurring blind spot). If none significant, write exactly
`None significant`. If significant: Category | Symptom | Impact | Workaround
| Hardening candidate, 3–6 lines total. If you used the branch-substitution
rule (§4 fact 9), one line noting it belongs here. This report does not
affect the MERGE/REVISE verdict unless it reveals a missing deliverable.
