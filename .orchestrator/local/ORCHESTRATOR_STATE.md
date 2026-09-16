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
| 002 | .orchestrator/prompts/002-bin-modulelint.md | bin/modulelint contract validator | arena/01a0ac22-mintbutler (pinned; substitution recorded per §4 fact 10) | #2 | Reviewed 2026-09-16 — MERGE advised, awaiting operator merge |

## Active Milestone
v0.1 — menu script + module discovery + modulelint + the two seed modules.

## Task Queue
- [x] PR #1: butler core + discovery + PROJECT_STATE.md bootstrap (Merged 2026-09-16)
- [ ] PR #2: bin/modulelint contract validator (Open — MERGE advised 2026-09-16)
- [ ] 003: seed module desktop-shortcut-creator (Pending — next; author AFTER #2 merges: touches tracker path #2 edits; introduces module-side ask helper)
- [ ] 004: seed module android-file-transfer (Pending; first elevated path)

## Interrupted Work
- none

## Deferred / Technical Debt
- CI workflow deferred by owner (2026-09-16); revisit after v0.1.
- Module-side ask/elevate helpers deferred to task 003 (first consumer).
- LICENSE file not yet requested.
- v0.2 features (categories, favorites) deferred until v0.1 is proven on the owner's machine.

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

## Known Gaps
- Sandboxes cannot verify real Mint desktop behavior (gvfs metadata trust flag, MTP) — owner acceptance covers those paths.

## Hardening Log
| Date | Seq | Category | Symptom | Impact | Disposition | Hardening |
|---|---|---|---|---|---|---|
| 2026-09-16 | 001 | Environment | Arena agent session was pinned to its own `arena/*` branch; prompt §8 target `feature/butler-core-discovery` could not be created/used | Could not follow branch/push-cadence lines verbatim; single `feat:` commit instead of wip checkpoints | Hardened | Branch-substitution rule written into prompt 002 §4 fact 10 + §8 |
| 2026-09-16 | 002 | Environment | Branch-substitution rule used: pinned branch `arena/01a0ac22-mintbutler`, recorded in Session Irregularities as instructed | none — rule worked as designed; full 6-checkpoint cadence followed | Scoped | — |
