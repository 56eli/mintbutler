# 001 — butler core: menu script, module discovery, flags

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/001-butler-core-discovery.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "001 — butler core".

## 1. TASK TITLE AND SCOPE

Implement the core `butler` menu script with module discovery, the shared
`lib/` helpers it needs, the four CLI flags, a zero-dependency test harness,
and bootstrap the canonical project tracker. Complete this in ONE pull
request.

## 2. REQUIRED READING ORDER

Read these before changing anything, in this order:

1. `docs/MODULE_SPEC.md` — the contract. Sections §1 (layout), §2 (manifest),
   §4 (menu behavior) are the law for this task; §3 and §5 define what later
   tasks will build against your extension points.
2. `README.md` — "The safety contract (non-negotiable)" is product law.
3. `docs/VISION.md` — the yardstick: "My trusted chore box: I press a number,
   the thing just works, and nothing I didn't ask for happened."
4. `git log --oneline -5` — commit style. Confirm, do not copy: the repo has a
   single commit ("Add files via upload"); there is NO established convention,
   so use Conventional-Commits-style subjects (`feat: …`, `chore: wip …`).

`docs/PROJECT_STATE.md` does not exist on `main` yet — this task creates it
(deliverable 6).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency, terminal-native toolbox for Linux Mint 22:
one `butler` script lists module-based chores as a numbered menu; modules are
drop-in folders under `modules/`. Nothing exists yet except the three spec
documents — you are writing the first code in this repository.

**Owner vision context:** this task delivers the "I start it, it shows
Tasks: 1) …, 2) …" experience from `docs/VISION.md` — instant,
understandable, safe by construction. Everything later (validator, seed
modules) plugs into what you build here.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

Treat these as settled — do not re-derive or re-litigate them:

1. **Manifest YAML subset.** The parser supports EXACTLY the fields documented
   in MODULE_SPEC §2: `title` (single line), `description` (`>-` folded
   block), `risk` (`low`|`elevated`), `undo` (`true`|`false`), `needs`
   (inline list `[]` or `[a, b]`), `order` (optional int), `platform`
   (optional). An unknown field or unparseable value makes the manifest
   *broken* (menu lists the module as broken, never crashes).
2. **Sorting:** by `(order, slug)`; modules without `order` sort after all
   ordered ones; ties by slug. Menu numbers are positions, recomputed each
   scan.
3. **Exact menu shape** (MODULE_SPEC §4 — confirm against the file, do not
   copy from here): header `mintbutler — Tasks:`, entries `  1) Title` with
   `⚠ elevated` badge for elevated modules, prompt line
   `Select a task number (or: q quit  /search  r refresh):`.
4. **Selection flow:** clear screen, show title, description, risk badge, and
   an undo statement (`Undo: available` or, for `undo: false`,
   `Undo: not available — the module description says so`), then the action
   menu `[d]ry-run  [r]un  [u]ndo  [b]ack`. Hide the `[u]ndo` entry when the
   manifest says `undo: false`.
5. **Plan before do:** pressing run shows the module's `plan` output first,
   then asks `y/N` confirmation for `risk: low`, or requires typing the
   module's slug exactly for `risk: elevated`. This realizes README rule 3
   ("Dry-run before do") and the spec's typed-confirmation rule.
6. **Dispatch contract:** the menu runs `bash modules/<slug>/module.sh <action>`
   with CWD = repo root and environment `MINTBUTLER_MODULE_DIR` (absolute
   path of the module folder), `MINTBUTLER_MODULE_SLUG`, and
   `MINTBUTLER_LIB_DIR` (absolute path of `lib/`). Module stdout passes
   through to the user; non-zero exit shows the module's stderr line in plain
   language. Actions used now: `describe`, `plan`, `dry-run`, `run`, `undo`.
7. **`--run <slug>`:** non-interactive dispatch honoring the same plan+confirm
   gate; `--dry-run` selects the `dry-run` action. If elevated confirmation
   is needed but stdin is not a TTY, refuse with a plain one-line message,
   exit 1, and suggest `--dry-run`.
