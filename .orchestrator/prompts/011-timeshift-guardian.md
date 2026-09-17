# 011 — module: timeshift-guardian

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/011-timeshift-guardian.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "011 — module: timeshift-guardian".

## 1. TASK TITLE AND SCOPE

Ship batch-#1 module `timeshift-guardian` (risk: elevated, `undo: false` —
honestly labeled, `needs: [timeshift]`, `order: 80`, `asks: 2`): a
diagnose-first guardian around Timeshift — report whether Timeshift is
installed and configured, show the snapshot count, and create ONE
owner-commented on-demand snapshot through the single visible confirmed
elevated step. Snapshots are ADDITIVE by owner policy: this module never
deletes, prunes, or restores snapshots, and says so. Complete this in ONE
pull request.

## 2. REQUIRED READING ORDER

1. `docs/PROJECT_STATE.md` — §3 conventions and order table (your module is
   `order: 80`, a FIXES-range number), and the batch rulings.
2. `README.md` — safety contract, especially rule 2 (elevated: exact
   command shown, explicit confirmation, honest undo statement).
3. `docs/MODULE_SPEC.md` — §2 manifest fields, §3 (elevated modules use the
   shared `elevate` helper ONLY), §5 gate.
4. `modules/screenshot-studio/module.sh` — the existing elevated module:
   `lib/elevate.sh` usage, preflight pattern, honest reporting,
   non-interactive behavior under modulelint.
