# 005 — seed module: android-file-transfer (+ lib/elevate.sh, completing v0.1)

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/005-android-file-transfer.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "005 — android-file-transfer".

## 1. TASK TITLE AND SCOPE

Ship the second and final v0.1 seed module — `android-file-transfer`
(risk: elevated, undo: false, `needs: [jmtpfs]`) per README's seed paragraph
and MODULE_SPEC §5 — plus the module-side `lib/elevate.sh` helper for the
single confirmed package-install step, harness coverage, and the tracker
update closing the v0.1 milestone. Complete this in ONE pull request.

## 2. REQUIRED READING ORDER

1. `README.md` — the android-file-transfer seed paragraph AND safety-contract
   rule 2 (elevated: says so in the menu, shows the exact command, requires
   explicit confirmation, explains the undo situation honestly).
2. `docs/MODULE_SPEC.md` — §2 (`asks:` budget), §3 (elevated modules use the
   shared `elevate` helper ONLY; question budget; scripted-stdin testability),
   §5 (the gate your module must pass).
3. `modules/desktop-shortcut-creator/module.sh` — the conforming sibling
   module: action structure, EOF refusal, how libs are sourced via
   `MINTBUTLER_LIB_DIR`.
4. `lib/ask.sh`, `lib/desktop-entry.sh` — helper style you follow.
5. `bin/modulelint` — the checks your module must pass, including
   sudo-in-elevated handling (allowed for elevated; advisory only) and
   sandbox execution with stdin `/dev/null`.
6. `lib/manifest.sh` — the manifest subset (`needs: [jmtpfs]` shape).
7. `butler` — the elevated confirmation flow already implemented menu-side
   (plan shown, typed-slug confirm) — your module plugs into it.
8. `tests/run-tests.sh` — the harness pattern and existing stages (a–r).
9. `docs/PROJECT_STATE.md` — the tracker you update.
10. `git log --oneline -5` — Conventional Commits convention (confirm, do not
    copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22. PRs #1–#3
landed the menu, the modulelint gate, and the first seed module. You ship the
second seed and close the v0.1 milestone: Android phones are the owner's
named pain — "sets up and launches MTP file access for Android phones via
the Mint-standard stack, installing the needed package as a visible,
confirmed, elevated step. Undo: not applicable (declared)."

**Owner vision context:** this is the first time the product touches root.
The trust yardstick applies at maximum strength here: the menu already shows
the `⚠ elevated` badge and asks for typed confirmation; the module itself
shows the EXACT command, runs exactly it through the shared elevate helper,
and then verifies and reports what actually happened — no guessing, no
silent failure.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

Treat these as settled:

1. **Mint-standard stack:** `jmtpfs` (FUSE MTP filesystem, in the Mint/Ubuntu
   repos) plus stock coreutils/FUSE user tooling (`fusermount3` ships with
   libfuse2 on Mint 22). Hence `needs: [jmtpfs]`. No other packages, no PPAs,
   no network calls from the module itself.
2. **`lib/elevate.sh` (new, shared):** the ONLY sanctioned path to root, per
   MODULE_SPEC §3. Contract: `elevate_run "<exact command string>"` —
   verifies the module's manifest risk is `elevated` (module passes its slug;
   refuse otherwise), prints the exact command to stdout, then executes
   `sudo <command>` (sudo is the single, visible, confirmed step); returns
   the command's exit code. It never composes commands from user input —
   callers pass reviewed, fixed command strings. EOF/non-TTY on sudo's
   password prompt is handled by sudo itself; elevate must not add its own
   confirmation prompt (the MENU already confirmed — see fact 6).
3. **Manifest (exact values):** `title: Android file transfer`;
   `description: >-` folding: "Sets up and launches MTP file access for
   Android phones via the Mint-standard stack. Installs the jmtpfs package as
   a visible, confirmed elevated step if missing. Undo is not applicable —
   it says so instead of pretending."; `risk: elevated`; `undo: false`;
   `needs: [jmtpfs]`; `asks: 3`; `order: 10` (with desktop-shortcut-creator's
   `order: 20`, the menu matches the README example: Android first).
