# Architecture

How the code is built, and what each piece cost to get right. This is the engineer-facing
half of the vault: the traps, the races, the approaches that were tried and abandoned.

`CLAUDE.md` at the repo root is the MAP over these — what exists and where it lives, plus the
rules that bite before you would think to open a doc. It stays short on purpose; **depth
belongs here**. When a change teaches you something, append it to the system's file below
rather than to the map.

For what the game *is*, see [[Docs/Design/_Index|Design]]. For what the tuning knobs *mean*,
see [[Docs/Technical/_Index|Technical]].

## Contents

- [[Autoloads]]: Settings, SaveManager, Calendar and the day/night cycle
- [[Desert]]: wind, the scorch window and cool pockets, the sand field shader
- [[Characters]]: the shared base scene, the component split, the enemy brain, animation
- [[Inventory]]: the grid, quick slots, the ammo economy, energy, the backpack UI
- [[Data]]: the state machine, and every `*Data` resource
- [[Weapons]]: the shot line, surfaces, impact VFX, blood pools
- [[Vehicles]]: the base scene, driving, damage, ground effects, the explosion
- [[Station]]: the pump, lockers and loot, the build grid
- [[Crops]]: growth rules, the plot and its spots, the fuel can
- [[Traffic]]: road splines, vehicle AI and steering, the delivery truck
- [[UI]]: HUD, screens, prompts and the interaction ladder
- [[Terrain]]: the ground mesh, the two GridMaps, the painter and autotiler
