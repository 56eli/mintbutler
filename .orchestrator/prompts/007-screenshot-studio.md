# 007 — module: screenshot-studio (+ lib/elevate.sh debut)

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/007-screenshot-studio.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "007 — screenshot-studio".

## 1. TASK TITLE AND SCOPE

Ship batch-#1 module `screenshot-studio` (risk: elevated, undo: true with an
honest mixed story, `needs: [flameshot]`, `order: 50`, `asks: 0`): install
Flameshot via the single visible confirmed elevated step, rebind Print Screen
to it through Cinnamon's dconf keybinding store with recorded-restore undo —
plus the first appearance of `lib/elevate.sh`, harness coverage, and the
tracker update recording the owner's revised build order. Complete this in
ONE pull request.

## 2. REQUIRED READING ORDER

1. `docs/PROJECT_STATE.md` — §3 conventions and order table (your module is
   `order: 50`), §4 milestone.
2. `README.md` — safety contract, especially rule 2 (elevated: exact command
   shown, explicit confirmation, honest undo statement).
3. `docs/MODULE_SPEC.md` — §2 manifest (`asks:`, `needs:`), §3 (elevated
   modules use the shared `elevate` helper ONLY; question budget), §5 gate.
4. `modules/desktop-shortcut-creator/module.sh` — conforming sibling: action
   structure, lib sourcing via `MINTBUTLER_LIB_DIR`, state-record/undo
   pattern, non-interactive EOF refusal.
5. `bin/modulelint` — the checks your module must pass (sandbox execution
   with stdin `/dev/null`; sudo in elevated modules is advisory only).
6. `butler` — the menu-side elevated flow (plan shown, typed-slug confirm)
   your module plugs into.
7. `tests/run-tests.sh` — harness pattern; existing stages (a)–(r).
8. `git log --oneline -5` — Conventional Commits convention (confirm, do not
   copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22. The v0.1
core (menu, discovery, modulelint gate, desktop-shortcut-creator) is on
`main`; batch #1 is under way. Owner's spec for this module: "Install
flameshot, rebind PrintScreen via dconf, record + restore the old binding on
undo" — risk elevated, undo story MIXED and labeled: the package install is
not cleanly undoable and the module says so; the keybinding IS restored on
undo. This is the first module to use root, so the trust yardstick applies
at full strength: one visible confirmed command, exact display, verified
outcome, honest reporting.

**Owner vision context:** "Understandable. Before anything runs, the owner
can read in plain language what is about to happen." Every dconf write is
listed in `plan`; every changed key is recorded for `undo`.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

1. **`lib/elevate.sh` (new, shared — first appearance):** the ONLY sanctioned
   path to root, per MODULE_SPEC §3. Contract: `elevate_run "<exact command
   string>"` — resolves the repo root from `MINTBUTLER_LIB_DIR` (its parent),
   reads the calling module's manifest (module passes its slug; parse via
   `lib/manifest.sh`) and REFUSES with a plain error (return 126) unless the
   manifest says `risk: elevated`; prints the exact command to stdout;
   executes `sudo <command>`; returns the command's exit code. It never
   composes commands from user input — callers pass reviewed fixed strings —
   and it never adds its own confirmation prompt (the MENU already took the
   typed-slug confirmation before dispatching `run`).
2. **Manifest (exact values):** `title: Screenshot studio`;
   `description: >-` folding EXACTLY: "Installs Flameshot and points the
   Print Screen key at it. The package install is a visible, confirmed
   elevated step and is not cleanly undoable; the key binding is recorded
   and restored on undo. This module says so instead of pretending.";
   `risk: elevated`; `undo: true`; `needs: [flameshot]`; `asks: 0`;
   `order: 50`.
3. **This module asks nothing** (`asks: 0`): no `ask_value`/`ask_yn` calls;
   the menu's elevated confirmation is the only gate. All actions must
   therefore work with stdin `/dev/null` EXCEPT that `run` may fail
   gracefully (see fact 8).
4. **Keybinding mechanics (Cinnamon on Mint 22, via `dconf` only — user
   session, never sudo):**
   - Built-in screenshot binding: `/org/cinnamon/keybindings/screenshot`
     (string array, e.g. `['Print']`; unset reads as empty output).
   - Custom keybinding slot: a FIXED, deterministic path owned by this
     module: `/org/cinnamon/keybindings/custom/mintbutler-flameshot/` with
     keys `name` = `'Flameshot (mintbutler)'`, `command` = `'flameshot
     gui'`, `binding` = `['Print']`.
   - Registration: the custom path must be present in the
     `/org/cinnamon/keybindings/custom-list` array (read current value —
     empty means none; append the path if absent; write back).
   These are the documented Cinnamon locations; real-schema acceptance
   happens on the owner's machine (verification-split ruling) — your job is
   exact, recorded, undoable dconf operations plus honest failures.
