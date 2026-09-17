# 006 — batch #1 kickoff: menu-ordering convention, docs alignment, backlog stub

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/006-batch1-convention-docs.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "006 — batch #1 kickoff".

## 1. TASK TITLE AND SCOPE

Documentation-only kickoff for owner-approved module batch #1: publish the
binding menu-ordering convention with the final unique order table, align
README/MODULE_SPEC/tracker with the cancelled android-file-transfer seed,
record the batch and its rulings in the tracker, and add the
post-update-doctor backlog stub row. No code changes. Complete this in ONE
pull request.

## 2. REQUIRED READING ORDER

1. `docs/PROJECT_STATE.md` — the tracker; your main deliverable.
2. `README.md` — the "Seed modules" and "Roadmap" sections you will align.
3. `docs/MODULE_SPEC.md` — §2 manifest (the `needs:` example line you swap).
4. `modules/desktop-shortcut-creator/module.yml` — confirm `order: 20`
   (confirm, do not copy); NO change needed there.
5. `git log --oneline -5` — Conventional Commits convention.

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22; v0.1 core
(menu, discovery, modulelint gate, desktop-shortcut-creator v1) is on `main`.
The owner cancelled the android-file-transfer seed before implementation
(2026-09-16: "I don't need adb phone mounting and file transfer functionality
anymore, you can remove it") and then approved module batch #1 — nine modules,
one reviewed PR each. This task makes the repository's docs match both facts
("docs never drift from reality" is the owner's standing ruling) and pins the
menu-ordering convention every batch module will declare in its manifest.

**Owner vision context:** the menu is the product surface; its ordering is a
product decision, so the convention and the final unique order live in the
tracker where every later module task reads them.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

1. **Menu ordering convention (binding, owner via hub 2026-09-16):** FEATURES
   sort first (`order:` 10, 20, 30…); FIXES sort after ALL features
   (`order:` 900, 910…); numbers unique, no ties; individual sorting within
   blocks comes later from the owner.
2. **Final unique order table (owner's batch listing with
   desktop-shortcut-creator fixed at 20, no ties):**
   - 10 appimage-installer (feature)
   - 20 desktop-shortcut-creator (feature — already shipped, manifest
     unchanged)
   - 30 default-apps-editor (feature)
   - 40 multimedia-codecs (feature)
   - 50 screenshot-studio (feature)
   - 60 printer-helper (feature)
   - 70 system-report-pack (feature)
   - 80 timeshift-guardian (feature)
   - 900 book-access-doctor (fix)
   - 910 audio-repair (fix)
3. **Batch build order (owner):** timeshift-guardian → audio-repair →
   appimage-installer → default-apps-editor → multimedia-codecs →
   screenshot-studio → printer-helper → system-report-pack →
   book-access-doctor. Next task after this PR is 007 timeshift-guardian.
4. **book-access-doctor v1 boundary (owner via hub 2026-09-16):** remount may
   be a declared elevated step, but persistent `/etc/fstab` edits are OUT of
   v1 — that module will print the line it would need; it does not write it.
   Record this in the tracker; implement nothing here.
5. **post-update-doctor is a BACKLOG STUB:** it gets a dated tracker row ONLY.
   Do NOT create any `modules/post-update-doctor/` folder or file
   (modulelint rejects shells; the gate stays green).
6. **Cancelled seed:** android-file-transfer was never implemented; all doc
   mentions of it are removed or rewritten per §6, mentioning the
   cancellation where context requires.
7. **Docs-only PR:** no source, manifest, test, or gate changes. The full
   test suite must remain green untouched.
8. **Quote-by-copy rule:** every `old → new` replacement below was transcribed
   from `main` at authoring time; before editing, re-find each target with the
   given `grep` and if the current text differs, HALT and report instead of
   guessing.
9. **Branch-pinning rule:** if your runner pins your session to a branch and
   forbids creating another, use the pinned branch as the target (base stays
   `main`), substitute its name in §8/§9, and record it under
   `#### Session Irregularities`. Never push to
   `arena/01a0abf2-mintbutler`.

**Scope boundaries:** do NOT touch `butler`, `lib/`, `bin/modulelint`,
`modules/`, or `tests/`; do NOT invent order numbers beyond the §4 table; do
NOT implement any module.

**Expected-absent at delivery:** no new folders under `modules/`; if one
appears, HALT and report.

## 5. CORE OBJECTIVE

After this PR, `docs/PROJECT_STATE.md` states the milestone, the convention,
the order table, the batch rulings, and the backlog stub; README no longer
promises the cancelled seed; MODULE_SPEC's example is neutral; the suite is
green; the next agent (task 007) finds everything it needs in the tracker.

**Done criteria:** all §6 edits landed exactly; `bash tests/run-tests.sh`
exit 0 unchanged; `./butler --scan` exit 0; `git status` clean; everything
pushed.

## 6. EXACT DELIVERABLES

Modify `docs/PROJECT_STATE.md`:

1. Append these bullets to `## 3. Settled Decisions & Rationale`:

```markdown
- android-file-transfer seed cancelled by owner before implementation (2026-09-16): "I don't need adb phone mounting and file transfer functionality anymore" — docs aligned in task 006.
- Module batch #1 approved (owner via hub, 2026-09-16): features appimage-installer, default-apps-editor, multimedia-codecs, screenshot-studio, printer-helper, system-report-pack, timeshift-guardian; fixes book-access-doctor, audio-repair; post-update-doctor deferred as a backlog stub. Build order: timeshift-guardian → audio-repair → appimage-installer → default-apps-editor → multimedia-codecs → screenshot-studio → printer-helper → system-report-pack → book-access-doctor. One reviewed PR per module; modulelint + suite green for each.
- Menu ordering convention (binding, 2026-09-16): FEATURES sort first (`order:` 10, 20, 30…), FIXES after all features (`order:` 900, 910…); numbers unique, no ties. Final batch #1 order: 10 appimage-installer, 20 desktop-shortcut-creator, 30 default-apps-editor, 40 multimedia-codecs, 50 screenshot-studio, 60 printer-helper, 70 system-report-pack, 80 timeshift-guardian, 900 book-access-doctor, 910 audio-repair.
- book-access-doctor v1 boundary (2026-09-16): remount may be a declared elevated step, but persistent `/etc/fstab` edits are out of scope — the module prints the line it would need; it does not write it.
```

2. Replace the `## 4. Active Milestone & Current State` section (find with
   `grep -n "Active Milestone" docs/PROJECT_STATE.md`) with EXACTLY:

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** Module batch #1 (owner-approved 2026-09-16): nine modules — seven features, two fixes — one reviewed PR at a time on the v0.1 core.
- **Current State:** v0.1 core complete under owner-revised scope: menu + discovery (PR #1), `bin/modulelint` gate (PR #2), desktop-shortcut-creator v1 (PR #3). The android-file-transfer seed was cancelled by the owner before implementation (2026-09-16). Menu-ordering convention, batch rulings, and docs alignment landed via PR for task 006.
- **Immediate Next Task:** task 007 — module `timeshift-guardian` (elevated / snapshots additive), first in the owner's build order.
```

3. Append at the END of the file:

```markdown

## 5. Module Backlog
- **post-update-doctor** (recorded 2026-09-16 — backlog stub, NOT implemented; deliberately no module folder): post-update regressions — Bluetooth autostart lost, NVIDIA fallback → wrong resolution, monitors mis-detected. Becomes a real task prompt when the chore bites.
```

Modify `README.md`:

4. Replace the "Seed modules (first dispatches)" block (find with
   `grep -n "Seed modules" README.md`) with EXACTLY:

```markdown
Modules shipped and planned:

- **Desktop shortcut creator** (shipped, v0.1) — validated `.desktop`
  entries the right way (user session, no sudo): scan & place installed
  apps or build custom app/folder/URL launchers, trusted desktop copies,
  undo = delete exactly the files it wrote. See
  `modules/desktop-shortcut-creator/`.
- **Module batch #1** (owner-approved 2026-09-16): appimage-installer,
  default-apps-editor, multimedia-codecs, screenshot-studio,
  printer-helper, system-report-pack, timeshift-guardian (features) and
  book-access-doctor, audio-repair (fixes) — one reviewed PR per module.
  The Android file transfer seed was cancelled by the owner before
  implementation.
```

5. In the Roadmap section (find with `grep -n "v0.1 —" README.md`), replace
   the v0.1 line and its continuation so it reads EXACTLY:

```markdown
- v0.1 — menu script + module discovery + `modulelint` + desktop-shortcut-
  creator (the android-file-transfer seed was cancelled by owner) —
  complete.
```

Modify `docs/MODULE_SPEC.md`:

6. In the §2 manifest example comment (find with `grep -n "jmtpfs"
   docs/MODULE_SPEC.md`), replace `e.g. [jmtpfs]` with `e.g. [flameshot]`.
   This is the ONLY MODULE_SPEC change.

Modify nothing else anywhere.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

Each line ends with a checkpoint commit + push (§9):

1. Tracker edits (deliverables 1–3) → commit + push
2. README alignment (deliverables 4–5) → commit + push
3. MODULE_SPEC example swap (deliverable 6) → commit + push
4. Final pass: `bash tests/run-tests.sh` exit 0, `./butler --scan` exit 0,
   `./butler --list` unchanged (desktop-shortcut-creator still listed),
   `git status` clean → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `docs/batch1-convention` — EXCEPT the §4 fact 9
  substitution if your runner pins you to a session branch.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +docs/batch1-convention:refs/remotes/origin/_resume
git checkout -B docs/batch1-convention refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B docs/batch1-convention origin/main
```

(Substitute the pinned branch name if §4 fact 9 applies.) Do not commit on
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
the valid checkpoint form; use `docs: …` for the final subject if you squash
nothing (this repo squash-merges; the PR title carries the subject).

Open ONE pull request at the end. Do not open a draft PR first. Never commit
secrets. Never push to the orchestrator branch.

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

- Docs-only edits: exact markdown as specified; preserve each file's existing
  voice and formatting conventions.
- TEST_COMMAND: `bash tests/run-tests.sh` (must pass UNCHANGED — proves the
  docs-only PR broke nothing)
- INTEGRATION_TEST_COMMAND: not applicable — no code boundary is crossed by
  documentation edits; the untouched suite plus `./butler --scan` exit 0 is
  the end-to-end evidence
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured
- MUTATION_TEST_COMMAND: not warranted — no logic changes
- LINT_COMMAND: not applicable (prose); verify no stray whitespace damage by
  re-grepping each replaced block after editing
- BUILD_COMMAND: not applicable

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: the suite, the gate, the menu, any existing module.
- Do not remove historical PR references (#1/#2/#3) from the tracker.
- The cancellation wording must be factual, not editorial.

## 12. CLEANUP RULES

No commented-out text, no TODO markers, no leftover old paragraphs. Do not
reformat sections you were not told to touch. Do not commit the fetched
prompt file or anything from `/tmp`.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- Do NOT implement, stub, or folder-create ANY module (expected-absent check
  applies).
- Do NOT touch `butler`, `lib/`, `bin/modulelint`, `modules/`, `tests/`.
- Do NOT assign order numbers to anything beyond the §4 fact 2 table.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

1. `bash tests/run-tests.sh` — exit 0, unchanged file.
2. `./butler --scan` — exit 0.
3. `grep -c "jmtpfs" docs/MODULE_SPEC.md` — 0 hits.
4. `grep -n "android-file-transfer\|Android file transfer" README.md` —
   only the cancellation sentence remains.
5. Tracker contains the new §5 backlog section and the order table.
6. Worktree clean, all work pushed.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `docs: batch #1 convention, order table, and cancellation alignment`.
Description: summary of the six edits; rationale (docs never drift from
reality; the convention is a product decision pinned before module PRs
start); test results (suite green unchanged, --scan exit 0); statement that
no code changed; breaking changes (none); migration notes (none). Describe
only this PR's own changes. Include `#### Session Irregularities` per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only (interfered with following this prompt AND
cost >~10 min / blocked progress / required a workaround / reveals a
recurring blind spot). If none significant, write exactly
`None significant`. If significant: Category | Symptom | Impact | Workaround
| Hardening candidate, 3–6 lines total. If you used the branch-substitution
rule (§4 fact 9), one line noting it belongs here. This report does not
affect the MERGE/REVISE verdict unless it reveals a missing deliverable.
