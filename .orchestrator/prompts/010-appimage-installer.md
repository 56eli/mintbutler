# 010 — module: appimage-installer

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/010-appimage-installer.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "010 — module: appimage-installer".

## 1. TASK TITLE AND SCOPE

Ship batch-#1 module `appimage-installer` (risk: low, undo: true,
`needs: []`, `order: 10`, `asks: 3`): install an AppImage file for the
current user — validate it, copy it to a managed location, mark it
executable, and create a menu entry through the SHARED
`lib/desktop-entry.sh` pipeline (reuse, do not reimplement) — with undo that
removes the entry and the installed copy. Complete this in ONE pull request.

## 2. REQUIRED READING ORDER

1. `docs/PROJECT_STATE.md` — §3 conventions and order table (your module is
   `order: 10`), and the settled decision that this module reuses
   `lib/desktop-entry.sh`.
2. `README.md` — safety contract.
3. `docs/MODULE_SPEC.md` — §2 manifest fields, §3 actions and the bounded
   `asks:` series, §5 gate.
4. `lib/desktop-entry.sh` — the shared pipeline you MUST reuse; its public
   functions are `desktop_sanitize_name`, `desktop_check_shadowing`,
   `desktop_validate_exec`, `desktop_build_content`, `desktop_validate_file`,
   `desktop_resolve_target`, `desktop_trust_and_exec`, `desktop_record_path`,
   `desktop_undo`. Read their contracts carefully (confirm, do not copy).
5. `modules/desktop-shortcut-creator/module.sh` — the existing consumer of
   that library: entry target directory, temp-file + resolve + write +
   validate + trust + record flow, state-record/undo wiring.
6. `modules/default-apps-editor/module.sh` — newest sibling: guided-ask
   style, honest reporting, state-dir layout.
7. `lib/ask.sh` — the bounded-question helpers.
8. `bin/modulelint` — the gate your module must pass (its sandbox runs `run`
   with stdin `/dev/null`).
9. `tests/run-tests.sh` — harness pattern; the stage letter sequence ends at
   `(af)` — your new stages continue `(ag)` onward (confirm with
   `grep -n "Stage af" tests/run-tests.sh`; confirm, do not copy).
