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
- Contract validation is mechanical: `bin/modulelint` enforces MODULE_SPEC §5 and reuses the menu's own `lib/manifest.sh` parser (single source of truth for manifests).

## 3. Settled Decisions & Rationale
- Project name is `mintbutler` — confirmed by owner 2026-09-16; no rename.
- CI is deferred for now (owner 2026-09-16); `modulelint` is the local gate.
- Verification split (owner 2026-09-16): sandbox verification (syntax, shellcheck, harness, later modulelint) plus owner manual acceptance on Mint 22.2; all owner-run commands must be non-destructive.
- desktop-shortcut-creator icon field: free text — an icon file path or a theme icon name; empty = system default (owner, 2026-09-16).
- desktop-shortcut-creator name conflict: never overwrite — create the launcher alongside with a `-N` version suffix and leave the existing entry untouched (owner, 2026-09-16).
- Module questions: a bounded series declared in the manifest (`asks: <n>`); optional values accept Enter to skip; safety confirmations stay with the menu; flows testable via scripted stdin — MODULE_SPEC §3 amended accordingly (owner, 2026-09-16). No standing exceptions: docs never drift from reality.
- 23-line law: no menu or submenu screen may exceed 23 terminal lines — ever; screens paginate (entries page + one header + one footer). Enforced in the test suite. MODULE_SPEC §4 amended (owner, 2026-09-16).
- desktop-shortcut-creator v1 ships two entry modes — Scan & place (default) and Custom — sharing `lib/desktop-entry.sh`; pagination lives in shared `lib/picker.sh` for reuse by future pickers (owner + hub review, 2026-09-16).

## 4. Active Milestone & Current State
- **Active Milestone:** v0.1 — menu script + module discovery + modulelint + the two seed modules.
- **Current State:** core menu (PR #1, merged 2026-09-16) and `bin/modulelint` gate (PR #2, merged 2026-09-16) landed; desktop-shortcut-creator v1 (Scan & place + Custom modes, shared entry/picker libs, 23-line law) landed via PR for task 003.
- **Immediate Next Task:** task 004 — seed module `android-file-transfer` (risk: elevated, undo: false).
