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
