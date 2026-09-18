# 017 — module: book-access-doctor

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/017-book-access-doctor.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "017 — module: book-access-doctor".

## 1. TASK TITLE AND SCOPE

Ship batch-#1 module `book-access-doctor` (FIX kind, `risk: elevated`,
`undo: true`, `needs: [findmnt, mount]`, `order: 900`, `asks: 1`): a
diagnose-first doctor for e-reader/book-device access on Linux Mint 22 —
inspects the automounted removable mounts under `/media/<user>` and
`/run/media/<user>`, reports each one's source, filesystem type, mount
options and writability in plain words, and performs exactly ONE kind of
repair when a mount is read-only: an elevated `mount -o remount,rw` after
one confirmation, recorded and undoable (undo remounts read-only again).
Persistent-mount guidance is PRINT ONLY — mintbutler never writes fstab,
never runs chmod anywhere, and NEVER `chmod -R 777`. Complete this in ONE
pull request.

## 2. REQUIRED READING ORDER

1. `docs/PROJECT_STATE.md` — §3 conventions and order table (your module is
   `order: 900`, FIXES range), and the batch rulings.
2. `README.md` — safety contract.
3. `docs/MODULE_SPEC.md` — §2 manifest fields, §3 (elevated modules use the
   shared `elevate` helper ONLY), §5 gate.
4. `modules/audio-repair/module.sh` — closest sibling: diagnose-first
   ladder, `lib/elevate.sh` usage with helper-driven display
   (`elevate_command_line` for variable-argument commands), honest
   verdicts, record-before-apply + undo-from-record semantics.
5. `modules/printer-helper/module.sh` — read-only ladder style and honest
   guidance pointing at Mint's own tools.
6. `lib/elevate.sh`, `lib/ask.sh` — the elevated helper and the question
   helper (`ask_yn`: Enter = NO, EOF = NO).
7. `bin/modulelint` — the gate your module must pass (its sandbox runs
   `run` with stdin `/dev/null`).
8. `tests/run-tests.sh` — harness pattern; the stage letter sequence ends at
   `(bl)` — your new stages continue `(bm)` onward (confirm with
   `grep -n "Stage bl" tests/run-tests.sh`; confirm, do not copy).