10. `git log --oneline -5` — Conventional Commits convention (confirm, do
    not copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22. Core,
gate, desktop-shortcut-creator, screenshot-studio, and default-apps-editor
are on `main`. The owner-approved batch names this module
"appimage-installer (order 10; reuses lib/desktop-entry.sh)". Owner vision:
a downloaded `.AppImage` becomes a trustworthy, launchable menu entry in a
few typed answers — the file is validated, copied to a stable user-owned
location, made executable, and registered — with everything reversible.
Nothing outside the user's HOME is touched; no root anywhere.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

1. **Manifest (exact values):** `title: AppImage installer`;
   `description: >-` folding EXACTLY: "Installs an AppImage for the current
   user: validates the file, copies it to a managed location, marks it
   executable, and creates a menu entry through the shared desktop-entry
   library. Undo removes the entry and the installed copy.";
   `risk: low`; `undo: true`; `needs: []`; `asks: 3`; `order: 10`.
2. **`asks: 3` budget, used as:** (a) path to the `.AppImage` file,
   (b) entry name — the derived default is offered and Enter accepts it,
   (c) apply confirmation (`ask_yn`, Enter defaults to NO). `q` at any
   question aborts cleanly (exit 0, "Nothing changed.", nothing written).
3. **Input validation (plain error + exit 1, nothing written):** path must
   exist, be a regular file, be readable, and its basename must end in
   `.AppImage` or `.appimage`. Derive the default entry name from the
   basename minus that extension (underscores and dashes become spaces).
4. **Install mechanics (user-level only):** install dir
   `$HOME/.local/share/mintbutler-appimages/`. Copy name: the sanitized
   slug (`desktop_sanitize_name` of the entry name) plus `.AppImage` —
   sanitized names keep `desktop_validate_exec` happy (it rejects Exec
   values containing spaces). If the copy target already exists:
   byte-identical (`cmp -s`) → reuse it (idempotent, say so); different →
   append `-N` before the extension (first free N ≥ 2). Then `chmod +x`
   the copy. The ORIGINAL file is never modified, moved, or deleted.
5. **Entry creation MUST reuse `lib/desktop-entry.sh`:** build the content
   with `desktop_build_content Application "<name>" "<installed copy path>"
   "" false ""` into a temp file; check shadowing with
   `desktop_check_shadowing`; resolve the final path with
   `desktop_resolve_target` against the same user applications directory
   desktop-shortcut-creator uses (follow that module exactly); validate the
   written file with `desktop_validate_file`; then `desktop_trust_and_exec`;
   then record BOTH the entry path and the installed-copy path with
   `desktop_record_path appimage-installer <slug> <path>` (two records —
   undo depends on both). Do NOT reimplement or duplicate any of this logic
   in the module. Known shared-library quirk, accepted for v1:
   `desktop_build_content` writes `Comment=Created by mintbutler
   desktop-shortcut-creator` — leave it; note it in the PR description.
6. **Undo:** delegate to `desktop_undo appimage-installer` — it removes
   every recorded path (the entry AND the installed copy) and the state
   files. Missing state → "Nothing to undo." exit 0. After removing, say
   plainly that the original downloaded file was never touched.
7. **Actions:** `describe` one line; `plan` plain numbered steps;
   `dry-run` = plan + exact paths it would use (install dir, applications
   dir) with zero writes, exit 0. `plan` and `dry-run` render in ≤ 23
   lines.
8. **Non-interactive behavior (modulelint compatibility):** modulelint runs
   `run` with stdin `/dev/null`; the first `ask` hits EOF and the module
   prints one plain stderr line and exits 1 having written NOTHING
   (nothing is written before confirmation anyway — keep it that way).
9. **Forbidden-pattern compliance:** no `sudo`/`pkexec`/`eval`/`curl|bash`
   literals in the module; quote every expansion — the gate SC2086-fails
   wherever shellcheck is present.
10. **Owner acceptance ruling (2026-09-16, binding):** acceptance commands
    are non-destructive: `./butler --list`, `./butler --scan`,
    `./butler --run appimage-installer --dry-run`, menu navigation. Tests
    never touch real `$HOME` state: fake HOMEs, temp AppImage fixtures, and
    the harness's existing sandbox app-dir pattern only.
11. **Branch-pinning rule:** if your runner pins your session to a branch
    and forbids creating another, use the pinned branch as the target (base
    stays `main`), substitute its name in §8/§9, and record it under
    `#### Session Irregularities`. Never push to
    `arena/01a0abf2-mintbutler`.

**Scope boundaries:** NO changes to `lib/desktop-entry.sh` (the Comment
quirk stays), NO changes to `butler`, `bin/*`, other `lib/*`, other modules,
or docs other than the tracker edit in §6; NO downloading AppImages
(yesterday's `curl`/`wget` of anything is out of scope); NO execution of the
AppImage itself at install time.

**Expected-absent at delivery:** no new module folder other than
`appimage-installer`; no new or modified files under `lib/`. If any
appears, HALT and report.

## 5. CORE OBJECTIVE

`appimage-installer` passes `bin/modulelint`; the menu lists it at its
order-10 position (first feature entry); installing an AppImage produces a
launchable user menu entry via the shared library with the copy recorded;
undo removes entry and copy; the original file is never touched.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exit 0 including new stages; `bin/modulelint` exit 0; `./butler --scan`
exit 0; `bash -n` clean; shellcheck clean if installed; worktree clean;
everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `modules/appimage-installer/module.yml` — per §4 fact 1.
2. `modules/appimage-installer/module.sh` — executable (git mode 755), per
   §4 facts 2–9.

Modify:

3. `tests/run-tests.sh` — keep all existing stages passing; add stages
   `(ag)`–`(al)` (letters confirmed from the harness per §2.9) using fake
   HOMEs and temp `.AppImage` fixture files (a few bytes are enough); NEVER
   real HOME state:
   - (ag) `./butler --scan` exit 0; `bin/modulelint` exit 0 with
     `PASS appimage-installer`; `./butler --list` shows the module FIRST
     among features (order 10); `plan`/`dry-run` exit 0, non-empty, ≤ 23
     lines each; `run` with stdin `/dev/null` exits 1 with one plain
     stderr line and writes nothing (fake HOME byte-identical);
   - (ah) happy path: scripted stdin (path, Enter to accept the derived
     name, `y`) → exit 0; the installed copy exists in the fake install
     dir, is executable, byte-equal to the fixture; the `.desktop` entry
     exists in the fake applications dir with `Exec=` pointing at the copy;
     the state record lists both paths; the original fixture file is
     unchanged;
   - (ai) idempotency: second run with the same fixture and same answers →
     reports already-done/reuse, exit 0, no `-2` copy created, no second
     entry;
   - (aj) undo after (ah): entry file gone, installed copy gone, state
     gone, original fixture untouched; second undo → "Nothing to undo."
     exit 0;
   - (ak) error paths: nonexistent file → exit 1 plain error, nothing
     written; wrong extension (e.g. `.txt`) → exit 1 plain error, nothing
     written;
   - (al) name collision with different bytes: pre-create the would-be copy
     with different content, run → a `-2` copy is installed and the entry
     points at it; pre-existing copy byte-identical → reused, no `-2`.
4. `docs/PROJECT_STATE.md` — replace the `## 4. Active Milestone & Current
   State` section with EXACTLY (verify the old text first with
   `grep -n "Immediate Next Task" docs/PROJECT_STATE.md`; confirm, do not
   copy):

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** Module batch #1 (owner-approved 2026-09-16): nine modules — seven features, two fixes — one reviewed PR at a time on the v0.1 core.
- **Current State:** v0.1 core complete; batch #1 in progress — screenshot-studio (PR #5), governing orchestrator spec + `bin/orchestrator-check` gate (PR #6), default-apps-editor (PR #7) landed.
- **Immediate Next Task:** task 011 — module `timeshift-guardian` (elevated / snapshots additive), fourth in the owner's revised build order.
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

1. `modules/appimage-installer/module.yml` + read-only actions
   (describe/plan/dry-run, ≤23-line screens) → commit + push
2. `module.sh` guided `run` (validate → name → confirm → copy → entry via
   shared lib → record) → commit + push
3. `module.sh` `undo` (shared `desktop_undo`, honest reporting) → commit +
   push
4. Harness stages (ag)–(al), full suite green → commit + push
5. Tracker edit → commit + push
6. Final pass: `bash -n` touched scripts, shellcheck if installed,
   `bin/modulelint` green, `./butler --scan` exit 0, `--list` check, full
   harness, §14 smokes, clean tree → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/appimage-installer` — EXCEPT the §4 fact 11
  substitution if your runner pins you.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/appimage-installer:refs/remotes/origin/_resume
git checkout -B feature/appimage-installer refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/appimage-installer origin/main
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
  EVERY expansion. Reference style: `modules/desktop-shortcut-creator/module.sh`.
- Module I/O contract: stdout for humans, stderr for errors; exit 0
  success; non-zero failure with one plain-language stderr line.
- TEST_COMMAND: `bash tests/run-tests.sh` (stages ag–al: gate, happy path,
  idempotency, undo, error paths, collision versioning)
- INTEGRATION_TEST_COMMAND: stage (ag) — real `./butler --scan` and
  `--list` exercising the real menu/gate with the new module present
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — each behavioral branch (validate
  failures, reuse, -N versioning, confirm-no, EOF, undo with/without state)
  has a direct harness assertion; no bash mutation tooling exists under the
  zero-dependency constraint
- LINT_COMMAND: `bash -n modules/appimage-installer/module.sh butler
  lib/*.sh bin/modulelint tests/run-tests.sh` (always) plus `shellcheck` on
  the same set when installed; additionally `bin/modulelint
  appimage-installer` must exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages; existing modules; menu behavior;
  `lib/manifest.sh` parsing of `needs: []` and `asks: 3`.
- The original AppImage file is NEVER modified, moved, or deleted — only
  copied. Everything written lives under `$HOME/.local/`.
- Owner-acceptance safety (fact 10): the non-destructive set stays
  non-destructive; tests use fake HOMEs and temp fixtures only.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- NO changes to `lib/desktop-entry.sh` or any other lib file, NO other
  modules, NO downloading of anything, NO execution of AppImages at install
  time, NO icon extraction from AppImage internals.
- Do NOT modify `butler`, `bin/modulelint`, `bin/orchestrator-check`,
  other modules, README.md, docs/VISION.md, or docs/MODULE_SPEC.md.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

1. `bash tests/run-tests.sh` — exit 0, every stage asserts successfully.
2. `bin/modulelint appimage-installer` — exit 0 with PASS.
3. `bin/modulelint` — exit 0 (4 modules).
4. `./butler --scan` — exit 0.
5. `./butler --list` — shows `appimage-installer: AppImage installer` as
   the FIRST feature (order 10); all existing modules still listed.
6. `./butler --run appimage-installer --dry-run` — exit 0, side-effect-free.
7. `bash -n` clean over all changed/new scripts; shellcheck clean if
   installed (record absence otherwise).
8. Worktree clean, all work pushed, no extra module folders, no lib changes.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: appimage-installer — user-level AppImage install via shared
desktop-entry library`. Description: summary; design rationale (why copy
instead of move — the original stays untouched and undo is exact; why
sanitized copy names — `desktop_validate_exec` rejects spaces; the
`-N`/reuse idempotency split; why `desktop_build_content`'s Comment quirk
stays — shared library, out of this task's scope; the fake-HOME test
strategy and its honest limit — real Cinnamon menu pickup and AppImage
runtime behavior are owner acceptance on Mint); test results per §10 layer
with exact commands and outcomes; safety statement "the module only reads
the original file and writes under \$HOME/.local/; nothing is executed at
install time; all tests run against fake HOMEs and temp fixtures"; what the
owner should try on Mint (download any AppImage → `./butler` → AppImage
installer → answer three questions → launch from menu → then `[u]ndo`);
breaking changes (none); migration notes (none). Describe only this PR's
own changes. Include `#### Session Irregularities` per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only (interfered with following this prompt AND
cost >~10 min / blocked progress / required a workaround / reveals a
recurring blind spot). If none significant, write exactly
`None significant`. If significant: Category | Symptom | Impact | Workaround
| Hardening candidate, 3–6 lines total. If you used the branch-substitution
rule (§4 fact 11), one line noting it belongs here. This report does not
affect the MERGE/REVISE verdict unless it reveals a missing deliverable.
