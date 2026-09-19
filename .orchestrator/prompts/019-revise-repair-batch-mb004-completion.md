# 019 — REVISION of PR #16: complete the MB-004 law (option A)

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/019-revise-repair-batch-mb004-completion.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "019 — REVISION of PR #16".

## 1. WHAT THIS REVISION IS

The orchestrator review of PR #16 (repair batch #2) advised **REVISE with
one targeted item**, and the owner chose **option A**: complete the MB-004
law. The new MODULE_SPEC law says a module must never prompt for a y/N or
other safety confirmation itself and that `asks:` counts value questions
only — but two modules still carry in-module y/N apply confirmations. This
revision removes exactly those two prompts and aligns their manifests and
harness stages. NOTHING else in PR #16 is touched. Same target branch as
PR #16 (`arena/01a0b63a-mintbutler`), base stays `main`.

## 2. THE TWO CHANGES (EXACT)

1. **`modules/appimage-installer/module.sh` + `module.yml`:**
   - Remove question 3 of 3 — the `ask_yn "Install this AppImage?"` apply
     confirmation — and its `Nothing changed.` branch. Keep the "About to
     install:" summary block (from/copy/entry lines) as INFORMATIONAL
     output immediately before the install proceeds; renumber/reword the
     surrounding comments ("Question 2 of 2" etc.) so no stale "3 of 3"
     text remains.
   - Manifest: `asks: 3` → `asks: 2` (the two VALUE questions: source
     path, entry name). Change nothing else in the manifest.
   - Update any `describe`/`plan`/`dry-run` text that states the question
     count or mentions the apply confirmation; keep every screen ≤ 23
     lines (modulelint now hard-fails this).
2. **`modules/default-apps-editor/module.sh` + `module.yml`:**
   - Remove question 4 of 4 — the `ask_yn "Apply this change?"` apply
     confirmation — and its `Nothing changed.` branch. Keep the
     current-vs-new listing as INFORMATIONAL output immediately before the
     change proceeds; renumber/reword comments so no stale "4 of 4" text
     remains.
   - Manifest: `asks: 4` → `asks: 3`. Change nothing else.
   - Same ≤ 23-line and text-consistency rule.

Leave EVERYTHING else alone: timeshift-guardian's comment VALUE question
stays; desktop-shortcut-creator's option questions (run-in-terminal,
desktop-copy) are value questions and stay; the MB-001/002/003/005 work,
`lib/*`, `bin/*`, `butler`, README.md, and docs/MODULE_SPEC.md need NO
changes — after option A the existing MODULE_SPEC wording is exactly true.

## 3. HARNESS ALIGNMENT

Adjust ONLY the stages that exercise the removed prompts (confirm, do not
copy; locate with `grep -n "Install this AppImage\|Apply this change\|asks"
tests/run-tests.sh`):

- appimage-installer stages: the happy path (ah) and every scripted-stdin
  drive-through lose their final `y` answer; keep the abort test at the
  FIRST question and the non-interactive `</dev/null` assertions (the flow
  must still exit non-zero having written nothing when stdin closes at the
  first VALUE question). Update any assertion that counted three questions
  or grepped the removed prompt text.
- default-apps-editor stages: same treatment for question 4; the
  happy-path/undo/rollback stages lose their final `y`; first-question
  abort and non-interactive assertions stay in force.
- If any gate stage asserts the `asks:` value of either module, update it
  to the new number.

The suite must remain fully green (`bash tests/run-tests.sh` exit 0;
expect the total count to drop by exactly the number of assertions you
remove — record the new total in the PR description), the stage (by)
tripwire must still show zero real sudo attempts, `bin/modulelint` must
stay 10 passed with the same honest WARNs, and stage (bt)'s 23-line sweep
must still pass for both modules.

## 4. PR HYGIENE

Push the fix as a new commit on the PR's branch (subject e.g.
`fix: MB-004 completion — no in-module safety prompts anywhere (option A)`)
and update the PR #16 description: in the MB-004 section state that the
law is now universal — appimage-installer (`asks: 2`) and
default-apps-editor (`asks: 3`) included — and update the verification
numbers to the new suite total. Do not open a new PR.

## 5. SAFETY AND BOUNDARIES

- Do NOT modify `butler`, `bin/modulelint`, `lib/*.sh`, README.md,
  docs/*.md, other modules, or any stage unrelated to the two removed
  prompts.
- Do NOT push to `arena/01a0abf2-mintbutler`.
- Tests never reach real privilege: the harness's refusing tripwire sudo
  and the modulelint sandbox stubs are the containment contract — if a
  change of yours produces ANY new tripwire hit, HALT and report.

## 6. DONE CRITERIA

1. Both apply prompts gone; both manifests at the new `asks:` values; no
   stale "N of M" text anywhere.
2. `bash tests/run-tests.sh` exit 0, tripwire clean, new total recorded.
3. `bin/modulelint` exit 0 (10 passed, same WARNs).
4. `./butler --scan` exit 0; `./butler --list` unchanged in content.
5. `bash -n` clean over touched scripts; shellcheck clean if installed.
6. Worktree clean, everything pushed to the PR branch, PR description
   updated.
