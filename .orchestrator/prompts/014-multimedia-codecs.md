# 014 — module: multimedia-codecs

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/014-multimedia-codecs.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "014 — module: multimedia-codecs".

## 1. TASK TITLE AND SCOPE

Ship batch-#1 module `multimedia-codecs` (feature kind, `risk: elevated`,
`undo: false` — honest no-undo, `needs: [dpkg, apt-get]`, `order: 40`,
`asks: 1`): a diagnose-first codec installer for Linux Mint 22 — checks which
curated codec packages are already installed, reports exactly what is missing
in plain words, and after ONE confirmation installs only the missing
packages through one elevated `apt-get install` step, then verifies
per-package and reports an honest mixed result. It never pretends an install
can be undone: instead of a fake undo it prints the exact manual removal
command. Complete this in ONE pull request.

## 2. REQUIRED READING ORDER

1. `docs/PROJECT_STATE.md` — §3 conventions and order table (your module is
   `order: 40`, features range), and the batch rulings.
2. `README.md` — safety contract.
3. `docs/MODULE_SPEC.md` — §2 manifest fields (`undo: false` behavior), §3
   (elevated modules use the shared `elevate` helper ONLY), §5 gate.
4. `modules/audio-repair/module.sh` — newest elevated sibling: diagnose-first
   ladder, `lib/elevate.sh` usage with helper-driven display, honest verdicts,
   zero `sudo` literals, per-step plain-word reporting.
5. `modules/timeshift-guardian/module.sh` — elevated confirmation flow and
   the "cannot confirm elevated module without a terminal" menu guard.
6. `lib/elevate.sh`, `lib/ask.sh` — the elevated helper and the question
   helper (`ask_yn`: Enter = NO, EOF = NO).
7. `bin/modulelint` — the gate your module must pass (its sandbox runs
   `run` with stdin `/dev/null`; EOF on `ask_yn` means NO, so a sandbox run
   stops at the confirmation and installs nothing).
8. `tests/run-tests.sh` — harness pattern; the stage letter sequence ends at
   `(aw)` — your new stages continue `(ax)` onward (confirm with
   `grep -n "Stage aw" tests/run-tests.sh`; confirm, do not copy).
9. `butler` — how `undo: false` modules appear in the menu (no `[u]ndo`
   entry; confirm with `grep -n "undo" butler lib/menu.sh lib/manifest.sh`;
   confirm, do not copy).
