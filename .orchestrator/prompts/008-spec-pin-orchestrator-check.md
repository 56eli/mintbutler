# 008 — pin governing orchestrator spec + bin/orchestrator-check (meta-tooling)

## 0. FETCH AND VERIFY

You fetched this file with:

```bash
git fetch --depth 1 origin +arena/01a0abf2-mintbutler:refs/remotes/origin/_orch
git show refs/remotes/origin/_orch:.orchestrator/prompts/008-spec-pin-orchestrator-check.md > /tmp/task.md
```

Rules: read it from `/tmp/task.md`. Do not use `origin/arena/01a0abf2-mintbutler`
(single-branch clones don't create it). Do not use `FETCH_HEAD` (later fetches
overwrite it). Do not `git checkout` any `.orchestrator/` path into your
worktree. Never commit this file or anything written to `/tmp`. Never push to
the orchestrator branch `arena/01a0abf2-mintbutler`. HALT and report if this
file is empty or its title does not match "008 — pin governing orchestrator
spec + bin/orchestrator-check".

## 1. TASK TITLE AND SCOPE

Ship the owner-directed structural fix: pin the governing orchestrator prompt
(CORE v4.5) byte-faithful into this repo, record its sha256 anchor in the
canonical tracker, and deliver `bin/orchestrator-check` — a zero-dependency
meta-tool (sibling of `bin/modulelint`, NOT a user-facing module) that fails
closed on the mechanically checkable subset of orchestrator compliance.
Complete this in ONE pull request.

## 2. REQUIRED READING ORDER

1. `docs/PROJECT_STATE.md` — canonical tracker; you will append ONE anchor
   bullet to §2. Find §2 with: `grep -n '^## 2\.' docs/PROJECT_STATE.md`
   (confirm, do not copy).
2. `bin/modulelint` — the style sibling: zero-dependency bash, PASS/FAIL
   lines, exit-code contract, `--` guards on token parsing.
3. `tests/run-tests.sh` — harness; existing stages (a)–(y); add stage (z).
4. `README.md` — zero-dependency product law.
5. `git log --oneline -5` — Conventional Commits convention (confirm, do not
   copy).

Do NOT read the fetched spec file for analysis — your job is to land it
byte-faithful and verify its checksum, not to interpret it.

## 3. PROJECT CONTEXT AND OWNER VISION

mintbutler is a zero-dependency bash toolbox for Linux Mint 22. The
orchestrator coordinating its development is governed by a prompt
("ORCHESTRATOR CORE v4.5") that until now lived only in chat — a drift audit
found the orchestrator deviating from it. Owner ruling (2026-09-17, relayed
via repotester agent): MATERIALIZE THE SPEC — commit it byte-faithful, record
file+sha256 in `docs/PROJECT_STATE.md` as the governing spec anchor — and
MECHANICAL COMPLIANCE CHECK — `bin/orchestrator-check`, sibling of
modulelint, NOT a user-facing module, that fails closed on the checkable
subset; judgment duties stay audit-based and its help text must say so.
This advances the owner's goal by making the governance contract checkable
instead of trust-based.

## 4. CONFIRMED FACTS, ARCHITECTURAL INVARIANTS, AND SCOPE BOUNDARIES

1. **Spec source and integrity.** Fetch the spec with:
   `curl -fsSL -H 'Accept: application/vnd.github.raw' 'https://api.github.com/repos/56eli/temp/contents/ORCHESTRATOR%20CORE%20v4.5%20%E2%80%94%20GENERAL%20PURPOSE.md?ref=main'`
   If and only if that host is unreachable, retry once with
   `curl -fsSL 'https://raw.githubusercontent.com/56eli/temp/main/ORCHESTRATOR%20CORE%20v4.5%20%E2%80%94%20GENERAL%20PURPOSE.md'`.
   If neither works, HALT and report — do not improvise another source, do
   not retype content. The fetched bytes MUST have sha256
   `b71bb681788c23530c21cc46a5ed02194ef873c0ce7abea48e10e14e7096e372`
   (113640 bytes). Verify with `sha256sum` immediately after download; on
   mismatch HALT and report — never "fix" the bytes.
