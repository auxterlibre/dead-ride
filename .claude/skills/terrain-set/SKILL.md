---
name: terrain-set
description: Fix, conform, and wire TerraBrush terrain texture sets in this project using the _tools/terrain_set.gd tool instead of manual conversion. Use whenever the user adds new terrain textures, says "fix the textures in <folder>", drops files (png/bmp/jpg) into assets/textures/terrains/, hits TerraBrush errors like "does not have the expected format" or a black terrain, or a set won't appear in the paint palette — even if they only name a texture folder without mentioning TerraBrush. Do NOT hand-write conversion scratchpad scripts for terrain textures; the tool already does it.
---

# Terrain texture sets

TerraBrush stacks every palette set's textures into `Texture2DArray`s, which demand one format
and size per slot across ALL sets: **albedo RGB8, normal RGBA8, roughness RGB8, height L8 —
all 1024x1024 PNG, mipmaps ON**. Any texture off-contract breaks the whole array ("expected
format" errors, black terrain). `Project/_tools/terrain_set.gd` conforms a set folder in one
run; don't redo its work by hand.

## Commands

Fix/wire one set (folder name under `assets/textures/terrains/`):

```bash
./Project/_tools/verify.sh dbg script res://_tools/terrain_set.gd -- <folder>
```

Then import (registers uids, builds mipmapped ctex — the tool pre-writes `.import` sidecars
with mipmaps on and minted uids, so ONE import pass suffices):

```bash
./Project/_tools/verify.sh import errors
```

Audit every set folder (formats, sizes, mipmaps, palette membership):

```bash
./Project/_tools/verify.sh dbg script res://_tools/terrain_set.gd -- check
```

The fix run: classifies sources by filename (albedo/color/diff, normal, rough,
height/heigh/disp), converts any loadable format (bmp/jpg/tga/webp -> png, originals
deleted), strips junk alpha, resizes to 1024, generates a flat 0.87 roughness when missing,
rewrites the set `.tres` (reusing legacy file names and uids), and adds the set to
`terrain_sets.tres`. Idempotent — rerunning on a healthy set changes nothing.

## When the tool refuses

- **"alpha channel carries data"** — the albedo's alpha varies, so stripping it would destroy
  something. If the TerraBrush node's `albedoAlphaChannelUsage` is None (the project default),
  the alpha is an export artifact: flatten it in the source and rerun. If the user means to
  pack roughness/height into alpha, the project contract itself changes — stop and discuss.
- **"no albedo/normal/height texture found"** — the tool won't invent detail maps. Ask the
  user for the missing source (only roughness is generatable).
- A non-square source gets stretched to 1024 with a warning — it's usually a photo crop, not
  a tileable texture. Tell the user to eyeball it in-game and swap in a proper source if it
  smears.

## Gotchas

- The user's open editor holds the TerraBrush DLL, so headless runs print GDExtension load
  errors — harmless for texture work, but TerraBrush's own array validation only runs when
  the editor is closed. A truly clean `import errors` pass with the editor closed is the
  definitive check.
- The open editor also rewrites `terrain_sets.tres` and swaps texture files without warning.
  Re-read files before editing them, rerun `check` rather than trusting earlier results, and
  after fixing tell the user to reload the scene (or restart the editor if stale array
  caches persist).
- Every palette set needs all four slots — a set missing one poisons that slot's array for
  everyone (the addon placeholder doesn't match every slot format).
