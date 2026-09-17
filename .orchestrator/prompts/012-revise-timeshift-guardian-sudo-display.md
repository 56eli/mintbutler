# 012 — REVISION: timeshift-guardian sudo-literal display strings

## FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/012-revise-timeshift-guardian-sudo-display.md > /tmp/task.md
```

Read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD`. Do not
`git checkout` orchestrator paths into your worktree. Never commit this file
or anything written to `/tmp`. Never push to `arena/01a0abf2-mintbutler`.
HALT and report if this file is empty or its title does not match
"012 — REVISION: timeshift-guardian".

## TASK: REVISION / FIX FOR PR #10

BRANCH: continue on the existing PR branch — do not start fresh:

```bash
git fetch --depth 50 origin +arena/01a0b18d-mintbutler:refs/remotes/origin/_resume
git checkout -B arena/01a0b18d-mintbutler refs/remotes/origin/_resume
```

SUPERSEDES: none — this repairs the deliverable of
`.orchestrator/prompts/011-timeshift-guardian.md` (read it from the
orchestrator branch with `git show` if you need the original wording).

## FAILED ACCEPTANCE CRITERIA

- Prompt 011 §4 fact 7: "`sudo` appears ONLY via `lib/elevate.sh`;
  `module.sh` contains no `sudo`/`pkexec`/`eval`/`curl|bash` literal."
  The elevated command's display is owned by the shared helper
  (`elevate_command_line`) — the same convention screenshot-studio follows
  and documents.

## REGRESSIONS / DEFECTS FOUND

- `modules/timeshift-guardian/module.sh`, `plan()` step 4 (the line
  `printf '   sudo timeshift --create --comments <comment>\n'`): hardcoded
  `sudo` literal; also shows an unquoted `<comment>` placeholder while the
  command that actually runs wraps the comment in single quotes — the plan
  screen must display the exact command shape.
- `modules/timeshift-guardian/module.sh`, `dry_run()` (the line
  `printf '  sudo timeshift --create --comments <comment>\n'`): same two
  defects.
- Note: `run()` itself is CORRECT — it passes
  `timeshift --create --comments '<comment>'` (no `sudo` prefix) to
  `elevate_run` and displays via `elevate_command_line`. Do not touch it.

## REQUIRED ACTIONS

1. Replace BOTH hardcoded lines with helper-driven display, keeping the
   quoted placeholder so the shown shape matches what actually runs:

   ```bash
   printf '   %s\n' "$(elevate_command_line "timeshift --create --comments '<comment>'")"
   ```

   in `plan()` step 4 (keep the existing 3-space indent of that step line),
   and the same with 2-space indent in `dry_run()`'s exact-commands list.
2. Verify no `sudo`, `pkexec`, or `eval` token remains anywhere in
   `modules/timeshift-guardian/module.sh` (`grep -nE
   '\bsudo\b|\bpkexec\b|\beval\b'` must print nothing).
3. Re-run the original section-10 test plan: `bash tests/run-tests.sh`
   (expect all 228 assertions green — plan/dry-run content assertions
   still hold, they match on `timeshift --create --comments`),
   `bin/modulelint` (expect `5 passed, 0 failed`), `./butler --scan`,
   `./butler --run timeshift-guardian --dry-run` (exit 0, still ≤ 23
   lines), `bash -n modules/timeshift-guardian/module.sh`. Record skips
   and reasons.
4. Lint: `bash -n modules/timeshift-guardian/module.sh lib/elevate.sh
   butler lib/*.sh bin/modulelint tests/run-tests.sh`; shellcheck if
   installed.
5. Note the re-verification in the PR (a short comment or description
   addendum): what changed, and the fresh test-result lines.

## PUSH CADENCE

- The branch is already published. Do NOT rebase it.
- Sync with: `git fetch --depth 50 origin +main:refs/remotes/origin/main &&
  git merge --no-edit origin/main` — if the sync refuses with "refusing to
  merge unrelated histories", halt and report. Never pass
  `--allow-unrelated-histories`.
- Commit and push after each required action above. One command, the
  universal checkpoint form:
  `git add -A && (git diff --cached --quiet || git commit -qm "chore: wip <sub-task>") && git push -qu origin arena/01a0b18d-mintbutler`
- Match the project's commit convention; `chore: wip <sub-task>` is the
  fallback. Never push to the orchestrator branch. Never force-push. If
  the push is rejected non-fast-forward, halt and report — do not
  `git pull`.

## DO NOT TOUCH

- `run()` logic, the manifest, the harness stages (am)–(aq), the tracker
  edit, and every other file in PR #10 — all approved and correct.
- `lib/elevate.sh`, other modules, `butler`, `bin/*`.

## CONTEXT

- The original prompt file was:
  `.orchestrator/prompts/011-timeshift-guardian.md`
- The PR summary claimed: elevated commands displayed through the shared
  helper, no `sudo` literal in the module.
- The actual diff shows: `run()` conforms; `plan()` and `dry_run()` carry
  two hardcoded `sudo timeshift --create --comments <comment>` display
  lines (reviewer grep, 2026-09-17).

## Session Irregularities

Report in the PR under `#### Session Irregularities` per the threshold;
`None significant` if none.