2. **Destination path (exact, spaces + em dash, quote it in every shell
   command):** `.orchestrator/ORCHESTRATOR CORE v4.5 — GENERAL PURPOSE.md`
   The committed blob hash must equal the blob hash of the fetched file
   (`git hash-object` both) — no newline translation, no trailing edits.
3. **Tracker edits (exact deliverable, two bullets, two sections).** Locate
   the sections first: `grep -n '^## 2\.\|^## 3\.' docs/PROJECT_STATE.md`
   (confirm, do not copy). (a) Append this bullet as the LAST bullet of
   `## 2. Architectural Invariants`:

   `- **Governing spec anchor (owner ruling 2026-09-17):** orchestrator governing prompt pinned byte-faithful at `.orchestrator/ORCHESTRATOR CORE v4.5 — GENERAL PURPOSE.md` — sha256 `b71bb681788c23530c21cc46a5ed02194ef873c0ce7abea48e10e14e7096e372` — verified by `bin/orchestrator-check` (spec-anchor check). Pre-adoption orchestrator drift audited and filed 2026-09-17.`

   (The backticks above are literal file content.)
   (b) Append this bullet as the LAST bullet of
   `## 3. Settled Decisions & Rationale` (carries a Deferred (needs owner
   decision) hardening item from the PR #5 review, per the spec's Knowledge
   Bridge rule):

   `- Deferred gate hardening (PR #5 review, 2026-09-17): on hosts with passwordless sudo, bin/modulelint's sandboxed run of an elevated module can reach real sudo (observed there: an apt-get install -y flameshot attempt; package absent; nothing changed). Fix candidate: shadow sudo/pkexec on PATH during sandbox runs — awaiting owner decision. On interactive-sudo Mint with stdin closed, scans fail safe today.`

   Change nothing else in the tracker.
4. **`bin/orchestrator-check` contract.** Zero-dependency bash
   (`#!/usr/bin/env bash`, `set -euo pipefail`, every expansion quoted),
   executable (git mode 755). Reads only; writes nothing outside an
   explicitly passed fixture dir. Options: `--repo-root DIR` (default:
   `git rev-parse --show-toplevel`), `--ref REF` (default:
   `refs/remotes/origin/_orch`), `--state FILE` (default:
   `$REPO_ROOT/.orchestrator/local/ORCHESTRATOR_STATE.md` if it exists, else
   `git show REF:.orchestrator/local/ORCHESTRATOR_STATE.md`), `-h|--help`.
   Output: one line per check — `PASS <name>` or `FAIL <name> — <reason>`;
   exit 0 iff all pass; exit 2 on usage error. Checks, ALL fail-closed
   (inconclusive = FAIL with the reason stated):
   - `spec-anchor`: the tracker at `docs/PROJECT_STATE.md` contains the
     Governing spec anchor bullet; extract the recorded 64-hex sha; the file
     at the recorded path exists and its `sha256sum` equals the recorded
     sha. Missing file, missing bullet, or mismatch = FAIL.
   - `stub-first-line`: derive the expected header mechanically — basename
     of `git remote get-url origin` (strip trailing `.git`), first 10
     characters verbatim, plus the suffix ` agent` (repo `mintbutler` ⇒
     `mintbutler agent`). In the state file's `## Run Log` section, every
     line whose kind field is `dispatch` must carry
     `stub first line: <expected header>` OR
     `stub first line: n/a (not dispatched)` OR
     `stub first line: n/a (pre-adoption, prose dispatch)`. A dispatch line
     missing the field = FAIL; no Run Log section at all = FAIL.
   - `publish-form`: every commit on REF that touches `.orchestrator/prompts/`
     (enumerate with `git log --format=%H%x09%s REF -- .orchestrator/prompts/`)
     must (a) have subject matching `^chore: publish [0-9]{3}-[a-z0-9-]+$`
     and (b) change ONLY paths under `.orchestrator/prompts/` and/or
     `.orchestrator/local/ORCHESTRATOR_STATE.md` (enumerate with
     `git show --name-only --format=`). Enforcement scope: only commits
     strictly AFTER the compliance epoch (see next bullet); commits at or
     before the epoch are counted and reported as
     `PASS publish-form (N grandfathered pre-adoption)`. If REF has no
     prompt-touching commit after the epoch, report FAIL — the check must
     have something to discriminate.
   - `run-log-coverage`: list prompt files on REF
     (`git ls-tree --name-only REF .orchestrator/prompts/`); every sequence
     number must appear in the Run Log text; every prompt published after
     the epoch must have a `publish` kind entry. Missing = FAIL.
   - `no-merge-into-orchestrator`: `git rev-list --merges REF` must print
     nothing. If the repository is shallow and REF's history reaches the
     graft boundary (rev-list count equals the shallow depth cap, or
     `git rev-parse REF^{commit}` shows a grafted root), report FAIL —
     inconclusive ancestry is fail-closed, with a hint to fetch deeper.