8. **`--scan`:** executes `bin/modulelint` if it exists; if it does not exist
   yet, print one plain line to stderr (`modulelint not found at
   bin/modulelint`) and exit 1. (`bin/modulelint` arrives in task 002 —
   expected-absent here.)
9. **Search filter:** an input line starting with `/` filters the numbered
   list (case-insensitive substring over title and slug, renumbered); `/`
   alone clears the filter. `r` rescans; `q` and Ctrl-C quit cleanly
   (`trap` INT).
10. **Colors:** ANSI only when stdout is a TTY; plain output otherwise
    (SSH/pipe-safe). No escape bytes may appear in piped output.
11. **Missing/empty `modules/`:** the menu renders with a plain hint
    (`(no modules found)`) and does not crash. Broken manifests are listed at
    the bottom as `(broken — excluded)` per spec §4.
12. **Tests use no production hooks:** the harness copies `butler` + `lib/` +
    fixture modules into a temp directory and runs the real script there. Do
    NOT add env-var overrides or flags to `butler` for testing purposes.
13. **Module-side `ask`/`elevate` helpers do NOT ship in this PR** — they
    arrive with the first seed module (task 003). You only ship the menu-side
    plumbing described above.
14. **Owner acceptance ruling (2026-09-16, binding):** every command the
    owner may run to accept this PR must be non-destructive on a live Linux
    machine — "running them on linux for the first time has no accidents".
    Core butler is read-only: it scans, renders, and dispatches; it writes
    nothing itself.

**Scope boundaries:** do not create `bin/modulelint` (task 002), do not
create anything under `modules/` (tasks 003/004), do not touch
README/VISION/MODULE_SPEC, no CI, no new dependencies, no sudo, no network
access anywhere in the code.

**Expected-absent at delivery:** `bin/`, `modules/`. If either exists when
you finish, HALT and report — do not delete, do not work around.

## 5. CORE OBJECTIVE

A user can clone the repo, run `./butler`, see the numbered task list from
whatever lives in `modules/`, select an entry, read what will happen, and run
dry-run/run/undo with the confirmation gates above; power users can use
`--list`, `--run <slug> [--dry-run]`, `--scan`, `--help`. Broken modules
never crash the menu. All of it proven by a repeatable zero-dependency test
harness.

**Done criteria:** all deliverables in §6 exist; `bash tests/run-tests.sh`
exits 0; `bash -n` passes on every script; shellcheck (if installed) reports
no errors; the interactive menu, piped output, and all four flags behave per
§4 rulings; `docs/PROJECT_STATE.md` exists with the exact §6 content;
worktree clean; everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `butler` — main entry script, executable (`chmod +x`), bash.
2. `lib/ui.sh` — TTY color detection, headings, risk badge rendering,
   plain-language error output.
3. `lib/manifest.sh` — strict parser for the §2 manifest subset; returns
   broken status on unknown fields/unparseable values.
4. `lib/menu.sh` — module scan, light validation, `(order, slug)` sort,
   numbered rendering incl. broken section; search-filter support.
5. `lib/confirm.sh` — y/N and typed-slug confirmation helpers.
6. `tests/run-tests.sh` — zero-dependency harness (stages listed in §10).
7. `tests/fixtures/modules/{alpha-fixture,beta-fixture,gamma-fixture,broken-fixture}/`
   — fixture modules for the harness: `beta-fixture` `order: 1`,
   `alpha-fixture` `order: 10`, `gamma-fixture` no `order`, `broken-fixture`
   with an invalid manifest. Each valid fixture implements
   `describe`/`plan`/`dry-run`/`run`, prints plain lines, and writes nothing.
   Fixtures live ONLY under `tests/fixtures/` — never under `modules/`.
8. `docs/PROJECT_STATE.md` — canonical tracker bootstrap, EXACTLY this
   content:

```markdown
# Project State

Canonical project tracker.

## 1. Owner Vision & Scope Boundaries
- **Product Vision:** "My trusted chore box: I press a number, the thing just works, and nothing I didn't ask for happened." — a zero-dependency terminal toolbox for Linux Mint 22; clone, `./butler`, pick a number.
- **Scope Boundaries (Non-Goals):** No GUI. No daemons, background services, auto-updates, or telemetry. No config sprawl (zero-config is the norm). No dependency pile (fresh Mint 22 is the whole platform). No `sudo` in the happy path. No runtime-generated commands — reviewed scripts only.

## 2. Architectural Invariants
- Safety contract (README, non-negotiable): no runtime command generation; user-level first; dry-run before do; undo or say so; idempotent where sensible; zero dependencies.
- `docs/MODULE_SPEC.md` is the binding contract for `modules/` and the menu; the manifest YAML subset is limited to its §2 fields.
- Menu numbers are positions recomputed at scan time; folder slugs are stable identities.
- Owner acceptance commands must be non-destructive on a live Linux machine (owner ruling 2026-09-16).

## 3. Settled Decisions & Rationale
- Project name is `mintbutler` — confirmed by owner 2026-09-16; no rename.
- CI is deferred for now (owner 2026-09-16); `modulelint` is the local gate.
- Verification split (owner 2026-09-16): sandbox verification (syntax, shellcheck, harness, later modulelint) plus owner manual acceptance on Mint 22.2; all owner-run commands must be non-destructive.

## 4. Active Milestone & Current State
- **Active Milestone:** v0.1 — menu script + module discovery + modulelint + the two seed modules.
- **Current State:** specs complete (README, VISION, MODULE_SPEC); core menu script landed via PR for task 001.
- **Immediate Next Task:** task 002 — `bin/modulelint` contract validator.
```

Modify: nothing else. Do not reformat or touch any existing file.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

Each line ends with a checkpoint commit + push (§9):

1. `lib/ui.sh` — color/TTY detection and render helpers → commit + push
2. `lib/manifest.sh` — strict manifest parser → commit + push
3. `lib/confirm.sh` + `lib/menu.sh` — scan/sort/render/filter → commit + push
4. `butler` — arg parsing, interactive loop, selection flow, confirmation
   gates, `q`/`r`/Ctrl-C, flags → commit + push
5. `tests/fixtures/` + `tests/run-tests.sh` — harness green → commit + push
6. `docs/PROJECT_STATE.md` — exact §6 content → commit + push
7. Final pass: `bash -n` all scripts, shellcheck (if installed), full harness,
   smoke checks of §14, clean tree → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/butler-core-discovery`
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only, never
  a base or target.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip — being on a branch
named `feature/butler-core-discovery` is not evidence it is the remote one:

```bash
git fetch --depth 50 origin +feature/butler-core-discovery:refs/remotes/origin/_resume
git checkout -B feature/butler-core-discovery refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/butler-core-discovery origin/main
```

Do not skip the fetch because you appear to be on the target. Do not commit
on `main`. "couldn't find remote ref" here is not an environment failure.

## 9. WORK PERSISTENCE AND PUSH CADENCE

Checkpoint after each sub-task in §7, before any long or risky operation, and
at the end. Your session can expire without warning; unpushed work is lost.
There is no time-based rule — §7 is your push schedule.

A checkpoint is ONE command — first push, later pushes, and the
nothing-to-push no-op are all the same form. Do not run status/diff
inspections around it:

```bash
git add -A && (git diff --cached --quiet || git commit -qm "chore: wip <sub-task>") && git push -qu origin feature/butler-core-discovery
```

Match the project's commit convention: none is established (confirm with
`git log`), so Conventional-Commits subjects are the standard;
`chore: wip <sub-task>` is the checkpoint form.

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

- Language: bash as shipped on Linux Mint 22 (bash 5.x). Every script starts
  `#!/usr/bin/env bash` and `set -euo pipefail`. Quote every expansion. No
  aliases. Follow the shell-style rules in MODULE_SPEC §3.
- Zero dependencies: nothing beyond a fresh Mint 22 install — no `jq`, no
  Python, no packages. awk/sed/grep from coreutils/standard Mint are fine.
- `butler` resolves its own directory (`BASH_SOURCE`) and finds `lib/` and
  `modules/` relative to it, so the harness's temp-dir copy works unchanged.