10. `git log --oneline -5` — Conventional Commits convention (confirm, do
    not copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22. Nine
modules are on `main` (latest: audio-repair via PR #11). The owner-approved
batch names this module "multimedia-codecs (elevated install, honest
no-undo)". Owner rulings that shape it: diagnose first; the honest
mixed/no-undo convention — package installs are NOT undone by the module, and
the module must say so plainly instead of pretending; the one real action is
installing exactly the missing curated packages, nothing more. Owner vision:
one menu entry tells you which codecs are missing on this machine and, only
after you confirm, installs exactly those — then reports per-package what
actually happened.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

1. **Manifest (exact values):** `title: Multimedia codecs`;
   `description: >-` folding EXACTLY: "Checks a curated codec bundle —
   GStreamer bad/ugly plugin sets, GStreamer libav, and libavcodec-extra —
   against what is already installed, names exactly what is missing in
   plain words, and after one confirmation installs only the missing
   packages via a single elevated apt-get step with per-package
   verification. Package installs are not undone by the module; the exact
   manual removal command is printed instead of a fake undo.";
   `risk: elevated`; `undo: false`; `needs: [dpkg, apt-get]`; `asks: 1`;
   `order: 40`.
2. **`asks: 1` budget:** the single question is the confirmation of the
   install (`ask_yn`, Enter defaults to NO). Every other step is read-only
   diagnosis or honest reporting.
3. **Curated package list (fixed, in-code documented):**
   `gstreamer1.0-plugins-bad`, `gstreamer1.0-plugins-ugly`,
   `gstreamer1.0-libav`, `libavcodec-extra`. The module installs ONLY
   packages from this list that `dpkg -s` reports as not installed. The
   list is a code constant with a comment naming the base system (Linux
   Mint 22 / Ubuntu 24.04).
4. **Diagnosis/action ladder:**
   (i) preflight: `dpkg` and `apt-get` present (they ship on Mint; if
   somehow missing, one plain honest stderr line, exit 1, nothing else);
   (ii) read-only status: for each curated package run
   `dpkg -s <pkg> >/dev/null 2>&1` → installed or missing; build two lists;
   (iii) nothing missing → honest verdict "all four curated codec packages
   are already installed; nothing to do", exit 0, no elevated call, nothing
   written;
   (iv) some missing → show installed vs missing lists, the exact elevated
   command via the helper display, and the honest no-undo notice ("these
   installs are not undone by mintbutler; the removal command is printed
   after a successful install"), then ask the ONE confirmation; NO/EOF →
   "Nothing installed." exit 0;
   (v) YES → the single elevated step: display and run
   `apt-get install -y <missing...>` through `elevate_run`;
   (vi) verification: re-run `dpkg -s` for every package that was missing;
   all now installed → success report listing them + the exact manual
   removal command (`sudo apt-get remove <those packages>` displayed via the
   helper, never a `sudo` literal in the module) + the no-undo reminder,
   exit 0; some still missing → honest MIXED report: per-package
   installed/failed lists, plain hint (refresh software sources, check the
   network, re-run), the removal command for what DID install, exit 1;
   elevated step itself failed → one plain stderr line ("the elevated
   apt-get step failed (exit N)"), nothing claimed, exit 1.
5. **Honest no-undo (owner ruling):** the module has NO `undo` action and
   writes NO state file anywhere. `describe`, `plan`, and the post-install
   report all state plainly that installs are not undone by the module.
6. **Actions:** `describe` one line; `plan` the ladder in plain numbered
   steps including the no-undo notice; `dry-run` = plan + the exact commands
   it would run (elevated ones displayed via the elevate helper) with zero
   execution. `plan` and `dry-run` render in ≤ 23 lines.
7. **Non-interactive behavior (modulelint compatibility):** modulelint runs
   `run` with stdin `/dev/null`. In the sandbox `dpkg` is real: whatever the
   curated status happens to be, the flow stops at `ask_yn` (EOF = NO) →
   "Nothing installed." exit 0, nothing written, no elevated call. All
   writes are apt-managed package state and happen only after the confirmed
   YES.
8. **Forbidden-pattern compliance:** `sudo` appears ONLY via
   `lib/elevate.sh`; `module.sh` contains no `sudo`/`pkexec`/`eval`/
   `curl|bash` literal; EVERY elevated command display uses
   `elevate_command_line` (PR #10's revision exists because a previous
   module hardcoded a display string — do not repeat that); quote every
   expansion.
9. **Owner acceptance ruling (2026-09-16, binding):** acceptance commands
   are non-destructive: `./butler --list`, `./butler --scan`,
   `./butler --run multimedia-codecs --dry-run`, menu navigation. Tests
   never invoke real `sudo` or real `apt-get` writes — PATH stubs with
   canned outputs only.
10. **Branch-pinning rule:** if your runner pins your session to a branch
    and forbids creating another, use the pinned branch as the target (base
    stays `main`), substitute its name in §8/§9, and record it under
    `#### Session Irregularities`. Never push to
    `arena/01a0abf2-mintbutler`.

**Scope boundaries:** NO `apt-get update` (install runs against cached
package lists; if a package is unknown to them the honest mixed/failed path
reports it — document this in plan); NO package removal or purge by the
module; NO config-file edits; NO service restarts; NO snaps/flatpaks; NO
changes to `butler`, `bin/*`, `lib/*`, other modules, or docs other than the
tracker edit in §6.

**Expected-absent at delivery:** no new module folder other than
`multimedia-codecs`; no new or modified files under `lib/`. If any appears,
HALT and report.

## 5. CORE OBJECTIVE

`multimedia-codecs` passes `bin/modulelint`; the menu shows it with the
`⚠ elevated` badge at its order-40 position and WITHOUT an undo entry; the
ladder covers all outcomes (all installed, some missing + confirm-no, some
missing + confirm-yes + full success, confirm-yes + mixed/failed result,
elevated failure); installs are honest per-package; no state file is ever
written.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exit 0 including new stages; `bin/modulelint` exit 0; `./butler --scan`
exit 0; `bash -n` clean; shellcheck clean if installed; worktree clean;
everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `modules/multimedia-codecs/module.yml` — per §4 fact 1.
2. `modules/multimedia-codecs/module.sh` — executable (git mode 755), per
   §4 facts 2–8.

Modify:

3. `tests/run-tests.sh` — keep all existing stages passing; add stages
   `(ax)`–`(bc)` (letters confirmed from the harness per §2.8) using
   PATH-prefix stubs (`dpkg`, `apt-get`, and a stub `sudo` that runs its
   command for the elevated path) with canned outputs; NEVER real
   install/removal. Where the module's interactive confirmation matters,
   drive the module binary directly with piped stdin (document in stage
   comments):
   - (ax) gate + read-only smokes: `./butler --scan` exit 0;
     `bin/modulelint` exit 0 with `PASS multimedia-codecs`; `./butler
     --list` shows the elevated badge and NO undo affordance for the
     module; `plan`/`dry-run` exit 0, non-empty, ≤ 23 lines, dry-run
     contains the exact strings `dpkg -s` and `apt-get install` (the
     latter shown as the elevated line via the helper's display);
     dry-run contains the no-undo notice; `run` with stdin `/dev/null`
     under the all-installed stub set → exit 0 "nothing to do", nothing
     written, no elevated call in the stub log;
   - (ay) all-installed path under stub `dpkg` (all four present) →
     verdict says already installed, exit 0, no elevated call, no state
     file anywhere (fake HOME byte-identical);
   - (az) missing + confirm-no: stub `dpkg` reports two missing; scripted
     stdin `n` → exit 0, "Nothing installed.", no apt-get call in the
     stub log, nothing written;
   - (ba) missing + confirm-yes + full success: scripted stdin `y`, stub
     `apt-get` exit 0 and a stub `dpkg` that flips the missing packages to
     installed after the apt-get call → exit 0; output shows installed-vs-
     missing BEFORE confirming, the exact elevated command via the helper
     display, per-package success, the manual removal command display, and
     the no-undo reminder; stub log shows exactly one `apt-get install -y`
     call naming exactly the two missing packages;
   - (bb) confirm-yes + MIXED result: stub `apt-get` exit 0 but stub
     `dpkg` keeps one package missing after → exit 1, output names the
     per-package installed and failed lists and the plain retry hint;
   - (bc) elevated failure: stub `sudo` refusing → non-zero exit, one
     plain stderr line naming the failed elevated step, nothing claimed,
     nothing written.
4. `docs/PROJECT_STATE.md` — replace the `## 4. Active Milestone & Current
   State` section with EXACTLY (verify the old text first with
   `grep -n "Immediate Next Task" docs/PROJECT_STATE.md`; confirm, do not
   copy):

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** Module batch #1 (owner-approved 2026-09-16): nine modules — seven features, two fixes — one reviewed PR at a time on the v0.1 core.
- **Current State:** v0.1 core complete; batch #1 in progress — screenshot-studio (PR #5), orchestrator spec + `bin/orchestrator-check` gate (PR #6), default-apps-editor (PR #7), appimage-installer (PRs #8/#9), timeshift-guardian (PR #10), audio-repair (PR #11) landed.
- **Immediate Next Task:** task 015 — module `printer-helper` (guided printer setup, never vendor blobs), seventh in the owner's revised build order.
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

1. `modules/multimedia-codecs/module.yml` + read-only actions
   (describe/plan/dry-run, ≤23-line screens, no-undo notice visible) →
   commit + push
2. `module.sh` diagnosis ladder (preflight → dpkg status → nothing-missing
   verdict → missing lists + confirmation gate) → commit + push
3. `module.sh` the single elevated install + per-package verification +
   honest mixed reporting → commit + push
4. Harness stages (ax)–(bc), full suite green → commit + push
5. Tracker edit → commit + push
6. Final pass: `bash -n` touched scripts, shellcheck if installed,
   `bin/modulelint` green, `./butler --scan` exit 0, `--list` badge + no-
   undo check, full harness, §14 smokes, clean tree → commit + push, then
   open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/multimedia-codecs` — EXCEPT the §4 fact 10
  substitution if your runner pins you.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/multimedia-codecs:refs/remotes/origin/_resume
git checkout -B feature/multimedia-codecs refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/multimedia-codecs origin/main
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
  success (the nothing-missing and confirm-no verdicts count as success);
  non-zero failure (mixed result, elevated failure) with one plain-language
  stderr line plus the honest per-package detail on stdout.
- TEST_COMMAND: `bash tests/run-tests.sh` (stages ax–bc: gate/smokes,
  all-installed, confirm-no, full success, mixed result, elevated failure)
- INTEGRATION_TEST_COMMAND: stage (ax) — real `./butler --scan` and
  `--list` exercising the real menu/gate with the new elevated module
  present
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — every ladder branch and the mixed
  path have direct harness assertions; no bash mutation tooling exists under
  the zero-dependency constraint
- LINT_COMMAND: `bash -n modules/multimedia-codecs/module.sh lib/elevate.sh
  butler lib/*.sh bin/modulelint tests/run-tests.sh` (always) plus
  `shellcheck` on the same set when installed; additionally
  `bin/modulelint multimedia-codecs` must exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages; existing modules; menu behavior;
  `lib/manifest.sh` parsing of `needs: [dpkg, apt-get]`, `asks: 1`,
  `undo: false`.
- The ONLY elevated operation is the single `apt-get install -y` of the
  missing curated packages via `lib/elevate.sh`. No removals, no updates,
  no config edits, no services.
- The module writes NO state file (honest no-undo).
- Owner-acceptance safety (fact 9): the non-destructive set stays
  non-destructive; tests use stubs only — a stub `apt-get` NEVER performs a
  real install.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- NO `apt-get update`, NO package removal/purge, NO config-file edits, NO
  service management, NO snaps/flatpaks, NO other modules, NO lib changes.
- Do NOT modify `butler`, `bin/modulelint`, `bin/orchestrator-check`,
  `lib/*.sh`, other modules, README.md, docs/VISION.md, or
  docs/MODULE_SPEC.md.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

1. `bash tests/run-tests.sh` — exit 0, every stage asserts successfully.
2. `bin/modulelint multimedia-codecs` — exit 0 with PASS.
3. `bin/modulelint` — exit 0 (7 modules).
4. `./butler --scan` — exit 0.
5. `./butler --list` — shows `multimedia-codecs: Multimedia codecs` with
   the elevated badge and no undo entry; all existing modules still listed.
6. `./butler --run multimedia-codecs --dry-run` — exit 0, side-effect-free.
7. `bash -n` clean over all changed/new scripts; shellcheck clean if
   installed (record absence otherwise).
8. Worktree clean, all work pushed, no extra module folders, no lib changes.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: multimedia-codecs — diagnose-first curated codec install with
honest no-undo`. Description: summary; design rationale (the ladder and why
each exit path is honest; why exactly these four curated packages; why no
`apt-get update` is run and how stale-list failure is reported honestly;
the honest no-undo convention per the owner ruling — removal command printed
instead of fake undo; the single-elevated-step design; the stub test
strategy and its honest limit — real apt/codec behavior on Mint is owner
acceptance); test results per §10 layer with exact commands and outcomes;
safety statement "the only elevated operation is one apt-get install of the
missing curated packages via lib/elevate.sh; the module writes no state
file; all tests run against stub binaries that never install anything";
what the owner should try on Mint (`./butler` → Multimedia codecs → read
the missing list → accept the install → check playback in a media app);
breaking changes (none); migration notes (none). Describe only this PR's
own changes. Include `#### Session Irregularities` per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only (interfered with following this prompt AND
cost >~10 min / blocked progress / required a workaround / reveals a
recurring blind spot). If none significant, write exactly
`None significant`. If significant: Category | Symptom | Impact | Workaround
| Hardening candidate, 3–6 lines total. If you used the branch-substitution
rule (§4 fact 10), one line noting it belongs here. This report does not
affect the MERGE/REVISE verdict unless it reveals a missing deliverable.
