# 009 — module: default-apps-editor

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/009-default-apps-editor.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "009 — module: default-apps-editor".

## 1. TASK TITLE AND SCOPE

Ship batch-#1 module `default-apps-editor` (risk: low, undo: true,
`needs: [xdg-mime]`, `order: 30`, `asks: 4`): change the default application
for a chosen MIME category (or a custom MIME type) through `xdg-mime`,
showing current-versus-new before anything changes, with whole-file
backup/restore undo of `~/.config/mimeapps.list`. Complete this in ONE pull
request.

## 2. REQUIRED READING ORDER

1. `docs/PROJECT_STATE.md` — §3 conventions and order table (your module is
   `order: 30`).
2. `README.md` — safety contract (user-level first, dry-run before do, undo
   or say so, idempotent, zero dependencies).
3. `docs/MODULE_SPEC.md` — §2 manifest fields, §3 actions and the bounded
   `asks:` series, §5 gate.
4. `modules/desktop-shortcut-creator/module.sh` — conforming sibling: action
   structure, `ask`/`picker` usage, state-record/undo pattern,
   non-interactive EOF refusal.
5. `modules/screenshot-studio/module.sh` — newer sibling: state-dir layout,
   honest reporting style.
6. `lib/ask.sh`, `lib/picker.sh` — the bounded-question helpers and the
   paginated picker (23-line law lives in the footer there).
7. `bin/modulelint` — the gate your module must pass (its sandbox runs `run`
   with stdin `/dev/null`).
8. `tests/run-tests.sh` — harness pattern; the stage letter sequence ends at
   `(aa)` — your new stages continue `(ab)` onward (confirm with
   `grep -n "Stage aa" tests/run-tests.sh`; confirm, do not copy).
9. `git log --oneline -5` — Conventional Commits convention (confirm, do not
   copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22. Core,
gate, desktop-shortcut-creator, and screenshot-studio are on `main`; batch
#1 continues with this module — the owner-approved list names it
"default-apps-editor (low / undo:true; xdg-mime defaults with
current-vs-new display)". Owner vision: "Understandable. Before anything
changes, the owner sees the current default, the candidate apps, and the
exact new assignment — then decides." Nothing system-wide is touched:
`xdg-mime default` writes user-level `mimeapps.list` state only.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

1. **Manifest (exact values):** `title: Default apps editor`;
   `description: >-` folding EXACTLY: "Changes the default application for a
   MIME type — pick a category or type your own, see the current default
   versus the new one, then apply. Your mimeapps.list is backed up before
   the first change and restored byte for byte on undo.";
   `risk: low`; `undo: true`; `needs: [xdg-mime]`; `asks: 4`; `order: 30`.
2. **`asks: 4` budget, used as:** (a) category choice, (b) custom MIME type
   — only when (a) picks "custom", (c) application choice, (d) apply
   confirmation. `q`/quit at any question aborts cleanly (exit 0, nothing
   written, plain "Nothing changed." message). Enter at the category
   question does NOT skip — a category is required; Enter at the
   confirmation defaults to NO (nothing changes).
3. **Categories (fixed list, displayed numbered):** web browser
   (`text/html` + `x-scheme-handler/http` + `x-scheme-handler/https`),
   e-mail (`x-scheme-handler/mailto`), image viewer (`image/png` +
   `image/jpeg`), video player (`video/mp4`), audio player (`audio/mpeg`),
   PDF viewer (`application/pdf`), text editor (`text/plain`), archive
   manager (`application/zip`), plus entry `9` "custom MIME type". A
   category may apply to several MIME types — treat the category as that
   small ordered list and assign the chosen app to every type in it.
4. **Candidate discovery:** scan `.desktop` files under every directory in
   `${XDG_DATA_DIRS:-/usr/local/share:/usr/share}` (colon-split) plus
   `$HOME/.local/share/applications`; a file is a candidate for a MIME type
   iff its `MimeType=` line contains that type. Show candidates by their
   `Name=` value with the desktop file id in parentheses, paginated through
   `lib/picker.sh` (23-line law). No candidates for any type of the chosen
   category → one plain honest line (name the type(s) searched), exit 1,
   nothing written.
5. **Apply flow:** display `current: <xdg-mime query default result or
   (none)>` vs `new: <Name> (<file.desktop>)` for every type in the
   category; confirmation question (default NO); on YES — first back up
   `~/.config/mimeapps.list` byte-for-byte into
   `$HOME/.local/state/mintbutler/default-apps-editor/mimeapps.list.backup`
   (record `BACKUP_MISSING=yes` if the file did not exist), then run
   `xdg-mime default <file.desktop> <mime>` for each type, then verify each
   with `xdg-mime query default`; any mismatch → restore the backup, plain
   error, exit 1. Success → print each assignment and the undo note.