5. **Compliance epoch.** The state file carries a section:

   ```markdown
   ## Compliance Epoch
   Epoch: <40-hex sha on the orchestrator branch>
   Enforcement of bin/orchestrator-check publish-form/run-log-coverage begins
   at the epoch's first child commit; commits at or before the epoch are
   pre-adoption (drift audited 2026-09-17, recorded in the orchestrator's
   working state, never rewritten).
   ```

   `bin/orchestrator-check` parses the `Epoch:` sha. Missing section or
   unparseable sha = FAIL (both publish-form and run-log-coverage) — the
   tool must not silently check nothing. If the epoch sha is not an
   ancestor of REF and not REF itself (check with
   `git merge-base --is-ancestor`), that is inconclusive = FAIL with the
   hint to fetch REF at `--depth 50` or more. NOTE: the orchestrator sets
   the epoch value in its own state when it publishes the next prompt —
   YOU do not author the epoch sha; your fixture tests supply their own.
6. **Help text (exact required sentence).** `--help` must state, verbatim
   among its usage text: `Judgment duties — MERGE/REVISE verdicts, scope and
   vision decisions, and PR review — remain audit-based and are NOT enforced
   by this tool; it fails closed on the mechanically checkable subset only.`
   Help must also map the owner's five items to checks: stub first line →
   stub-first-line; publish commits use the guarded form → publish-form;
   prompt-copy sha256 matches the recorded anchor → spec-anchor; every
   trigger/run entry logged → run-log-coverage; orchestrator branch receives
   no merges → no-merge-into-orchestrator.
7. **Fixture-test design (stage z).** Tests build throwaway git repos under
   `mktemp -d` — never the real repo, never the network, never real
   credentials. Fixture construction: `git init -q -b orch` (or
   checkout -b), deterministic `GIT_AUTHOR_*`/`GIT_COMMITTER_*` env,
   `git remote add origin https://github.com/example/mintbutler.git` (URL
   only — never fetched; makes the header derivation deterministic:
   `mintbutler agent`). Fixture content: a dummy spec file + tracker whose
   anchor sha matches it, a state file with `## Run Log` and
   `## Compliance Epoch` sections, and crafted commits on branch `orch`:
   conforming `chore: publish 001-fixture-task` commit (prompt path + state
   only, after epoch), then negative variants in separate fixtures or
   re-runs. Run the tool with
   `bin/orchestrator-check --repo-root "$fix" --ref refs/heads/orch --state "$fix_state"`.
   Assert: (z1) good fixture → exit 0, five PASS lines; (z2) dispatch line
   missing `stub first line:` → exit 1, FAIL stub-first-line; (z3) publish
   commit also touching `README.md` → FAIL publish-form; (z4) prompt commit
   with subject `wip: prompt` → FAIL publish-form; (z5) a merge commit on
   orch (create a side branch + `git merge --no-ff`) → FAIL
   no-merge-into-orchestrator; (z6) tracker sha differs from file → FAIL
   spec-anchor; (z7) a prompt seq absent from the Run Log → FAIL
   run-log-coverage; (z8) state without `## Compliance Epoch` → FAIL.
   Keep every fixture dir self-contained; clean up with `rm -rf` at stage
   end. `bash tests/run-tests.sh` must stay green when no network exists.
