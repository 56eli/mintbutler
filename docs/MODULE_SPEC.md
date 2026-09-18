# Module Spec — the contract between menu and solver

This is the law for everything under `modules/` and for the menu script that
discovers it. The gate (`modulelint` + orchestrator review) enforces it
mechanically. PRs that violate the contract are rejected regardless of code
quality — see the safety contract in the README.

## 1. Layout

```
mintbutler/
├── butler                  # the main script (bash, POSIX-ish, ANSI)
├── lib/                    # shared helpers (menu render, confirm, ui)
├── modules/
│   └── <slug>/             # one folder per solver; slug = [a-z0-9-]+
│       ├── module.sh       # the solver (see §3)
│       ├── module.yml      # the manifest (see §2)
│       └── assets/         # optional: templates, icons, seed files
├── bin/
│   └── modulelint          # contract validator (runs in CI and gates)
└── docs/
```

Rules:

- One folder per module. The folder name **is** the slug (stable identity).
- No numbering anywhere in names. Menu numbers are positions computed at
  scan time — that is what makes "integrated as 3), 4), 5)" automatic and
  renumbering safe.
- Adding a solver = adding one folder. Removing = deleting one folder. The
  menu reflects both on the next launch with zero wiring.

## 2. Manifest (`module.yml`)

Every field is required unless marked optional. Kept deliberately small.

```yaml
title: Desktop shortcut creator        # menu label, plain language
description: >-                        # 1–3 sentences shown before running
  Creates a validated application menu entry and optional desktop icon,
  trusted the right way (user session, no sudo).
risk: low                              # low | elevated
undo: true                             # true | false
needs: []                              # optional: packages needed beyond a
                                       # fresh Mint 22 install, e.g. [flameshot]
order: 20                              # optional int; menu sorts by (order, slug);
                                       # omit → sorts after all ordered modules
asks: 2                                  # optional int; the module's question
                                         # budget (see §3); omit → 1
platform: mint-22                      # optional: compat target; default mint-22
```