6. **Undo:** state dir present → restore the backup over
   `~/.config/mimeapps.list` (or delete the file when
   `BACKUP_MISSING=yes`), print the recorded assignments reversed, delete
   the state dir, exit 0. No state → "Nothing to undo." exit 0.
7. **Actions:** `describe` one line; `plan` plain numbered steps;
   `dry-run` = plan + exact `xdg-mime` commands it would run (query form)
   and the backup path, exit 0, zero writes. `plan` and `dry-run` render in
   ≤ 23 lines.
8. **Non-interactive behavior (modulelint compatibility):** modulelint runs
   `run` with stdin `/dev/null`. The first `ask` hits EOF; the module must
   then print one plain stderr line and exit 1 having written NOTHING
   (nothing is written before the confirmation anyway — keep it that way).
9. **Forbidden-pattern compliance:** no `sudo`/`pkexec`/`eval`/`curl|bash`
   literals in the module; quote every expansion — the gate SC2086-fails
   wherever shellcheck is present (two earlier PRs went through revision
   for exactly this).
10. **Owner acceptance ruling (2026-09-16, binding):** acceptance commands
    are non-destructive: `./butler --list`, `./butler --scan`,
    `./butler --run default-apps-editor --dry-run`, menu navigation. Tests
    never touch the real `~/.config/mimeapps.list`, real `$XDG_DATA_DIRS`
    app directories, or real `xdg-mime` behavior beyond PATH stubs and fake
    HOMEs.
11. **Branch-pinning rule:** if your runner pins your session to a branch
    and forbids creating another, use the pinned branch as the target (base
    stays `main`), substitute its name in §8/§9, and record it under
    `#### Session Irregularities`. Never push to
    `arena/01a0abf2-mintbutler`.

**Scope boundaries:** NO system-wide changes (nothing outside the user's
HOME), NO editing of `.desktop` files, NO new `.desktop` creation, NO
per-scheme subtleties beyond the listed category types, NO changes to
`butler`, `bin/modulelint`, `lib/*`, other modules, or docs other than the
tracker edit in §6.

**Expected-absent at delivery:** no new module folder other than
`default-apps-editor`; no new files under `lib/`. If any appears, HALT and
report.

## 5. CORE OBJECTIVE

`default-apps-editor` passes `bin/modulelint`; the menu lists it at its
order-30 position; its guided flow shows current-vs-new before any change;
every change is preceded by a byte-for-byte backup of `mimeapps.list` and
`undo` restores that backup exactly; all interactive paths are testable via
scripted stdin against stubs.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exit 0 including new stages; `bin/modulelint` exit 0; `./butler --scan`
exit 0; `bash -n` clean; shellcheck clean if installed; worktree clean;
everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `modules/default-apps-editor/module.yml` — per §4 fact 1.
2. `modules/default-apps-editor/module.sh` — executable (git mode 755), per
   §4 facts 2–9.

Modify:

3. `tests/run-tests.sh` — keep all existing stages passing; add stages
   `(ab)`–`(af)` (letters confirmed from the harness per §2.8) using a
   PATH-prefix stub `xdg-mime` backed by a fake HOME and a fake
   `XDG_DATA_DIRS` tree of small `.desktop` files; NEVER the real config or
   the real data dirs:
   - (ab) `./butler --scan` exit 0; `bin/modulelint` exit 0 with
     `PASS default-apps-editor`; `./butler --list` shows the module;
     `plan`/`dry-run` exit 0, non-empty, ≤ 23 lines each; `run` with stdin
     `/dev/null` exits 1 with one plain stderr line and writes nothing
     (fake HOME byte-identical before/after);
   - (ac) happy path: scripted stdin (category `1`, app `1`, confirm `y`)
     → exit 0; fake `mimeapps.list` now assigns the chosen desktop id to
     every type of the category; state dir holds the backup (byte-equal to
     the pre-run file) and a changes record; output shows current-vs-new;
   - (ad) undo after (ac): `mimeapps.list` byte-identical to the pre-run
     original; state dir gone; second undo → "Nothing to undo." exit 0;
   - (ae) no-candidate path: category whose MIME types appear in no stub
     `.desktop` file → exit 1, plain honest line naming the type searched,
     nothing written, no state dir;
   - (af) verification-failure path: stub `xdg-mime` that accepts writes
     but reports a different app on `query default` → exit 1, backup
     auto-restored (file byte-equal to pre-run), state dir removed or
     absent.
