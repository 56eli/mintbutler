# 016 — module: system-report-pack

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/016-system-report-pack.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "016 — module: system-report-pack".

## 1. TASK TITLE AND SCOPE

Ship batch-#1 module `system-report-pack` (feature kind, `risk: low`,
`undo: false` — there is nothing to undo because nothing is ever changed,
`needs: [df, free, uname, uptime]`, `order: 70`, `asks: 0`): a strictly
read-only plain-text system report for Linux Mint 22 — distro + kernel +
hostname + uptime, CPU model/cores/load, memory, disk usage of `/`, and
session type — gathered ONLY from standard Mint tools and printed to stdout
in one clean screen. It installs NOTHING — never inxi, never anything —
and writes nothing anywhere. Complete this in ONE pull request.

## 2. REQUIRED READING ORDER

1. `docs/PROJECT_STATE.md` — §3 conventions and order table (your module is
   `order: 70`, features range), and the batch rulings.
2. `README.md` — safety contract.
3. `docs/MODULE_SPEC.md` — §2 manifest fields, §5 gate. Confirm the risk
   vocabulary (`low|elevated` per `lib/manifest.sh`) with
   `grep -h "^risk:" modules/*/module.yml` — your module is `risk: low`.
4. `modules/printer-helper/module.sh` — newest `risk: low` sibling: module
   structure, manifest style, honest plain-word reporting.
5. `modules/multimedia-codecs/module.sh` — the newest `undo: false`
   sibling: how no-undo is stated plainly in describe/plan.
6. `bin/modulelint` — the gate your module must pass (its sandbox runs
   `run` with stdin `/dev/null`; with the report tools absent from the
   sandbox, your preflight exits 1 before anything else — that is the
   passing lint path).
7. `tests/run-tests.sh` — harness pattern; the stage letter sequence ends at
   `(bi)` — your new stages continue `(bj)` onward (confirm with
   `grep -n "Stage bi" tests/run-tests.sh`; confirm, do not copy).
8. `git log --oneline -5` — Conventional Commits convention (confirm, do
   not copy).

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency terminal toolbox for Linux Mint 22. Eleven
modules are on `main` (latest: printer-helper via PR #13). The
owner-approved batch names this module "system-report-pack (honest system
report, never installs inxi)". Owner ruling that shapes it: the module must
NEVER install inxi or anything else — the report is built from the tools a
stock Mint already ships. Owner vision: one menu entry prints a clean,
copy-pasteable snapshot of this machine — what to send when asking for help.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

1. **Manifest (exact values):** `title: System report pack`;
   `description: >-` folding EXACTLY: "Prints a clean, copy-pasteable
   snapshot of this machine — distro, kernel, hostname, uptime, CPU model
   and load, memory, disk usage of /, and session type — gathered only
   from tools a stock Mint ships and written nowhere. Installs nothing,
   never inxi; there is nothing to undo because nothing is ever changed.";
   `risk: low`; `undo: false`; `needs: [df, free, uname, uptime]`;
   `asks: 0`; `order: 70`.
2. **Zero-side-effect invariant:** `run` performs ONLY reads and prints to
   stdout. No state file, no config, no network, no packages, no
   elevation, no questions. `undo` action does not exist; the module does
   not source `lib/elevate.sh` or `lib/ask.sh`.
3. **Report sections (exact order, plain text, one screen ≤ 23 lines):**
   (i) header line naming the module + generation context;
   (ii) `System:` hostname (`uname -n`), distro pretty-name
   (`/etc/os-release` PRETTY_NAME), kernel (`uname -r`), architecture
   (`uname -m`), uptime (`uptime -p`);
   (iii) `CPU:` model + core count (`lscpu` when available — OPTIONAL tool,
   degrade honestly to `(unavailable)` when missing or failing) and load
   average (`uptime`);
   (iv) `Memory:` total/used/available (`free -h`, the Mem line);
   (v) `Disk /:` size/used/avail/use% (`df -h /`, the single data line);
   (vi) `Session:` `XDG_SESSION_TYPE` and `XDG_CURRENT_DESKTOP` from the
   environment (say `(not set)` when absent).
4. **Data-source rule:** gather ONLY via `uname`, `uptime`, `free`, `df`,
   optional `lscpu`, `/etc/os-release`, and environment variables. No
   `/proc` file parsing, no other binaries, no network. Every gather is
   stubbable via PATH for the tests.
5. **Honest degradation:** any single section whose gather fails or times
   out renders its section header with `(unavailable)` and the report
   still exits 0 — a report with gaps beats no report; EXCEPT the four
   `needs` tools (df, free, uname, uptime): if any is missing at preflight,
   one plain honest stderr line, exit 1, nothing printed to stdout.
6. **Actions:** `describe` one line; `plan` states plainly what the report
   contains and that it reads only, installs nothing (never inxi), writes
   nothing; `dry-run` = plan (there is nothing to preview beyond it). Both
   render in ≤ 23 lines.
