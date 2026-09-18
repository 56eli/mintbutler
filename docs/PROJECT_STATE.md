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
- **Governing spec anchor (owner ruling 2026-09-17):** orchestrator governing prompt pinned byte-faithful at `.orchestrator/ORCHESTRATOR CORE v4.5 — GENERAL PURPOSE.md` — sha256 `b71bb681788c23530c21cc46a5ed02194ef873c0ce7abea48e10e14e7096e372` — verified by `bin/orchestrator-check` (spec-anchor check). Pre-adoption orchestrator drift audited and filed 2026-09-17.
- Elevated-module root path (PR #5, 2026-09-17): lib/elevate.sh is the ONLY sanctioned path to root; it refuses (plain error, exit 126) unless the calling module's manifest declares risk: elevated; modules hold reviewed command strings as data and never the sudo token; every elevated module records and restores its non-package changes.

## 3. Settled Decisions & Rationale
- Project name is `mintbutler` — confirmed by owner 2026-09-16; no rename.
- CI is deferred for now (owner 2026-09-16); `modulelint` is the local gate.
- Verification split (owner 2026-09-16): sandbox verification (syntax, shellcheck, harness, later modulelint) plus owner manual acceptance on Mint 22.2; all owner-run commands must be non-destructive.
- desktop-shortcut-creator icon field: free text — an icon file path or a theme icon name; empty = system default (owner, 2026-09-16).
- desktop-shortcut-creator name conflict: never overwrite — create the launcher alongside with a `-N` version suffix and leave the existing entry untouched (owner, 2026-09-16).
- Module questions: a bounded series declared in the manifest (`asks: <n>`); optional values accept Enter to skip; safety confirmations stay with the menu; flows testable via scripted stdin — MODULE_SPEC §3 amended accordingly (owner, 2026-09-16). No standing exceptions: docs never drift from reality.
- 23-line law: no menu or submenu screen may exceed 23 terminal lines — ever; screens paginate (entries page + one header + one footer). Enforced in the test suite. MODULE_SPEC §4 amended (owner, 2026-09-16).
- desktop-shortcut-creator v1 ships two entry modes — Scan & place (default) and Custom — sharing `lib/desktop-entry.sh`; pagination lives in shared `lib/picker.sh` for reuse by future pickers (owner + hub review, 2026-09-16).
- android-file-transfer seed cancelled by owner before implementation (2026-09-16): "I don't need adb phone mounting and file transfer functionality anymore" — docs aligned in task 006.
- Module batch #1 approved (owner via hub, 2026-09-16): features appimage-installer, default-apps-editor, multimedia-codecs, screenshot-studio, printer-helper, system-report-pack, timeshift-guardian; fixes book-access-doctor, audio-repair; post-update-doctor deferred as a backlog stub. Build order (revised by owner 2026-09-16): screenshot-studio → default-apps-editor → appimage-installer → timeshift-guardian → audio-repair → multimedia-codecs → printer-helper → system-report-pack → book-access-doctor. One reviewed PR per module; modulelint + suite green for each.
- Menu ordering convention (binding, 2026-09-16): FEATURES sort first (`order:` 10, 20, 30…), FIXES after all features (`order:` 900, 910…); numbers unique, no ties. Final batch #1 order: 10 appimage-installer, 20 desktop-shortcut-creator, 30 default-apps-editor, 40 multimedia-codecs, 50 screenshot-studio, 60 printer-helper, 70 system-report-pack, 80 timeshift-guardian, 900 book-access-doctor, 910 audio-repair.
- book-access-doctor v1 boundary (2026-09-16): remount may be a declared elevated step, but persistent `/etc/fstab` edits are out of scope — the module prints the line it would need; it does not write it.
- Deferred gate hardening (PR #5 review, 2026-09-17): on hosts with passwordless sudo, bin/modulelint's sandboxed run of an elevated module can reach real sudo (observed there: an apt-get install -y flameshot attempt; package absent; nothing changed). Fix candidate: shadow sudo/pkexec on PATH during sandbox runs — awaiting owner decision. On interactive-sudo Mint with stdin closed, scans fail safe today.
- Elevated-module honesty convention (PR #5, 2026-09-17): mixed or absent undo is stated plainly in the manifest description and in run/undo output — what is undoable, what stays; external-tool behavior is tested with PATH stubs and fake HOMEs only, and real system access remains owner acceptance.

## 4. Active Milestone & Current State
- **Active Milestone:** Module batch #1 (owner-approved 2026-09-16): nine modules — seven features, two fixes — one reviewed PR at a time on the v0.1 core.
- **Current State:** v0.1 core complete; batch #1 in progress — screenshot-studio (PR #5), orchestrator spec + `bin/orchestrator-check` gate (PR #6), default-apps-editor (PR #7), appimage-installer (PRs #8/#9), timeshift-guardian (PR #10) landed.
- **Immediate Next Task:** task 014 — module `multimedia-codecs` (elevated install, honest no-undo), sixth in the owner's revised build order.

## 5. Module Backlog
- **post-update-doctor** (recorded 2026-09-16 — backlog stub, NOT implemented; deliberately no module folder): post-update regressions — Bluetooth autostart lost, NVIDIA fallback → wrong resolution, monitors mis-detected. Becomes a real task prompt when the chore bites.
