# Orchestrator Working State

## Orchestrator Branch
arena/01a0abf2-mintbutler — never merges. Distribution channel only.

## Continuation
(empty — fresh engagement, started 2026-09-16)

## Canonical Project Tracker
docs/PROJECT_STATE.md on main — live since PR #1 (merged 2026-09-16).

## Published Task Prompts
| Seq | Prompt path | Task | Agent branch | PR | Status |
|---|---|---|---|---|---|
| 001 | .orchestrator/prompts/001-butler-core-discovery.md | butler core: menu script, module discovery, flags, tracker bootstrap | arena/01a0ac05-mintbutler (session-pinned; deviation disclosed) | #1 | Merged 2026-09-16 (merge commit f0eb800) |
| 002 | .orchestrator/prompts/002-bin-modulelint.md | bin/modulelint contract validator | arena/01a0ac22-mintbutler (pinned; substitution recorded per §4 fact 10) | #2 | Merged 2026-09-16 (merge commit 4eeac97) |
| 003 | .orchestrator/prompts/003-desktop-shortcut-creator.md | desktop-shortcut-creator v1: scan & place + custom modes, shared entry/picker libs, spec amendments, 23-line law | arena/01a0ac62-mintbutler (pinned; substitution recorded) | #3 | Merged 2026-09-16 (merge commit 52963a4) |
| 004 | .orchestrator/prompts/004-revise-shortcut-creator-sc2086.md | REVISION of PR #3: shellcheck-clean test-launch word splitting | arena/01a0ac62-mintbutler (continued) | #3 | Completed 2026-09-16 — fix verified, folded into PR #3 verdict |
| 005 | .orchestrator/prompts/005-android-file-transfer.md | seed module android-file-transfer + lib/elevate.sh (completes v0.1) | — | — | CANCELLED 2026-09-16 — owner withdrew the need; prompt never dispatched (retained, bannered, DO NOT RUN) |
| 006 | .orchestrator/prompts/006-batch1-convention-docs.md | batch #1 kickoff: menu-ordering convention, docs alignment, backlog stub | arena/01a0acb9-mintbutler (pinned; substitution recorded) | #4 | Merged 2026-09-17 (merge commit 8d0bd3e) |
| 007 | .orchestrator/prompts/007-screenshot-studio.md | screenshot-studio: flameshot install + Print Screen dconf rebind, recorded-restore undo, lib/elevate.sh debut | arena/01a0accc-mintbutler (pinned; substitution recorded) | #5 | Merged 2026-09-17 (merge commit d576a42) |
| 008 | .orchestrator/prompts/008-spec-pin-orchestrator-check.md | pin governing CORE v4.5 spec byte-faithful + tracker sha anchor + bin/orchestrator-check meta-tool with fixture tests (+ PR #5 distillation/deferred rows) | arena/01a0b02b-mintbutler (pinned; substitution recorded) | #6 | Reviewed 2026-09-17 — MERGE advised, awaiting operator merge |

## Active Milestone
Module batch #1 (owner-approved 2026-09-16) — currently detoured to the owner's 2026-09-17 structural fix (spec pin + mechanical compliance check, task 008); screenshot-studio (007) is next in the build order.

## Orchestrator Output Contract (survival anchor — do not delete)
- Dispatch stub first line = `<first 10 chars of repo name> agent` ⇒ `mintbutler agent` (spec Artifact 2; mechanical cut from `git remote get-url origin`). Stub is plain text — no fences, no task restatement, exact branch + prompt path, fetch lines indented in prose.
- After every plan of actions: attach the dispatch stub (owner directive 2026-09-17; "not a rule recorded" — just do it).
- Orchestrator replies open with `mintbutler agent` (owner-accepted convention since the 2026-09-17 drift report; the underlying spec duty is the stub first line).
- After every dispatch, end the turn with the structured question "PR open?" (options: Yes — link in my answer / Not yet / Failed or expired; free-text enabled) — spec PR hand-back; no prose next-steps narration.

## Compliance Epoch
Epoch: 76b2eb3a0e380f23348a57583498d4f1adab9230
Enforcement of bin/orchestrator-check publish-form/run-log-coverage begins at the epoch's first child commit; commits at or before the epoch are pre-adoption (drift audited 2026-09-17 against the pinned CORE v4.5 text, recorded below, never rewritten).

## Task Queue
- [x] PR #1: butler core + discovery + PROJECT_STATE.md bootstrap (Merged 2026-09-16)
- [x] PR #2: bin/modulelint contract validator (Merged 2026-09-16)
- [x] PR #3: desktop-shortcut-creator v1 (Merged 2026-09-16)
- [~] 005: android-file-transfer — CANCELLED by owner 2026-09-16 before dispatch
- [x] 006: batch #1 convention + docs alignment (PR #4 merged 2026-09-17, commit 8d0bd3e)
- [ ] 008: spec pin + bin/orchestrator-check — PR #6 reviewed 2026-09-17, MERGE advised; awaiting operator merge
- [x] 007: screenshot-studio — PR #5 merged 2026-09-17 (d576a42)
- [ ] 009: default-apps-editor (Pending — build order 2; order 30; xdg-mime, current-vs-new display)
- [ ] 010: appimage-installer (Pending — build order 3; order 10; reuses lib/desktop-entry.sh)
- [ ] 011: timeshift-guardian (Pending — build order 4; elevated, snapshots additive, order 80)
- [ ] 012: audio-repair (Pending — build order 5; elevated, config-backup undo, diagnose-first, order 910)
- [ ] 013: multimedia-codecs (Pending — build order 6; order 40; elevated install, honest no-undo)
- [ ] 014: printer-helper (Pending — build order 7; order 60; driverless/IPP-first, never vendor blobs; real-printer acceptance)
- [ ] 015: system-report-pack (Pending — build order 8; order 70; additive report file, never installs inxi — plain-tool fallback)
- [ ] 016: book-access-doctor (Pending — build order 9 (last); order 900; targeted grants only, never chmod -R 777; fstab PRINT-only ruling)

## Batch #1 Master Data (owner-approved 2026-09-16)
- Convention: FEATURES order 10/20/30… first; FIXES 900/910… after all features; unique numbers, no ties. Final table: 10 appimage-installer, 20 desktop-shortcut-creator, 30 default-apps-editor, 40 multimedia-codecs, 50 screenshot-studio, 60 printer-helper, 70 system-report-pack, 80 timeshift-guardian, 900 book-access-doctor, 910 audio-repair.
- Build order (owner revision 2026-09-16, effective with PR #4): screenshot-studio → default-apps-editor → appimage-installer → timeshift-guardian → audio-repair → multimedia-codecs → printer-helper → system-report-pack → book-access-doctor. (Owner typed screenshot-studio twice — treated as typo, flagged.)
- Rulings: book-access-doctor remount = declared elevated OK; persistent /etc/fstab edits OUT of v1 (print, don't write). post-update-doctor = backlog stub only (no folder). Hub notes MB-001 in flight; PRs landing mid-review expected — record pins sha, MB-002 catches delta.

## Interrupted Work
- none

## Deferred / Technical Debt
- CI workflow deferred by owner (2026-09-16); revisit after v0.1.
- lib/elevate.sh ships with task 007 (screenshot-studio; first elevated consumer).
- LICENSE file not yet requested.
- v0.2 features (categories, favorites) deferred until v0.1 is proven on the owner's machine.
- `desktop_trust_and_exec` swallows gio failures silently (`2>/dev/null || true`); honest advisory output is preferable — candidate for a future small task (noted at PR #3 review, not REVISE-worthy).
- Gate hardening (Deferred, needs owner decision; from PR #5 review 2026-09-17): shadow sudo/pkexec on PATH during modulelint sandbox runs so NOPASSWD hosts never reach real privileged tools; carried to docs/PROJECT_STATE.md via task 008's tracker deliverable.

## Scope Boundaries
- No modules beyond the two seeds until the owner names new chores (backlog = owner's life).
- Zero runtime dependencies is product law; no new deps without owner sign-off.
- No GUI, daemons, telemetry, auto-update, config sprawl (VISION.md anti-goals).

## Architectural Invariants
- README safety contract is product law: no runtime command generation; user-level first; dry-run before do; undo or say so; idempotent; zero dependencies.
- MODULE_SPEC.md is the binding contract for modules/ and the menu; manifest YAML subset limited to its §2 fields; numbers are positions, slugs are identities.
- Owner ruling 2026-09-16 (verbatim): "acceptance split is fine as long as all commands are non-destructive so running them on linux for the first time has no accidents" — every owner-acceptance command must be safe on a live machine.
- Dispatch contract implemented in PR #1 (2026-09-16): menu runs `bash modules/<slug>/module.sh <action>`, CWD = repo root, env `MINTBUTLER_MODULE_DIR` / `MINTBUTLER_MODULE_SLUG` / `MINTBUTLER_LIB_DIR`; slugs validated against `^[a-z0-9-]+$`; manifest parser accepts only the MODULE_SPEC §2 subset, unknown field = broken.
- Gate live since PR #2 (2026-09-16): every module PR requires `bin/modulelint` green (manifest/slug, bash -n, forbidden patterns, sandbox HOME/XDG execution with diff containment, optional strace). `./butler --scan` delegates to it. Containment honest limits: diff covers sandbox HOME always; strace only when installed; shellcheck-gated SC2086 for unquoted expansions, advisory when absent.
- Elevated-module root path (PR #5 distillation, 2026-09-17): lib/elevate.sh is the ONLY sanctioned path to root — refuses (plain error, exit 126) unless the calling module's manifest declares risk: elevated; modules hold reviewed command strings as data, never the sudo token; recorded-restore undo for every non-package change. Carried to docs/PROJECT_STATE.md §2 via task 008.
- Elevated-module honesty convention (PR #5 distillation, 2026-09-17): mixed/no undo is stated plainly in the manifest description and in run/undo output; external-tool behavior is tested with PATH stubs + fake HOMEs only, real system access stays owner acceptance. Carried to docs/PROJECT_STATE.md §3 via task 008.

## Settled Decisions (owner)
- Name confirmed: "mintbutler is the decided name confirmed" — no rename (2026-09-16).
- CI: "Lets keep CI out for now" (2026-09-16).
- Tracker bootstrap at orchestrator discretion: "go ahead with bootstrapping docs at your own discretions" (2026-09-16).
- Verification split: sandbox checks (syntax, shellcheck, harness, later modulelint) + owner manual acceptance on Mint 22.2 (2026-09-16).
- desktop-shortcut-creator icon field: free text — icon file path or theme icon name; empty = system default (2026-09-16).
- desktop-shortcut-creator name conflict: create alongside with `-N` version suffix, never overwrite (2026-09-16).
- Cancellation (owner, 2026-09-16, verbatim): "Oh i don't need adb phone mounting and file transfer functionality anymore, you can remove it." — task 005 cancelled before dispatch; prompt retained with a DO-NOT-RUN banner. lib/elevate.sh re-homed to 007.
- Owner v1 rulings (2026-09-16, relayed via hub review): MODULE_SPEC §3 amended — bounded question series, `asks: <n>` budget in manifest, Enter skips optionals, confirmations stay with the menu, flows testable via scripted stdin; "No standing exceptions — docs never drift from reality." 23-line law; pagination footer; shared libs lib/desktop-entry.sh + lib/picker.sh; Exec-quoting refuse-with-reason; transparency close-out; shadow warning. Out of scope: panel pinning, editing existing entries.
- Owner drift rulings (2026-09-17, relayed via repotester agent): (1) MATERIALIZE THE SPEC — fetch the governing prompt from github.com/56eli/temp "ORCHESTRATOR CORE v4.5 — GENERAL PURPOSE.md", commit byte-faithful (quote the path — spaces + em dash), sha256sum it, record file+sha in docs/PROJECT_STATE.md as governing spec anchor; run full compliance diff against the pinned text; file findings honestly; one reviewed PR. (2) MECHANICAL COMPLIANCE CHECK — design bin/orchestrator-check (meta-tooling, sibling of modulelint, NOT a user-facing module) that fails closed on the checkable subset: stub first line = `mintbutler agent`, publish commits use the guarded form, prompt-copy sha256 matches recorded anchor, every trigger phrase has a run-log entry, orchestrator branch receives no merges; judgment duties stay audit-based — say so in its help text. Both land through the normal reviewed-PR loop. Executed as task 008.
- Owner workflow directive (2026-09-17): after every plan of actions, provide the dispatch-agent stub; "not a rule recorded" — behavioral, no tracker entry.

## Known Gaps
- Sandboxes cannot verify real Mint desktop behavior (gvfs metadata trust flag, MTP, real dconf schema) — owner acceptance covers those paths.
- shellcheck uninstallable in orchestrator sandbox — SC2086 verified by inspection for orchestrator-authored snippets; module prompts carry the gate so agent PRs are covered wherever shellcheck exists.

## Compliance Findings (2026-09-17 — orchestrator audit vs pinned CORE v4.5)
Audited after materializing the governing prompt (owner drift ruling). Findings, all self-filed:
- F1 stub format (HIGH): dispatch stubs used code fences, restated the task, wrong first line ("You are the dispatch agent…"). Spec Artifact 2: first line `<repo10> agent`, plain text, no fences, no restatement. Corrected from 008 dispatch onward; check = stub-first-line.
- F2 publish form (MEDIUM-HIGH): condensed publish block used instead of the full guarded form (no ls-remote probe, no depth-50 two-way ancestry test, no rewind backup/overlay compare; explicit `HEAD:<branch>` refspec instead of `git push -qu origin HEAD`; commit subjects `chore(orchestrator): publish prompt NNN — …` instead of `chore: publish <NNN>-<slug>`); state updates published in separate commits instead of the same commit as the prompt. Full form restored from the 008 publish onward; check = publish-form (pre-adoption history grandfathered via Compliance Epoch).
- F3 hand-back question (MEDIUM): turns ended with prose next-steps instead of the structured "PR open?" ask_user question; merge-anticipation question ("<NNN> merged?") not used. Corrected from 008 dispatch onward (audit-based; no mechanical check).
- F4 working-state schema (MEDIUM): `## Run Log` absent; Published Task Prompts table had stale rows (006 status, 007 missing); Active Milestone stale (v0.1). Rebuilt in this state file; check = run-log-coverage.
- F5 output-contract misreading (LOW): reply-header duty over-applied — the spec's requirement is the stub first line; reply headers kept only as owner-accepted convention, contract block corrected.
- F6 compliant (verified): orchestrator branch received no merges and no source files; one agent at a time; orchestrator never opened a PR; refresh-before-author and refresh-on-merge-report both honored; prompt §0–16 structure present in 007; expected-absent declarations used; quote-by-copy verified for 007's tracker strings against main (build-order substring + §4 replacement block both byte-match).
- Residual: pre-adoption orchestrator-branch history (commits ≤ epoch) is immutable drift — grandfathered, never rewritten; enforcement is forward-only by design.

## Hardening Log
| Date | Seq | Category | Symptom | Impact | Disposition | Hardening |
|---|---|---|---|---|---|---|
| 2026-09-16 | 001 | Environment | Arena agent session was pinned to its own `arena/*` branch; prompt §8 target could not be created | Could not follow branch lines verbatim; single `feat:` commit instead of wip checkpoints | Hardened | Branch-substitution rule written into prompt 002 §4 fact 10 + §8; carried in every prompt since |
| 2026-09-16 | 002 | Environment | Branch-substitution rule used: pinned branch `arena/01a0ac22-mintbutler` | none — rule worked as designed | Scoped | — |
| 2026-09-16 | 003 | Repository | `bin/modulelint` crashed on `-n` tokens (`basename: invalid option`) inside `check_write_targets` | modulelint errored on `[[ -n … ]]`; agent fixed within allowed scope (`basename --`) | Scoped | Fixed in PR #3; future lint edits keep `--` guards on token-parsing calls |
| 2026-09-16 | 003 | Environment | Branch-substitution rule used again: pinned branch `arena/01a0ac62-mintbutler` | none — rule worked | Scoped | — |
| 2026-09-16 | 003-review | Repository | SC2086 exposure in delivered module (`setsid ${launch_cmd}`) — gate hard-fails where shellcheck exists | REVISE issued (prompt 004); not blocking on owner's shellcheck-less Mint | Hardened | Revision 004 fixed; module prompts now remind agents the gate SC2086-fails unquoted expansions |
| 2026-09-16 | 006 | Environment | Branch-substitution rule used (3rd time): pinned branch `arena/01a0acb9-mintbutler` | none — rule worked | Scoped | — |
| 2026-09-17 | orch | Prompt | Session condensation dropped output-format duties (stub first line, publish form); no repo artifact re-anchored them | drift until owner audit; ~1 session of non-conforming publishes | Hardened | Spec materialized in repo (task 008); output contract + run log persisted in this state; bin/orchestrator-check enforces forward |
| 2026-09-17 | 007-review | Environment | Sandbox has passwordless sudo; modulelint's sandboxed `run` of the elevated module executed real `sudo apt-get install -y flameshot` (package absent; nothing installed) | gate can reach real privileged tools on NOPASSWD hosts; seconds per gate run | Deferred (needs owner decision) | fix candidate: shadow sudo/pkexec in modulelint sandbox runs — dedicated prompt after owner sign-off; carried to tracker via task 008 |
| 2026-09-17 | 007 | Environment | Branch-substitution rule used (4th time): pinned branch `arena/01a0accc-mintbutler` | none — rule worked | Scoped | — |
| 2026-09-17 | 008 | Prompt | 008 §4 fact 7 assumed next harness stage letter was (z); (z) already existed via PR #5 | agent resolved correctly (stage (aa), documented in-file); near-collision cost nothing | Hardened | future prompts: derive the next stage letter from tests/run-tests.sh itself, not memory |
| 2026-09-17 | 008 | Environment | Branch-substitution rule used (5th time): pinned branch `arena/01a0b02b-mintbutler` | none — rule worked | Scoped | — |
| 2026-09-17 | orch | Environment | Platform worktree rewind reverted uncommitted verdict-state edits between tool calls; verdict block compared against HEAD (rewound too) instead of the pin, so the backup branch never fired | verdict state edits lost once; re-applied manually from record | Hardened | state edits are now backed up to .orchestrator/local/recovery/ immediately after editing, before any publish block; compare pending edits against the PIN, never HEAD |

## Run Log
- 2026-09-16 | publish | 001-butler-core-discovery published on orchestrator branch (pre-adoption)
- 2026-09-16 | dispatch | 001 handed to operator; stub first line: n/a (pre-adoption, prose dispatch)
- 2026-09-16 | verdict | 001 / PR #1 — MERGE advised after 3-stage review; merged by operator (f0eb800)
- 2026-09-16 | refresh-main | post-PR#1 merge report; tracker re-read before 002 authoring
- 2026-09-16 | publish | 002-bin-modulelint published (pre-adoption)
- 2026-09-16 | dispatch | 002 handed to operator; stub first line: n/a (pre-adoption, prose dispatch)
- 2026-09-16 | verdict | 002 / PR #2 — MERGE advised; merged by operator (4eeac97)
- 2026-09-16 | publish | 003-desktop-shortcut-creator published incl. amendments 1–2 (pre-adoption)
- 2026-09-16 | dispatch | 003 handed to operator; stub first line: n/a (pre-adoption, prose dispatch)
- 2026-09-16 | verdict | 003 / PR #3 — REVISE (SC2086) → revision prompt 004 dispatched on same branch → re-review MERGE advised; merged by operator (52963a4)
- 2026-09-16 | publish | 005-android-file-transfer published; same day CANCELLED by owner — bannered DO-NOT-RUN, never dispatched (pre-adoption)
- 2026-09-16 | publish | 006-batch1-convention-docs published (pre-adoption)
- 2026-09-16 | dispatch | 006 handed to operator; stub first line: n/a (pre-adoption, prose dispatch)
- 2026-09-17 | verdict | 006 / PR #4 — MERGE advised (texts verbatim vs tracker; suite 51/51 at tip)
- 2026-09-17 | refresh-main | owner reported PR #4 merged (8d0bd3e) + revised build order; tracker re-read before 007 authoring
- 2026-09-17 | publish | 007-screenshot-studio published (tip 070d9a1) — pre-adoption publish form (see F2)
- 2026-09-17 | dispatch | 007 stub handed to operator; agent launch deferred by owner's drift audit; stub first line: n/a (not dispatched)
- 2026-09-17 | refresh-main | pre-008 authoring; verified 007's quoted tracker strings byte-match main (quote-by-copy rule)
- 2026-09-17 | publish | 008-spec-pin-orchestrator-check published (first conforming publish; full guarded form, prompt + state same commit)
- 2026-09-17 | dispatch | 008 handed to operator ahead of 007 per owner structural-fix ruling; stub first line: mintbutler agent
- 2026-09-17 | dispatch | 007 ran first instead (operator choice): PR #5 opened from pinned branch arena/01a0accc-mintbutler; stub first line: mintbutler agent
- 2026-09-17 | refresh-main | PR #5 hand-back — main refreshed before two-dot diff
- 2026-09-17 | verdict | 007 / PR #5 — MERGE advised: 3-stage gate (diff audit; harness 106/0 re-run by orchestrator under stub sudo; modulelint 2/2 PASS; scan/list/dry-run; bash -n; deliverables 1:1 vs prompt incl. byte-exact tracker edits)
- 2026-09-17 | publish | 008-spec-pin-orchestrator-check amended in place pre-dispatch (adds PR #5 Deferred gate-hardening row to its tracker deliverable); verdict-time state publish in same commit
- 2026-09-17 | refresh-main | owner reported PR #5 merged (d576a42); main refreshed, net diff = exactly PR #5 content, no surprises
- 2026-09-17 | distillation | MERGE-verdict knowledge from 007: elevate root-path invariant + mixed-undo/stub-test honesty convention — recorded in invariants; tracker carry mandated via 008 deliverable (3rd pre-dispatch amendment)
- 2026-09-17 | dispatch | 008 dispatched (stub first line: mintbutler agent); operator opened PR #6 from pinned branch arena/01a0b02b-mintbutler
- 2026-09-17 | refresh-main | PR #6 hand-back — main refreshed before two-dot diff
- 2026-09-17 | verdict | 008 / PR #6 — MERGE advised: 3-stage gate (diff audit; spec sha256+blob-hash verified by orchestrator; harness 114/0 re-run; live orchestrator-check self-run 5/5 PASS incl. 10 grandfathered; deliverables 1:1 vs prompt incl. four byte-exact tracker bullets; stage (z)->(aa) adaptation documented and correct)
