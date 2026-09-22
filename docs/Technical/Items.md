# Items

All items extend `ItemData` (base resource). Seven subclasses cover every item type. Files live under `data/items/`; scripts under `scripts/data/items/`.

---

## The Knob / Span System

Weapons and explosives expose **0–100 integer knobs** for tuning. The engine remaps these to real units at read time via `*_SPAN` constants and `*_value` getters. Gameplay code always reads the getters: never the raw knobs.

**Why it matters for balancing:**
- You compare weapons on a uniform 0–100 scale regardless of what unit they measure.
- To recalibrate an entire weapon class (e.g. make all pistols hit harder), change the `DAMAGE_SPAN` constant: no need to touch every `.tres`.
- The in-game tooltip intentionally shows knob values, not remapped units.

**Exceptions: these are literal, not knobs:**
`max_ammo`, `projectiles_per_shot`, `max_stack`, `cock_time`, `aim_yaw_offset`, `ConsumableData.health`: counts and calibration that don't need a uniform scale.

---

## ItemData (base)

Every item has these fields:

| Field | Type | Default | Notes |
|---|---|---|---|
| `name` | String | — | Display name |
| `weight` | float | 0.0 | Currently unused for movement penalty, but tracked |
| `size` | Vector2i | (1,1) | Grid footprint in the inventory. Width × Height in cells |
| `icon` | Texture2D | null | Inventory icon |
| `rarity` | Enum | `COMMON` | `COMMON`, `UNCOMMON`, `RARE`, `EPIC`: drives tooltip colour |
| `price` | int | 0 | What the delivery truck pays per unit |

---

## WeaponData

Script: `weapon_data.gd`. All numeric stats except `max_ammo`, `projectiles_per_shot`, and `cock_time` are **0–100 knobs**.

### Identifiers

| Field | Type | Notes |
|---|---|---|
| `type` | Enum | `MELEE_1H`, `MELEE_2H`, `RANGED_1H`, `RANGED_2H` |
| `weapon_class` | Enum | `PISTOL`, `REVOLVER`, `SHOTGUN`, `ASSAULT_RIFLE`, `SMG`, `RIFLE`, `MELEE` |
| `ammo_type` | Enum | `LIGHT`, `MEDIUM`, `HEAVY`, `SHOTGUN` |
| `fire_mode` | Enum | `SEMI_AUTO`, `AUTOMATIC`, `MANUAL` (pump/bolt: requires `cock_time`) |
| `model` | PackedScene | 3D weapon model |

### Stat Knobs (0–100) and their real ranges

| Knob | Real range | Notes |
|---|---|---|
| `damage` | 1–21 HP | Damage per projectile hit |
| `effective_range` | 2–42 m | Distance at which accuracy starts to degrade |
| `accuracy` | 30→0° cone | **Inverted**: 100 = laser (0° spread), 0 = wild (30°) |
| `recoil` | 0–100% | Bloom added per shot |
| `knockback_distance` | 0–5 m | How far the target is pushed per hit |
| `fire_rate` | 1–21 shots/s | Rate of fire. Determines `fire_interval` (1 / rate) |
| `reload_time` | 0.5–5.5 s | Full reload duration |
| `camera_kick` | 0–1 | Camera lurch per shot. 0 = none, 1 = max |
| `projectiles_spread` | 0–60° | Cone spread between pellets (mainly for shotguns) |
| `noise` | 0–60 m | Detection radius on fire |

### Literal fields

| Field | Type | Notes |
|---|---|---|
| `max_ammo` | int | Magazine size. 0 = melee |
| `projectiles_per_shot` | int | Pellets fired per trigger pull |
| `cock_time` | float (s) | Pump/bolt delay. Only applies to `MANUAL` fire mode |
| `aim_yaw_offset` | float (−90°–90°) | Rotates the aim direction. Use for sideways-held or angled weapons |

### Runtime (not exported)

- `current_ammo: int`: starts at −1 (unloaded) until the player loads it.

---

## ExplosiveData

Script: `explosive_data.gd`. Same knob pattern as weapons.

| Knob | Real range | Notes |
|---|---|---|
| `damage` | 10–160 HP | Damage at the centre of the blast |
| `blast_radius` | 1–12 m | Outer edge of the explosion |
| `core_size` | 0–1 (share) | Fraction of `blast_radius` that takes full damage. Beyond the core, damage falls off linearly |
| `fuse_time` | 0–8 s | Delay before detonation |
| `knockback_distance` | 0–8 m | Knockback at the centre |

Literal fields: `max_stack` (1–9), `model` (thrown body scene), `held_scene` (hand pose scene).

Methods: `damage_at(distance)` and `knockback_at(distance)` return interpolated values from centre to edge.

---

## ConsumableData

Script: `consumable_data.gd`.

| Field | Type | Notes |
|---|---|---|
| `health` | int | HP restored on use. **Literal, not a knob** |
| `max_stack` | int (1–9) | How many can occupy one inventory slot |

---

## AmmoData

Script: `ammo_data.gd`. Only one field:

| Field | Type | Notes |
|---|---|---|
| `ammo_type` | Enum | `LIGHT`, `MEDIUM`, `HEAVY`, `SHOTGUN` |

Stack size is fixed by calibre: not editable per item:

| Ammo type | Max stack |
|---|---|
| Light | 80 |
| Medium | 60 |
| Heavy | 20 |
| Shotgun | 30 |

---

## BackpackData

Script: `backpack_data.gd`.

| Field | Type | Notes |
|---|---|---|
| `slots` | int | Total quick-bar slots. The first 2 are always weapon slots |
| `storage` | StorageData | The grid definition (see below) |
| `mesh` | Mesh | 3D backpack mesh |
| `skin` | Skin | Mesh skin/rig binding |

---

## StorageData

Script: `storage_data.gd`. Defines the inventory grid layout using an **ASCII mask**:

- `.` or space = usable cell
- Any other character = locked cell

The mask is drawn as a multiline string that visually matches the grid shape. Example: a 6×6 octagon with 20 usable cells (the hiker pack):

```
XX..XX
X....X
......
......
X....X
XX..XX
```

The `size` (Vector2i) and `open_cells` dictionary are parsed lazily from the mask. You never need to count cells manually.

---

## ToolData

Script: `tool_data.gd`.

| Field | Type | Notes |
|---|---|---|
| `mesh` | Mesh | 3D tool mesh |
| `repair_amount` | int (0–100) | Percentage of max vehicle hull restored per use |

---

## TrinketData

Script: `trinket_data.gd`. No extra fields: these are purely collectible/sellable. `ItemData.price` is the only stat that matters.

---

## LootTableData

Script: `loot_table_data.gd`. Defines what a container can drop.

| Field | Type | Notes |
|---|---|---|
| `entries` | Array[LootEntryData] | Possible drops |
| `draws` | Vector2i | Random range of how many entries are drawn per open |

**LootEntryData** (`loot_entry_data.gd`):

| Field | Type | Notes |
|---|---|---|
| `item` | ItemData | The item to potentially drop |
| `weight` | float | Relative probability: higher = more likely |
| `count` | Vector2i | Min–max quantity drawn (inclusive) |

---

## Creating a New Item

1. Choose the right subclass for the item type.
2. Duplicate a similar `.tres` from `data/items/` as a starting point.
3. Fill in the base `ItemData` fields: `name`, `size`, `icon`, `rarity`, `price`.
4. Set subclass-specific fields using the knob ranges as a guide: compare against existing items of the same class.
5. For weapons, remember `accuracy` is inverted (100 = most accurate).
6. For storage/backpacks, draw the ASCII mask in `StorageData`: the grid shape is what you see.