5. `lib/elevate.sh` — the ONLY sanctioned path to root (refuses unless the
   caller's manifest says `risk: elevated`).
6. `lib/ask.sh` — the bounded-question helpers.
7. `bin/modulelint` — the gate your module must pass (its sandbox runs
   `run` with stdin `/dev/null`).
8. `tests/run-tests.sh` — harness pattern; the stage letter sequence ends at
   `(al)` — your new stages continue `(am)` onward (confirm with
   `grep -n "Stage al" tests/run-tests.sh`; confirm, do not copy).
9. `git log --oneline -5` — Conventional Commits convention (confirm, do
   not copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22. Seven
modules are on `main` (latest: appimage-installer via PRs #8/#9). The
owner-approved batch names this module "timeshift-guardian (order 80;
elevated, snapshots additive)". Owner rulings that shape it: elevated steps
are one visible confirmed command; snapshots are ADDITIVE — the module never
deletes or prunes them; diagnose-first — an unconfigured Timeshift gets
honest guidance, not a forced operation; this module does NOT install
Timeshift itself (consistent with the batch's never-install stance — the
Software Manager is the installer of record). Owner vision: before risky
work, one typed answer creates a named restore point the owner can trust,
and the module never pretends to undo what is additive by policy.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

1. **Manifest (exact values):** `title: Timeshift guardian`;
   `description: >-` folding EXACTLY: "Checks whether Timeshift is
   installed and configured, shows the snapshot count, and creates one
   commented on-demand snapshot through a single visible confirmed elevated
   step. Snapshots are additive: this module never deletes them and
   honestly says undo is not offered.";
   `risk: elevated`; `undo: false`; `needs: [timeshift]`; `asks: 2`;
   `order: 80`.
2. **No undo action.** Because snapshots are additive by owner policy, the
   module implements only `describe`, `plan`, `dry-run`, and `run`; there is
   deliberately no `undo` action (unknown action → one plain stderr line,
   exit 1). `plan` and every success message state the additive policy in
   plain words.
3. **`asks: 2` budget, used as:** (a) snapshot comment — a default of
   `mintbutler guard <YYYY-MM-DD>` is offered and Enter accepts it,
   (b) creation confirmation (`ask_yn`, Enter defaults to NO). `q` at the
   comment question aborts cleanly (exit 0, "Nothing changed.").
4. **`run` flow (diagnose-first):**
   (i) `command -v timeshift` missing → one plain honest line ("Timeshift
   is not installed; install it from the Software Manager and configure it
   once in the Timeshift GUI — this module does not install it"), exit 1,
   nothing else attempted;
   (ii) status via `elevate_run "timeshift --list"` — display the raw
   output verbatim, then summarize: configured or not (heuristics on the
   output text: any snapshot row or a named device ⇒ configured;
   empty/error/"not found"/"not configured" wording ⇒ not configured);
   NOT configured → one plain guidance paragraph (open Timeshift GUI once,
   pick a snapshot device/type; then re-run), exit 0, no snapshot created;
   (iii) configured → ask the comment, display the EXACT command
   `sudo timeshift --create --comments '<comment>'` (via the elevate
   helper's display function), confirm, create through `elevate_run`, then
   re-run `timeshift --list` through the helper and show the new count;
   (iv) success message ends with the honest additive statement: the
   snapshot stays until removed in Timeshift itself; this module never
   deletes snapshots and offers no undo.
   Any elevated step failing → one plain stderr line, non-zero exit, no
   further steps.
5. **`plan`/`dry-run`:** plain numbered steps; exact elevated commands with
   placeholder comment; exit 0; zero executions. Both render in ≤ 23 lines.
6. **Non-interactive behavior (modulelint compatibility):** modulelint runs
   `run` with stdin `/dev/null`. In sandboxes without timeshift the
   preflight exits 1 with the honest line before any elevated call — that
   is the passing lint outcome. Where timeshift exists but sudo fails
   non-interactively, the elevated step fails and the module exits
   non-zero with one plain stderr line, having created nothing. Either way
   nothing is written.
7. **Forbidden-pattern compliance:** `sudo` appears ONLY via
   `lib/elevate.sh`; `module.sh` contains no `sudo`/`pkexec`/`eval`/
   `curl|bash` literal; quote every expansion — the gate SC2086-fails
   wherever shellcheck is present.
8. **Owner acceptance ruling (2026-09-16, binding):** acceptance commands
   are non-destructive: `./butler --list`, `./butler --scan`,
   `./butler --run timeshift-guardian --dry-run`, menu navigation. The one
   mutating operation (snapshot creation) is elevated, badged, planned, and
   typed-slug-confirmed by the menu; tests never require it. Tests never
   invoke real `sudo` or real `timeshift` — PATH stubs only.
9. **Branch-pinning rule:** if your runner pins your session to a branch
   and forbids creating another, use the pinned branch as the target (base
   stays `main`), substitute its name in §8/§9, and record it under
   `#### Session Irregularities`. Never push to
   `arena/01a0abf2-mintbutler`.

**Scope boundaries:** NO snapshot deletion/pruning/restoration — EVER; NO
installing timeshift or any package; NO schedule editing (`--enable-*`,
cron); NO config writes (`/etc/timeshift`); NO other Timeshift subcommands
than `--list` and `--create --comments`; NO changes to `butler`,
`bin/*`, `lib/*`, other modules, or docs other than the tracker edit in §6.

**Expected-absent at delivery:** no new module folder other than
`timeshift-guardian`; no new or modified files under `lib/`. If any
appears, HALT and report.

## 5. CORE OBJECTIVE

`timeshift-guardian` passes `bin/modulelint`; the menu shows it with the
`⚠ elevated` badge at its order-80 position; the diagnose-first flow is
fully covered (missing / unconfigured / configured); the single mutating
operation is one visible confirmed elevated `timeshift --create` with the
owner's comment; the additive policy is stated everywhere it matters.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exit 0 including new stages; `bin/modulelint` exit 0; `./butler --scan`
exit 0; `bash -n` clean; shellcheck clean if installed; worktree clean;
everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `modules/timeshift-guardian/module.yml` — per §4 fact 1.
2. `modules/timeshift-guardian/module.sh` — executable (git mode 755), per
   §4 facts 2–7.

Modify:

3. `tests/run-tests.sh` — keep all existing stages passing; add stages
   `(am)`–`(aq)` (letters confirmed from the harness per §2.8) using a
   PATH-prefix stub `timeshift` (logs every invocation with arguments to a
   stage file; `--list` prints configurable canned output; `--create`
   appends to the log and exits 0) plus the existing stub-sudo pattern;
   NEVER real sudo/timeshift:
   - (am) `./butler --scan` exit 0; `bin/modulelint` exit 0 with
     `PASS timeshift-guardian`; `./butler --list` shows the module with
     the elevated badge; `plan`/`dry-run` exit 0, non-empty, ≤ 23 lines
     each, plan contains the exact strings `timeshift --list` and
     `timeshift --create --comments`; `run` with stdin `/dev/null` and no
     timeshift stub on PATH → exit 1, one plain stderr line mentioning the
     Software Manager, stub log absent/empty;
   - (an) unconfigured variant: stub `timeshift` on PATH whose `--list`
     prints "Device not found" style output; drive the module binary
     directly (`bash modules/timeshift-guardian/module.sh run`) with a
     piped stdin and a stub `sudo` that succeeds; expect exit 0, the
     guidance paragraph, and a stub log containing `--list` but NO
     `--create`;
   - (ao) configured happy path: stub `--list` prints a snapshot table
     (one existing snapshot); scripted stdin = Enter (accept default
     comment) then `y`; expect exit 0; stub log shows `--list`, then
     `--create --comments` with the default comment containing
     `mintbutler guard`, then `--list` again; output contains the exact
     elevated command display and the additive statement;
   - (ap) confirm-no: same stub, stdin = Enter then `n`; exit 0, "Nothing
     changed.", stub log contains `--list` but NO `--create`;
   - (aq) elevated-failure path: stub `sudo` exits 1; run → non-zero exit,
     one plain stderr line, no `--create` in the stub log.
   Stages (an)–(aq) invoke the module directly (`bash
   modules/timeshift-guardian/module.sh run` with the stub PATH and piped
   stdin) since the menu path cannot script elevated confirmation;
   document that in the stage comments.
4. `docs/PROJECT_STATE.md` — replace the `## 4. Active Milestone & Current
   State` section with EXACTLY (verify the old text first with
   `grep -n "Immediate Next Task" docs/PROJECT_STATE.md`; confirm, do not
   copy):

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** Module batch #1 (owner-approved 2026-09-16): nine modules — seven features, two fixes — one reviewed PR at a time on the v0.1 core.
- **Current State:** v0.1 core complete; batch #1 in progress — screenshot-studio (PR #5), orchestrator spec + `bin/orchestrator-check` gate (PR #6), default-apps-editor (PR #7), appimage-installer (PRs #8/#9) landed.
- **Immediate Next Task:** task 012 — module `audio-repair` (elevated, config-backup undo, diagnose-first), fifth in the owner's revised build order.
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

1. `modules/timeshift-guardian/module.yml` + read-only actions
   (describe/plan/dry-run, ≤23-line screens) → commit + push
2. `module.sh` `run` (diagnose-first: missing → unconfigured → configured
   → confirmed elevated create → verify → additive statement) → commit +
   push
3. Harness stages (am)–(aq), full suite green → commit + push
4. Tracker edit → commit + push
5. Final pass: `bash -n` touched scripts, shellcheck if installed,
   `bin/modulelint` green, `./butler --scan` exit 0, `--list` badge check,
   full harness, §14 smokes, clean tree → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/timeshift-guardian` — EXCEPT the §4 fact 9
  substitution if your runner pins you.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/timeshift-guardian:refs/remotes/origin/_resume
git checkout -B feature/timeshift-guardian refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/timeshift-guardian origin/main
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
  EVERY expansion. Reference style: `modules/screenshot-studio/module.sh`.
- Module I/O contract: stdout for humans, stderr for errors; exit 0
  success; non-zero failure with one plain-language stderr line.
- TEST_COMMAND: `bash tests/run-tests.sh` (stages am–aq: gate, unconfigured
  guidance, configured create, confirm-no, elevated failure)
- INTEGRATION_TEST_COMMAND: stage (am) — real `./butler --scan` and
  `--list` exercising the real menu/gate with the new elevated module
  present
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — every behavioral branch (missing
  tool, unconfigured, configured create, confirm-no, elevated failure,
  EOF/non-interactive) has a direct harness assertion; no bash mutation
  tooling exists under the zero-dependency constraint
- LINT_COMMAND: `bash -n modules/timeshift-guardian/module.sh lib/elevate.sh
  butler lib/*.sh bin/modulelint tests/run-tests.sh` (always) plus
  `shellcheck` on the same set when installed; additionally
  `bin/modulelint timeshift-guardian` must exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages; existing modules; menu behavior;
  `lib/manifest.sh` parsing of `needs: [timeshift]`, `asks: 2`, `undo: false`.
- The ONLY potentially mutating operation in this module is the single
  visible confirmed `sudo timeshift --create --comments '<comment>'` via
  `lib/elevate.sh`. Nothing deletes or restores snapshots. No config files
  are written by the module.
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

- NO snapshot deletion, pruning, or restoration. NO package installation.
  NO Timeshift schedule/config editing. NO subcommands beyond `--list` and
  `--create --comments`. NO other modules, NO lib changes, NO menu changes.
- Do NOT modify `butler`, `bin/modulelint`, `bin/orchestrator-check`,
  `lib/*.sh`, other modules, README.md, docs/VISION.md, or
  docs/MODULE_SPEC.md.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

1. `bash tests/run-tests.sh` — exit 0, every stage asserts successfully.
2. `bin/modulelint timeshift-guardian` — exit 0 with PASS.
3. `bin/modulelint` — exit 0 (5 modules).
4. `./butler --scan` — exit 0.
5. `./butler --list` — shows `timeshift-guardian: Timeshift guardian` with
   the elevated badge; all existing modules still listed.
6. `./butler --run timeshift-guardian --dry-run` — exit 0, side-effect-free.
7. `bash -n` clean over all changed/new scripts; shellcheck clean if
   installed (record absence otherwise).
8. Worktree clean, all work pushed, no extra module folders, no lib changes.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: timeshift-guardian — diagnose-first Timeshift guardian with
one confirmed additive snapshot`. Description: summary; design rationale
(diagnose-first ordering and why each early exit is honest; why the module
never installs Timeshift; why `undo: false` is the honest label for an
additive-only module — the menu offers no undo for it and every message
says snapshots stay until removed in Timeshift itself; the stub-timeshift
test strategy and its honest limit — real Timeshift behavior against a
real snapshot device is owner acceptance on Mint); test results per §10
layer with exact commands and outcomes; safety statement "the only
potentially mutating operation in this PR is the single visible confirmed
'sudo timeshift --create --comments' via lib/elevate.sh; nothing deletes or
restores snapshots; all tests run against stub binaries"; what the owner
should try on Mint (`./butler` → Timeshift guardian → see status → accept
the default comment → confirm → see the new snapshot in Timeshift);
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
