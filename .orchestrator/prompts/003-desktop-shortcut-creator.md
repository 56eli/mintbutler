# 003 — seed module: desktop-shortcut-creator (+ module-side ask helper)

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/003-desktop-shortcut-creator.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "003 — desktop-shortcut-creator".

## 1. TASK TITLE AND SCOPE

Ship the first real module — `desktop-shortcut-creator` (risk: low,
undo: true) per MODULE_SPEC §6 — plus the module-side `lib/ask.sh` helper it
introduces, harness stages proving its behavior and that it passes the
modulelint gate, and the tracker update. Complete this in ONE pull request.

## 2. REQUIRED READING ORDER

1. `docs/MODULE_SPEC.md` — §3 (script contract), §6 (the worked example for
   THIS module — follow it), §5 (the gate your module must pass).
2. `README.md` — the seed-module paragraph for desktop-shortcut-creator and
   the safety contract.
3. `bin/modulelint` — the checks your module must pass (manifest, syntax,
   forbidden patterns, sandbox execution with stdin `/dev/null`).
4. `lib/manifest.sh` — the manifest subset (`>-` description etc.).
5. `butler` — dispatch contract (env vars, CWD, action invocation) and the
   selection flow your module plugs into.
6. `tests/run-tests.sh` + `tests/fixtures/modules/alpha-fixture/` — harness
   pattern and a conforming module example.
