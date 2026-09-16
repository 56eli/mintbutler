# Orchestrator Working State

## Orchestrator Branch
arena/01a0abf2-mintbutler — never merges. Distribution channel only.

## Continuation
(empty — fresh engagement, started 2026-09-16)

## Canonical Project Tracker
docs/PROJECT_STATE.md on main. Does not exist yet; bootstrapped as a deliverable of task 001 (owner gave discretion, 2026-09-16).

## Published Task Prompts
| Seq | Prompt path | Task | Agent branch | PR | Status |
|---|---|---|---|---|---|
| 001 | .orchestrator/prompts/001-butler-core-discovery.md | butler core: menu script, module discovery, flags, tracker bootstrap | arena/01a0ac05-mintbutler (session-pinned; deviation disclosed) | #1 | Reviewed 2026-09-16 — MERGE advised, awaiting operator merge |

## Active Milestone
v0.1 — menu script + module discovery + modulelint + the two seed modules.

## Task Queue
- [ ] PR #1: butler core + discovery + PROJECT_STATE.md bootstrap (Open — MERGE advised 2026-09-16)
- [ ] 002: bin/modulelint contract validator (Pending — next; author AFTER #1 merges: touches tracker path #1 creates)
- [ ] 003: seed module desktop-shortcut-creator (Pending; introduces module-side ask helper)
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
| 2026-09-16 | 001 | Environment | Arena agent session was pinned to its own `arena/*` branch; prompt §8 target `feature/butler-core-discovery` could not be created/used | Could not follow branch/push-cadence lines verbatim; single `feat:` commit instead of wip checkpoints | Hardening candidate | Prompt 002 §8/§9: declare that if the runner pins the session to a branch, use the pinned branch as target (base stays `main`), commit/push there, open the PR from it |
