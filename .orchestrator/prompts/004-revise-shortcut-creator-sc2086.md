# 004 — REVISION: desktop-shortcut-creator SC2086 gate exposure

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/004-revise-shortcut-creator-sc2086.md > /tmp/task.md
```

Read this file from `/tmp`. Do not check orchestrator paths into the
worktree. Do not use `origin/arena/01a0abf2-mintbutler` or `FETCH_HEAD`.
Never commit this file. Never push to the orchestrator branch
`arena/01a0abf2-mintbutler`. HALT and report if this file is empty or the
title does not match "004 — REVISION".

## TASK: REVISION / FIX FOR PR #3

SUPERSEDES: .orchestrator/prompts/003-desktop-shortcut-creator.md
(revision of its delivered PR; the original prompt documents the full task).

## BRANCH (continue on it, do not start fresh)

```bash
git fetch --depth 50 origin +arena/01a0ac62-mintbutler:refs/remotes/origin/_resume
git checkout -B arena/01a0ac62-mintbutler refs/remotes/origin/_resume
```

The PR branch is `arena/01a0ac62-mintbutler` (the session-pinned branch used
for task 003). If YOUR runner pins you to a different branch, cherry-pick is
NOT available to you — instead HALT and report; do not re-create the work.

## FAILED ACCEPTANCE CRITERIA

- From prompt 003 §10 LINT_COMMAND and task 002's gate contract: modulelint
  must stay green wherever its optional tools exist. The gate treats
  shellcheck SC2086 (unquoted variable expansion) as a HARD FAIL when
  shellcheck is installed. The delivered module contains one unquoted
  expansion, so on any shellcheck-equipped machine
  `bin/modulelint desktop-shortcut-creator` would fail this module.

## REGRESSIONS / DEFECTS FOUND

- `modules/desktop-shortcut-creator/module.sh`, in the Custom-mode
  test-launch block (find with: `grep -n 'setsid' modules/desktop-shortcut-creator/module.sh`):

  ```bash
  setsid ${launch_cmd} </dev/null >/dev/null 2>&1 &
  ```

  `${launch_cmd}` is deliberately word-split here, but that is exactly
  SC2086. No `shellcheck disable` directive justifies it.

## REQUIRED ACTIONS

1. Replace the unquoted expansion with shellcheck-clean word splitting that
   preserves identical behavior, e.g.:

   ```bash
   local -a launch_args=()
   read -r -a launch_args <<< "${launch_cmd}"
   setsid "${launch_args[@]}" </dev/null >/dev/null 2>&1 &
   ```

   (An empty `launch_args` cannot occur — `launch_cmd` derives from a
   required, validated Exec — but guard anyway if you prefer; a plain
   `# shellcheck disable=SC2086` with a one-line justification comment is
   also acceptable if you keep the split form. Prefer the array form.)
2. Sweep the rest of `modules/desktop-shortcut-creator/module.sh` for any
   other unquoted expansions and fix them the same way; introduce no new
   disable directives beyond an explicitly justified one.
3. Re-run the original section-10 test plan:
   - `bash tests/run-tests.sh` — all stages (a–r) must pass, exit 0;
   - `bin/modulelint desktop-shortcut-creator` — exit 0 with PASS;
   - `./butler --scan` — exit 0;
   - EOF refusal still works:
     `printf '' | HOME=$(mktemp -d) bash modules/desktop-shortcut-creator/module.sh run`
     exits 1 with the plain "interactive input" stderr line.
   Record any skip and its reason.
4. Run lint: `bash -n modules/desktop-shortcut-creator/module.sh` (and
   `shellcheck` on it if installed in your environment — record the outcome).

## PUSH CADENCE

- The branch is already published. Do NOT rebase it.
- Sync with: `git fetch --depth 50 origin +main:refs/remotes/origin/main && git merge --no-edit origin/main`
- If the sync refuses with "refusing to merge unrelated histories", halt
  and report. Never pass `--allow-unrelated-histories`.
- Commit and push after each required action above. One command, the
  universal checkpoint form:

  ```bash
  git add -A && (git diff --cached --quiet || git commit -qm "chore: wip <sub-task>") && git push -qu origin arena/01a0ac62-mintbutler
  ```

  Conventional Commits subjects; `chore: wip …` is the checkpoint form.
- Never push to the orchestrator branch. Never force-push.
- If the push is rejected non-fast-forward, halt and report. Do not
  `git pull`. That is a base mismatch, not an environment failure.
- If GitHub auth fails with HTTP 401/403 "Bad credentials", ask the operator
  via `ask_user` with an option reading exactly `I reconnected GitHub —
  retry now`; do not improvise credentials.

## DO NOT TOUCH

- Everything else in the PR: `lib/ask.sh`, `lib/picker.sh`,
  `lib/desktop-entry.sh`, `lib/manifest.sh`, `lib/menu.sh`, `butler`,
  `bin/modulelint`, the spec amendments, the tracker update, and all harness
  stages — they were reviewed and approved.
- Do not change behavior: the test-launch must still launch exactly the
  recorded Exec, detached, only after an explicit yes.
- No new features, no refactors beyond the fix.

## CONTEXT

- Original prompt: `.orchestrator/prompts/003-desktop-shortcut-creator.md`
  (fetch it the same way if you need the full task background).
- The PR description claimed: 51/51 harness assertions passing, modulelint
  PASS, shellcheck absent in the authoring sandbox.
- The review verified all of that independently; this revision addresses the
  single finding above and nothing else.
- Update the PR description afterwards: add a short "Revision 1" note
  stating the SC2086 fix and the re-run results; keep
  `#### Session Irregularities` current (append, don't rewrite).
