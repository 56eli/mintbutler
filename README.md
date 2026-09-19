# mintbutler — the instant chore box for Linux Mint

_Working name — rename freely. Target: Linux Mint 22.x (Cinnamon; degrades gracefully on Xfce/MATE editions). Built and maintained by an agent fleet under owner governance — see "How this repo is built"._

## Why

I switched from Windows to Linux Mint and I love it. But Linux doesn't let me
"explore" the way Windows did: a terminal command that looks arcane to me can
scramble my operating system, dangerous and mundane commands look alike, and
AI assistants keep handing me command snippets that might be buggy.

At the same time the daily pains are real: creating a desktop shortcut is a
ritual, populating the start menu with application links is buggy in the
shipping tools, and every little chore sends me down a forum rabbit hole.

**mintbutler is the fix: a toolbox and chorekit that gives instant solutions
to my Linux environment.** One pretty terminal script. I press a number, the
thing just works, and nothing I didn't ask for happened.

## What it is

A single zero-dependency script (`butler`) that lists module-based tasks:

```
mintbutler — Tasks:

  1) Android file transfer
  2) Desktop shortcut creator
  3) ...

Select a task number (or: q quit  /search  r refresh):
```

Every entry is a **module**: a small, reviewed task solver that lives in
`modules/`. Drop a new folder into `modules/` and it appears as the next
number on the next launch — no registration, no edits to the main script.
Numbers are **positions, not identities**: they renumber automatically as
modules come and go, and every module also has a stable slug
(`./butler --run desktop-shortcut-creator`).

Quality-of-life built in: colored output, risk badges, a description +
plan shown before anything runs, dry-run mode for every module, undo where
the underlying operation allows it, `--list` and `--run <slug>` flags for
power use, `q` quits, works over plain SSH.

## The safety contract (non-negotiable)

1. **No runtime command generation.** `butler` never composes or improvises
   shell commands. It only runs module scripts that were reviewed and merged
   into this repository. AI assistance happens at *authoring* time, inside a
   reviewed PR — never at *execution* time on the machine.
2. **User-level first.** Modules operate inside the home directory and never
   need `sudo`. Anything that genuinely requires root (e.g. installing a
   package) is risk-class `elevated`: it says so in the menu, shows the exact
   command, requires an explicit confirmation, and explains the undo
   situation honestly (some things, like package installs, cannot be cleanly
   undone — the module says so instead of pretending).
3. **Dry-run before do.** Every module implements `dry-run`: it prints
   exactly what it *would* do, changes nothing, and exits.
4. **Undo or say so.** Every module either ships an `undo` action or declares
   `undo: false` in plain language.
5. **Idempotent where sensible.** Re-running a module must not pile up
   garbage; it detects done-work and says so.
6. **Zero dependencies beyond a fresh Mint 22 install.** If a chore needs a
   package, the module installs it as an explicit, visible, confirmed step —
   and that's the exception, never the pattern.

## Modules

Each module is one folder with a manifest and a script. The full contract —
manifest fields, actions, output conventions, validation — lives in
[docs/MODULE_SPEC.md](docs/MODULE_SPEC.md). The owner vision this all serves
is [docs/VISION.md](docs/VISION.md).

Modules shipped and planned:

- **Desktop shortcut creator** (shipped, v0.1) — validated `.desktop`
  entries the right way (user session, no sudo): scan & place installed
  apps or build custom app/folder/URL launchers, trusted desktop copies,
  undo = delete exactly the files it wrote. See
  `modules/desktop-shortcut-creator/`.
- **Module batch #1** (owner-approved 2026-09-16): appimage-installer,
  default-apps-editor, multimedia-codecs, screenshot-studio,
  printer-helper, system-report-pack, timeshift-guardian (features) and
  book-access-doctor, audio-repair (fixes) — one reviewed PR per module.
  The Android file transfer seed was cancelled by the owner before
  implementation.

## Running

```bash
git clone https://github.com/56eli/mintbutler.git
cd mintbutler
./butler
```

That's the whole install. No services, no daemons, no auto-update, no
telemetry, no config sprawl.

## How this repo is built (for agent and orchestrator sessions)

This repository is developed by an agent fleet under a fixed governance
loop: **agents author pull requests; the orchestrator gates every PR by
independent verification; the owner is the only one who merges.** If you are
an orchestrator or builder session booting here:

1. Read `docs/VISION.md` first — it is the owner's vision baseline and the
   yardstick every later review measures drift against. Do not paraphrase
   it; quote it.
2. Read `docs/MODULE_SPEC.md` before touching `modules/` or the menu
   script — the module contract and `modulelint` validation are the gate's
   mechanical teeth.
3. The safety contract above is product law, not documentation. A PR that
   violates it is rejected regardless of code quality.
4. Never test against the owner's machine. All verification happens in this
   repo's sandboxes/CI plus the owner's manual acceptance; the owner runs
   `butler` on Mint 22.2 and reports back.

### Running the tests

```bash
bash tests/run-tests.sh
bin/modulelint                 # all modules in modules/
bin/modulelint <slug>          # one module
```

- `tests/run-tests.sh` is a zero-dependency harness: it copies butler +
  lib + fixtures into a temp dir and exercises every module against stub
  binaries. **It defaults to NEVER invoking real binaries** — by default a
  refusing, recording `sudo` stub sits first on the harness PATH as a
  tripwire (any accidental real `sudo` is declined and logged). Enter
  `MB_TEST_ALLOW_REAL_SUDO=1 bash tests/run-tests.sh` to consent to the
  real-sudo lane, which today only probes `sudo -n true` and reports the
  result; no stage needs it.
- `bin/modulelint` runs `describe`/`plan`/`dry-run`/`run` in a sandbox:
  fake `HOME`, and `sudo`, `amixer`, `lpoptions`, `dconf` shadowed by
  refusing stubs, so a module can never touch real privileges or session
  settings through lint.

## Roadmap

- v0.1 — menu script + module discovery + `modulelint` + desktop-shortcut-
  creator (the android-file-transfer seed was cancelled by owner) —
  complete.
- v0.2 — categories/sections in the menu, search filter, favorites.
- v0.3+ — the backlog *is the owner's life*: each new chore he hits becomes
  exactly one reviewed module.
