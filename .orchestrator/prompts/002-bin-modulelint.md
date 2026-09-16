# 002 — bin/modulelint: the module contract validator

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/002-bin-modulelint.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "002 — bin/modulelint".

## 1. TASK TITLE AND SCOPE

Implement `bin/modulelint`, the mechanical gate of MODULE_SPEC §5: it
validates manifests, script syntax and actions, scans for forbidden patterns,
and executes each module's `dry-run`/`run`/`undo` inside a sandbox HOME with
filesystem-diff containment checks; wire its results through the existing
`./butler --scan` path; extend the test harness; update the canonical
tracker. Complete this in ONE pull request.

## 2. REQUIRED READING ORDER

Read these before changing anything, in this order:

1. `docs/MODULE_SPEC.md` — §5 is the law for this task; §1–§3 define what you
   validate.
2. `butler` — note `butler_scan()` (already `exec`s `bin/modulelint`; you must
   NOT need to change it) and how `lib/` is sourced/resolved.
3. `lib/manifest.sh` — the strict §2-subset parser you will REUSE, not fork.
4. `tests/run-tests.sh` + `tests/fixtures/modules/` — the harness you extend;
   note that `broken-fixture` has an invalid manifest and must FAIL lint,
   while `alpha`/`beta`/`gamma` must PASS.
5. `docs/PROJECT_STATE.md` — the canonical tracker you update (§6 deliverable).
6. `README.md` — the safety contract; `docs/VISION.md` — the yardstick.
7. `git log --oneline -5` — confirm, do not copy: Conventional-Commits-style
   subjects are the established convention (e.g. `feat: butler core menu
   script with module discovery`).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22: one