7. `docs/PROJECT_STATE.md` — tracker you update (§6 deliverable).
8. `git log --oneline -5` — Conventional Commits convention (confirm, do not
   copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22: the
`butler` menu (PR #1) dispatches drop-in modules, and `bin/modulelint` (PR #2)
is the mechanical gate. You are shipping the FIRST real module: on the
owner's Mint machine, creating a desktop shortcut is a ritual — this module
writes a validated `.desktop` entry, sets the executable bit and the trusted
flag the right way (user session, never sudo), and offers a desktop copy.
Undo deletes exactly the files the module wrote.

**Owner vision context:** "I press a number, the thing just works, and
nothing I didn't ask for happened." Before anything runs, the owner reads a
plain plan; the module asks only for what only he knows (app name, command,
icon), and every write is recorded for undo.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

Treat these as settled:

1. **Manifest** (exact values): `title: Desktop shortcut creator`,
   `description: >-` folding the two spec §6 sentences ("Creates a validated
   application menu entry and optional desktop icon, trusted the right way
   (user session, no sudo)."), `risk: low`, `undo: true`, `needs: []`,
   `order: 20`. `desktop-file-utils` and `glib` (`gio`) ship with a fresh
   Mint 22 install, hence `needs: []`.
2. **`ask` helper (new, `lib/ask.sh`):** module-facing, sourced via
   `"${MINTBUTLER_LIB_DIR}/ask.sh"`. Provides `ask_value <prompt> [default]`
   (prints `prompt: ` to **stderr**, reads one line from stdin, trims it,
   prints the value to stdout; on EOF returns 1 printing nothing; empty input
   with a default returns the default) and `ask_yn <prompt>` (y/yes → 0,
   anything else or EOF → 1; `[y/N]` suffix). It must never hang and never
   read more than one line per call.
3. **Actions:** `describe`, `plan`, `dry-run` must never prompt and never
   write. Prompts happen ONLY inside `run`: first the value phase
   (`ask_value` for Name — required; Command — required; Icon path —
   optional, empty means none), then ONE `ask_yn` "place a copy on the
   desktop?". That is the module's allowed questioning, exactly as §6
   describes it.
4. **`run` flow:** ask values → derive entry filename by sanitizing the Name
   (`[a-z0-9]` kept, other runs → single `-`, trimmed, lowercased; abort with
   a plain stderr line if empty) → target
   `$HOME/.local/share/applications/<sanitized>.desktop` → if it exists with
   identical content: report already-created and exit 0 (idempotent); if it
   exists with different content: abort with a plain stderr line telling the
   user to undo first, exit 1 → write the entry, record paths, then (only if
   the desktop copy was accepted) copy to `$HOME/Desktop/<sanitized>.desktop`,
   `chmod +x` that copy, and `gio set <copy> metadata::trusted true` in the
   user session — NEVER sudo.
5. **`.desktop` content:** `[Desktop Entry]`, `Type=Application`, `Name=`,
   `Exec=`, `Icon=` only when given, `Comment=Created by mintbutler
   desktop-shortcut-creator`. Validate with `desktop-file-validate` WHEN
   INSTALLED; if it fails validation, abort BEFORE recording anything and
   show the validator's output. If the binary is absent, print an advisory
   line and continue.
6. **Tool absence honesty:** if `gio` is absent when a desktop copy was
   requested, still copy and `chmod +x`, but print a plain advisory that the
   trusted flag could not be set and Cinnamon may ask until it is trusted
   manually. Never fail the whole run over an optional enhancement.
7. **State record:** after a successful write, append the absolute path of
   every file created to
   `$HOME/.local/state/mintbutler/desktop-shortcut-creator/<sanitized>.paths`
   (one path per line; create parent dirs). This file itself is module state,
   not a created artifact — undo removes it last.
8. **`undo`:** read every `*.paths` under the state dir; for each recorded
   path that still exists, delete it; then delete the state files. Missing
   state → print "Nothing to undo." and exit 0. Only touch recorded paths —
   never glob user directories. Undo needs no prompts.
9. **No desktop-environment restarts or cache pokes.** Do NOT run `nemo -q`,
   `killall`, cache rebuilds, or any refresh command: the Cinnamon applet
   picks new entries up itself, and the safety contract forbids side effects
   the owner didn't ask for. Say in `plan` that the menu/desktop picks the
   entry up automatically.
10. **Non-interactive behavior (modulelint compatibility):** `bin/modulelint`
    executes `run` with stdin `/dev/null`. The first `ask_value` hits EOF,
    and `run` must then print one plain stderr line (e.g. "This module needs
    interactive input; start it from the butler menu.") and exit 1 WITHOUT
    writing anything. This is a passing lint outcome per MODULE_SPEC §5.5 and
    is asserted in the harness.
11. **`dry-run`:** print the plan plus the exact command sequence with
    `<app name>` / `<command>` / `<icon>` placeholders, exit 0, write nothing
    (asserted by modulelint's sandbox diff and by the harness).
12. **Owner acceptance ruling (2026-09-16, binding):** acceptance commands
    must be non-destructive on a live machine — the safe set is
    `./butler --list`, `./butler --scan`, `./butler --run
    desktop-shortcut-creator --dry-run`, and plain menu navigation.
    Interactive `run` on the owner's machine is a real chore execution:
    permitted for acceptance because it is confirmed, planned, and undoable —
    but your tests must never require it.
13. **Branch-pinning rule (hardened from task 001):** if your runner pins
    your session to a branch and forbids creating another, use the pinned
    branch as the target (base stays `main`), substitute its name in §8/§9,
    and record it under `#### Session Irregularities`. Never push to
    `arena/01a0abf2-mintbutler`.

**Scope boundaries:** no second seed module (`android-file-transfer` is task
004), no changes to `butler`, `lib/manifest.sh`, `lib/menu.sh`, `lib/ui.sh`,
`lib/confirm.sh`, or `bin/modulelint` (report defects instead of fixing), no
CI, no dependencies, no sudo/pkexec anywhere, no network.

**Expected-absent at delivery:** `modules/android-file-transfer`. If it
exists, HALT and report.

## 5. CORE OBJECTIVE

`modules/desktop-shortcut-creator/` passes `bin/modulelint`, appears in the
`butler` menu as a normal low-risk undoable entry, and behaves per §4 in both
interactive and non-interactive contexts; `lib/ask.sh` is the reusable
module-side question helper; the harness proves all of it; the tracker names
task 004 next.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exits 0 including the new stages; `bin/modulelint` exits 0 on the real
module; `./butler --scan` exits 0; `bash -n` clean everywhere; shellcheck
clean if installed; worktree clean; everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `modules/desktop-shortcut-creator/module.yml` — per §4 fact 1.
2. `modules/desktop-shortcut-creator/module.sh` — executable (git mode 755),
   per §4 facts 3–11.
3. `lib/ask.sh` — per §4 fact 2.

Modify:

4. `tests/run-tests.sh` — add stages running against a fake `HOME`
   (`mktemp -d`), invoking the REAL module script directly with piped stdin:
   - (k) `./butler --scan` in the real repo exits 0 and its output contains
     `PASS desktop-shortcut-creator`;
   - (l) non-interactive `run` (stdin `/dev/null`, fake HOME): exits 1,
     stderr contains "interactive", fake HOME unchanged (`diff -r`);
   - (m) simulated interactive run:
     `printf 'Test App\n/usr/bin/true\n\nn\n' | HOME=<fake> bash module.sh run`
     exits 0; the fake HOME gains
     `.local/share/applications/test-app.desktop` containing `Name=Test App`
     and `Exec=/usr/bin/true`; the state dir contains `test-app.paths`
     listing exactly that path; re-running the same input exits 0 printing an
     already-created message and changes nothing (byte-diff before/after);
   - (n) desktop-copy variant:
     `printf 'Copy App\n/usr/bin/true\n\ny\n' | HOME=<fake2> … run` exits 0;
     `<fake2>/Desktop/copy-app.desktop` exists and is executable; its path is
     recorded in `copy-app.paths`;
   - (o) undo after (m) or (n): `HOME=<same fake> bash module.sh undo` exits
     0, deletes every recorded file and the state file; a second undo exits 0
     printing "Nothing to undo.";
   - (p) `plan` and `dry-run` with stdin `/dev/null` exit 0 with non-empty
     output and leave the fake HOME unchanged.
   (If `desktop-file-validate` or `gio` exist in the environment, the module
   exercises them; if not, the advisories are expected — assert only the
   filesystem outcomes above, not tool presence.)
5. `docs/PROJECT_STATE.md` — replace its `## 4. Active Milestone & Current
   State` section with EXACTLY:

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** v0.1 — menu script + module discovery + modulelint + the two seed modules.
- **Current State:** core menu (PR #1, merged 2026-09-16) and `bin/modulelint` gate (PR #2, merged 2026-09-16) landed; seed module `desktop-shortcut-creator` landed via PR for task 003.
- **Immediate Next Task:** task 004 — seed module `android-file-transfer` (risk: elevated, undo: false).
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

Each line ends with a checkpoint commit + push (§9):

1. `lib/ask.sh` (ask_value, ask_yn; EOF-safe, single-line reads) → commit +
   push
2. `modules/desktop-shortcut-creator/module.yml` + `module.sh` read-only
   actions (`describe`, `plan`, `dry-run`) → commit + push
3. `module.sh` `run` (value phase, validation, write, record, desktop copy +
   trust, idempotency) and `undo` → commit + push
4. Harness stages (k)–(p), full suite green → commit + push
5. Tracker update per §6 → commit + push
6. Final pass: `bash -n` everything, shellcheck if installed,
   `bin/modulelint` green, `./butler --scan` exit 0, full harness, §14
   smokes, clean tree → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/desktop-shortcut-creator` — EXCEPT the §4 fact 13
  substitution if your runner pins you to a session branch.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only, never
  a base or target.
- Dependencies: none (PRs #1 and #2 are merged).
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/desktop-shortcut-creator:refs/remotes/origin/_resume
git checkout -B feature/desktop-shortcut-creator refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/desktop-shortcut-creator origin/main
```

(Substitute the pinned branch name per §4 fact 13 if applicable.) Do not
skip the fetch because you appear to be on the target. Do not commit on
`main`. "couldn't find remote ref" here is not an environment failure.

## 9. WORK PERSISTENCE AND PUSH CADENCE

Checkpoint after each sub-task in §7, before any long or risky operation, and
at the end. Your session can expire without warning; unpushed work is lost.
There is no time-based rule — §7 is your push schedule.

A checkpoint is ONE command — first push, later pushes, and the
nothing-to-push no-op are all the same form. Do not run status/diff
inspections around it:

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
`--force-with-lease`. On merge conflict: halt and report the conflicting
files. Same for a sync that refuses with "refusing to merge unrelated
histories" — never pass `--allow-unrelated-histories`.

If a push or fetch fails with an authentication or network error, report it
plainly and keep working locally; retry the push at the next checkpoint.
Never claim work is pushed while a push has failed, and never modify
credentials, remotes, or git config to work around it. If GitHub auth fails
with HTTP 401/403 "Bad credentials", ask the operator via `ask_user` with an
option reading exactly `I reconnected GitHub — retry now`; do not improvise
credentials.

If the push is rejected non-fast-forward, halt and report the raw rejection.
That is a base mismatch, not an environment failure. Do not `git pull`. Do
not force-push. Already-pushed checkpoints on the remote are safe; a later
agent will resume from them.

## 10. TECHNICAL REQUIREMENTS

- Language: bash 5.x, `#!/usr/bin/env bash`, `set -euo pipefail`, quote
  every expansion — your module is scanned by modulelint, and SC2086 fails
  the gate wherever shellcheck runs. Reference style:
  `tests/fixtures/modules/alpha-fixture/module.sh` plus `lib/confirm.sh`.
- Module I/O contract: stdout for humans, stderr for errors; exit 0 success;
  non-zero failure with one plain-language stderr line.
- Zero dependencies: `desktop-file-validate` and `gio` are USED WHEN PRESENT
  with advisory degradation (§4 facts 5–6). No `sudo`/`pkexec` — the trust
  flag is a per-user gvfs metadata operation (`gio set … metadata::trusted
  true`) in the user session.
- All module writes stay under `$HOME` (`.local/share/applications`,
  `Desktop`, `.local/state/mintbutler/<slug>/`).
- TEST_COMMAND: `bash tests/run-tests.sh` (stages k–p cover the new module:
  gate pass, non-interactive refusal, simulated interactive run, desktop
  copy, undo, idempotency, read-only actions)
- INTEGRATION_TEST_COMMAND: stage (k) — the real `./butler --scan` executing
  the real `bin/modulelint` against the real module (crosses the
  menu→validator→module boundary end-to-end)
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — each behavioral branch (idempotent
  hit, conflicting-file abort, EOF refusal, desktop-copy yes/no, undo
  with/without state) has a direct harness assertion; no bash mutation
  tooling exists under the zero-dependency constraint
- LINT_COMMAND: `bash -n modules/desktop-shortcut-creator/module.sh
  lib/ask.sh butler lib/*.sh bin/modulelint tests/run-tests.sh` (always)
  plus `shellcheck` on the same set when installed; additionally
  `bin/modulelint desktop-shortcut-creator` must exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages (a)–(j); `butler` menu behavior for
  a newly discovered module (numbers are positions — your module simply
  appears); modulelint behavior.
- The module writes ONLY the files it announces in `plan`, records each one,
  and `undo` removes exactly the recorded set. No cache rebuilds, no process
  kills, no environment edits beyond the module's own execution (§4 fact 9).
- Never `sudo`; the trusted flag is set per-user via `gio` (§4 fact 4).
- Owner-acceptance safety (§4 fact 12): every assertion in your tests runs
  against fake `HOME` directories in `mktemp`; the module is never pointed
  at the real HOME by the harness.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- Do NOT create `modules/android-file-transfer` (expected-absent; task 004).
- Do NOT modify `butler`, `bin/modulelint`, `lib/ui.sh`, `lib/menu.sh`,
  `lib/manifest.sh`, `lib/confirm.sh`, README.md, docs/VISION.md, or
  docs/MODULE_SPEC.md.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT add GUI steps, daemons, telemetry, or auto-refresh hacks.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Artifacts: if this task produces a build artifact, do not commit it
  anywhere; write its path and sha256 into the PR description and stop.
  Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

Before opening the PR, all of these must pass:

1. `bash tests/run-tests.sh` — exit 0, every stage asserts successfully.
2. `bin/modulelint desktop-shortcut-creator` — exit 0 with `PASS`.
3. `bin/modulelint` — exit 0 (all real modules pass).
4. `./butler --scan` — exit 0.
5. `./butler --list` — shows `desktop-shortcut-creator: Desktop shortcut
   creator`.
6. `printf 'q\n' | ./butler` — exit 0 (menu still quits cleanly with a real
   module present).
7. `bash -n` over all changed/new scripts — clean; shellcheck clean if
   installed (record absence otherwise).
8. Worktree clean, all work pushed, `modules/android-file-transfer` absent.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: desktop-shortcut-creator seed module`. The description must
contain: a summary; design rationale (why prompts live only in `run`; how
undo uses the recorded path list; how non-interactive refusal keeps the gate
green; the tool-absence degradation policy); test results per §10 layer with
exact commands and outcomes; the safety statement "this module writes only
under $HOME, never uses sudo, records every file it creates, and undo removes
exactly that recorded set; all harness assertions run against fake HOME
directories"; what the owner should try on Mint (interactive run via the
menu, then `[u]ndo`); breaking changes (none); migration notes (none).
Describe only this PR's own changes. Include `#### Session Irregularities`
per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only: something that interfered with following
this prompt AND cost >~10 min, blocked progress, required a
workaround/deviation, or reveals a hidden repo/session invariant or prompt
blind spot that would recur for the next worker. If none significant, write
exactly `None significant` — that satisfies this section. If significant, one
row per irregularity: Category (Environment/Prompt/Repository/Tooling) |
Symptom (1 sentence) | Impact | Workaround | Hardening candidate (optional),
3–6 lines total. If you used the branch-substitution rule (§4 fact 13), one
line noting it belongs here. Do not pad with trivial single retries or
expected platform behavior. This report does not affect the MERGE/REVISE
verdict unless it reveals a missing deliverable.