7. **Non-interactive behavior (modulelint compatibility):** modulelint runs
   `run` with stdin `/dev/null`. In sandboxes without df/free/uptime the
   preflight exits 1 before anything else — the passing lint outcome. With
   the tools present, `run` just prints the report: no prompts, no writes.
8. **Forbidden-pattern compliance:** `module.sh` contains no
   `sudo`/`pkexec`/`eval`/`curl|bash` literal anywhere; no package-manager
   invocation of any kind; quote every expansion.
9. **Owner acceptance ruling (2026-09-16, binding):** acceptance commands
   are non-destructive: `./butler --list`, `./butler --scan`,
   `./butler --run system-report-pack --dry-run`, menu navigation, and
   `./butler --run system-report-pack` itself (read-only by design). Tests
   use PATH stubs with canned outputs so assertions are deterministic.
10. **Branch-pinning rule:** if your runner pins your session to a branch
    and forbids creating another, use the pinned branch as the target (base
    stays `main`), substitute its name in §8/§9, and record it under
    `#### Session Irregularities`. Never push to
    `arena/01a0abf2-mintbutler`.

**Scope boundaries:** NO package installation (never inxi, never anything);
NO writes of any kind (no state files, no report-to-file option in v1);
NO network activity; NO elevation; NO `/proc` parsing; NO changes to
`butler`, `bin/*`, `lib/*`, other modules, or docs other than the tracker
edit in §6.

**Expected-absent at delivery:** no new module folder other than
`system-report-pack`; no new or modified files under `lib/`; no
`lib/elevate.sh` or `lib/ask.sh` sourcing in the module. If any appears,
HALT and report.

## 5. CORE OBJECTIVE

`system-report-pack` passes `bin/modulelint`; the menu shows it WITHOUT an
elevated badge at its order-70 position; `run` prints the full report in ≤
23 lines using only the allowed data sources; every failure mode degrades
honestly; nothing is ever installed, written, or asked.

**Done criteria:** all §6 deliverables exist; `bash tests/run-tests.sh`
exit 0 including new stages; `bin/modulelint` exit 0; `./butler --scan`
exit 0; `bash -n` clean; shellcheck clean if installed; worktree clean;
everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `modules/system-report-pack/module.yml` — per §4 fact 1.
2. `modules/system-report-pack/module.sh` — executable (git mode 755), per
   §4 facts 2–8.

Modify:

3. `tests/run-tests.sh` — keep all existing stages passing; add stages
   `(bj)`–`(bl)` (letters confirmed from the harness per §2.8) using
   PATH-prefix stubs (`uname`, `uptime`, `free`, `df`, `lscpu`) with canned
   outputs and a canned `/etc/os-release` handled via the module's
   documented seam (see stage comments — the simplest honest seam is an
   env override like `MINTBUTLER_OS_RELEASE_FILE` defaulting to
   `/etc/os-release`, documented in code):
   - (bj) gate + read-only smokes: `./butler --scan` exit 0;
     `bin/modulelint` exit 0 with `PASS system-report-pack`; `./butler
     --list` shows the module WITHOUT an elevated badge; `plan`/`dry-run`
     exit 0, non-empty, ≤ 23 lines, plan contains the exact strings
     `never inxi` (or `never installs`) and `writes nothing` (case-
     insensitive); `run` with stdin `/dev/null` and no report-tool stubs →
     exit 1, one plain stderr line, empty stdout, fake HOME byte-identical;
     module source grep asserts zero `sudo`/`pkexec` literals, no
     `lib/elevate.sh`/`lib/ask.sh` sourcing, and no `apt`/`dpkg -i`/
     package-manager invocation;
   - (bk) full report: all stubs present incl. `lscpu` + canned os-release
     + `XDG_SESSION_TYPE=x11` `XDG_CURRENT_DESKTOP=X-Cinnamon` → exit 0;
     report ≤ 23 lines; contains ALL section headers and at least one
     canned value from each section (hostname, PRETTY_NAME, kernel, uptime,
     CPU model, load, Mem line, df line, session values); fake HOME
     byte-identical; no stub reports any write-like invocation;
   - (bl) honest degradation: same stubs but `lscpu` absent AND `free`
     failing → exit 0; CPU section shows the unavailable marker, Memory
     section shows the unavailable marker, ALL other sections still render
     with their canned values; fake HOME byte-identical.
4. `docs/PROJECT_STATE.md` — replace the `## 4. Active Milestone & Current
   State` section with EXACTLY (verify the old text first with
   `grep -n "Immediate Next Task" docs/PROJECT_STATE.md`; confirm, do not
   copy):

```markdown
## 4. Active Milestone & Current State
- **Active Milestone:** Module batch #1 (owner-approved 2026-09-16): nine modules — seven features, two fixes — one reviewed PR at a time on the v0.1 core.
- **Current State:** v0.1 core complete; batch #1 in progress — screenshot-studio (PR #5), orchestrator spec + `bin/orchestrator-check` gate (PR #6), default-apps-editor (PR #7), appimage-installer (PRs #8/#9), timeshift-guardian (PR #10), audio-repair (PR #11), multimedia-codecs (PR #12), printer-helper (PR #13) landed.
- **Immediate Next Task:** task 017 — module `book-access-doctor` (fix kind: remount-as-elevated OK, persistent fstab edits OUT — print only, targeted grants only — NEVER `chmod -R 777`), ninth and final in the owner's revised build order.
```

   Modify nothing else in the tracker.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