5. **`run` flow:** (a) preflight `command -v flameshot`; missing → print the
   exact command `sudo apt-get install -y flameshot`, run it through
   `elevate_run`, re-check presence; still missing → one plain stderr line,
   exit 1, nothing else done. Present → say so, skip install; (b) if
   `command -v dconf` is missing → one plain stderr line ("dconf not
   available; keybinding changes need the Cinnamon session tools"), exit 1,
   nothing written; (c) **already-configured check** — if the custom slot
   exists with `command` containing `flameshot` → report already-configured
   (including where the binding points), exit 0, nothing changed
   (idempotent); (d) **record** — read the current
   `/org/cinnamon/keybindings/screenshot` value and the current
   `custom-list` value into
   `$HOME/.local/state/mintbutler/screenshot-studio/binding.paths` (plain
   key=value lines; `UNSET` marker for empty values); (e) **rebind** —
   write the three custom-slot keys; append the slot path to `custom-list`
   if absent; and ONLY IF the recorded built-in value contains `Print`,
   clear it (write `@as []`); (f) **verify** — re-read the custom slot's
   `command` and `binding`; mismatch → plain error, exit 1 (records stay,
   undo can reverse); success → print what changed and the honest mixed
   statement: the binding is undoable via `[u]ndo`; flameshot stays
   installed because package installs don't cleanly undo.
6. **`undo`:** read the state file; restore
   `/org/cinnamon/keybindings/screenshot` to the recorded value (write it,
   or reset if `UNSET`); remove the slot path from `custom-list`; `dconf
   reset -f` the custom slot; delete the state file. Missing state →
   "Nothing to undo." exit 0. Never touch keys that weren't recorded. Undo
   prints plainly that flameshot remains installed (package installs are
   not cleanly undoable — honesty, not silence).
7. **Actions:** `describe` one line; `plan` plain numbered steps including
   the exact install command (conditional) and every dconf path to be read
   or written; `dry-run` = plan + exact commands with values, exit 0, zero
   writes. `plan` and `dry-run` must render in ≤ 23 lines (23-line law).
8. **Non-interactive behavior (modulelint compatibility):** modulelint runs
   `run` with stdin `/dev/null`. In the sandbox flameshot is absent, so the
   preflight reaches `elevate_run`, whose `sudo` fails non-interactively →
   the module prints one plain stderr line and exits 1 WITHOUT writing
   anything. That is a passing lint outcome per MODULE_SPEC §5.5 and is
   asserted in the harness.
9. **Forbidden-pattern compliance:** `sudo` appears ONLY inside
   `lib/elevate.sh`; `module.sh` contains no `sudo`/`pkexec` literal, no
   `eval`, no `curl|bash`, and no unquoted expansions — the gate
   SC2086-fails when shellcheck is present (PR #3 went through revision for
   exactly this).
10. **Owner acceptance ruling (2026-09-16, binding):** non-destructive
    acceptance set: `./butler --list` (badge visible), `./butler --scan`,
    `./butler --run screenshot-studio --dry-run`, menu navigation. The real
    elevated run on the owner's machine is acceptance-legal because it is
    badged, planned, and typed-slug-confirmed; tests never require it and
    never invoke real `sudo`, real `apt-get`, or real `dconf` against the
    real settings store.
11. **Branch-pinning rule:** if your runner pins your session to a branch
    and forbids creating another, use the pinned branch as the target (base
    stays `main`), substitute its name in §8/§9, and record it under
    `#### Session Irregularities`. Never push to
    `arena/01a0abf2-mintbutler`.

**Scope boundaries:** NO other keybindings touched, NO flameshot
configuration beyond the rebind (no settings writes), NO alternatives like
scrot/gnome-screenshot, NO changes to `butler`, `bin/modulelint`, or
existing lib/module files except creating `lib/elevate.sh`; NO CI, NO
dependencies beyond `needs: [flameshot]`, NO network calls.

**Expected-absent at delivery:** no new module folder other than
`screenshot-studio`. If another appears, HALT and report.

## 5. CORE OBJECTIVE

`screenshot-studio` passes `bin/modulelint`; the menu shows it with the
`⚠ elevated` badge at its order-50 position; the elevated path is the single
visible confirmed flameshot install via `lib/elevate.sh`; the Print Screen
rebind is recorded before it happens and fully restored by `undo`; the mixed
undo story is stated plainly everywhere it matters; the harness proves every
testable path with stub binaries only.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exits 0 including new stages; `bin/modulelint` exit 0; `./butler --scan`
exit 0; `bash -n` clean; shellcheck clean if installed; worktree clean;
everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `lib/elevate.sh` — per §4 fact 1.
2. `modules/screenshot-studio/module.yml` — per §4 fact 2.
3. `modules/screenshot-studio/module.sh` — executable (git mode 755), per
   §4 facts 3–9.

Modify:

4. `tests/run-tests.sh` — keep stages (a)–(r) passing; add stages using a
   PATH-prefix dir of stub executables (`mktemp/bin`) and a fake HOME; NEVER
   real sudo/apt-get/dconf:
   - stubs: `flameshot` (exit 0), `sudo` (configurable: default exit 1 with
     one stderr line), `dconf` (file-backed store: a plain text file of
     `path<TAB>value` lines under the stage dir, honoring `read`, `write`,
     `reset`, `reset -f`, `list`; missing path on `read` prints nothing);
   - (s) `./butler --scan` exit 0; `bin/modulelint` exit 0 with
     `PASS screenshot-studio`; `./butler --list` shows the screenshot-studio
     line with the elevated badge text;
   - (t) rebind path: seed the stub store with
     `/org/cinnamon/keybindings/screenshot` = `['Print']`; stub flameshot on
     PATH (present → install skipped); run with stdin `/dev/null` → exit 0;
     assert: custom slot keys exist with `flameshot gui` and `['Print']`;
     `custom-list` contains the slot path; built-in screenshot key cleared;
     state file records the previous values; output contains the honest
     mixed statement;
   - (u) undo after (t): exit 0; built-in binding restored to `['Print']`;
     slot path gone from store and from `custom-list`; state file gone;
     output mentions flameshot remains installed; second undo → "Nothing to
     undo." exit 0;
   - (v) missing flameshot + failing sudo stub: exit 1, one plain stderr
     line mentioning the install, stub store byte-identical before/after;
   - (w) idempotency: run (t) twice — second run reports already-configured,
     exit 0, stub store byte-identical between runs;
   - (x) no dconf on PATH (flameshot present): exit 1 with the plain
     dconf-missing line, nothing recorded;
   - (y) `plan`/`dry-run` exit 0, non-empty, ≤ 23 lines each, plan contains
     the exact string `sudo apt-get install -y flameshot` and at least one
     `/org/cinnamon/keybindings/` path.
5. `docs/PROJECT_STATE.md` —
   (a) in the `## 3` batch bullet, replace the substring

   `Build order: timeshift-guardian → audio-repair → appimage-installer → default-apps-editor → multimedia-codecs → screenshot-studio → printer-helper → system-report-pack → book-access-doctor.`

   with EXACTLY

   `Build order (revised by owner 2026-09-16): screenshot-studio → default-apps-editor → appimage-installer → timeshift-guardian → audio-repair → multimedia-codecs → printer-helper → system-report-pack → book-access-doctor.`

   (find with `grep -n "Build order" docs/PROJECT_STATE.md`);
   (b) replace the `## 4. Active Milestone & Current State` section with
   EXACTLY:

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** Module batch #1 (owner-approved 2026-09-16): nine modules — seven features, two fixes — one reviewed PR at a time on the v0.1 core.
- **Current State:** v0.1 core complete; batch #1 in progress — screenshot-studio (flameshot install + Print Screen rebind with recorded-restore undo, shared `lib/elevate.sh` debut) landed via PR for task 007. Build order revised by owner 2026-09-16: screenshot-studio first.
- **Immediate Next Task:** task 008 — module `default-apps-editor` (low / undo:true; xdg-mime defaults with current-vs-new display), second in the owner's revised build order.
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

Each line ends with a checkpoint commit + push (§9):

1. `lib/elevate.sh` (risk check via shared parser; exact-command display;
   sudo execution; no self-confirmation) → commit + push
2. `modules/screenshot-studio/module.yml` + read-only actions
   (describe/plan/dry-run, ≤23-line screens) → commit + push
3. `module.sh` `run` (preflight/install, dconf guard, already-configured
   check, record, rebind, verify) + `undo` → commit + push
4. Harness stages (s)–(y), full suite green → commit + push
5. Tracker edits (build-order revision + §4) → commit + push
6. Final pass: `bash -n` all touched scripts, shellcheck if installed,
   `bin/modulelint` green, `./butler --scan` exit 0, `--list` badge check,
   full harness, §14 smokes, clean tree → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/screenshot-studio` — EXCEPT the §4 fact 11
  substitution if your runner pins you.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/screenshot-studio:refs/remotes/origin/_resume
git checkout -B feature/screenshot-studio refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/screenshot-studio origin/main
```

(Substitute the pinned branch name if §4 fact 11 applies.) Do not commit on
`main`. "couldn't find remote ref" here is not an environment failure.

## 9. WORK PERSISTENCE AND PUSH CADENCE

Checkpoint after each sub-task in §7, before any long or risky operation, and
at the end. Your session can expire without warning; unpushed work is lost.
There is no time-based rule — §7 is your push schedule.

A checkpoint is ONE command:

```bash
git add -A && (git diff --cached --quiet || git commit -qm "chore: wip <sub-task>") && git push -qu origin <target-branch>
```

Conventional Commits is the project convention; `chore: wip <sub-task>` is
the valid checkpoint form.

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
  EVERY expansion — SC2086 fails the gate wherever shellcheck runs.
  Reference style: `modules/desktop-shortcut-creator/module.sh`,
  `lib/ask.sh`.
- Module I/O contract: stdout for humans, stderr for errors; exit 0 success;
  non-zero failure with one plain-language stderr line.
- dconf value handling: treat everything read from the store as opaque
  strings to record and restore; do NOT parse GVariant contents beyond
  substring checks (`contains Print`, `contains flameshot`, `contains the
  slot path`).
- Tests NEVER invoke real sudo/apt-get/dconf and never touch the real
  settings store or HOME: PATH-prefix stubs + fake HOMEs in `mktemp`.
- TEST_COMMAND: `bash tests/run-tests.sh` (stages s–y: gate pass, rebind,
  undo/restore, install-failure, idempotency, dconf-absent, screen height)
- INTEGRATION_TEST_COMMAND: stage (s) — real `./butler --scan` and
  `--list` exercising the real menu/gate with the new elevated module
  present
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — each behavioral branch (install
  skip/fail, already-configured, rebind, verify mismatch path, undo
  with/without state, dconf absence) has a direct harness assertion; no
  bash mutation tooling exists under the zero-dependency constraint
- LINT_COMMAND: `bash -n modules/screenshot-studio/module.sh lib/elevate.sh
  butler lib/*.sh bin/modulelint tests/run-tests.sh` (always) plus
  `shellcheck` on the same set when installed; additionally `bin/modulelint
  screenshot-studio` must exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages (a)–(r); both existing modules;
  menu behavior; `lib/manifest.sh` parsing of `needs: [flameshot]` and
  `asks: 0`.
- The ONLY root operation in this PR is `sudo apt-get install -y flameshot`
  inside `lib/elevate.sh`, reached only when flameshot is missing and only
  after the menu's typed-slug confirmation. All dconf work is user-session.
- No keybindings other than the two recorded paths are ever written.
- Owner-acceptance safety (fact 10): the non-destructive set stays
  non-destructive; tests use stubs only.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- NO other modules, NO flameshot settings beyond the rebind, NO alternative
  screenshot tools, NO GNOME/XFCE keybinding schemas.
- Do NOT modify `butler`, `bin/modulelint`, `lib/ask.sh`, `lib/picker.sh`,
  `lib/desktop-entry.sh`, `lib/manifest.sh`, `lib/menu.sh`, `lib/ui.sh`,
  `lib/confirm.sh`, existing modules, README.md, docs/VISION.md, or
  docs/MODULE_SPEC.md.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

1. `bash tests/run-tests.sh` — exit 0, every stage (a–y) asserts
   successfully.
2. `bin/modulelint screenshot-studio` — exit 0 with PASS.
3. `bin/modulelint` — exit 0.
4. `./butler --scan` — exit 0.
5. `./butler --list` — shows `screenshot-studio: Screenshot studio` with
   the elevated badge; desktop-shortcut-creator still listed.
6. `./butler --run screenshot-studio --dry-run` — exit 0, side-effect-free.
7. `bash -n` clean over all changed/new scripts; shellcheck clean if
   installed (record absence otherwise).
8. Worktree clean, all work pushed, no extra module folders.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: screenshot-studio — flameshot install + Print Screen rebind
with recorded-restore undo`. Description: summary; design rationale (why
elevate holds the only sudo; why a fixed custom-slot path gives idempotency;
why the built-in binding is only cleared when it holds Print; the mixed-undo
honesty; the stub-dconf test strategy and its honest limit — real-schema
behavior is owner-acceptance on Mint); test results per §10 layer with exact
commands and outcomes; safety statement "the only root operation in this PR
is the single visible confirmed 'sudo apt-get install -y flameshot' inside
lib/elevate.sh; every dconf write is recorded before it happens and restored
by undo; all tests run against stub binaries and fake HOMEs"; what the owner
should try on Mint (run via menu → badge + typed confirm → press Print
Screen → Flameshot appears; then `[u]ndo` → old binding restored); breaking
changes (none); migration notes (none). Describe only this PR's own changes.
Include `#### Session Irregularities` per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only (interfered with following this prompt AND
cost >~10 min / blocked progress / required a workaround / reveals a
recurring blind spot). If none significant, write exactly
`None significant`. If significant: Category | Symptom | Impact | Workaround
| Hardening candidate, 3–6 lines total. If you used the branch-substitution
rule (§4 fact 11), one line noting it belongs here. This report does not
affect the MERGE/REVISE verdict unless it reveals a missing deliverable.