`butler` menu script plus drop-in modules under `modules/`. Task 001 landed
the core menu, `lib/` helpers, and the test harness. You now build the
mechanical teeth of the review gate: every future module PR is judged by
`modulelint` green plus human review, per MODULE_SPEC §5 ("The gate for every
module PR = modulelint green + orchestrator's independent read of the exact
commands + owner merge").

**Owner vision context:** the owner does not trust stray snippets; modulelint
is what makes "everything this tool can do was reviewed in the open"
mechanically enforceable — safe by construction.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

Treat these as settled:

1. **Reuse the parser.** `bin/modulelint` sources `lib/manifest.sh` (resolve
   it relative to the script's own location: `bin/../lib`). Do not fork or
   duplicate manifest parsing. Manifest outcomes from `manifest_parse` map
   1:1 to lint results (`MANIFEST_BROKEN=1` → FAIL with `MANIFEST_ERROR`).
2. **CLI:** `bin/modulelint` (scan every folder under `modules/`),
   `bin/modulelint <slug>` (scan one). Output is human-readable: one
   `PASS <slug>` or `FAIL <slug>: <plain reason>` line per module, then a
   summary line. Exit 0 iff every scanned module passes. A missing/empty
   `modules/` prints `(no modules found)` and exits 0 (that is not a lint
   failure).
3. **Check 1 — manifest & slug (spec §5.1):** folder name matches
   `^[a-z0-9-]+$`; manifest exists, parses via the shared parser, required
   fields present, `risk` ∈ {low, elevated}, `undo` ∈ {true, false}.
4. **Check 2 — actions & syntax (spec §5.2):** `bash -n module.sh` must pass;
   then in the sandbox HOME invoke each declared action (`describe`, `plan`,
   `dry-run`, `run`; `undo` only when `undo: true`) — each must exit 0 except
   `run`/`undo`, which may exit non-zero ONLY with a non-empty plain-language
   stderr line. Every invocation runs under `timeout 30` when the `timeout`
   binary exists (skip the wrapper with an advisory note if it does not); a
   timeout is a FAIL. Modules must not prompt interactively — stdin is
   `/dev/null`.
5. **Check 3 — forbidden patterns (spec §5.3), hard fail:** word-boundary
   `eval`; the fetch-and-execute family (`curl`/`wget` output piped into
   `sh`/`bash`/`zsh`, including `curl ... | sudo bash`); `rm -rf` whose
   target is not a quoted path beginning `"$HOME"`/`"${HOME}"` (anything
   else fails — the strict reading of "clearly scoped"); `sudo` or `pkexec`
   anywhere in a `risk: low` module. Unquoted variable expansions are
   enforced mechanically ONLY when `shellcheck` is installed (run it, treat
   SC2086 findings as hard fails, other findings as advisory lines); when
   shellcheck is absent print an explicit advisory line saying the
   unquoted-expansion check was skipped for that reason — do not attempt a
   home-grown regex detector. Literal absolute write targets outside `$HOME`
   and `/tmp` (redirections, `cp`/`mv`/`install`/`tee`/`mkdir -p` with a
   leading `/` path): hard fail for `risk: low`; advisory for `elevated`
   (the elevate-helper pattern lands in task 003).
6. **Checks 4+5 — sandbox execution (spec §5.4–5.5):** create one sandbox per
   module run: a fresh `mktemp -d` root containing an empty `home/`; set
   `HOME=<home>`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`,
   `XDG_CACHE_HOME` all inside the sandbox; also pass
   `MINTBUTLER_MODULE_DIR`, `MINTBUTLER_MODULE_SLUG`, `MINTBUTLER_LIB_DIR`
   exactly as `butler` does; CWD = repository root. Snapshot the sandbox
   (`cp -a`) before each action, diff after: `dry-run` must exit 0, print a
   non-empty plan, and leave the sandbox byte-identical; `run` (and `undo`
   after it when declared) must never modify anything outside the sandbox
   home. When `strace` is installed, additionally wrap the `run` execution
   and fail on any write/open-for-write syscall path outside the sandbox;
   when absent, note it in an advisory line. Clean up the sandbox after each
   module. modulelint itself must not write outside its sandboxes and
   `/tmp`.
7. **Order of checks:** manifest/slug first, then syntax, then patterns, then
   sandbox execution; report the first failing category per module and stop
   executing that module (never run a module whose manifest or syntax
   failed).
8. **`butler` wiring already exists:** `butler_scan()` execs `bin/modulelint`.
   After this PR, `./butler --scan` on a repo with fixtures-style broken
   modules exits 1, and on an empty/absent `modules/` exits 0 with
   `(no modules found)`. Do not modify `butler` unless a genuine defect in
   `butler_scan()` blocks you — if so, stop and report instead of changing it
   silently.
9. **Owner acceptance ruling (2026-09-16, binding):** every command the owner
   may run to accept this PR must be non-destructive on a live Linux machine.
   `bin/modulelint` and `./butler --scan` only read module files and execute
   sandboxed actions with stdin `/dev/null` — they must never touch the real
   HOME or system paths.
10. **Branch-pinning rule (hardened from task 001's session report):** if your
    runner environment pins your session to a specific branch (e.g. an Arena
    session branch) and forbids creating another, use the pinned branch as
    your target branch: branch from `main`, commit and push there, open the PR
    from it, and substitute the pinned branch name in §9's push command. Base
    is always `main`. Never push to `arena/01a0abf2-mintbutler` regardless.
    Record the substitution under `#### Session Irregularities` if you use it.

**Scope boundaries:** do not create anything under `modules/` (tasks 003/004),
do not create module-side `ask`/`elevate` helpers (task 003), do not modify
`lib/manifest.sh` or `lib/menu.sh` (report if you believe they are wrong),
no CI workflows, no new dependencies, no network access, no sudo.

**Expected-absent at delivery:** `modules/`. If it exists when you finish,
HALT and report — do not delete, do not work around.

## 5. CORE OBJECTIVE

`bin/modulelint` mechanically enforces MODULE_SPEC §5 for any current or
future module: on the test fixtures it prints `PASS` for
`alpha-fixture`/`beta-fixture`/`gamma-fixture` and `FAIL` for
`broken-fixture`, exiting 1; on a single passing slug it exits 0;
`./butler --scan` delegates to it; everything is proven by the extended
harness; the tracker names task 003 as next.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exits 0 including the new lint stages; `bash -n` passes on every changed or
new script; shellcheck clean if installed; `./butler --scan` exits 0 with
`(no modules found)` in the real repo (modules/ absent); worktree clean;
everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `bin/modulelint` — executable bash script implementing §4 checks 1–5 with
   the §4.2 CLI/output contract.

Modify:

2. `tests/run-tests.sh` — add lint stages running in a SEPARATE stage
   directory (copy `butler`, `lib/`, `bin/`, and the fixtures there; keep the
   existing stages untouched, in particular stage (e), which depends on `bin/`
   being ABSENT from its own stage):
   - (g) `bin/modulelint` over all fixtures: exit 1; output contains
     `PASS alpha-fixture`, `PASS beta-fixture`, `PASS gamma-fixture`, and
     `FAIL broken-fixture`;
   - (h) `bin/modulelint alpha-fixture`: exit 0;
   - (i) `./butler --scan` in the lint stage: exit 1 (broken fixture fails);
   - (j) modulelint leaves the real repo and the real HOME untouched:
     snapshot the lint stage directory before, run all fixtures, `diff -r`
     shows only the expected sandboxes were involved (assert the stage tree
     unchanged, ignoring nothing).
3. `docs/PROJECT_STATE.md` — replace its `## 4. Active Milestone & Current
   State` section with EXACTLY:

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** v0.1 — menu script + module discovery + modulelint + the two seed modules.
- **Current State:** core menu script landed (PR #1, merged 2026-09-16); `bin/modulelint` contract validator landed via PR for task 002.
- **Immediate Next Task:** task 003 — seed module `desktop-shortcut-creator` (risk: low, undo: true).
```

   and append one line to its `## 2. Architectural Invariants` list:

```markdown
- Contract validation is mechanical: `bin/modulelint` enforces MODULE_SPEC §5 and reuses the menu's own `lib/manifest.sh` parser (single source of truth for manifests).
```

Modify nothing else. Do not reformat unrelated tracker lines.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

Each line ends with a checkpoint commit + push (§9):

1. `bin/modulelint` skeleton: arg parsing, module discovery, manifest+slug
   check via shared parser, PASS/FAIL/summary output, exit codes → commit +
   push
2. Syntax + action checks (bash -n; sandbox invocation of describe/plan/
   dry-run/run/undo with timeout and stdin /dev/null) → commit + push
3. Forbidden-pattern scan (eval, curl|bash family, rm -rf scoping, sudo in
   low, shellcheck-gated unquoted expansions, absolute write targets) →
   commit + push
4. Sandbox containment: HOME/XDG overrides, snapshot+diff for dry-run/run/
   undo, optional strace pass, cleanup → commit + push
5. Extend `tests/run-tests.sh` with stages (g)–(j) in a separate lint stage
   dir; full harness green → commit + push
6. Update `docs/PROJECT_STATE.md` exactly per §6 → commit + push
7. Final pass: `bash -n` all touched scripts, shellcheck if installed, full
   harness, §14 smoke checks, clean tree → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/modulelint-validator` — EXCEPT per §4 fact 10: if
  your runner pins you to a session branch, use that branch instead and note
  it in the PR's Session Irregularities.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only, never
  a base or target.
- Dependencies: none (PR #1 is already merged into `main`).
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip — being on a branch
named like the target is not evidence it is the remote one:

```bash
git fetch --depth 50 origin +feature/modulelint-validator:refs/remotes/origin/_resume
git checkout -B feature/modulelint-validator refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/modulelint-validator origin/main
```

(If pinned to a session branch per §4 fact 10, substitute its name in both
forms.) Do not skip the fetch because you appear to be on the target. Do not
commit on `main`. "couldn't find remote ref" here is not an environment
failure.

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

The project's convention is Conventional Commits (`git log`);
`chore: wip <sub-task>` is the valid checkpoint form.

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

- Language: bash 5.x as shipped on Mint 22; `#!/usr/bin/env bash`,
  `set -euo pipefail`, quote every expansion. Follow the style of `butler`
  and `lib/*.sh` (they are your reference).
- Zero dependencies: coreutils/awk/sed/grep/diff as on a fresh Mint 22.
  `shellcheck`, `strace`, `timeout` are USED WHEN PRESENT, never required —
  each absence degrades to a clearly printed advisory line, never a crash.
- Sandbox: `mktemp -d` per module; overrides for HOME plus all four XDG_*
  directories; `cp -a` snapshot + `diff -r` containment check; cleanup via
  `trap`. stdin of every module invocation is `/dev/null`.
- Tests: plain-bash stages appended to the existing harness, in their own
  stage directory; no production hooks.
- TEST_COMMAND: `bash tests/run-tests.sh` (now covering stages a–j; stages
  g–j cover the new behavior: fixture verdicts, single-slug mode, --scan
  wiring, containment)
- INTEGRATION_TEST_COMMAND: stages (e) and (i) of `bash tests/run-tests.sh`
  exercise `./butler --scan` end-to-end in both modulelint-absent and
  modulelint-present stage layouts — no separate component boundary exists
  beyond what those stages cross
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh` (the only suite at v0.1)
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — each lint check has a direct
  behavioral assertion via fixtures (a passing fixture proves the check does
  not false-positive; `broken-fixture` plus the harness assertions prove the
  manifest path catches violations); no bash mutation tooling exists under
  the zero-dependency constraint
- LINT_COMMAND: `bash -n bin/modulelint butler lib/*.sh tests/run-tests.sh`
  (always) plus `shellcheck bin/modulelint butler lib/*.sh tests/run-tests.sh`
  when installed (confirm with `command -v shellcheck`)
- BUILD_COMMAND: not applicable — interpreted bash, no compile step

## 11. SAFETY AND COMPATIBILITY RULES

- `bin/modulelint` performs no writes outside `mktemp` sandboxes and `/tmp`.
  No sudo/pkexec anywhere. No `eval`, no `curl|bash`, no network.
- Must not break: all existing harness stages (a)–(f) keep passing unchanged;
  `butler` itself is not modified (see §4 fact 8); `lib/manifest.sh` behavior
  is unchanged (you source it, never edit it).
- Backward compatibility: `./butler --scan`'s documented behavior is extended
  from "modulelint missing → exit 1" to "modulelint present → its verdict".
- Owner-acceptance safety (binding ruling, §4 fact 9): `bin/modulelint`,
  `bin/modulelint alpha-fixture`, and `./butler --scan` must be safe to run
  on a live machine with zero side effects outside `/tmp`.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- Do NOT create anything under `modules/` (expected-absent; halt and report
  if present), no seed modules (tasks 003/004).
- Do NOT create module-side `ask`/`elevate` helpers (task 003).
- Do NOT add CI workflows, packaging, config files, LICENSE, or dependencies.
- Do NOT modify `butler`, `lib/*.sh`, README.md, docs/VISION.md, or
  docs/MODULE_SPEC.md — if you believe one is wrong, say so in the PR
  description instead.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Do NOT invent a home-grown unquoted-expansion detector (§4 fact 5).
- Artifacts: if this task produces a build artifact, do not commit it
  anywhere; write its path and sha256 into the PR description and stop.
  Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

Before opening the PR, all of these must pass:

1. `bash tests/run-tests.sh` — exit 0, every stage (a–j) asserts
   successfully.
2. `bash -n bin/modulelint butler lib/*.sh tests/run-tests.sh` — no syntax
   errors.
3. `shellcheck bin/modulelint butler lib/*.sh tests/run-tests.sh` — zero
   findings if installed; record its absence in the PR description otherwise.
4. `./butler --scan` in the real repo — exit 0 printing `(no modules found)`
   (modules/ is absent here).
5. `bin/modulelint` in a harness-style fixture tree — PASS/FAIL lines and
   exit 1 exactly as stage (g) asserts.
6. Worktree clean (`git status --short` empty), all work pushed.
7. `modules/` still absent.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: modulelint contract validator`. The description must contain: a
summary; design rationale (why the shared manifest parser is sourced rather
than forked; how sandbox containment is enforced and its honest limits —
HOME/XDG override plus diff always, strace only when installed; why
unquoted-expansion enforcement is shellcheck-gated); test results per §10
layer with exact commands and outcomes; the safety statement "modulelint
writes only inside mktemp sandboxes and /tmp, runs modules with stdin
/dev/null, and every owner-acceptance command is non-destructive on a live
machine"; known limitations (shellcheck/strace optional); breaking changes
(none); migration notes (none). Describe only this PR's own changes. Include
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
3–6 lines total. If you used the branch-substitution rule (§4 fact 10), one
line noting it belongs here. Do not pad with trivial single retries or
expected platform behavior. This report does not affect the MERGE/REVISE
verdict unless it reveals a missing deliverable.
