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


  ## Current Implementations

  AppImage installer (order 10) — (a) Turns a downloaded .AppImage file into a proper Mint menu app: it installs a private copy and creates the menu entry for you. (b) It asks for the file path and an entry name, validates the file, copies it to ~/.local/share/mintbutler-appimages/, makes it executable, and writes the .desktop entry through the shared desktop-entry pipeline; name collisions land as -2, -3… and an identical existing copy is reused instead of duplicated. (c) It never touches your original file, works only inside your home directory (no system files, no root), refuses to create an entry whose command line would break from unquoted spaces, and records everything it creates so undo removes exactly the copy and the entry and nothing else.

Desktop shortcut creator (order 20) — (a) Creates desktop/menu launchers: custom apps, folder links, web links, or copies of existing entries found by scanning your system. (b) It walks you through a short question series (type, target, name, icon), builds a standards-compliant .desktop file, and places it where you choose; if an existing entry would be shadowed it warns you and records that. (c) It only writes launcher files and its own state record — never edits existing entries, never changes system config — and it refuses unquoted commands with spaces rather than producing a broken shortcut; undo deletes exactly the files it created.

Default apps editor (30) — (a) Changes which application opens a whole MIME category (e.g. web browser, mail client) or a custom MIME type. (b) It scans the installed .desktop files that claim the category's MIME types, shows you the current default versus the new one for every type, then applies the change with xdg-mime. (c) Before writing anything it makes a byte-for-byte backup of your mimeapps.list, verifies every single assignment after writing, and on any mismatch automatically restores the backup; undo restores that backup exactly. It only ever touches that one per-user file inside $HOME — nothing system-wide.

Multimedia codecs (40) — (a) Gets your missing multimedia codecs installed — the GStreamer bad/ugly plugin sets, GStreamer libav, and libavcodec-extra — so stubborn audio/video formats play. (b) It first checks each of the four curated packages with dpkg -s, shows you exactly which are missing, and after the menu confirmation runs one elevated apt-get install -y of only the missing ones through the shared elevate helper, then re-checks each package and reports per-package. (c) It can only ever install those four exact packages (hard-coded, reviewed list — nothing else, no apt-get update, no removals), shows you the precise elevated command before it runs, and never pretends an install can be undone — it prints the exact manual removal command instead; the test suite runs against stub binaries that never install anything.

Screenshot studio (50) — (a) Sets up a proper screenshot workflow: installs Flameshot and binds it to the Print key, optionally in a custom screenshot slot. (b) After the menu confirmation it performs the elevated apt-get install flameshot, then rebinds the key via dconf, recording the previous binding and slot state before it changes anything. (c) The install command is fixed and reviewed, every elevated step travels as a safe argument list through the shared elevate helper, and re-running is idempotent — it detects an existing correct setup and changes nothing. Its undo story is stated honestly: undo restores the old key binding and removes the slot, but Flameshot itself stays installed (the module says so rather than pretending otherwise).

Printer helper (60) — (a) A doctor for printing: it tells you in plain words what's going on with your printers — service state, configured queues, detected devices — and guides setup when nothing is configured yet. (b) It reads the CUPS state with lpstat and lpinfo, reports each queue's state, and its one repair is pointing the default printer at a healthy queue when the default is missing or stale (via lpoptions -d), after the menu confirmation. (c) It runs with zero elevation — no root, no service management, no driver downloads (never vendor blobs), no queue creation or deletion — and guidance for anything requiring root points you to Mint's own tools instead; the default-printer change is recorded first and undo restores the previous default exactly.

System report pack (70) — (a) Prints a clean, copy-pasteable snapshot of your machine — distro, kernel, hostname, uptime, CPU model and load, memory, disk usage of /, session type — handy when asking for help. (b) It gathers only from tools a stock Mint ships (uname, uptime, free, df, optional lscpu, /etc/os-release, your session environment) and prints one short screen; any section that can't be read shows (unavailable) instead of failing. (c) It is read-only by construction: it installs nothing (never inxi), writes nothing anywhere, uses no network, needs no root, asks no questions — there is literally nothing it could break, and its undo is honestly marked "nothing to undo because nothing is ever changed."

Timeshift guardian (80) — (a) Makes sure you get a fresh Timeshift system snapshot — your safety net before anything risky. (b) It runs elevated timeshift --list to read the current state; if Timeshift isn't configured yet it explains how to set it up and stops there; if it is configured, after the menu confirmation it creates exactly one new snapshot with a dated comment and verifies it with a second --list. (c) It is strictly additive: it never deletes, prunes, or restores snapshots, so the worst it can do is create one extra snapshot; the snapshot comment travels as a single safely-quoted argument, every elevated step goes through the shared elevate helper, and a failed elevated step is reported plainly with nothing claimed.

Book access doctor (900) — (a) Fixes the classic "my e-reader/book device landed read-only" problem: it inspects removable mounts under /media and /run/media and tells you what each one is and whether it takes writes. (b) It reads the mount table with findmnt, reports each mount's source, filesystem, options, and writability, and if a mount is read-only it offers one repair — an elevated mount -o remount,rw of that one mount — shown to you exactly before the confirmation. (c) The repair only applies to filesystems where remounting genuinely helps (vfat/exfat/ext/ntfs3/f2fs — a read-only disc gets an honest "not applicable" verdict), it records the previous options before remounting and undo remounts read-only again, it never writes fstab (persistence guidance is print-only, pointing at the Disks app), and it never runs chmod of any kind — no chmod -R 777, ever.

Audio repair (910) — (a) A sound doctor: when audio goes silent it diagnoses the whole chain and, when there's one true fix, applies it — otherwise it tells you honestly what's wrong. (b) It walks a fixed ladder: sound-server status (pactl info), output devices (pactl list short sinks), the Master mixer control (amixer), and — only when no output device exists — a read-only elevated dmesg scan for driver/firmware errors. Its one repair is restoring a muted or zeroed Master control; driver-level problems get a plain "this may need a newer kernel or firmware" verdict instead of a fake config fix. (c) Every step is read-only until the single confirmed repair, which records the exact previous volume and mute state before applying, verifies the result, and rolls back on any mismatch; undo restores the recorded state exactly, and the only elevated operation in the whole module is a read-only kernel-log scan.