8. **Branch-pinning rule:** if your runner pins your session to a branch and
   forbids creating another, use the pinned branch as the target (base stays
   `main`), substitute its name in §8/§9, and record it under
   `#### Session Irregularities`. Never push to
   `arena/01a0abf2-mintbutler`.

**Scope boundaries:** NO module folders, NO changes to `butler`,
`bin/modulelint`, `lib/*`, `modules/*`, `docs/VISION.md`, `docs/MODULE_SPEC.md`;
NO edits to the fetched spec bytes; NO CI; NO network access in tests; NO
git tag or release.

**Expected-absent at delivery:** no changes anywhere under `modules/` or
`lib/`; no file under `bin/` other than the new `orchestrator-check`. If any
appears in your diff, HALT and report.

## 5. CORE OBJECTIVE

The repo carries the governing spec byte-faithful with a verifiable anchor on
`main`; `bin/orchestrator-check` runs green on a conforming fixture and red
(fail-closed, reason printed) on each of the seven negative variants; the
harness proves all of it without network access; the tracker names the
anchor. Done = all §6 deliverables exist, `bash tests/run-tests.sh` exit 0
including stage (z), `bash -n` clean, shellcheck clean if installed,
worktree clean, everything pushed.

## 6. EXACT DELIVERABLES

Create:

1. `.orchestrator/ORCHESTRATOR CORE v4.5 — GENERAL PURPOSE.md` — the fetched
   bytes, sha-verified per §4 facts 1–2.
2. `bin/orchestrator-check` — per §4 facts 4–6, mode 755.

Modify:

3. `docs/PROJECT_STATE.md` — append the two exact bullets of §4 fact 3
   (anchor → last bullet of §2; deferred gate hardening → last bullet of
   §3); nothing else.
4. `tests/run-tests.sh` — add stage (z) per §4 fact 7; stages (a)–(y)
   untouched and passing.

## 7. SUB-TASK BREAKDOWN AND CHECKPOINTS

1. Fetch + sha-verify + commit the spec file → commit + push
2. Tracker anchor bullet → commit + push
3. `bin/orchestrator-check` (all five checks + epoch + help text) → commit + push
4. Harness stage (z): fixture builder + eight assertions, full suite green →
   commit + push
5. Final pass: `bash -n`, shellcheck if installed, suite re-run, clean tree →
   commit + push, then open the PR

## 8. BRANCH AND TARGET

- Base branch: `main` — never the orchestrator branch.
- Target branch: `chore/spec-pin-orchestrator-check` — EXCEPT the §4 fact 8
  substitution if your runner pins you.
- Orchestrator branch: `arena/01a0abf2-mintbutler` — fetch source only.
- Dependencies: none.
- Resuming: fresh branch from main.

Before the first checkpoint, align HEAD to a remote tip:

```bash
git fetch --depth 50 origin +chore/spec-pin-orchestrator-check:refs/remotes/origin/_resume
git checkout -B chore/spec-pin-orchestrator-check refs/remotes/origin/_resume
```

If that fetch cannot find the remote ref, the branch is new:

