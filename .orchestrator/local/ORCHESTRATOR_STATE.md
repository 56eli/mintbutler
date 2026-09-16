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
| 005 | .orchestrator/prompts/005-android-file-transfer.md | seed module android-file-transfer + lib/elevate.sh (completes v0.1) | feature/android-file-transfer (or pinned session branch) | — | Dispatched 2026-09-16 |

## Active Milestone
v0.1 — menu script + module discovery + modulelint + the two seed modules.

## Task Queue
- [x] PR #1: butler core + discovery + PROJECT_STATE.md bootstrap (Merged 2026-09-16)
- [x] PR #2: bin/modulelint contract validator (Merged 2026-09-16)
- [x] PR #3: desktop-shortcut-creator v1 (Merged 2026-09-16)
- [ ] 005: seed module android-file-transfer + lib/elevate.sh (In Progress — dispatched 2026-09-16; completes v0.1)
- [ ] After v0.1: owner acceptance on Mint 22.2, then v0.2 backlog (menu categories, favorites) + owner's chore backlog

## Interrupted Work
- none

## Deferred / Technical Debt
- CI workflow deferred by owner (2026-09-16); revisit after v0.1.
- Module-side `ask` helper ships with task 003 (in flight); `elevate` helper ships with task 004 (first elevated consumer).
- LICENSE file not yet requested.
- v0.2 features (categories, favorites) deferred until v0.1 is proven on the owner's machine.
- `desktop_trust_and_exec` swallows gio failures silently (`2>/dev/null || true`); honest advisory output is preferable — candidate for a future small task (noted at PR #3 review, not REVISE-worthy).

## Scope Boundaries
- No modules beyond the two seeds until the owner names new chores (backlog = owner's life).
- Zero runtime dependencies is product law; no new deps without owner sign-off.
- No GUI, daemons, telemetry, auto-update, config sprawl (VISION.md anti-goals).

## Architectural Invariants
- README safety contract is product law: no runtime command generation; user-level first; dry-run before do; undo or say so; idempotent; zero dependencies.
- MODULE_SPEC.md is the binding contract for modules/ and the menu; manifest YAML subset limited to its §2 fields; numbers are positions, slugs are identities.
- Owner ruling 2026-09-16 (verbatim): "acceptance split is fine as long as all commands are non-destructive so running them on linux for the first time has no accidents" — every owner-acceptance command must be safe on a live machine.
- Dispatch contract implemented in PR #1 (2026-09-16): menu runs `bash modules/<slug>/module.sh <action>`, CWD = repo root, env `MINTBUTLER_MODULE_DIR` / `MINTBUTLER_MODULE_SLUG` / `MINTBUTLER_LIB_DIR`; slugs validated against `^[a-z0-9-]+$`; manifest parser accepts only the MODULE_SPEC §2 subset, unknown field = broken. Module-side helpers (ask/elevate) still to ship with 003.
- Gate live since PR #2 (2026-09-16): every module PR requires `bin/modulelint` green (manifest/slug, bash -n, forbidden patterns, sandbox HOME/XDG execution with diff containment, optional strace). `./butler --scan` delegates to it. Containment honest limits: diff covers sandbox HOME always; strace only when installed; shellcheck-gated SC2086 for unquoted expansions, advisory when absent.

## Settled Decisions (owner, 2026-09-16)
- Name confirmed: "mintbutler is the decided name confirmed" — no rename.
- CI: "Lets keep CI out for now".
- Tracker bootstrap at orchestrator discretion: "go ahead with bootstrapping docs at your own discretions".
- Verification split: sandbox checks (syntax, shellcheck, harness, later modulelint) + owner manual acceptance on Mint 22.2.
- desktop-shortcut-creator icon field: free text — icon file path or theme icon name; empty = system default (answer to structured question, 2026-09-16).
- desktop-shortcut-creator name conflict: create alongside with `-N` version suffix, never overwrite (answer to structured question, 2026-09-16). Both rulings folded into prompt 003 pre-dispatch (amendment banner in file) and into its tracker deliverable.
- Owner v1 rulings (2026-09-16, relayed via hub review): MODULE_SPEC §3 amended — bounded question series, budget declared as `asks: <n>` in the manifest, Enter skips optionals, confirmations stay with the menu, flows testable via scripted stdin; "No standing exceptions — docs never drift from reality." Two entry modes: Scan & place (default: scan user+system app dirs, paginated multi-select picker, one confirmation, trusted desktop copies, whole-set undo) and Custom (guided type/target/name/icon/terminal?/workdir?/desktop-copy sequence). New spec law (§4, enforced in suite): "No menu or submenu screen may exceed 23 terminal lines — ever"; pagination = entries page + one header + one footer (`n next / p prev / numbers / s search / q done`). Shared libs: lib/desktop-entry.sh (write→validate→trust→record; future appimage-installer reuses it) and lib/picker.sh (shared pagination footer per hub note). v1 quality items: Exec-quoting refuse-with-reason, end-of-run transparency (final entry content + offered test-launch), shadow warning vs /usr/share/applications. Out of scope: panel pinning; editing existing entries (future menu-entry-manager). All folded into prompt 003 amendment 2 pre-dispatch.

## Known Gaps
- Sandboxes cannot verify real Mint desktop behavior (gvfs metadata trust flag, MTP) — owner acceptance covers those paths.

## Hardening Log
| Date | Seq | Category | Symptom | Impact | Disposition | Hardening |
|---|---|---|---|---|---|---|
| 2026-09-16 | 001 | Environment | Arena agent session was pinned to its own `arena/*` branch; prompt §8 target `feature/butler-core-discovery` could not be created/used | Could not follow branch/push-cadence lines verbatim; single `feat:` commit instead of wip checkpoints | Hardened | Branch-substitution rule written into prompt 002 §4 fact 10 + §8 |
| 2026-09-16 | 002 | Environment | Branch-substitution rule used: pinned branch `arena/01a0ac22-mintbutler`, recorded in Session Irregularities as instructed | none — rule worked as designed; full 6-checkpoint cadence followed | Scoped | — |
| 2026-09-16 | 003 | Repository | `bin/modulelint` crashed on `-n` tokens (`basename: invalid option`) inside `check_write_targets` | modulelint errored on scripts containing `[[ -n … ]]`; agent fixed within allowed modify scope (`basename --`) | Scoped | Fixed in PR #3; future lint edits must keep `--` guards on token-parsing utility calls |
| 2026-09-16 | 003 | Environment | Branch-substitution rule used again: pinned branch `arena/01a0ac62-mintbutler` | none — rule worked | Scoped | — |
| 2026-09-16 | 003-review | Repository | SC2086 exposure in delivered module (`setsid ${launch_cmd}`) — gate hard-fails it wherever shellcheck exists | REVISE issued (prompt 004); not blocking on owner's shellcheck-less Mint | Hardened | Revision 004 fixes; future module prompts: remind agents the gate SC2086-fails unquoted expansions when shellcheck is present |
