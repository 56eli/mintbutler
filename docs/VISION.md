# Vision — the owner's baseline (quote, never paraphrase)

This document is the measuring stick. Every review, every gate, every new
module is checked against what the owner actually said. It is a vision
baseline, not marketing: when reality and this file disagree, the work is
drifting, and drift gets flagged.

## The owner, in his own situation

> I like Linux and I loved the switch from Windows. At the same time I can't
> really go "exploring" like on Windows, because I could easily scramble my
> operating system by using commands in a terminal that look arcane to me,
> where dangerous and mundane commands might look similar. Or even worse,
> where AI can hand me command snippets which might be buggy.

> The vision is a toolbox and chorekit to give instant solutions to my Linux
> environment. A pretty script — no GUI — that lists module-based tasks:
> I start it, it shows "Tasks: 1) Android file transfer, 2) Desktop shortcut
> creator", and whenever I build new task solvers I want them integrated
> like modules in the main script, added as 3), 4), 5), with flexible
> ordering and all that quality-of-life stuff.

## The yardstick

**"My trusted chore box: I press a number, the thing just works, and nothing
I didn't ask for happened."**

A module, a PR, or a feature that fails this sentence fails review — no
matter how clever the code is.

## What success feels like

- **Instant.** Clone, `./butler`, pick a number. Seconds, not setup.
- **Understandable.** Before anything runs, the owner can read in plain
  language what is about to happen. Nothing arcane, nothing that hides.
- **Reversible, or honest.** Undo exists where the operation allows it; where
  it doesn't, the module says so up front. Never silent one-way doors.
- **Growing without friction.** A new solver is one new folder in `modules/`.
  It shows up numbered. Nothing else to wire.
- **Safe by construction.** The owner never trusts a stray snippet again:
  everything this tool can do was reviewed in the open, in this repo.

## Anti-goals (a "no" here is a feature)

- No GUI. Terminal-native, pretty through craft: clean layout, color, order.
- No daemons, no background services, no auto-updates, no telemetry.
- No config sprawl: zero-config must remain the normal case.
- No dependency pile: a fresh Linux Mint 22 install is the whole platform.
- No `sudo` in the happy path; root appears only as a loud, confirmed,
  exceptional step (e.g. a package install a chore genuinely needs).
- No generated-at-runtime commands. Ever. Reviewed scripts only.

## Succession note for future sessions

The owner's trust is the product. Code can be rewritten in an afternoon;
trust, once broken by one silent surprise, cannot. When in doubt between
convenience and the safety contract, the contract wins — and the doubt gets
recorded and shown to the owner.
