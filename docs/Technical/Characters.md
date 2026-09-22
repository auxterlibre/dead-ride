# Characters

Characters are defined as `CharacterData` resources (`.tres` files) stored under `data/characters/` (player, mannequin) and `data/enemies/` (survivalist, scavenger, marksman). The script is `scripts/data/character_data.gd`.

---

## CharacterData Fields

| Field | Type | Default | What it does |
|---|---|---|---|
| `first_name` | String | — | Character's first name |
| `last_name` | String | — | Character's last name |
| `faction` | Enum | `PLAYER` | Determines allegiance: `PLAYER`, `ENEMY`, or `NEUTRAL` |
| `max_health` | int (1–100) | 10 | Maximum HP. Higher = tankier |
| `speed` | float (1–10) | 5.0 | Movement speed. 1 = very slow, 10 = very fast |
| `vision_range` | float (0–50) | 15.0 | Radius of the detection sphere. Enemy sees the player if within this range |
| `detection_range` | float (0–20) | 5.0 | Inner radius for instant acquisition: no build-up needed. Must be ≤ `vision_range` |
| `combat_range` | float (0–60) | 30.0 | Once engaged, enemy stays aggressive while the player is within this radius |
| `current_weapon_idx` | int (0–2) | 0 | Which weapon in `weapon_inventory` is equipped at spawn |
| `backpack` | BackpackData | null | Backpack resource, defines inventory space |
| `body_path` | String | — | Path to the folder containing the character's rig meshes (e.g. `res://assets/meshes/characters/lumberjack/`) |
| `dead_animation` | String | `"death_a"` | Animation clip played on death |
| `ai_script` | Script | null | The AI behaviour script attached to this character. Leave null for the player |
| `weapon_inventory` | Array[WeaponData] | [] | Weapons the character carries. Index matches `current_weapon_idx` |
| `starting_items` | Array[ItemData] | [] | Non-weapon items the character spawns with |

### Computed

- `name`: read-only, returns `"First Last"`. Do not try to set it.

---

## Vision vs Detection vs Combat Range

These three ranges work together to shape how an enemy reacts:

- **vision_range**: the outer bubble. The enemy can *see* the player from here, but may take a moment to react.
- **detection_range**: the inner bubble. Stepping inside this means instant aggro, no delay.
- **combat_range**: once engaged, the enemy won't disengage until the player exits this radius. Set it larger than `vision_range` if you want persistent pursuit; smaller if you want enemies to give up easily.

---

## Runtime State

Defined in `scripts/characters/character.gd` (`Character extends CharacterBody3D`). These are not part of the resource: they live on the scene instance:

- `current_health: int`: starts at `max_health`
- `is_dead: bool`
- `stored_collision_layer: int`: saved before death to restore if needed
- Component refs: `movement`, `animator`, `aim`, `weapons`, `carried`, `trail`

### Signals
- `died`: emitted on death
- `damaged(attack)`: emitted when hit, passes an `AttackData` object

---

## AttackData

Constructed at the call site (not a resource). Fields:

| Field | Type | Notes |
|---|---|---|
| `damage` | int | HP removed |
| `knockback_origin` | Vector3 | Point the knockback pushes away from |
| `knockback_distance` | float | How far the target is pushed |
| `attacker` | Node3D | Reference to the attacking character |

---

## Player Money

`PlayerData` is a static-only class (not a resource). It holds `current_money: int` and exposes `add_money()` and `spend_money()`.

---

## Creating a New Character

1. Duplicate an existing `.tres` from `data/characters/` or `data/enemies/` as a starting point.
2. Set `first_name`, `last_name`, and `faction`.
3. Tune `max_health` and `speed` for the role.
4. Set the three range values. A good rule of thumb: `detection_range` < `vision_range` < `combat_range`.
5. Assign a `body_path` pointing to the mesh folder.
6. Assign an `ai_script` (enemies) or leave null (player).
7. Populate `weapon_inventory` and `starting_items`.
