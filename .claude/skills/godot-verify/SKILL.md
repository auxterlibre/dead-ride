---
name: godot-verify
description: Run this project's Godot checks headlessly - parse/run a scene, run one probe, run the whole probe suite, reimport assets, or take the windowed screenshot captures. Use after editing any GDScript, scene, shader or resource, whenever asked whether something still runs or what it measures, and before calling a change done. Do NOT hand-write ad-hoc Godot command lines; verify.sh is the one allowlisted entry point.
---

# Verifying

There is no test suite. Verification is **probes**: scenes that build a situation, print
`DBG PASS/FAIL <claim>: <measurement>` lines, and quit. Everything runs through
`Project/_tools/verify.sh`, which derives the project path and filters the engine's noise.
Never invoke the Godot binary directly — the permission allowlist matches whole commands,
and a raw command line turns a silent check into a prompt.

## Commands

```bash
./Project/_tools/verify.sh probes                  # every headless probe, tallied
./Project/_tools/verify.sh probes world            # one subject folder
./Project/_tools/verify.sh probes world/heat_probe # one probe
./Project/_tools/verify.sh shots                   # the WINDOWED *_shot captures
./Project/_tools/verify.sh scene res://scenes/game.tscn 120   # parse/run check
./Project/_tools/verify.sh import                  # reimport assets
./Project/_tools/verify.sh errors scene res://scenes/game.tscn  # error/DBG lines only
```

`probes` exits non-zero if any check failed **or** any probe ended without a tally.
`GODOT_BIN` overrides the binary; `PROBE_FRAMES` (default 20000) is the hang backstop.

## The order that avoids wasted runs

1. **Added a `class_name`?** `verify.sh import` FIRST, once — otherwise the run dies with
   `Identifier "Foo" not declared`.
2. **Added or renamed a `.gd`?** Godot mints its `.uid` sidecar during that import. Commit
   it with the script; a missing one has already cost a follow-up commit.
3. Run the probes for the subject you touched, then `verify.sh probes` before calling done.
4. **Touched anything visual?** The probes cannot see it — go to Windowed, below.

## Headless vs windowed — this is not a preference

`--headless` installs a dummy rasteriser. Under it, screenshots save **blank** and
`RenderingServer.frame_post_draw` never resolves, which hangs a capture step until the frame
budget kills it. So:

- `*_probe` = headless, rules and measurements.
- `*_shot` = **windowed**, look checks. `verify.sh shots` runs these without `--headless`.
  Asked to run one headlessly, say so rather than producing blank images.

A shot proves a visual claim by **toggling and diffing**, never by eye: capture with the
effect on, switch it off, capture again, compare mean RGB delta against the run's own floor.
Wisps and tints are routinely invisible in a still — three heat-smoke captures were called
"no smoke" while the emitter was rendering the whole time.

## Reading a run honestly

- Quote the actual `DBG` lines, error text and exit status. Never paraphrase a measurement
  into "looks fine".
- A **surprising** number is a finding even with no FAIL: a count that changed, a timing that
  doubled, a probe that passed far faster than it should, output that stops early.
- Probe runs are only *mostly* deterministic — timer-driven draws race on frame alignment, so
  identical runs reproduce one of a small set of traces. Never pin a claim to one exact trace.
- Known-benign noise, already filtered but worth recognising: `minimal_theme.tres` load
  failures, `resource_format_text.cpp:1442`, `resource_loader.cpp:317`, and exit-time
  `ObjectDB instances were leaked` / `resources still in use`.

## Delegating

The `godot-runner` agent runs these and reports raw evidence without deciding anything. Use
it for a verification sweep when you want the measurements back without the transcript. It
cannot edit files, by design — a fix it spots is reported, not made.

## Writing a new probe

See the `godot-probe` skill. Probes are KEPT, never deleted, so a later change re-runs them.