4. `docs/PROJECT_STATE.md` — replace the `## 4. Active Milestone & Current
   State` section with EXACTLY (the old text, for verification — confirm
   with `grep -n "Immediate Next Task" docs/PROJECT_STATE.md`; confirm, do
   not copy):

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** Module batch #1 (owner-approved 2026-09-16): nine modules — seven features, two fixes — one reviewed PR at a time on the v0.1 core.
- **Current State:** v0.1 core complete; batch #1 in progress — screenshot-studio landed (PR #5); governing orchestrator spec pinned byte-faithful with `bin/orchestrator-check` mechanical compliance gate (PR #6).
- **Immediate Next Task:** task 010 — module `appimage-installer` (low / undo:true; reuses `lib/desktop-entry.sh`), third in the owner's revised build order.
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

1. `modules/default-apps-editor/module.yml` + read-only actions
   (describe/plan/dry-run, ≤23-line screens) → commit + push
2. `module.sh` guided `run` (category → candidates → current-vs-new →
   confirm → backup → apply → verify) → commit + push
3. `module.sh` `undo` (backup restore, BACKUP_MISSING handling) → commit +
   push
4. Harness stages (ab)–(af), full suite green → commit + push
5. Tracker edit → commit + push
6. Final pass: `bash -n` touched scripts, shellcheck if installed,
   `bin/modulelint` green, `./butler --scan` exit 0, `--list` check, full
   harness, §14 smokes, clean tree → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/default-apps-editor` — EXCEPT the §4 fact 11
  substitution if your runner pins you.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/default-apps-editor:refs/remotes/origin/_resume
git checkout -B feature/default-apps-editor refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/default-apps-editor origin/main
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
- `xdg-mime` is invoked as a bare command (PATH lookup); everything it reads
  or writes in tests is inside a fake HOME / fake `XDG_DATA_DIRS`.
- TEST_COMMAND: `bash tests/run-tests.sh` (stages ab–af: gate, happy path,
  undo byte-restore, no-candidate, verify-failure rollback)
- INTEGRATION_TEST_COMMAND: stage (ab) — real `./butler --scan` and
  `--list` exercising the real menu/gate with the new module present
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — each behavioral branch (category,
  custom type, no-candidate, confirm-no, backup-missing, verify-failure,
  undo with/without state) has a direct harness assertion; no bash mutation
  tooling exists under the zero-dependency constraint
- LINT_COMMAND: `bash -n modules/default-apps-editor/module.sh butler
  lib/*.sh bin/modulelint tests/run-tests.sh` (always) plus `shellcheck` on
  the same set when installed; additionally `bin/modulelint
  default-apps-editor` must exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages; existing modules; menu behavior;
  `lib/manifest.sh` parsing of `needs: [xdg-mime]` and `asks: 4`.
- Nothing outside the user's HOME is ever written; the only file modified
  is `~/.config/mimeapps.list`, always behind a backup.
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

- NO system-wide writes, NO `.desktop` creation or editing, NO new lib
  files, NO other modules, NO alternative MIME tooling (update-alternatives,
  mimetype, gio mime) — `xdg-mime` only.
- Do NOT modify `butler`, `bin/modulelint`, `bin/orchestrator-check`,
  `lib/*.sh`, other modules, README.md, docs/VISION.md, or
  docs/MODULE_SPEC.md.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

1. `bash tests/run-tests.sh` — exit 0, every stage asserts successfully.
2. `bin/modulelint default-apps-editor` — exit 0 with PASS.
3. `bin/modulelint` — exit 0.
4. `./butler --scan` — exit 0.
5. `./butler --list` — shows `default-apps-editor: Default apps editor`;
   both existing modules still listed.
6. `./butler --run default-apps-editor --dry-run` — exit 0, side-effect-free.
7. `bash -n` clean over all changed/new scripts; shellcheck clean if
   installed (record absence otherwise).
8. Worktree clean, all work pushed, no extra module folders, no new lib
   files.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: default-apps-editor — xdg-mime defaults with current-vs-new
display and byte-for-byte undo`. Description: summary; design rationale (why
whole-file backup/restore instead of per-line mimeapps.list surgery; why the
category list is fixed; how `asks: 4` is spent; the stub-xdg-mime test
strategy and its honest limit — real desktop-environment default resolution
is owner-acceptance on Mint); test results per §10 layer with exact commands
and outcomes; safety statement "the module writes only inside the user's
HOME: one backup copy plus changes to ~/.config/mimeapps.list, always
behind the backup; all tests run against a stub xdg-mime and fake HOMEs";
what the owner should try on Mint (`./butler` → Default apps editor → pick
a category → see current vs new → confirm → then `[u]ndo`); breaking
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