- Tests: the harness is plain bash, no framework. Stages, each asserting on
  real output of the real script run from a temp copy with fixture modules:
  (a) `--list` prints `beta-fixture`, `alpha-fixture`, `gamma-fixture` in
  exactly that order and flags `broken-fixture` as broken/excluded;
  (b) `--run alpha-fixture --dry-run` exits 0 and prints the fixture's plan,
  and the temp HOME tree is byte-identical before/after (no writes);
  (c) piped menu output contains no ANSI escape bytes;
  (d) `printf 'q\n' | ./butler` exits 0;
  (e) `--scan` exits 1 with the plain modulelint-missing line (bin/ absent);
  (f) `--help` exits 0 and mentions all four flags.
- TEST_COMMAND: `bash tests/run-tests.sh`
- INTEGRATION_TEST_COMMAND: not applicable as a separate layer — the harness
  runs the real `butler` end-to-end (stages b and d exercise the full
  scan→parse→render→dispatch path); there is no component boundary inside one
  bash script beyond what those stages cross.
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh` (the only suite that exists
  at v0.1 — risk-based equivalent is the same run)
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — the harness directly asserts each
  discovery/sort/dispatch/flag branch; no bash mutation tooling exists under
  the zero-dependency constraint
- LINT_COMMAND: `bash -n butler lib/*.sh tests/run-tests.sh` (always) plus
  `shellcheck butler lib/*.sh tests/run-tests.sh` when installed — confirm
  with `command -v shellcheck`; advisory locally per MODULE_SPEC §5, zero
  findings expected
- BUILD_COMMAND: not applicable — interpreted bash, no compile step

## 11. SAFETY AND COMPATIBILITY RULES

- Core butler performs ZERO filesystem writes (scanning, rendering, and
  dispatching only). No sudo/pkexec anywhere. No `eval`, no `curl|bash`,
  no command strings built from input — these are hard rejects.
- Nothing may break that already works: the repo currently has no code, so
  the constraint is forward-looking — your extension points (§4 fact 6) are
  the contract tasks 002–004 will build against; keep them exactly as
  specified.
- Owner-acceptance safety (binding ruling, §4 fact 14): `./butler`,
  `--list`, `--help`, `--scan`, menu navigation, `q`, and any fixture
  dry-run must be safe to run on a live machine with zero side effects.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- Do NOT create `bin/modulelint` or anything under `modules/` (expected-
  absent; if present at delivery, halt and report).
- Do NOT ship module-side `ask`/`elevate` helpers (task 003).
- Do NOT add CI workflows, LICENSE, .gitignore, packaging, or config files.
- Do NOT modify README.md, docs/VISION.md, or docs/MODULE_SPEC.md — if you
  believe one of them is wrong, say so in the PR description instead.
- Do NOT add dependencies or network calls.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Artifacts: if this task produces a build artifact, do not commit it
  anywhere; write its path and sha256 into the PR description and stop.
  Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

Before opening the PR, all of these must pass:

1. `bash tests/run-tests.sh` — exit 0, every stage asserts successfully.
2. `bash -n butler lib/*.sh tests/run-tests.sh` — no syntax errors.
3. `shellcheck butler lib/*.sh tests/run-tests.sh` — zero findings if
   shellcheck is installed; if not installed, record that in the PR
   description.
4. `./butler --help` — exit 0.
5. `printf 'q\n' | ./butler` — exit 0, no escape bytes in the output.
6. `./butler --scan` — exit 1 with the plain modulelint-missing line.
7. Worktree clean (`git status --short` empty), all work pushed.
8. `bin/` and `modules/` still absent.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: butler core menu script with module discovery`. The description
must contain: a summary of what was built; the design rationale (why the
manifest parser is a strict awk/bash subset parser; why the test harness
copies into a temp dir instead of adding hooks; how the confirmation gates
map to the safety contract); test results per layer of §10 with exact
commands and outcomes; the safety statement "Core butler performs zero
filesystem writes, contains no sudo/eval/curl|bash, and every owner-
acceptance command is non-destructive on a live machine"; breaking changes
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
3–6 lines total. Do not pad with trivial single retries or expected platform
behavior. This report does not affect the MERGE/REVISE verdict unless it
reveals a missing deliverable.