```bash
git fetch --depth 1 origin +main:refs/remotes/origin/main && git checkout -B chore/spec-pin-orchestrator-check origin/main
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
  EVERY expansion. Reference style: `bin/modulelint`.
- Tool I/O contract: PASS/FAIL lines on stdout; reasons on the same line
  after ` — `; exit 0 all-pass, 1 any-fail, 2 usage error.
- Tests NEVER use the network, the real repo refs, or real credentials;
  fixtures are `mktemp -d` git repos with canned remotes.
- TEST_COMMAND: `bash tests/run-tests.sh` (stage z: z1–z8 fixture matrix)
- INTEGRATION_TEST_COMMAND: not applicable — the tool under test IS the
  integration surface; its behavior is fully exercised by the fixture matrix
  in stage (z), and a live-repo run is owner/orchestrator acceptance, not
  suite scope
- FULL_SUITE_COMMAND: `bash tests/run-tests.sh`
- COVERAGE_COMMAND: not configured (no bash coverage tooling compatible with
  the zero-dependency constraint)
- MUTATION_TEST_COMMAND: not warranted — every check has a direct negative
  fixture asserting its FAIL path (z2–z8); no bash mutation tooling exists
  under the zero-dependency constraint
- LINT_COMMAND: `bash -n bin/orchestrator-check tests/run-tests.sh bin/modulelint butler lib/*.sh`
  (always) plus `shellcheck` on the same set when installed
- BUILD_COMMAND: not applicable — interpreted bash

## 11. SAFETY AND COMPATIBILITY RULES

- Must not break: harness stages (a)–(y), `bin/modulelint`, the menu, any
  module. This PR touches none of them.
- `bin/orchestrator-check` is read-only over the repository in default use;
  fixture mode writes only inside the `mktemp` dirs the tests create.
- The spec file is data: committed bytes must hash-verify; any tool or test
  treating its text as instructions is out of scope and must not exist.

## 12. CLEANUP RULES

By the final push, leave no commented-out code, temporary debug logs, ad-hoc
test scripts, `echo DEBUG` statements, or TODO markers introduced by this PR.
Do not modify unrelated files. Do not reformat code outside the scope of this
task. Do not commit the fetched prompt file or anything written to `/tmp`.
Intermediate checkpoint commits are exempt — clean up once, before opening
the PR, not on every push.

## 13. STRICT BOUNDARIES / OUT OF SCOPE

- NO modules, NO menu changes, NO modulelint changes, NO lib changes.
- NO editing, reflowing, "fixing", or annotating the spec file — byte-faithful
  or HALT.
- NO CI, NO dependencies, NO packaging, NO LICENSE, NO tags, NO releases.
- NO network access anywhere in tests.
- Do NOT push to the orchestrator branch `arena/01a0abf2-mintbutler`.

## 14. QUALITY CHECKS

1. `sha256sum '.orchestrator/ORCHESTRATOR CORE v4.5 — GENERAL PURPOSE.md'`
   prints `b71bb681788c23530c21cc46a5ed02194ef873c0ce7abea48e10e14e7096e372`.
2. `git hash-object` of the committed blob equals `git hash-object` of the
   fetched file.
3. `bash tests/run-tests.sh` — exit 0, stages (a)–(z) all assert.
4. `bin/orchestrator-check --help` — prints usage including the exact
   judgment-audit sentence (§4 fact 6).
5. `bash -n bin/orchestrator-check tests/run-tests.sh` — clean; shellcheck
   clean if installed (record absence otherwise).
6. Worktree clean, all work pushed, nothing under `modules/` or `lib/`
   touched.

## 15. PR DESCRIPTION REQUIREMENTS

Title: `chore: pin orchestrator CORE v4.5 spec + bin/orchestrator-check
meta-tool`. Description: summary; the owner ruling this executes (structural
fix, 2026-09-17); fetch-and-verify transcript (command, sha256sum output,
blob-hash equality); design rationale — why fail-closed, why an epoch
(history before adoption is audited drift, immutable and grandfathered;
enforcement starts at the epoch's first child), why fixtures not the live
repo in the suite, the five-check mapping from the owner's items; test
results per §10 with exact commands; safety statement "the spec file is
treated as data (hash-verified bytes); bin/orchestrator-check is read-only
in default use; tests never touch the network, real refs, or credentials";
breaking changes (none); migration notes (the orchestrator sets the
compliance epoch in its working state at its next publish; until then the
tool FAILs publish-form/run-log-coverage by design — fail-closed). Include
`#### Session Irregularities` per §16.

## 16. HARDENING REPORT — Session Irregularities (thresholded, low-cost)

In the PR description, under heading `#### Session Irregularities`, report
significant irregularities only (interfered with following this prompt AND
cost >~10 min / blocked progress / required a workaround / reveals a
recurring blind spot). If none significant, write exactly
`None significant`. If significant: Category | Symptom | Impact | Workaround
| Hardening candidate, 3–6 lines total. If you used the branch-substitution
rule (§4 fact 8), one line noting it belongs here. This report does not
affect the MERGE/REVISE verdict unless it reveals a missing deliverable.
