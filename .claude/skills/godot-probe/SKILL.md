---
name: godot-probe
description: Write or repair a probe for this Godot project - the .tscn + .gd pairs under _tools/probes that assert a claim with DBG PASS/FAIL lines, and the windowed *_shot captures that prove a visual one. Use when adding checks for new behaviour, when a probe broke after a scene or API change, or when a claim needs measuring rather than eyeballing. For RUNNING probes, use godot-verify instead.
---

# Writing a probe

A probe is a scene that **builds the situation it wants, measures it, and quits**. It states
claims in English and backs each with a number. It is kept forever, so a later change re-runs
it — which means it must not depend on anything the designer is free to rearrange.

Layout: `_tools/probes/<subject>/<name>_probe.{tscn,gd}`, subjects being `characters`,
`explosives`, `inventory`, `tracks`, `ui`, `vfx`, `world`. The `.tscn` is three lines — a
`Node` with the script attached.

## The spine

Extend `ProbeBase` (`_tools/probes/probe_base.gd`) rather than re-declaring the counters:

```gdscript
extends ProbeBase
# DBG probe: <the claim this file exists to defend, in one sentence>

func _ready():
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await settle(6)   # let bodies fall onto the floor before measuring

	check(thing.works, "the thing works", "%d units" % thing.count)
	finish()          # prints the tally verify.sh counts the run by
```

`ProbeBase` gives you `check(ok, label, detail)`, `finish()`, `settle(frames)`, `headless()`,
`windowed(what)`, `capture()`, `frame_diff(a, b, step, band)`, `idle_floor()`,
`changed_mean(a, b)` and `save_shot(image, name)`. Adding a `class_name` means one
`verify.sh import` before the first run, and the generated `.gd.uid` gets committed beside
the script.

## Rules that were each paid for

1. **NEVER hardcode a scene path.** The level layout is the designer's and has moved under
   probes twice, each time as a null-instance crash. Reach the player through
   `InputManager.player` or the `player` group, singletons by TYPE
   (`find_children("*", "SandField", true, false)`), authored nodes by NAME
   (`find_child("TerrainFloors", true, false)`).
2. **Point mutable state at scratch files.** `SaveManager.save_path`/`backup_path` are vars
   precisely so a probe can never eat the real save.
3. **Barrier on the FACT, not a frame count.** Wait for the thing to be true — a live
   `current_scene` containing an armed player — not for N frames. Frame-counting lost the
   save-load race twice.
4. **The world runs while you measure.** The station spawn stands inside the pump's cool
   pocket, the noon sun burns an exposed probe player to death, and the 08:00 truck can
   wander through your test square. Stage the situation somewhere it is actually alone.
5. **One probe, one subject, kept forever.** Do not delete a probe to make a change pass.
6. **Never pin to one exact trace.** Timer-driven draws race on frame alignment; identical
   runs reproduce one of a small set of traces. Assert the invariant (live entries packed
   first, zeros after), not the slot order.

## Shots: proving something you can only look at

`*_shot` probes are **windowed** — `--headless` renders blank and hangs `frame_post_draw`.
Guard with `if not windowed("the haze"): finish()` and let the run report the skip.

The pattern that works is **toggle and diff**, never the eye:

```gdscript
var creep: float = await idle_floor()    # what a still frame costs on its own
var with_it: Image = await capture()
emitter.emitting = false
await settle(130)                        # let airborne particles live out
var without: Image = await capture()
var delta: float = frame_diff(with_it, without, 8, 0.34)
check(delta > maxf(creep * 6.0, 0.005), "the burning player visibly smokes",
		"%.5f over %.5f creep" % [delta, creep])
```

- Measure against **the run's own floor**, not an absolute — `idle_floor()` captures two
  frames with nothing changed, and the claim has to beat it severalfold. A hand-picked
  threshold is a number that was true on one machine on one day.
- **A lineup is a claim too.** A shot that stages models side by side is asserting they
  render *and* that none came up as Godot's white fallback: show them one at a time against
  the bare floor, and read `changed_mean(bare, lit)` to tell a texture from the stand-in.
- **Save through `save_shot(image, name)`**, which writes to `user://`. Six shots once
  carried an absolute path into the temp directory of the session that wrote them, and went
  on "saving" into somewhere that had stopped existing.
- **Let lerped state converge** before the capture pair (the screen haze takes ~90 frames);
  a drain-out mid-measurement pollutes the baseline.
- Save the png too (`user://<name>.png`) for the eyeball pass — but the check is the number.
- **Do not sample in screen space.** `CameraFollow.apply_zoom_anchor` offsets the camera per
  frame off the live cursor, so `unproject_position` does not land where things draw. That
  cost five rounds once. Diff whole frames or bands instead.

## When a shader effect "doesn't show"

Bisect with unconditional shader paints — a hardcoded disc, the raw uniform as `ALBEDO` —
**before** touching the data path. Two of three "fixes" in one night broke a working system
while chasing a misread capture, and SDFGI occlusion blobs pass convincingly for a radial
tint at small radii.
