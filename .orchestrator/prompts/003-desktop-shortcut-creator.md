# 003 — desktop-shortcut-creator v1: two entry modes, shared entry/picker libs, spec amendments

> AMENDED 2026-09-16 before dispatch (no agent has fetched this file).
> Amendment 1 folded two owner rulings (free-text icon field; `-N` versioning
> on name conflict). Amendment 2 — THIS version — folds the owner's v1
> rulings: the MODULE_SPEC §3 question-budget amendment, two entry modes
> (Scan & place default + Custom), the 23-line screen law, shared
> `lib/desktop-entry.sh` and `lib/picker.sh`, Exec-quoting validation,
> transparency close-out with test-launch offer, and the system-entry
> shadow warning.

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
file is empty or its title does not match "003 — desktop-shortcut-creator v1".

## 1. TASK TITLE AND SCOPE

Ship desktop-shortcut-creator **v1**: a module with two entry modes —
Scan & place (default: pick from installed apps, one confirmation, trusted
desktop copies) and Custom (guided creation of app/folder/URL launchers) —
plus the shared libraries they run on (`lib/desktop-entry.sh`,
`lib/picker.sh`, `lib/ask.sh`), the 23-line screen law with menu
pagination, the owner-approved MODULE_SPEC amendments, harness coverage, and
the tracker update. Complete this in ONE pull request.

## 2. REQUIRED READING ORDER

1. `docs/MODULE_SPEC.md` — §2 (manifest), §3 (script contract — you AMEND
   this section per §6), §4 (menu behavior — you AMEND this section too),
   §5 (the gate), §6 (the original worked example for this module).
2. `README.md` — safety contract and the seed-module paragraph.
3. `docs/VISION.md` — the yardstick: "I press a number, the thing just
   works, and nothing I didn't ask for happened."
4. `bin/modulelint` — every check your module must pass (sandbox execution
   with stdin `/dev/null` included).
5. `lib/manifest.sh` — the manifest subset parser you extend with `asks`.
6. `butler` — menu loop, `menu_render`, dispatch contract; you add
   pagination here.
7. `lib/menu.sh`, `lib/ui.sh`, `lib/confirm.sh` — rendering and helpers you
   build on.
8. `tests/run-tests.sh` + `tests/fixtures/modules/` — the harness pattern and
   conforming module examples.
