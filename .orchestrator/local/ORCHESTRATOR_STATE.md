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
| 008 | .orchestrator/prompts/008-spec-pin-orchestrator-check.md | pin governing CORE v4.5 spec byte-faithful + tracker sha anchor + bin/orchestrator-check meta-tool with fixture tests (+ PR #5 distillation/deferred rows) | arena/01a0b02b-mintbutler (pinned; substitution recorded) | #6 | Merged 2026-09-17 (merge commit 1255277) |
| 009 | .orchestrator/prompts/009-default-apps-editor.md | default-apps-editor: xdg-mime defaults with current-vs-new display, byte-for-byte mimeapps.list backup/restore undo | arena/01a0b065-mintbutler (pinned; substitution recorded) | #7 | Merged 2026-09-17 (merge commit 9674a43) |
| 010 | .orchestrator/prompts/010-appimage-installer.md | appimage-installer: user-level AppImage install reusing lib/desktop-entry.sh, copy-never-move, undo removes entry+copy | arena/01a0b0c2-mintbutler + arena/01a0b14e-mintbutler (duplicate dispatch — see 2026-09-17 process note) | #8 (+#9 follow-up) | MERGED BEFORE REVIEW 2026-09-17 (d046064, b930e0b) — health+content branch run post-hoc: FULLY GREEN, no defects, no follow-up |
| 011 | .orchestrator/prompts/011-timeshift-guardian.md | timeshift-guardian: diagnose-first Timeshift guardian, one confirmed additive snapshot, elevated, no undo (additive policy) | arena/01a0b18d-mintbutler (pinned; substitution recorded) | #10 | Merged 2026-09-17 (merge commit a41bfb3, after revision 012) |
| 012 | .orchestrator/prompts/012-revise-timeshift-guardian-sudo-display.md | REVISION of PR #10: helper-driven elevated-command display, no sudo literals in module.sh | arena/01a0b18d-mintbutler (continued) | #10 | Completed 2026-09-17 — fix verified; PR #10 merged a41bfb3 |
| 013 | .orchestrator/prompts/013-audio-repair.md | audio-repair: diagnose-first sound doctor, honest newer-kernel verdict, one recorded undoable Master repair, elevated dmesg read | arena/01a0b1e6-mintbutler (pinned; substitution recorded in PR) | #11 | Merged 2026-09-17 (merge commit bb25037) |
| 014 | .orchestrator/prompts/014-multimedia-codecs.md | multimedia-codecs: diagnose-first curated codec install, single elevated apt-get step, honest no-undo, order 40 | arena/01a0b3b3-mintbutler (pinned; substitution recorded in PR) | #12 | Merged 2026-09-17 (merge commit a2ecf27) |
| 015 | .orchestrator/prompts/015-printer-helper.md | printer-helper: diagnose-first CUPS doctor + recorded default-printer repair, risk low (confirmed token), never vendor blobs, order 60 | arena/01a0b3eb-mintbutler (pinned; substitution recorded in PR) | #13 | Merged 2026-09-17 (merge commit aa77fa7) |
| 016 | .orchestrator/prompts/016-system-report-pack.md | system-report-pack: read-only plain-text system report, zero installs (never inxi), risk low, order 70 | arena/01a0b487-mintbutler (pinned; substitution recorded in PR) | #14 | Merged 2026-09-17 (merge commit f37c699) |
| 017 | .orchestrator/prompts/017-book-access-doctor.md | book-access-doctor: diagnose-first e-reader mount doctor, one elevated remount-rw repair with undo, print-only fstab guidance, targeted grants only (never chmod -R), order 900 | arena/01a0b4db-mintbutler (pinned; substitution recorded in PR) | #15 | Merged 2026-09-17 (merge commit a9255f8) — BATCH #1 COMPLETE |
| 018 | .orchestrator/prompts/019-revise-repair-batch-mb004-completion.md (revision) | REPAIR BATCH #2: MB-001 elevate argv end-to-end, MB-002 consent switch + tripwire + modulelint sandbox stubs, MB-003/MB-005 mechanical 23-line law + needs enforcement, MB-004 single menu confirmation | arena/01a0b63a-mintbutler | #16 | Merged 2026-09-18 (merge commit b4e9464, after revision 019) |
| 019 | .orchestrator/prompts/019-revise-repair-batch-mb004-completion.md | REVISION of PR #16 (option A): remove appimage-installer + default-apps-editor in-module apply prompts; asks: 3→2 / 4→3 | arena/01a0b63a-mintbutler (continued) | #16 | Completed 2026-09-18 — fix 7bba5ac verified exact; folded into PR #16 MERGE verdict |

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
- [x] 008: spec pin + bin/orchestrator-check — PR #6 merged 2026-09-17 (1255277); mechanical compliance gate live
- [x] 007: screenshot-studio — PR #5 merged 2026-09-17 (d576a42)
- [x] 009: default-apps-editor — PR #7 merged 2026-09-17 (9674a43)
- [x] 010: appimage-installer — PR #8 (+#9) merged 2026-09-17 (d046064, b930e0b) before review; post-hoc gate 199/0 + deliverables 1:1
- [x] 011: timeshift-guardian — PR #10 merged 2026-09-17 (a41bfb3) after revision 012
- [x] 013: audio-repair — PR #11 merged 2026-09-17 (bb25037)
- [x] 014: multimedia-codecs — PR #12 merged 2026-09-17 (a2ecf27)
- [x] 015: printer-helper — PR #13 merged 2026-09-17 (aa77fa7)
- [x] 016: system-report-pack — PR #14 merged 2026-09-17 (f37c699)
- [x] 017: book-access-doctor — PR #15 merged 2026-09-17 (a9255f8). **BATCH #1 COMPLETE: all nine modules on main.** post-update-doctor remains a backlog stub only; the owner decides the next milestone.
- [ ] 014: multimedia-codecs (Pending — build order 6; order 40; elevated install, honest no-undo)
- [ ] 015: printer-helper (Pending — build order 7; order 60; driverless/IPP-first, never vendor blobs; real-printer acceptance)
- [ ] 016: system-report-pack (Pending — build order 8; order 70; additive report file, never installs inxi — plain-tool fallback)
- [ ] 017: book-access-doctor (Pending — build order 9 (last); order 900; targeted grants only, never chmod -R 777; fstab PRINT-only ruling)

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
| 2026-09-17 | 009 | Environment | Branch-substitution rule used (6th time): pinned branch `arena/01a0b065-mintbutler` | none — rule worked | Scoped | — |
| 2026-09-17 | 010 | Environment | Duplicate dispatch: task 010 ran in two agent sessions (PR #8 full delivery, PR #9 refinements) and both merged before orchestrator review; a third dispatch correctly reported 'already merged' instead of redoing work | no defects — post-hoc health+content gate fully green; process lesson only | Hardened | operator confirms no task is in flight before pasting a stub (the 'PR open?' question is that checkpoint); orchestrator ran the merged-before-reviewed branch per spec |
| 2026-09-17 | 011-review | Prompt | Elevated-module prompt left the placeholder-comment display pattern implicit; agent hardcoded 'sudo timeshift --create …' in plan/dry-run (2 lines) instead of elevate_command_line, violating prompt §4 fact 7 | REVISE issued (revision 012); no functional defect — run() was correct | Hardened | elevated-module prompts now show the exact placeholder pattern: elevate_command_line "<cmd> '<placeholder>'" wherever a variable-argument command must be displayed |
| 2026-09-17 | 011 | Environment | Branch-substitution rule used (7th time): pinned branch `arena/01a0b18d-mintbutler` | none — rule worked | Scoped | — |

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
- 2026-09-17 | refresh-main | owner reported PR #6 merged (1255277); main refreshed, net diff = exactly PR #6 content, no surprises; anchor bullet verified live in §2
- 2026-09-17 | publish | 009-default-apps-editor published (conforming form; stage letters (ab)-(af) derived from harness per hardening)
- 2026-09-17 | dispatch | 009 handed to operator; stub first line: mintbutler agent
- 2026-09-17 | dispatch | operator opened PR #7 for 009 from pinned branch arena/01a0b065-mintbutler
- 2026-09-17 | refresh-main | PR #7 hand-back — main refreshed before two-dot diff
- 2026-09-17 | verdict | 009 / PR #7 — MERGE advised: 3-stage gate (diff audit; harness 150/0 re-run by orchestrator; modulelint 3/3 PASS; scan/list/dry-run 17 lines; bash -n; deliverables 1:1 vs prompt incl. byte-exact manifest, byte-exact tracker §4, stages (ab)-(af))
- 2026-09-17 | refresh-main | owner reported PR #7 merged (9674a43); main refreshed, net diff = exactly PR #7 content; desktop-entry.sh API re-read for quote-by-copy in 010
- 2026-09-17 | publish | 010-appimage-installer published (conforming form; stage letters (ag)-(al) derived from harness)
- 2026-09-17 | dispatch | 010 handed to operator; stub first line: mintbutler agent
- 2026-09-17 | refresh-main | duplicate-dispatch report → main refreshed: PR #8 (d046064) + PR #9 (b930e0b) merged before review, both task 010 work
- 2026-09-17 | verdict | 010 / PR #8+#9 (merged-before-reviewed branch): health battery at b930e0b — suite 199/0, modulelint 4/4, scan/list/dry-run clean, bash -n clean, frozen surfaces untouched; content — deliverables 1:1 vs prompt 010 §6 (byte-exact manifest + tracker §4; stages ag-al; PR #9 refinements align INSTALL_DIR with the prompt and extend validate/trust to the already-done path). VERDICT: green, no defects, no follow-up
- 2026-09-17 | publish | 011-timeshift-guardian published (conforming form)
- 2026-09-17 | dispatch | 011 handed to operator; stub first line: mintbutler agent
- 2026-09-17 | dispatch | operator opened PR #10 for 011 from pinned branch arena/01a0b18d-mintbutler
- 2026-09-17 | refresh-main | PR #10 hand-back — main refreshed before two-dot diff
- 2026-09-17 | verdict | 011 / PR #10 — REVISE: 3-stage gate (harness 228/0 re-run; modulelint 5/5; scan/list/dry-run 15 lines; bash -n; tracker §4 byte-exact; stages am-aq; mode 755; no undo action — all conforming EXCEPT two hardcoded sudo display strings in plan/dry-run vs §4 fact 7, and unquoted placeholder differs from the actually-run command shape)
- 2026-09-17 | publish | 012-revise-timeshift-guardian-sudo-display published (revision structure with the three guardrails)
- 2026-09-17 | dispatch | 012 handed to operator (same branch arena/01a0b18d-mintbutler); stub first line: mintbutler agent
- 2026-09-17 | verdict | 012 / PR #10 re-review — MERGE advised: revision c26cf79 is exactly the two directed lines via elevate_command_line with quoted placeholder; battery at final commit: 228/0, modulelint 5/5, dry-run 15 lines now shows quoted '<comment>' matching the run shape, bash -n clean, no forbidden tokens
- 2026-09-17 | refresh-main | owner reported PR #10 merged (a41bfb3); main refreshed, net diff = exactly PR #10 content
- 2026-09-17 | distillation | MERGE-verdict knowledge from 011: elevated display via elevate_command_line incl. quoted placeholders is now the enforced convention (already distilled to the hardening log; carried in-prompt for 013 via §4 fact 7)
- 2026-09-17 | publish | 013-audio-repair published (conforming form; stage letters (ar)-(aw) derived from harness)
- 2026-09-17 | dispatch | 013 handed to operator; stub first line: mintbutler agent
- 2026-09-17 | review | 013 / PR #11 — MERGE advised: diff = exactly the 4 deliverables; suite 277/0 (+49 over 228, stages (ar)-(aw)); modulelint 6/6 incl. PASS audio-repair; --scan exit 0; --list badge ok; plan 14 / dry-run 23 lines; manifest byte-exact; tracker §4 byte-exact incl. task-012→014 fix; zero sudo/pkexec/eval literals (module + siblings regression-checked); bash -n clean; ask_yn default NO; record-before-apply + verify-mismatch rollback + undo-from-record all verified in code; Session Irregularities present (branch substitution disclosed)
- 2026-09-17 | refresh-main | owner reported PR #11 merged (bb25037); main refreshed, net diff = exactly PR #11 content
- 2026-09-17 | incident | worktree rewind mid-review wiped untracked .orchestrator/ incl. recovery dir (review-checkout rm -rf mistake); fully rebuilt from published orchestrator branch — recovery-from-remote works; future checkouts preserve .orchestrator/ first
- 2026-09-17 | publish | 014-multimedia-codecs published (conforming form; stage letters (ax)-(bc); tracker deliverable names task 015 printer-helper)
- 2026-09-17 | dispatch | 014 handed to operator; stub first line: mintbutler agent
- 2026-09-17 | review | 014 / PR #12 — MERGE advised: diff = exactly the 4 deliverables; suite 339/0 (+62, stages (ax)-(bc)); modulelint 7/7 incl. PASS multimedia-codecs; --scan exit 0; --list badge ok; menu navigation asserts NO [u]ndo affordance (undo:false convention live-verified); plan 16 / dry-run 22 lines with no-undo notice; manifest byte-exact; tracker §4 byte-exact (task 015 printer-helper); zero sudo/pkexec/eval literals (module + all elevated siblings regression-checked); bash -n clean; live sandbox non-interactive run stops at ask_yn EOF → 'Nothing installed.' exit 0; honest mixed exit-1 path verified in code; Session Irregularities present (branch substitution disclosed)
- 2026-09-17 | distillation | MERGE-verdict knowledge from 014: (a) undo:false convention = module omits the undo action + menu detail screen shows 'Undo: not available' with no [u]ndo key, assertable via scripted menu navigation; (b) ask_yn EOF=NO is the modulelint-sandbox safety gate for install-type modules — non-interactive run must end at the confirmation with zero writes
- 2026-09-17 | refresh-main | owner reported PR #12 merged (a2ecf27); main refreshed, net diff = exactly PR #12 content
- 2026-09-17 | publish | 015-printer-helper published (conforming form; stage letters (bd)-(bi); risk token to be confirmed by agent from existing user-level modules; zero-elevation invariant; tracker deliverable names task 016 system-report-pack)
- 2026-09-17 | dispatch | 015 handed to operator; stub first line: mintbutler agent
- 2026-09-17 | review | 015 / PR #13 — MERGE advised: diff = exactly the 4 deliverables; suite 407/0 (+68, stages (bd)-(bi)); modulelint 8/8 incl. PASS printer-helper; --scan exit 0; --list shows module WITHOUT elevated badge; plan 13 / dry-run 22 lines; manifest byte-exact with risk: low (repo vocabulary — prompt guessed 'user', agent used its own tie-break and recorded it: correct behavior); tracker §4 byte-exact (task 016 system-report-pack); harness includes source-grep assertions for zero sudo/pkexec literals and no lib/elevate.sh sourcing; live sandbox preflight exit 1 verified; record-before-apply + apply-fail-deletes-record + undo-with-verify all in code; PR body complete incl. two honest Session Irregularities (risk-token conflict, branch substitution)
- 2026-09-17 | distillation | MERGE-verdict knowledge from 015: (a) manifest risk vocabulary is EXACTLY low|elevated per lib/manifest.sh — user-level modules use risk: low; future prompts must not guess 'user'; (b) user-level repair apply-failure convention = DELETE the record and report nothing-changed (contrast: elevated audio-repair keeps the record for undo when apply fails mid-way)
- 2026-09-17 | refresh-main | owner reported PR #13 merged (aa77fa7); main refreshed, net diff = exactly PR #13 content
- 2026-09-17 | publish | 016-system-report-pack published (conforming form; stage letters (bj)-(bl); report sections fixed; os-release seam via documented env override; tracker deliverable names task 017 book-access-doctor with all three owner rulings inline)
- 2026-09-17 | dispatch | 016 handed to operator; stub first line: mintbutler agent
- 2026-09-17 | review | 014 / PR #14 — MERGE advised: diff = exactly the 4 deliverables; suite 460/0 (+53, stages (bj)-(bl)); modulelint 9/9 incl. PASS system-report-pack; --scan exit 0; --list no elevated badge; menu detail screen asserts NO [u]ndo affordance (undo:false); plan/dry-run 16 lines with never-inxi + writes-nothing statements; manifest byte-exact; tracker §4 byte-exact (task 017 book-access-doctor with all three owner rulings); source greps assert zero sudo/pkexec, no elevate/ask sourcing, no package-manager invocation; LIVE sandbox run verified: 7-line full report, all sections render, exit 0, nothing written; honest degradation path harness-verified; PR body complete incl. branch-substitution irregularity
- 2026-09-17 | distillation | MERGE-verdict knowledge from 016: (a) zero-side-effect module pattern proven — asks 0, undo false, no elevation, no helper sourcing; stub call-logs can assert the EXACT read-only invocation set; (b) env-var seam convention for non-PATH-stubbable reads — documented in-code override (MINTBUTLER_OS_RELEASE_FILE style) defaulting to the real path, read-only
- 2026-09-17 | refresh-main | owner reported PR #14 merged (f37c699); main refreshed, net diff = exactly PR #14 content
- 2026-09-17 | publish | 017-book-access-doctor published (conforming form; stage letters (bm)-(br); all three owner rulings embedded: remount-as-elevated OK, fstab PRINT-ONLY, targeted-grants-only → zero chmod in v1; tracker deliverable marks batch #1 complete after merge)
- 2026-09-17 | dispatch | 017 handed to operator; stub first line: mintbutler agent
- 2026-09-17 | review | 015 / PR #15 — MERGE advised: diff = exactly the 4 deliverables; suite 555/0 (+95, stages (bm)-(br) incl. mixed-mount case and EOF=NO); modulelint 10/10 incl. PASS book-access-doctor; --scan exit 0; --list elevated badge; plan 16 / dry-run 22 lines with never-fstab/never-chmod statements; manifest byte-exact; tracker §4 byte-exact (batch #1 complete wording); source assertions: zero chmod/chown, zero sudo/pkexec/eval, /etc/fstab informational-only, privilege only via lib/elevate.sh, exactly one ask; keep-record-on-remount-failure + undo path-prefix guardrails verified in code; live sandbox no-device verdict exit 0 verified; PR body complete incl. four honest Session Irregularities (branch substitution; elevate display/execution quoting split catching a prompt error; mount-probe seam; mid-session GH 401 recovered via documented §9 reconnect flow)
- 2026-09-17 | hardening-triage | from PR #15 irregularities: (F-NEW-1) lib/elevate.sh word-splits the command string with no shell — DISPLAY must be quoted via elevate_command_line, EXECUTION string must stay unquoted; prompt 017's §4 fact 3(v) was wrong on this point and the agent corrected it; ALSO latent in merged timeshift-guardian: create_cmd embeds quoted '<comment>' which reaches timeshift with literal quote chars — candidate revision prompt, owner sign-off needed; (F-NEW-2) candidate MODULE_SPEC §3 additions: elevate display/execution quoting split + documented test-seam convention (MINTBUTLER_MOUNT_PROBE_ROOT style). Existing F items unchanged: shadow sudo/pkexec in modulelint sandbox runs
- 2026-09-17 | distillation | MERGE-verdict knowledge from 017: (a) elevate quoting split convention is now binding for future prompts; (b) keep-record-on-failure semantics extend to elevated repairs where undo can still restore a safe state; (c) undo may carry its own path-prefix guardrail (recorded target must stay under /media or /run/media)
- 2026-09-17 | refresh-main | owner reported PR #15 merged (a9255f8); main refreshed, net diff = exactly PR #15 content
- 2026-09-17 | closeout | BATCH #1 COMPLETE — final tally: 10 appimage-installer, 20 desktop-shortcut-creator, 30 default-apps-editor, 40 multimedia-codecs, 50 screenshot-studio, 60 printer-helper, 70 system-report-pack, 80 timeshift-guardian, 900 book-access-doctor, 910 audio-repair — all on main via reviewed PRs #1-#15; harness 555 assertions green; modulelint 10/10; compliance state: spec pinned byte-faithful (sha b71bb681...), orchestrator-check live, F1-F6 findings filed, F items pending owner: shadow sudo/pkexec in modulelint sandbox, timeshift-guardian quoted-comment elevate fix, MODULE_SPEC §3 additions
- 2026-09-18 | note | owner self-dispatched repair batch #2 (MB-001..MB-005) — items 1-3 absorb ALL THREE of my carried F items (shadow sudo/pkexec → MB-002 modulelint sandbox stubs + tripwire; timeshift quoted-comment → MB-001 argv lists; MODULE_SPEC §3 additions → MB-001/002/003/004/005 docs)
- 2026-09-18 | review | 016 / PR #16 (repair batch #2) — REVISE advised: battery 619/0 re-run by me matches the claim; all four mechanisms verified in code (elevate argv end-to-end with derived quoting incl. eval round-trip; refusing+recording tripwire stub with sha-pin; mechanical 23-line law in modulelint + stage (bt) over 10 modules x 6 screens; needs.sh enforcement in butler run/undo/menu + modulelint WARN; menu typed-slug/[y/N] single confirmation with developer lane documented). FINDING (one): MB-004's MODULE_SPEC text states the universal law 'a module must never prompt for a y/N or other safety confirmation itself — asks: counts value questions only', but appimage-installer (asks: 3, question 3/3 'Install this AppImage?') and default-apps-editor (asks: 4, question 4/4 'Apply this change?') still carry in-module y/N apply confirmations, and their manifests still count those questions in asks: — the PR's own docs drift from its own code. Fix options offered to owner: (A) complete the law — drop both prompts, asks: 3→2 / 4→3, stages adjusted; (B) narrow the law — MODULE_SPEC carve-out for the declared final apply question of bounded question-driven series (matches owner ruling 7's bounded-asks convention and the owner-merged history of PRs #3/#7/#8/#9). Recommended: B (cheapest, honors existing owner-merged behavior). NOTE: timeshift-guardian quoted-comment latent issue is FIXED by MB-001 (hostile-comment stages prove one-argv-word delivery); desktop-shortcut-creator's ask_yn calls are value questions (run-in-terminal / desktop-copy optionals), compliant under either option
- 2026-09-18 | decision | owner chose OPTION A (complete the law; drop both remaining in-module apply prompts)
- 2026-09-18 | publish | 019-revise-repair-batch-mb004-completion published (revision structure, same branch as PR #16; exact scope: two prompts + two manifests + affected stages only; suite stays green, tripwire clean)
- 2026-09-18 | dispatch | 019 handed to operator; stub first line: mintbutler agent
- 2026-09-18 | review | 019 / PR #16 re-review — MERGE advised: revision delta = exactly commit 7bba5ac over 5 files (two modules + two manifests + harness); both apply prompts gone with zero stale 'N of M' text; asks: 3→2 / 4→3; harness stdin feeds lose the final y and gain the two no-[y/N] proofs (619→621 assertions); my re-run: 621/0; tripwire still zero real sudo attempts; modulelint 10/10 with same WARNs; PR description updated to the universal law with the new total; the MB-004 MODULE_SPEC wording is now exactly true of every module
- 2026-09-18 | refresh-main | owner reported PR #16 merged (b4e9464); main refreshed — net diff vs a9255f8 = exactly the repair batch content (5 commits incl. revision 7bba5ac)
- 2026-09-18 | closeout | REPAIR BATCH #2 COMPLETE — all carried hardening items closed: (1) shadow sudo/pkexec containment → MB-002 refusing+recording tripwire + modulelint sandbox stubs (sudo/amixer/lpoptions/dconf) + consent switch; (2) timeshift-guardian quoted-comment latent issue → MB-001 argv-lists end-to-end (hostile-input stages prove one-word delivery); (3) MODULE_SPEC §3 additions → MB-001/002/003/004/005 docs. Repo posture at b4e9464: 10 modules, harness 621/0, modulelint 10/10, mechanical 23-line law, needs: launch-time enforcement, universal single-menu-confirmation law, zero real-sudo tripwire. Pending owner items: NONE carried by the orchestrator; next milestone is the owner's call (post-update-doctor remains a backlog stub only)