1. `modules/system-report-pack/module.yml` + read-only actions
   (describe/plan/dry-run, ≤23-line screens, never-inxi statement visible)
   → commit + push
2. `module.sh` report sections + preflight + honest degradation → commit +
   push
3. Harness stages (bj)–(bl), full suite green → commit + push
4. Tracker edit → commit + push
5. Final pass: `bash -n` touched scripts, shellcheck if installed,
   `bin/modulelint` green, `./butler --scan` exit 0, `--list` check (no
   elevated badge), full harness, §14 smokes incl. a real `run` with stubs,
   clean tree → commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `feature/system-report-pack` — EXCEPT the §4 fact 10
  substitution if your runner pins you.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +feature/system-report-pack:refs/remotes/origin/_resume
git checkout -B feature/system-report-pack refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B feature/system-report-pack origin/main
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
  EVERY expansion. Reference style: `modules/printer-helper/module.sh`.
- Module I/O contract: stdout for the report, stderr for errors; exit 0
  when the report renders (even with honest `(unavailable)` sections);
  exit 1 only for the missing-`needs`-tools preflight with one plain stderr
  line.
- TEST_COMMAND: `bash tests/run-tests.sh` (stages bj–bl: gate/smokes, full
  report, honest degradation)
- INTEGRATION_TEST_COMMAND: stage (bj) — real `./butler --scan` and
  `--list` exercising the real menu/gate with the new module present
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — every section render path and both
  failure modes have direct harness assertions; no bash mutation tooling
  exists under the zero-dependency constraint
- LINT_COMMAND: `bash -n modules/system-report-pack/module.sh butler
  lib/*.sh bin/modulelint tests/run-tests.sh` (always) plus `shellcheck` on
  the same set when installed; additionally
  `bin/modulelint system-report-pack` must exit 0
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: existing harness stages; existing modules; menu behavior;
  `lib/manifest.sh` parsing of `needs: [df, free, uname, uptime]`,
  `asks: 0`, `undo: false`, `risk: low`.
- The module is read-only by construction: zero writes, zero installs, zero
  network, zero elevation, zero questions.
- Owner-acceptance safety (fact 9): every acceptance command is
  non-destructive, including `run` itself.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- NO installs (never inxi), NO writes of any kind, NO network, NO
  elevation, NO `/proc` parsing, NO report-to-file option, NO other
  modules, NO lib changes.
- Do NOT modify `butler`, `bin/modulelint`, `bin/orchestrator-check`,
  `lib/*.sh`, other modules, README.md, docs/VISION.md, or
  docs/MODULE_SPEC.md.
- Do NOT add CI, dependencies, packaging, config files, or LICENSE.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.
- Never create a git tag or a GitHub release.

## 14. QUALITY CHECKS

1. `bash tests/run-tests.sh` — exit 0, every stage asserts successfully.
2. `bin/modulelint system-report-pack` — exit 0 with PASS.
3. `bin/modulelint` — exit 0 (9 modules).
4. `./butler --scan` — exit 0.
5. `./butler --list` — shows `system-report-pack: System report pack`
   WITHOUT an elevated badge; all existing modules still listed.
6. `./butler --run system-report-pack --dry-run` — exit 0, side-effect-free.
7. `bash -n` clean over all changed/new scripts; shellcheck clean if
   installed (record absence otherwise).
8. Worktree clean, all work pushed, no extra module folders, no lib changes.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `feat: system-report-pack — read-only system snapshot that installs
nothing`. Description: summary; design rationale (the section list and why
each data source was chosen — stock-Mint tools only; why the never-inxi
ruling leads to a built-in collector instead of wrapping inxi even when
present — deterministic, zero-dependency, honest; the honest-degradation
contract; why there is no report-to-file option in v1 — zero writes keeps
the module trivially safe; the `undo: false` honesty statement); test
results per §10 layer with exact commands and outcomes; safety statement
"the module is read-only by construction: zero writes, zero installs, zero
network, zero elevation, zero questions; all tests run against stub
binaries with canned outputs"; what the owner should try on Mint
(`./butler` → System report pack → read the snapshot, copy it into a help
request); breaking changes (none); migration notes (none). Describe only
this PR's own changes. Include `#### Session Irregularities` per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only (interfered with following this prompt AND
cost >~10 min / blocked progress / required a workaround / reveals a
recurring blind spot). If none significant, write exactly
`None significant`. If significant: Category | Symptom | Impact | Workaround
| Hardening candidate, 3–6 lines total. If you used the branch-substitution
rule (§4 fact 10), one line noting it belongs here. This report does not
affect the MERGE/REVISE verdict unless it reveals a missing deliverable.