9. `docs/PROJECT_STATE.md` — the tracker you update (§6).
10. `git log --oneline -5` — Conventional Commits convention (confirm, do not
    copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22: the
`butler` menu (PR #1) dispatches drop-in modules; `bin/modulelint` (PR #2) is
the mechanical gate. You ship the FIRST real module — desktop shortcut
creation, the owner's named daily pain — at v1 scope decided by the owner:
either pluck existing installed apps onto the desktop in one confirmed batch,
or hand-build an app/folder/URL launcher through a guided, plain-language
question sequence. Everything shares one write→validate→trust→record core so
later modules (e.g. a future appimage-installer) reuse it.

**Owner vision context:** "instant … understandable … reversible, or honest."
Every screen fits on one terminal view (23-line law); before anything runs
the owner reads exactly what will happen; every created file is recorded and
undo removes exactly the recorded set.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

Treat these as settled — owner rulings, do not re-litigate:

1. **Spec amendment procedure (owner ruling 2026-09-16):** "docs never drift
   from reality." This PR amends `docs/MODULE_SPEC.md` §2, §3, and §4 with
   EXACTLY the texts in §6 — no other spec edits.
2. **Question budget (new spec law, §3 amendment):** a module may ask a
   short, BOUNDED series of questions, each collecting a value only the user
   knows; the budget is declared in the manifest as `asks: <n>`; optional
   values accept Enter to skip; every safety confirmation (risk badge,
   run/undo, elevated) stays with the menu, never inside the module; question
   flows must be testable non-interactively via scripted stdin. This module
   declares `asks: 9` (worst-case Custom path: type, target, name, icon,
   terminal?, workdir?, desktop copy?, test-launch? plus one re-ask margin).
3. **23-line law (new spec law, §4 amendment, enforced in the suite):** "No
   menu or submenu screen may exceed 23 terminal lines — ever." Applies to
   EVERY screen this product renders: butler's top menu, the module's
   scan-picker pages, confirmations, close-outs. Mechanical check: captured
   render output of every screen ≤ 23 lines, asserted in the harness.
   Pagination pattern: entries page + one header + one footer
   (`n next / p prev / numbers / s search / q done` — adapt pronouns to the
   screen's semantics, keep the shape).
4. **`lib/picker.sh` (new, shared):** paginated number picker used by BOTH
   the butler top-level menu and the module's scan picker (and later the
   appimage-installer's file picker). Provides single-select and multi-select
   over an arbitrary entry list with owner-decided footer keys: numbers to
   select, `n` next page, `p` previous page, `s` (or `/`) search filter,
   `q` quit/done, and for multi-select `d` to confirm the selection. Page
   size computed so header + entries + footer ≤ 23 lines. Non-interactive
   stdin (EOF) → return failure, never hang. Sourced via
   `"${MINTBUTLER_LIB_DIR}/picker.sh"` by modules and by `butler` directly.
5. **`lib/desktop-entry.sh` (new, shared core):** the
   write→validate→trust→record core: builds the `.desktop` content, applies
   versioned filenames (§4 fact 9), validates (§4 fact 10), writes to
   `$HOME/.local/share/applications/`, optionally copies to `$HOME/Desktop/`
   with `chmod +x` and `gio set <copy> metadata::trusted true` in the user
   session (NEVER sudo; `gio`-absent advisory per fact 11), records every
   created path in the per-module state dir, and provides the matching
   undo-from-records operation. No desktop-environment restarts or cache
   pokes — Cinnamon picks entries up itself; `plan` says so.
6. **`lib/ask.sh` (new):** module-facing, sourced via
   `"${MINTBUTLER_LIB_DIR}/ask.sh"`. `ask_value <prompt> [default]` prints
   `prompt: ` to stderr, reads ONE line from stdin, trims it, prints the
   value to stdout; EOF → return 1 printing nothing; empty input with a
   default → print the default. `ask_yn <prompt>` appends `[y/N]`; y/yes →
   0, anything else or EOF → 1. Never hangs, never reads more than one line
   per call.
7. **Module manifest (exact values):** `title: Desktop shortcut creator`;
   `description: >-` folding: "Creates desktop shortcuts two ways: pick
   installed apps and place trusted desktop copies, or build a custom
   app/folder/URL launcher — validated, undoable, never sudo."; `risk: low`;
   `undo: true`; `needs: []`; `asks: 9`; `order: 20`.
8. **Two entry modes.** `run` asks ONE mode question first: "1) Scan & place
   (pick from installed apps)  2) Create a custom shortcut", default 1 on
   Enter.
   - **Scan & place (default):** scan `$HOME/.local/share/applications` and
     `/usr/share/applications` (parse each `.desktop`'s `Name=` with the
     filename slug as fallback; on duplicate name prefer the user-dir copy;
     skip unparseable files silently in the listing) → multi-select picker
     (§4 fact 4; footer: numbers toggle, `d` place, `q` back) → ONE
     confirmation screen listing exactly what will be created (≤ 23 lines,
     paginate the list if longer: "…and N more") → for each chosen app, copy
     its entry content verbatim to
     `$HOME/Desktop/<sanitized-name>.desktop` (versioned per fact 9),
     `chmod +x`, trust via `gio`, record. Copied verbatim entries are NOT
     revalidated with the refuse path (they already work in the system menu);
     if `desktop-file-validate` exists, show its findings as advisories only.
   - **Custom:** guided sequence with plain descriptions — entry type
     (app/folder/URL, default app); target (command / folder path / URL —
     REQUIRED, describe what's expected per type); name (required); icon
     (optional: file path OR theme icon name, Enter=skip; path containing
     `/` that does not exist → one advisory line, continue); for apps only:
     run-in-terminal? (`Terminal=true`, Enter=no) and working directory
     (`Path=`, Enter=skip); desktop copy? (default No).
9. **Filenames & versioning (owner ruling):** sanitize Name (`[a-z0-9]`
   kept, other runs → single `-`, lowercased; empty → abort with plain
   stderr line). Target
   `$HOME/.local/share/applications/<sanitized>.desktop` (Custom mode) or
   `$HOME/Desktop/<sanitized>.desktop` (Scan & place creates desktop copies
   only; nothing is added to the app menu in Scan mode). Identical content
   already there → report already-done, exit 0 for that entry (idempotent);
   DIFFERENT content → create `<sanitized>-2`, `-3`, … alongside, never
   overwrite, and say plainly which version was created and that the
   existing file was kept.
10. **Exec-quoting validation — refuse with reason, never silent breakage
    (owner ruling):** for CUSTOM entries, before recording anything: (a)
    `desktop-file-validate` (when installed) must pass — on failure show the
    validator output and abort the entry; (b) the Exec value must satisfy the
    desktop-entry quoting rule — if it contains whitespace and is not quoted
    as a whole, REFUSE with one plain line ("Exec contains spaces; quote the
    full command, e.g. \"/opt/my app/run\" …") and re-ask the target (counts
    against the ask budget); (c) folder targets must be existing absolute
    paths (`URL=file:///…` is generated from them); URL targets must start
    with a scheme (`https://`, `http://`, …). Link entries use `Type=Link`
    with `URL=`; app entries use `Type=Application` with `Exec=` plus
    `Terminal=true`/`Path=` only when given. Every entry carries `Comment=
    Created by mintbutler desktop-shortcut-creator`.
11. **Tool-absence honesty:** `gio` absent with a desktop copy requested →
    copy + `chmod +x` anyway, print a plain advisory that the trusted flag
    could not be set and Cinnamon may ask until trusted manually.
    `desktop-file-validate` absent → advisory line, continue. Never fail the
    whole run over an optional enhancement.
12. **Transparency close-out (owner ruling):** after each successful run,
    print the final content of every entry file created (the actual file
    bytes), then — for Custom app entries — offer ONE `ask_yn` "test-launch
    it now?"; on yes, launch exactly the recorded Exec/URL (apps via `setsid`
    detached, URLs via `xdg-open` when present else say so; folder links: no
    launch, say so) — the launch itself is declared part of the plan and the
    ask budget. Never launch anything in Scan & place mode.
13. **Shadow warning (owner ruling):** if the sanitized slug matches an
    existing file in `/usr/share/applications/`, print one plain warning that
    the new entry shadows a system-provided one (proceed; it's the user's own
    applications dir and undo removes it).
14. **State record & undo:** every created path appended to
    `$HOME/.local/state/mintbutler/desktop-shortcut-creator/<entry>.paths`
    (one path per line; parent dirs created). `undo` reads ALL `*.paths`
    there, deletes each still-existing recorded file, then the state files;
    missing state → "Nothing to undo." + exit 0. Only recorded paths are
    touched — never glob user directories. Undo needs no prompts. Scan &
    place's undo removes the whole created set of recorded copies.
15. **Non-interactive behavior (modulelint compatibility):** modulelint runs
    `run` with stdin `/dev/null`. The first `ask` hits EOF → `run` prints one
    plain stderr line ("This module needs interactive input; start it from
    the butler menu.") and exits 1 WITHOUT writing anything. That is a
    passing lint outcome per MODULE_SPEC §5.5 and is asserted in the harness.
    `describe`, `plan`, `dry-run` never prompt and never write; `dry-run`
    prints the plan plus the exact command sequence with `<placeholders>`.
16. **Menu changes in `butler`/`lib/menu.sh`:** render the top menu through
    `lib/picker.sh` pagination so EVERY screen ≤ 23 lines; the prompt line
    becomes the §6 spec text (`n next  p prev  /search  r refresh  q quit`);
    numbers remain positions within the CURRENT page; `--list` output stays
    flat and unchanged (it is not a screen); `--run`, `--scan`, `--help`
    untouched.
17. **Owner acceptance ruling (2026-09-16, binding):** acceptance commands
    must be non-destructive on a live machine — the safe set is
    `./butler --list`, `./butler --scan`, `./butler --run
    desktop-shortcut-creator --dry-run`, plain menu navigation, and the
    module's Scan-mode listing. Interactive `run` on the owner's machine is a
    real chore execution: permitted for acceptance because it is confirmed,
    planned, and undoable — but your tests must never require it.
18. **Branch-pinning rule (hardened from task 001):** if your runner pins
    your session to a branch and forbids creating another, use the pinned
    branch as the target (base stays `main`), substitute its name in §8/§9,
    and record it under `#### Session Irregularities`. Never push to
    `arena/01a0abf2-mintbutler`.

**Scope boundaries:** NO panel pinning, NO editing of existing entries
(future `menu-entry-manager`), NO `modules/android-file-transfer` (task
004), NO appimage-installer (future module reusing these libs), NO CI, NO
dependencies, NO sudo/pkexec, NO network, NO cache rebuilds/process kills.
Do not modify `lib/confirm.sh` or `lib/ui.sh` beyond what picker/menu
integration requires — report defects instead of fixing unrelated code.

**Expected-absent at delivery:** `modules/android-file-transfer`. If it
exists, HALT and report.

## 5. CORE OBJECTIVE

The module passes `bin/modulelint`; the menu shows it as one entry; Scan &
place copies chosen installed apps' launchers to the desktop with trust and
undo; Custom builds validated app/folder/URL launchers with versioning,
quoting refusal, shadow warning, and a transparent close-out; every screen
rendered anywhere in the product is ≤ 23 lines; the spec texts match the
shipped behavior exactly; the harness proves all of it against fake `$HOME`
trees.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exits 0 including the new stages; `bin/modulelint` exit 0 on the real
module; `./butler --scan` exit 0; `bash -n` clean; shellcheck clean if
installed; worktree clean; everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `lib/ask.sh` — per §4 fact 6.
2. `lib/picker.sh` — per §4 fact 4.
3. `lib/desktop-entry.sh` — per §4 fact 5.
4. `modules/desktop-shortcut-creator/module.yml` — per §4 fact 7.
5. `modules/desktop-shortcut-creator/module.sh` — executable (git mode 755),
   per §4 facts 8–15.

Modify:

6. `lib/manifest.sh` — add optional `asks` (non-negative integer) to the
   accepted subset; export `MANIFEST_ASKS` (empty when absent); update the
   file's subset comment. All existing fixtures must still parse.
7. `bin/modulelint` — accept `asks` as a known manifest field (it sources
   `lib/manifest.sh`, so add only what the subset change requires; do not
   restructure it).
8. `butler` + `lib/menu.sh` — pagination per §4 fact 16.
9. `docs/MODULE_SPEC.md` — three amendments, EXACTLY:
   - §2 manifest block: add after the `order:` line:

```yaml
asks: 2                                  # optional int; the module's question
                                         # budget (see §3); omit → 1
```

   - §3 conventions: REPLACE the bullet that starts "No interactive prompts
     inside modules." with:

```text
- A module may ask a short, BOUNDED series of questions, each collecting a value only the user knows. The question budget is declared in the manifest (`asks: <n>`). Optional values accept Enter to skip. Every safety confirmation (risk badge, run/undo, elevated) stays with the menu, never inside the module. Question flows must be testable non-interactively (scripted stdin).
```

   - §4 menu behavior: REPLACE the prompt-line bullet and add the law. The
     rendered prompt line becomes:

```text
Select a task number (or: n next  p prev  /search  r refresh  q quit):
```

     and add this new bullet to §4:

```text
- **23-line law (enforced in the test suite):** no menu or submenu screen may exceed 23 terminal lines — ever. Screens that exceed the budget paginate: entries page + one header + one footer (`n next / p prev / numbers / s search / q done`).
```

10. `tests/run-tests.sh` — keep stages (a)–(j) passing; add (all module runs
    against `mktemp` fake HOMEs, real scripts, piped stdin):
    - (k) `./butler --scan` in the real repo exits 0 and prints
      `PASS desktop-shortcut-creator`;
    - (l) non-interactive `run` (stdin `/dev/null`): exits 1, stderr contains
      "interactive", fake HOME unchanged (`diff -r`);
    - (m) Custom app: `printf '2\n1\n/usr/bin/true\nTest App\n\n\n\nn\nn\n'`
      (custom → app → target → name → icon skip → terminal no → workdir
      skip → desktop copy n → test-launch n) exits 0; fake HOME gains
      `.local/share/applications/test-app.desktop` with `Type=Application`,
      `Name=Test App`, `Exec=/usr/bin/true`; close-out output contains the
      entry content; state records the path; same input again → already-done,
      byte-identical; then `/usr/bin/false` variant → creates
      `test-app-2.desktop`, original untouched;
    - (n) Custom folder link: type folder + existing fake dir → entry with
      `Type=Link` and `URL=file:///<dir>`; Custom URL link: type URL +
      `https://example.com/` → `Type=Link`, `URL=https://example.com/`;
    - (o) Exec-quoting refusal: target `/opt/my app/run` (spaces, unquoted) →
      refusal line, re-ask; then quoted `"/opt/my app/run"` → accepted with
      the quoted Exec preserved;
    - (p) shadow warning: the module's system scan roots are overridable for
      tests ONLY via `MINTBUTLER_TEST_APP_DIRS` (colon-separated; production
      defaults `/usr/share/applications` unchanged when unset). Stage a fake
      system dir containing `shadowed.desktop`, run Custom mode with name
      "Shadowed" under that env, and assert the plain shadowing warning
      appears while the entry is still created and recorded;
    - (q) Scan & place: seed `<fake-home>/.local/share/applications/` with
      two valid `.desktop` files; script the picker to select both and press
      `d`; confirmation listing shown; desktop copies exist, executable,
      recorded; undo removes both copies and state; second undo → "Nothing to
      undo.";
    - (r) picker & 23-line law: with 30 synthetic modules generated into a
      lint-stage copy, capture `printf 'n\nn\nq\n' | ./butler` and assert
      EVERY screen between prompts is ≤ 23 lines and page 2 differs from
      page 1; same bound asserted on the scan-picker screen with 30 seeded
      entries.
11. `docs/PROJECT_STATE.md` — replace its `## 4. Active Milestone & Current
    State` section with EXACTLY:

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** v0.1 — menu script + module discovery + modulelint + the two seed modules.
- **Current State:** core menu (PR #1, merged 2026-09-16) and `bin/modulelint` gate (PR #2, merged 2026-09-16) landed; desktop-shortcut-creator v1 (Scan & place + Custom modes, shared entry/picker libs, 23-line law) landed via PR for task 003.
- **Immediate Next Task:** task 004 — seed module `android-file-transfer` (risk: elevated, undo: false).
```

   and append these bullets to its `## 3. Settled Decisions & Rationale`
   list:

```markdown
- desktop-shortcut-creator icon field: free text — an icon file path or a theme icon name; empty = system default (owner, 2026-09-16).
- desktop-shortcut-creator name conflict: never overwrite — create the launcher alongside with a `-N` version suffix and leave the existing entry untouched (owner, 2026-09-16).
- Module questions: a bounded series declared in the manifest (`asks: <n>`); optional values accept Enter to skip; safety confirmations stay with the menu; flows testable via scripted stdin — MODULE_SPEC §3 amended accordingly (owner, 2026-09-16). No standing exceptions: docs never drift from reality.
- 23-line law: no menu or submenu screen may exceed 23 terminal lines — ever; screens paginate (entries page + one header + one footer). Enforced in the test suite. MODULE_SPEC §4 amended (owner, 2026-09-16).
- desktop-shortcut-creator v1 ships two entry modes — Scan & place (default) and Custom — sharing `lib/desktop-entry.sh`; pagination lives in shared `lib/picker.sh` for reuse by future pickers (owner + hub review, 2026-09-16).
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

Each line ends with a checkpoint commit + push (§9):

1. `lib/manifest.sh` `asks` field + `bin/modulelint` acceptance; existing
   suite green → commit + push
2. `lib/ask.sh` → commit + push
3. `lib/picker.sh` (single + multi-select, pagination, footer contract) →
   commit + push
4. `lib/desktop-entry.sh` (write/version/validate/trust/record/undo core) →
   commit + push
5. `butler` + `lib/menu.sh` pagination, new prompt line, existing stages
   green → commit + push
6. `modules/desktop-shortcut-creator/` — manifest + read-only actions
   (describe/plan/dry-run) + Custom mode incl. quoting refusal, shadow
   warning, transparency close-out → commit + push
7. Scan & place mode + undo across both modes → commit + push
8. Harness stages (k)–(r), full suite green → commit + push
9. `docs/MODULE_SPEC.md` amendments per §6 (exact texts) → commit + push
10. Tracker update per §6 → commit + push
11. Final pass: `bash -n` all touched scripts, shellcheck if installed,
    `bin/modulelint` green, `./butler --scan` exit 0, full harness, §14
    smokes, clean tree → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/shortcut-creator-v1` — EXCEPT the §4 fact 18
  substitution if your runner pins you to a session branch.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only, never
  a base or target.
- Dependencies: none (PRs #1 and #2 are merged).
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/shortcut-creator-v1:refs/remotes/origin/_resume
git checkout -B feature/shortcut-creator-v1 refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/shortcut-creator-v1 origin/main
```

(Substitute the pinned branch name per §4 fact 18 if applicable.) Do not
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
  every expansion — modulelint scans your module, and SC2086 fails the gate
  wherever shellcheck runs. Reference style: `lib/confirm.sh`,
  `tests/fixtures/modules/alpha-fixture/module.sh`.
- Module I/O contract: stdout for humans, stderr for errors; exit 0 success;
  non-zero failure with one plain-language stderr line.
- Zero dependencies: `desktop-file-validate`, `gio`, `xdg-open`, `setsid`
  are USED WHEN PRESENT with advisory degradation (§4 fact 11). No
  sudo/pkexec anywhere — the trust flag is a per-user gvfs metadata
  operation.
- All module writes stay under `$HOME` (`Desktop`,
  `.local/state/mintbutler/<slug>/`); Scan mode creates nothing in
  `.local/share/applications`.
- TEST_COMMAND: `bash tests/run-tests.sh` (stages k–r: gate pass, EOF
  refusal, custom app/folder/URL, quoting refusal, shadow warning, scan &
  place with undo, picker pagination, 23-line law)
- INTEGRATION_TEST_COMMAND: stages (k) and (r) — real `./butler --scan`
  executing the real gate against the real module, and the real menu loop
  paginating 30 modules end-to-end
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — every behavioral branch (EOF
  refusal, idempotent hit, -N versioning, quoting refuse/accept, link types,
  scan multi-select, undo with/without state, page boundaries) has a direct
  harness assertion; no bash mutation tooling exists under the
  zero-dependency constraint
- LINT_COMMAND: `bash -n modules/desktop-shortcut-creator/module.sh
  lib/ask.sh lib/picker.sh lib/desktop-entry.sh butler lib/*.sh
  bin/modulelint tests/run-tests.sh` (always) plus `shellcheck` on the same
  set when installed; additionally `bin/modulelint
  desktop-shortcut-creator` must exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages (a)–(j); existing flags
  (`--list` flat output unchanged, `--run`, `--scan`, `--help`); fixture
  parsing through the extended manifest parser.
- The module writes ONLY files announced in `plan`, records each one, and
  `undo` removes exactly the recorded set. No cache rebuilds, no process
  kills, no environment edits beyond the module's own execution, never sudo.
- Test-launch (fact 12) runs ONLY after an explicit yes, exactly the
  recorded Exec/URL, detached; it never runs in Scan & place mode and never
  runs in tests.
- Owner-acceptance safety (fact 17): every harness assertion runs against
  fake `$HOME` trees in `mktemp`; the module is never pointed at the real
  HOME by the harness. The `MINTBUTLER_TEST_APP_DIRS` override exists ONLY
  for tests; production defaults are unchanged when it is unset.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- NO panel pinning; NO editing existing entries (future
  `menu-entry-manager`); NO appimage-installer; NO
  `modules/android-file-transfer` (expected-absent; task 004).
- Do NOT modify `lib/confirm.sh`, `lib/ui.sh`, README.md, or
  docs/VISION.md. `docs/MODULE_SPEC.md` changes ONLY the three §6 texts.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Artifacts: if this task produces a build artifact, do not commit it
  anywhere; write its path and sha256 into the PR description and stop.
  Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

Before opening the PR, all of these must pass:

1. `bash tests/run-tests.sh` — exit 0, every stage (a–r) asserts
   successfully, including the ≤23-line assertions.
2. `bin/modulelint desktop-shortcut-creator` — exit 0 with `PASS`.
3. `bin/modulelint` — exit 0.
4. `./butler --scan` — exit 0.
5. `./butler --list` — shows `desktop-shortcut-creator: Desktop shortcut
   creator`.
6. `printf 'q\n' | ./butler` — exit 0; every screen in the captured output
   ≤ 23 lines.
7. `bash -n` over all changed/new scripts — clean; shellcheck clean if
   installed (record absence otherwise).
8. Spec diff contains EXACTLY the three §6 amendments and nothing else.
9. Worktree clean, all work pushed, `modules/android-file-transfer` absent.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: desktop-shortcut-creator v1 — scan & place, custom launcher,
shared entry/picker libs, 23-line law`. The description must contain: a
summary; design rationale (the two modes and why Scan & place is default;
how the shared libs split; how versioning, quoting refusal, shadow warning,
and the transparency close-out implement the owner rulings; the
tool-absence degradation policy; how EOF refusal keeps the gate green); the
spec amendments listed with their exact locations; test results per §10
layer with exact commands and outcomes; the safety statement "this module
writes only under $HOME, never uses sudo, records every file it creates,
undo removes exactly that recorded set, test-launch only after an explicit
yes, and all harness assertions run against fake HOME directories"; what
the owner should try on Mint (Scan & place with two real apps, then undo;
one Custom URL launcher); breaking changes (menu prompt line gains `n`/`p`;
`--list` unchanged); migration notes (none). Describe only this PR's own
changes. Include `#### Session Irregularities` per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only: something that interfered with following
this prompt AND cost >~10 min, blocked progress, required a
workaround/deviation, or reveals a hidden repo/session invariant or prompt
blind spot that would recur for the next worker. If none significant, write
exactly `None significant` — that satisfies this section. If significant, one
row per irregularity: Category (Environment/Prompt/Repository/Tooling) |
Symptom (1 sentence) | Impact | Workaround | Hardening candidate (optional),
3–6 lines total. If you used the branch-substitution rule (§4 fact 18), one
line noting it belongs here. Do not pad with trivial single retries or
expected platform behavior. This report does not affect the MERGE/REVISE
verdict unless it reveals a missing deliverable.