Display rules: `risk: elevated` modules render a visible badge in the menu
and cannot be run without an explicit confirmation step that shows the exact
command and the undo statement. `undo: false` must be stated in the
description in plain words (e.g. "Package installs are not cleanly
undoable; this module says so instead of pretending.").

`needs:` enforcement (owner ruling 2026-09-18, MB-003/MB-005): entries are
LAUNCH-TIME requirements — commands the module cannot run without — never a
shopping list for the module to fetch (a module installs nothing to satisfy
its own needs; the user does that via Mint's Software Manager, explicitly).
While any declared need is absent on the host, the menu refuses to launch
`run`/`undo` with one plain line — `<slug>: not ready — missing need: <need>`
— and `--scan` reports the non-fatal `WARN <slug>: missing need: <need>`.
`plan`/`dry-run` stay available: they change nothing and teach the exact
command to satisfy the need.

## 3. Script contract (`module.sh`)

Invoked by the menu as:

```bash
module.sh <action>
```

Actions (all modules implement `describe`, `plan`, `dry-run`, `run`;
`undo` only when `undo: true`):

| Action    | Effect                                                                 |
|-----------|------------------------------------------------------------------------|
| `describe`| One-line human summary on stdout.                                       |
| `plan`    | What `run` *would* do, in plain numbered steps, before any dependency is touched. |
| `dry-run` | `plan` plus the exact commands, **changing nothing**, exit 0.           |
| `run`     | Do the thing. Detect already-done work and say so (idempotency).        |
| `undo`    | Reverse what `run` did (only what this module itself created/changed).  |

Conventions:

- **stdout is for humans**, stderr is for errors. Exit 0 = success, non-zero
  = failure with a one-line plain-language reason on stderr.
- **No runtime command generation.** Scripts contain reviewed commands;
  they must not `eval`, fetch-and-execute (`curl … | bash`), or build
  command strings from input at runtime.
- A module may ask a short, BOUNDED series of questions, each collecting a value only the user knows. The question budget is declared in the manifest (`asks: <n>`). Optional values accept Enter to skip. Every safety confirmation (risk badge, run/undo, elevated) stays with the menu, never inside the module. Question flows must be testable non-interactively (scripted stdin).
- **One confirmation per launch, at the menu (owner ruling 2026-09-18, MB-004).** The menu asks exactly one confirmation before a `run`/`undo` (typed slug for `risk: elevated`, one `Run '<slug>'? [y/N]` otherwise) and the module then runs to completion without re-asking anything. A module must never prompt for a y/N or other safety confirmation itself — `asks:` counts value questions only. A module invoked directly (developer lane) therefore also asks no safety question; it simply does its documented work.
- **User-level first.** No `sudo`/`pkexec` in `risk: low`. `elevated`
  modules use the shared `elevate` helper only (single confirmed, displayed
  step), and only for what genuinely needs it (e.g. `apt-get install` of
  `needs:`).
- **Home-directory scope** unless an elevated step is declared; never touch
  system config, never edit other users' files.
- **Idempotent**: re-run detects done-work, reports it, changes nothing.
- Shell style: `set -euo pipefail`, quote everything, no aliases, works
  under `bash` as shipped on Mint 22 (no bashisms beyond bash).

## 4. Menu behavior (`butler`)

- Scan `modules/` on every launch; parse manifests; validate lightly
  (missing/broken manifest → module listed as `(broken — excluded)` at the
  bottom, never crashes the menu).
- Sort by `(order, slug)`; render the numbered list exactly in the founder's
  shape:

  ```
  mintbutler — Tasks:

    1) Android file transfer        ⚠ elevated
    2) Desktop shortcut creator

  Select a task number (or: n next  p prev  /search  r refresh  q quit):
  ```

- On selection: clear screen, show `title`, `description`, risk badge, undo
  statement, then the menu: `[d]ry-run  [r]un  [u]ndo  [b]ack`.
- `run`/`undo` on `elevated`: show the exact command list, require typed
  confirmation, then execute with the `elevate` helper. This — and the
  matching single `[y/N]` for low-risk modules — is the ONLY confirmation of
  a launch; the module must not ask again (MB-004).
- Colors: ANSI when `stdout` is a TTY; plain otherwise (SSH/pipe-safe).
- Flags: `--list` (slugs + titles), `--run <slug>` (with `--dry-run`),
  `--scan` (run modulelint over all modules), `--help`.
- `q`/Ctrl-C quit cleanly everywhere; `r` rescans.
- **23-line law (enforced in the test suite):** no menu or submenu screen may exceed 23 terminal lines — ever. Screens that exceed the budget paginate: entries page + one header + one footer (`n next / p prev / numbers / s search / q done`).

## 5. Validation — `modulelint`

Runs on every PR (and via `./butler --scan` locally). A module passes only if:

1. Manifest exists, parses, all required fields present, `risk`/`undo` in
   the allowed sets; folder name matches `[a-z0-9-]+`.
2. Every declared action exists and is executable (`bash -n` syntax check
   minimum; `shellcheck` when installed — advisory, non-blocking on Mint
   defaults, blocking in CI).
3. Forbidden-pattern scan (hard fail): `eval`, `curl|bash`-family, `rm -rf`
   outside clearly scoped paths, unquoted variable expansions, `sudo` in
   `risk: low`, writes outside `$HOME` without an elevated declaration.
4. `dry-run` executed in a sandbox HOME (fake `$HOME`, captured env) must
   exit 0 and produce a non-empty plan; filesystem diff must be empty.
5. `run` executed in the same sandbox must either succeed, or fail with a
   plain-language stderr line — and never touch anything outside the
   sandbox HOME (strace/diff verified when available).
6. 23-line law, fully mechanical (MB-003): `describe`, `plan`, and `dry-run`
   stdout must each render in at most 23 terminal lines (strict line count,
   no exceptions). The test suite additionally renders every module's menu
   screens and applies the same bound.
7. `needs:` advisory (MB-005): a module whose declared needs are absent on
   the lint host still PASSES — honesty about a requirement is not a defect —
   but the report carries `WARN <slug>: missing need: <need>` (non-fatal).

The gate for every module PR = `modulelint` green + orchestrator's
independent read of the exact commands + owner merge. The same discipline
this repo's fleet uses everywhere else.

## 6. Worked example — seed module 2 (abridged)

`modules/desktop-shortcut-creator/` — `risk: low`, `undo: true`,
`needs: []`. `run`: ask (once) for app name/command/icon; write
`~/.local/share/applications/<slug>.desktop`; `desktop-file-validate` it;
`chmod +x`; `gio set <file> metadata::trusted true` **in the user session**
(never sudo — the gvfs metadata store is per-user); offer (second `ask`)
to copy to `~/Desktop`; refresh desktop icons. `undo`: delete exactly the
files this module wrote, re-checking the path list recorded at `run` time
under `~/.local/state/mintbutler/<slug>/`.