4. **Actions:** `describe`, `plan`, `dry-run` never prompt, never write,
   never elevate. `plan` prints the plain numbered steps including the exact
   install command shown conditionally ("if jmtpfs is missing: sudo apt-get
   install -y jmtpfs"). `dry-run` prints `plan` plus the exact command list
   with a `<mountpoint>` placeholder, exit 0. Prompts happen ONLY inside
   `run` (the mountpoint question), within the declared budget.
5. **`run` flow:** (a) **preflight** — `command -v jmtpfs`: if present, say
   so and skip install; if MISSING, print the exact command
   `sudo apt-get install -y jmtpfs`, say it needs the single elevated step,
   and run it through `elevate_run`; afterwards re-check presence — if still
   missing, print one plain error line and exit 1; (b) **already-mounted
   check** — if `/proc/mounts` shows a `fuse.jmtpfs` entry, report where it
   is mounted and exit 0 (idempotent); (c) **device check** — probe with
   `jmtpfs -l 2>/dev/null` (or the installed jmtpfs's device listing): if
   the binary errors or lists no devices, print ONE plain line ("No Android
   device detected. Unlock the phone, enable file transfer (MTP/USB), and
   run this task again.") and exit 0 — NOT a failure, nothing changed;
   (d) **mountpoint** — `ask_value "Mountpoint" "$HOME/Android"` (the only
   question; counts the budget), `mkdir -p` it, then `jmtpfs <mountpoint>`;
   (e) **verify** — read `/proc/mounts`; if the mountpoint now carries a
   `fuse.jmtpfs` entry, print the success line with the path and how to
   browse it (file manager or `ls`); if not, print one plain error and exit
   1. No auto-launch of file managers (the owner browses when he chooses —
   nothing he didn't ask for).
6. **No in-module confirmation dialogs:** the menu already shows the plan
   and takes the typed-slug confirmation for elevated modules before
   dispatching `run` (see `butler`). The module must not re-ask "are you
   sure" — it shows the exact command, then acts.
7. **Undo honesty:** `undo: false`; the module's `undo` action prints exactly
   one plain line — "Package installs and mounted sessions are not cleanly
   undoable; this module says so instead of pretending." — and exits 0. Do
   NOT implement unmount-or-remove as undo (unmounting what the owner may be
   using is exactly the kind of surprise the safety contract forbids);
   instead `plan` and the success line mention the manual unmount command
   (`fusermount3 -u <mountpoint>`) as information.
8. **Non-interactive behavior (modulelint compatibility):** modulelint runs
   `run` with stdin `/dev/null`. The preflight/install path is reached first:
   in the sandbox `command -v jmtpfs` fails, and `elevate_run`'s `sudo`
   fails non-interactively — the module must then print one plain stderr
   line and exit 1 WITHOUT mounting anything. That is a passing lint outcome
   per MODULE_SPEC §5.5 and is asserted in the harness. Additionally, to
   make the no-device path deterministically testable, honor
   `MINTBUTLER_TEST_FAKE_NO_DEVICE=1` (skip the device probe, behave as
   "no device detected") — test-only override, production defaults unchanged.
9. **Forbidden-pattern compliance:** `sudo` appears ONLY inside
   `lib/elevate.sh` and only as the fixed install command; the module script
   itself contains no `sudo`/`pkexec` literal (modulelint treats sudo in
   elevated modules as advisory, but keep the module clean anyway). No
   `eval`, no `curl|bash`, no unquoted expansions — the gate SC2086-fails
   when shellcheck is present (lesson from PR #3's revision).
10. **Owner acceptance ruling (2026-09-16, binding):** acceptance commands
    must be non-destructive on a live machine — the safe set is
    `./butler --list` (shows the `⚠ elevated` badge line), `./butler --scan`,
    `./butler --run android-file-transfer --dry-run`, and plain menu
    navigation. Actually running the module on the owner's machine requires
    a connected phone and (if jmtpfs is missing) a real package install —
    permitted for acceptance because it is badged, planned, and confirmed
    via typed slug, but your tests must never require it and never touch a
    real system.
11. **Branch-pinning rule (hardened from task 001):** if your runner pins
    your session to a branch and forbids creating another, use the pinned
    branch as the target (base stays `main`), substitute its name in §8/§9,
    and record it under `#### Session Irregularities`. Never push to
    `arena/01a0abf2-mintbutler`.

**Scope boundaries:** do NOT modify `butler`, `bin/modulelint`, or any
existing `lib/` file except creating `lib/elevate.sh`; do NOT touch the
desktop-shortcut-creator module; NO MTP auto-launch, NO file-manager
integration, NO transfer logic (the file manager is the transfer UI — the
module just opens the door); NO CI, NO dependencies beyond `needs: [jmtpfs]`,
NO network calls in code.

**Expected-absent at delivery:** no third module folder under `modules/`. If
one exists, HALT and report.

## 5. CORE OBJECTIVE

`modules/android-file-transfer/` passes `bin/modulelint`; the menu shows it
FIRST with the `⚠ elevated` badge (order 10 vs 20); the elevated path is the
single visible confirmed `apt-get install -y jmtpfs` via `lib/elevate.sh`;
device-absence and already-mounted are plain-language, non-failure outcomes;
undo is honest; the harness proves the testable paths against fake state;
the tracker closes the v0.1 milestone.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exits 0 including new stages; `bin/modulelint` exits 0 over both real
modules; `./butler --scan` exits 0; `./butler --list` shows
`android-file-transfer` first with the elevated badge; `bash -n` clean;
shellcheck clean if installed; worktree clean; everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `lib/elevate.sh` — per §4 fact 2.
2. `modules/android-file-transfer/module.yml` — per §4 fact 3.
3. `modules/android-file-transfer/module.sh` — executable (git mode 755),
   per §4 facts 4–9.

Modify:

4. `tests/run-tests.sh` — keep stages (a)–(r) passing; add (all runs with
   the module script invoked directly, controlled environment, never a real
   package install and never a real mount):
   - (s) `./butler --scan` exit 0; `bin/modulelint` exit 0 with
     `PASS android-file-transfer`; `./butler --list` first module line is
     `android-file-transfer` and contains the elevated badge text;
   - (t) `describe`/`plan`/`dry-run` (stdin `/dev/null`): exit 0, non-empty,
     plan contains the exact string `sudo apt-get install -y jmtpfs`, dry-run
     contains `jmtpfs <mountpoint>`;
   - (u) non-interactive `run` with `PATH` stripped of jmtpfs (it isn't in
     the sandbox): exits 1, stderr contains a plain single line about the
     failed elevated step, NOTHING mounted or written (assert no new paths
     under a fake `HOME`);
   - (v) no-device path: `PATH` prefix containing stub `jmtpfs` and
     `fusermount3` executables (a `mktemp/bin` dir; the jmtpfs stub: `-l` →
     print nothing + exit 0, mount attempts → exit 1; the fusermount3 stub
     exits 0) plus `MINTBUTLER_TEST_FAKE_NO_DEVICE=1`, stdin providing the
     mountpoint answer: exits 0, output contains "No Android device
     detected", fake HOME unchanged except no mountpoint dir created before
     the device check (assert the module asked nothing and wrote nothing);
   - (w) already-mounted path: fake `/proc/mounts` is not overridable — so
     stage this path by pointing the module at a test override ONLY if you
     implement the mounts read through a `MINTBUTLER_TEST_MOUNTS_FILE`
     variable (production default `/proc/mounts` when unset): with the fake
     file containing a `fuse.jmtpfs` line, `run` exits 0 printing the
     already-mounted report and performs no other action;
   - (x) `undo`: prints the honest not-undoable line and exits 0;
   - (y) 23-line law: the module's plan/dry-run output screens are ≤ 23
     lines each (captured output assertion).
5. `docs/PROJECT_STATE.md` — replace its `## 4. Active Milestone & Current
   State` section with EXACTLY:

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** v0.1 complete — menu script, module discovery, modulelint gate, and both seed modules landed.
- **Current State:** core menu (PR #1), `bin/modulelint` gate (PR #2), desktop-shortcut-creator v1 (PR #3), and android-file-transfer (PR for task 005) merged; v0.1 ready for owner acceptance on Mint 22.2.
- **Immediate Next Task:** owner acceptance of v0.1 on Mint 22.2; v0.2 backlog (menu categories, favorites) and the owner's chore backlog start afterwards.
```

   and append one bullet to its `## 3. Settled Decisions & Rationale` list:

```markdown
- The elevated path is a single visible confirmed step through shared `lib/elevate.sh` (fixed command strings only, never composed from input); android-file-transfer declares `undo: false` honestly instead of pretending (owner's seed spec + safety contract rule 2, 2026-09-16).
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

Each line ends with a checkpoint commit + push (§9):

1. `lib/elevate.sh` (elevate_run; risk check; exact-command display; sudo
   execution; no self-confirmation) → commit + push
2. `modules/android-file-transfer/module.yml` + read-only actions
   (describe/plan/dry-run) → commit + push
3. `module.sh` `run` (preflight/install, already-mounted, device check,
   mountpoint ask + mount, verify) + honest `undo` → commit + push
4. Harness stages (s)–(y), full suite green → commit + push
5. Tracker update per §6 → commit + push
6. Final pass: `bash -n` all touched scripts, shellcheck if installed,
   `bin/modulelint` green over both modules, `./butler --scan` exit 0,
   `--list` badge/order check, full harness, §14 smokes, clean tree →
   commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/android-file-transfer` — EXCEPT the §4 fact 11
  substitution if your runner pins you to a session branch.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only, never
  a base or target.
- Dependencies: none (PRs #1–#3 are merged).
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/android-file-transfer:refs/remotes/origin/_resume
git checkout -B feature/android-file-transfer refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/android-file-transfer origin/main
```

(Substitute the pinned branch name per §4 fact 11 if applicable.) Do not
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
  EVERY expansion — the gate SC2086-fails unquoted expansions wherever
  shellcheck runs (PR #3 went through revision for exactly this). Reference
  style: `modules/desktop-shortcut-creator/module.sh`, `lib/ask.sh`.
- Module I/O contract: stdout for humans, stderr for errors; exit 0 success;
  non-zero failure with one plain-language stderr line.
- Zero runtime dependencies beyond `needs: [jmtpfs]`; `fusermount3`
  referenced only as information text. All tool absence handled with plain
  one-line messages.
- Tests NEVER run a real `apt-get`, never invoke real `sudo`, never mount
  anything: stages use PATH-prefix stub binaries and fake HOMEs in `mktemp`.
- TEST_COMMAND: `bash tests/run-tests.sh` (stages s–y cover the gate pass,
  read-only actions, elevated-refusal path, no-device path, already-mounted
  path, honest undo, screen height)
- INTEGRATION_TEST_COMMAND: stage (s) — real `./butler --scan` and
  `./butler --list` exercising the real menu/gate with BOTH seed modules
  present (menu order + elevated badge asserted)
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — each behavioral branch (jmtpfs
  missing, install failure, already-mounted, no-device, mount success/failure
  via stubs, honest undo) has a direct harness assertion; no bash mutation
  tooling exists under the zero-dependency constraint
- LINT_COMMAND: `bash -n modules/android-file-transfer/module.sh
  lib/elevate.sh butler lib/*.sh bin/modulelint tests/run-tests.sh` (always)
  plus `shellcheck` on the same set when installed; additionally
  `bin/modulelint android-file-transfer` must exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages (a)–(r); both existing modules;
  menu behavior (your module simply appears first with the badge);
  `lib/manifest.sh` parsing of `needs: [jmtpfs]` (already supported shape).
- The ONLY root operation in this entire PR is `sudo apt-get install -y
  jmtpfs` inside `lib/elevate.sh`, reached only when jmtpfs is missing and
  only after the menu's typed-slug confirmation. Everything else is
  user-level.
- No mounts, no packages, no writes in tests — stubs and fake HOMEs only.
- Owner-acceptance safety (fact 10): the non-destructive command set must
  stay non-destructive; the real elevated run is acceptance-legal only
  because it is badged, planned, and confirmed.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- NO third module, NO transfer/backup logic, NO file-manager launching, NO
  device pairing settings changes, NO udev rules.
- Do NOT modify `butler`, `bin/modulelint`, or any existing lib/module file.
- Do NOT modify `docs/MODULE_SPEC.md` or `README.md` — if you believe one is
  wrong, say so in the PR description.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Artifacts: if this task produces a build artifact, do not commit it
  anywhere; write its path and sha256 into the PR description and stop.
  Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

Before opening the PR, all of these must pass:

1. `bash tests/run-tests.sh` — exit 0, every stage (a–y) asserts
   successfully.
2. `bin/modulelint android-file-transfer` — exit 0 with `PASS`.
3. `bin/modulelint` — exit 0 (both seed modules pass).
4. `./butler --scan` — exit 0.
5. `./butler --list` — FIRST line is
   `android-file-transfer: Android file transfer` with the elevated badge;
   desktop-shortcut-creator second.
6. `./butler --run android-file-transfer --dry-run` — exit 0, prints the
   plan with the exact install command and `<mountpoint>` placeholder
   (this is an owner-acceptance command — confirm it is side-effect-free).
7. `bash -n` over all changed/new scripts — clean; shellcheck clean if
   installed (record absence otherwise).
8. Worktree clean, all work pushed, no extra module folders.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: android-file-transfer seed module — completes v0.1`. The
description must contain: a summary; design rationale (why jmtpfs is the
Mint-standard choice; why elevate holds the only sudo; why undo is declared
false instead of implemented; how no-device/already-mounted stay
plain-language non-failures; the stub-based test strategy that never touches
a real system); test results per §10 layer with exact commands and outcomes;
the safety statement "the only root operation in this PR is the single
visible confirmed 'sudo apt-get install -y jmtpfs' inside lib/elevate.sh;
all tests run against stub binaries and fake HOMEs; every owner-acceptance
command except the confirmed elevated run is non-destructive"; what the
owner should try on Mint (connect + unlock phone, run via menu, expect the
badge + typed confirmation + mountpoint question; browse the mount; manual
`fusermount3 -u` when done); breaking changes (none); migration notes
(none). Describe only this PR's own changes. Include
`#### Session Irregularities` per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only: something that interfered with following
this prompt AND cost >~10 min, blocked progress, required a
workaround/deviation, or reveals a hidden repo/session invariant or prompt
blind spot that would recur for the next worker. If none significant, write
exactly `None significant` — that satisfies this section. If significant, one
row per irregularity: Category (Environment/Prompt/Repository/Tooling) |
Symptom (1 sentence) | Impact | Workaround | Hardening candidate (optional),
3–6 lines total. If you used the branch-substitution rule (§4 fact 11), one
line noting it belongs here. Do not pad with trivial single retries or
expected platform behavior. This report does not affect the MERGE/REVISE
verdict unless it reveals a missing deliverable.