9. `git log --oneline -5` — Conventional Commits convention (confirm, do
   not copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22. Twelve
modules are on `main` (latest: system-report-pack via PR #14). This is the
NINTH AND FINAL module of batch #1. Owner rulings that shape it (2026-09-16,
binding): remount-as-elevated is OK; persistent fstab edits are OUT — print
guidance only; permission grants, if ever made, are targeted only — NEVER
`chmod -R 777` (this module makes no chmod at all). Owner vision: when the
book reader lands mounted read-only or not at all, one menu entry says
WHAT is wrong with the mount in plain words and — only after you confirm —
flips it writable the honest way.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

1. **Manifest (exact values):** `title: Book access doctor`;
   `description: >-` folding EXACTLY: "Diagnoses removable mounts under
   /media and /run/media — where Mint automounts e-readers and book
   devices — reporting source, filesystem, options, and writability in
   plain words. The one repair it makes on a read-only mount is an
   elevated remount read-write, confirmed first, recorded, and restorable
   on undo; persistent-mount guidance is print-only — fstab is never
   written and chmod never runs.";
   `risk: elevated`; `undo: true`; `needs: [findmnt, mount]`; `asks: 1`;
   `order: 900`.
2. **`asks: 1` budget:** the single question is the confirmation of the
   remount repair (`ask_yn`, Enter defaults to NO). Every other step is
   read-only diagnosis or honest reporting.
3. **Diagnosis ladder (read-only steps first, in this order):**
   (i) preflight: `findmnt` and `mount` present (util-linux ships on Mint),
   else one plain honest stderr line, exit 1, nothing else;
   (ii) discover mounts: `findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS` —
   keep ONLY rows whose TARGET starts with `/media/` or `/run/media/`
   (Mint's automount roots); when zero → verdict: no removable mount found
   — guidance: plug the reader in and unlock it, wait for the file manager
   to mount it (or click the device there), then re-run; for automatic
   mounts use Mint's Disks app — mintbutler never writes fstab; exit 0,
   nothing written, no question;
   (iii) report each discovered mount plainly: target, source, fstype,
   `ro`/`rw` from OPTIONS, and writable-or-not via `test -w "<target>"`;
   (iv) all mounts rw and writable → healthy verdict, exit 0, no question,
   no elevated call;
   (v) read-only candidate found (OPTIONS contain `ro`, or not writable) →
   repair path: fstype allowlist check first — EXACTLY
   `vfat exfat ext4 ext3 ext2 ntfs ntfs3 f2fs`; fstype outside the list
   (e.g. iso9660, squashfs) → honest verdict "remounting rw does not apply
   to this filesystem type", exit 0, no question; inside the list → show
   current vs proposed, the exact elevated command via the helper display
   (`elevate_command_line "mount -o remount,rw '<target>'"` — quoted
   placeholder, never a hardcoded display string), the no-fstab / no-chmod
   notice, then the ONE confirmation; NO/EOF → "Nothing changed." exit 0;
   YES → record `target=` and `prev_opts=` (the OPTIONS string) to
   `$XDG_STATE_HOME-or-~/.local/state/mintbutler/book-access-doctor/remount.record`
   BEFORE running; run the elevated remount via `elevate_run`; re-check
   with `findmnt -n -o OPTIONS "<target>"` — OPTIONS now contain `rw` →
   success report with the print-only persistence note (a suggested fstab
   line shown as INFORMATIONAL TEXT built from the row's SOURCE and TARGET,
   plus the explicit statement that mintbutler will not write it — use
   Mint's Disks app), exit 0; remount failed or verify still reads ro →
   KEEP the record, plain stderr error ("undo can remount read-only to
   restore the previous state"), exit 1;
   (vi) mixed case (one mount rw, another ro): repair applies to the FIRST
   ro candidate in discovery order; the healthy ones are reported as such.
4. **Undo:** state file present → display and run the elevated
   `mount -o remount,ro '<target>'` from the record via the helper, verify
   OPTIONS read `ro` again, delete the record, report — with the plain note
   that this restores the pre-repair read-only state (any files written
   since stay on the device, but new writes stop); state file absent →
   "Nothing to undo." exit 0; undo's elevated step failing → keep the
   record, one plain stderr line, exit 1. Undo of a missing `mount`/
   `findmnt` is an honest refusal (record kept, exit 1).
5. **Actions:** `describe` one line; `plan` the ladder in plain numbered
   steps including the never-fstab-write and never-chmod statements;
   `dry-run` = plan + the exact commands it would run (elevated ones
   displayed via the helper with quoted placeholders) with zero execution.
   `plan` and `dry-run` render in ≤ 23 lines.
6. **Non-interactive behavior (modulelint compatibility):** modulelint runs
   `run` with stdin `/dev/null`. In the sandbox `findmnt` is real; rows
   under /media//run/media are typically zero → the no-device verdict,
   exit 0, no elevated call — the passing lint path. Where an ro mount
   exists, the flow stops at `ask_yn` EOF (= NO) → "Nothing changed." with
   zero writes. All writes are the single user-level state record, made
   only after the confirmed YES.
7. **Forbidden-pattern compliance:** `sudo` appears ONLY via
   `lib/elevate.sh`; `module.sh` contains no `sudo`/`pkexec`/`eval`/
   `curl|bash` literal; NO `chmod` invocation of any kind anywhere in the
   module (the harness asserts this); EVERY elevated command display uses
   `elevate_command_line` with quoted placeholders (the PR #10 revision
   exists because a previous module hardcoded a display string — do not
   repeat that); quote every expansion.
8. **Owner acceptance ruling (2026-09-16, binding):** acceptance commands
   are non-destructive: `./butler --list`, `./butler --scan`,
   `./butler --run book-access-doctor --dry-run`, menu navigation. Tests
   use PATH stubs (`findmnt`, `mount`, `sudo`) with canned outputs — NEVER
   a real remount.
9. **Branch-pinning rule:** if your runner pins your session to a branch
   and forbids creating another, use the pinned branch as the target (base
   stays `main`), substitute its name in §8/§9, and record it under
   `#### Session Irregularities`. Never push to
   `arena/01a0abf2-mintbutler`.

**Scope boundaries:** NO fstab writes (guidance is PRINT ONLY, labeled
informational); NO chmod/chown of any kind; NO mount/unmount other than the
single remount-rw repair and its undo remount-ro; NO udisks/udevd
interaction; NO package installation; NO changes to `butler`, `bin/*`,
`lib/*`, other modules, or docs other than the tracker edit in §6.

**Expected-absent at delivery:** no new module folder other than
`book-access-doctor`; no new or modified files under `lib/`. If any
appears, HALT and report.

## 5. CORE OBJECTIVE

`book-access-doctor` passes `bin/modulelint`; the menu shows it with the
`⚠ elevated` badge at its order-900 position; the ladder covers all
outcomes (missing tools, no removable mounts, all healthy, ro mount with
confirm-yes/confirm-no, non-remountable fstype, remount failure); the only
writes anywhere are the single state record and the confirmed remount;
fstab is never written and chmod never runs.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exit 0 including new stages; `bin/modulelint` exit 0; `./butler --scan`
exit 0; `bash -n` clean; shellcheck clean if installed; worktree clean;
everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `modules/book-access-doctor/module.yml` — per §4 fact 1.
2. `modules/book-access-doctor/module.sh` — executable (git mode 755), per
   §4 facts 2–7.

Modify:

3. `tests/run-tests.sh` — keep all existing stages passing; add stages
   `(bm)`–`(br)` (letters confirmed from the harness per §2.8) using
   PATH-prefix stubs (`findmnt` with env-controlled canned rows, `mount`
   with a call log and a stub state file flipping OPTIONS ro→rw / rw→ro,
   and a stub `sudo` that runs its command for the elevated path); NEVER
   real remounts. Where the module's interactive confirmation matters,
   drive the module binary directly with piped stdin (document in stage
   comments):
   - (bm) gate + read-only smokes: `./butler --scan` exit 0;
     `bin/modulelint` exit 0 with `PASS book-access-doctor`; `./butler
     --list` shows the elevated badge; `plan`/`dry-run` exit 0, non-empty,
     ≤ 23 lines; dry-run contains the exact substring `mount -o
     remount,rw` shown via the helper display and the never-fstab-write and
     never-chmod statements; `run` with stdin `/dev/null` and no findmnt
     stub → exit 1, one plain stderr line, fake HOME byte-identical;
     module source grep asserts zero `chmod`/`chown` invocations, zero
     `sudo` literals, and no fstab write path (`/etc/fstab` appears only in
     informational display strings, if at all);
   - (bn) no-removable-mounts: stub `findmnt` returning only non-media rows
     → exit 0, verdict names the plug-in/unlock/file-manager guidance and
     the Disks-app note, no elevated call, nothing written;
   - (bo) all-healthy: one rw+writable vfat media row → exit 0 healthy
     verdict, no question, no elevated call, nothing written;
   - (bp) ro repair + undo: one ro vfat row under /media; scripted stdin
     `y` → exit 0; state record holds target + prev opts; stub log shows
     exactly one elevated `mount -o remount,rw '<target>'`; success report
     shows the informational fstab line AND the explicit
     will-not-write-it statement; then `undo` → stub log shows the
     elevated `mount -o remount,ro '<target>'`, state deleted, exit 0;
     second undo → "Nothing to undo." exit 0;
   - (bq) confirm-no + non-remountable fstype: same ro fixture with stdin
     `n` → exit 0, "Nothing changed.", no mount call; separately an
     iso9660 ro row → exit 0, honest not-applicable verdict, no question,
     no mount call;
   - (br) remount failure: stub `mount` exiting 1 on the remount → exit 1,
     one plain stderr line, record kept, nothing claimed on stdout.
4. `docs/PROJECT_STATE.md` — replace the `## 4. Active Milestone & Current
   State` section with EXACTLY (verify the old text first with
   `grep -n "Immediate Next Task" docs/PROJECT_STATE.md`; confirm, do not
   copy):

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** Module batch #1 (owner-approved 2026-09-16): nine modules — seven features, two fixes — one reviewed PR at a time on the v0.1 core.
- **Current State:** v0.1 core complete; batch #1 in progress — screenshot-studio (PR #5), orchestrator spec + `bin/orchestrator-check` gate (PR #6), default-apps-editor (PR #7), appimage-installer (PRs #8/#9), timeshift-guardian (PR #10), audio-repair (PR #11), multimedia-codecs (PR #12), printer-helper (PR #13), system-report-pack (PR #14) landed.
- **Immediate Next Task:** task 017 merged = batch #1 complete (nine modules). post-update-doctor remains a backlog stub only; the owner decides the next milestone.
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

1. `modules/book-access-doctor/module.yml` + read-only actions
   (describe/plan/dry-run, ≤23-line screens, never-fstab / never-chmod
   statements visible) → commit + push
2. `module.sh` diagnosis ladder (preflight → mount discovery → per-mount
   report → healthy / no-device verdicts) → commit + push
3. `module.sh` the one recorded elevated remount repair + undo → commit +
   push
4. Harness stages (bm)–(br), full suite green → commit + push
5. Tracker edit → commit + push
6. Final pass: `bash -n` touched scripts, shellcheck if installed,
   `bin/modulelint` green, `./butler --scan` exit 0, `--list` badge check,
   full harness, §14 smokes, clean tree → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/book-access-doctor` — EXCEPT the §4 fact 9
  substitution if your runner pins you.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/book-access-doctor:refs/remotes/origin/_resume
git checkout -B feature/book-access-doctor refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/book-access-doctor origin/main
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
- TEST_COMMAND: `bash tests/run-tests.sh` (stages bm–br: gate/smokes,
  no-device, all-healthy, ro repair + undo, confirm-no + non-remountable,
  remount failure)
- INTEGRATION_TEST_COMMAND: stage (bm) — real `./butler --scan` and
  `--list` exercising the real menu/gate with the new elevated module
  present
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — every verdict branch and the
  repair/undo path have direct harness assertions; no bash mutation tooling
  exists under the zero-dependency constraint
- LINT_COMMAND: `bash -n modules/book-access-doctor/module.sh lib/elevate.sh
  butler lib/*.sh bin/modulelint tests/run-tests.sh` (always) plus
  `shellcheck` on the same set when installed; additionally
  `bin/modulelint book-access-doctor` must exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages; existing modules; menu behavior;
  `lib/manifest.sh` parsing of `needs: [findmnt, mount]`, `asks: 1`.
- The ONLY elevated operations are the single confirmed remount-rw and its
  undo remount-ro via `lib/elevate.sh`. No fstab writes, no chmod/chown,
  no unmount, no package installs.
- Owner-acceptance safety (fact 8): the non-destructive set stays
  non-destructive; tests use stubs only — NEVER a real remount.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- NO fstab writes, NO chmod/chown, NO unmount, NO udisks/udevd calls, NO
  installs, NO other modules, NO lib changes.
- Do NOT modify `butler`, `bin/modulelint`, `bin/orchestrator-check`,
  `lib/*.sh`, other modules, README.md, docs/VISION.md, or
  docs/MODULE_SPEC.md.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

1. `bash tests/run-tests.sh` — exit 0, every stage asserts successfully.
2. `bin/modulelint book-access-doctor` — exit 0 with PASS.
3. `bin/modulelint` — exit 0 (10 modules).
4. `./butler --scan` — exit 0.
5. `./butler --list` — shows `book-access-doctor: Book access doctor` with
   the elevated badge; all existing modules still listed.
6. `./butler --run book-access-doctor --dry-run` — exit 0, side-effect-free.
7. `bash -n` clean over all changed/new scripts; shellcheck clean if
   installed (record absence otherwise).
8. Worktree clean, all work pushed, no extra module folders, no lib changes.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: book-access-doctor — diagnose-first mount doctor with one
recorded remount repair`. Description: summary; design rationale (the
ladder and why each exit path is honest; why the fstype allowlist gates the
repair; why remount-rw is the ONE repair shipped in v1 — the owner's
remount-as-elevated ruling; print-only fstab guidance and why the Disks app
is named instead of hand-editing; the never-chmod ruling — this module makes
no permission grants at all; the keep-record-on-remount-failure choice so
undo can still restore read-only; the stub test strategy and its honest
limit — real mount/remount behavior on Mint is owner acceptance); test
results per §10 layer with exact commands and outcomes; safety statement
"the only elevated operations are the confirmed remount-rw and its undo
remount-ro via lib/elevate.sh; fstab is never written; chmod never runs;
all tests run against stub binaries that never remount anything"; what the
owner should try on Mint (plug an e-reader in; if it lands read-only:
`./butler` → Book access doctor → accept the remount → write a test file →
`[u]ndo` to restore read-only); breaking changes (none); migration notes
(none). Describe only this PR's own changes. Include
`#### Session Irregularities` per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only (interfered with following this prompt AND
cost >~10 min / blocked progress / required a workaround / reveals a
recurring blind spot). If none significant, write exactly
`None significant`. If significant: Category | Symptom | Impact | Workaround
| Hardening candidate, 3–6 lines total. If you used the branch-substitution
rule (§4 fact 9), one line noting it belongs here. This report does not
affect the MERGE/REVISE verdict unless it reveals a missing deliverable.
