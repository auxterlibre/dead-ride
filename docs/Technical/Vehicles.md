# Vehicles

Vehicle stats are defined as `VehicleData` resources (`.tres`) under `data/vehicles/`. Existing vehicles: `car.tres` (Station Wagon) and `delivery_truck.tres`. Scripts live under `scripts/data/` and `scripts/vehicles/`.

---

## The Knob / Span System

Like weapons, all vehicle performance stats are **0–100 integer knobs** remapped to real physics units via `*_SPAN` constants and `*_value` getters. Gameplay code always reads the getters.

**Calibration point: knob 50 = the original hand-tuned car.** If you edit the span ranges, verify that 50 still produces sensible behaviour before touching individual vehicles.

See [[Items#The Knob / Span System]] for the full rationale.

---

## VehicleData Fields

### Identity

| Field | Type | Notes |
|---|---|---|
| `name` | String | Display name: also used as the trunk container's title |
| `storage` | StorageData | Trunk grid layout. **null = no trunk to open** |
| `engine_audio` | AudioStream | Engine loop. null keeps the scene's default |
| `engine_malfunction_audio` | AudioStream | Swapped in automatically below 50% health |

### Stat Knobs (0–100) and their real ranges

| Knob | Real range | Notes |
|---|---|---|
| `health_max` | 50–550 HP | How much punishment the vehicle can take |
| `mass` | 400–2400 kg | Heavier = harder to push around and slower to accelerate |
| `engine_power` | 500–3000 (engine force) | Raw acceleration force |
| `speed_max` | 8–28 m/s | Top speed cap (~29–101 km/h) |
| `brake_force` | 50–450 | Stopping power |
| `fuel_tank_size` | 35–120 L | How far you can go before needing a refuel |
| `handling` | 0–1 dial | Expands into steer angle, steer speed, and wheel grip: see below |
| `drift` | 0–1 dial | Expands into rear grip loss, yaw assist, and drift brake: see below |
| `engine_tone` | 0–1 dial | Expands into engine audio pitch range: see below |

### Runtime (not exported)

- `current_fuel: float`: starts at a full tank, set by `apply_data()`.

---

## The Three Dial Knobs

Unlike one-to-one weapon stats, `handling`, `drift`, and `engine_tone` each fan out into multiple physics internals. **Knob 50 is the calibration point**: it reproduces the original tuned car.

### `handling`
Controls how the car steers and grips through corners.

| Internal | Range (0 → 100) | Effect |
|---|---|---|
| `steer_angle_max` | 0.3 → 0.7 rad | Max wheel turn angle |
| `steer_speed` | 1.5 → 3.5 | How fast the wheels respond to input |
| `rear_grip` | 1.0 → 2.0 | Wheel friction slip for all wheels (non-traction wheels get −0.1) |

Higher handling = sharper, more responsive steering and more grip.

### `drift`
Controls how easily the rear breaks away and how the car behaves in a slide.

| Internal | Range (0 → 100) | Effect |
|---|---|---|
| `drift_rear_grip` | 1.0 → 0.4 | Rear grip during a drift. Lower = slides more easily |
| `drift_yaw_assist` | 2.0 → 8.0 × mass_value | Rotational push during a drift. Keeps slides controllable |
| `drift_brake_force` | 15 → 5 | Braking strength while drifting |

Higher drift = tail slides out more aggressively. `drift_min_speed` is derived as `speed_max_value × 0.45`: drifting can't trigger below that speed.

### `engine_tone`
Purely audio: shapes the engine sound pitch range.

| Internal | Range (0 → 100) |
|---|---|
| `pitch_idle` | 0.6 → 1.1 |
| `pitch_full` | 1.1 → 1.9 |

---

## Runtime State (vehicle.gd)

`Vehicle extends VehicleBody3D`. The `data` resource is **duplicated at `_ready`** so two vehicles that share a `.tres` don't share a fuel tank.

### Control inputs

Anything that drives the vehicle writes to these three fields. The physics reads only them: no direct input calls. This is what lets the player and AI share the same steering:

| Field | Type | Notes |
|---|---|---|
| `control_throttle` | float | −1 (reverse) to 1 (forward) |
| `control_steer` | float | **+ is LEFT** (matches Godot's `VehicleBody3D.steering`) |
| `control_brake` | bool | |

### Key state

| Field | Notes |
|---|---|
| `health: int` | Has a setter: emits `Signals.vehicle_health_updated` only when player-driven |
| `driver: Character` | The character currently seated. Null if empty |
| `speed: float` | Current speed in m/s |
| `seated: bool` | Whether a driver is in the seat |
| `engine_power_scale: float` | Starts at 1.0, lerps down to 0.4 as health drops below 50% |
| `is_destroyed: bool` | Also aliased as `is_dead` so vision systems can duck-type vehicles as targets |
| `is_drifting: bool` | |
| `trunk_open: bool` | |
| `storage: Inventory` | The trunk inventory instance |

`get_faction()` returns the driver's faction, or **−1 when driverless**: no faction means no one's enemy.

### Constants

| Constant | Value | Notes |
|---|---|---|
| `EXIT_MAX_SPEED` | 10/3.6 m/s | Player can't exit above this speed |
| `FUEL_IDLE_BURN` | 0.02 L/s | Fuel consumed while engine is on but not accelerating |
| `FUEL_THROTTLE_BURN` | 0.2 L/s | Fuel consumed while accelerating |

---

## Damage (VehicleDamage)

No exported fields: all tuning is done via constants in the script.

### Ramming (hitting another character/vehicle at speed)

| Constant | Value |
|---|---|
| `RAM_MIN_SPEED` | 3.0 m/s |
| `RAM_MAX_SPEED` | 20.0 m/s |
| `RAM_LAUNCH_SPEED` | 8.0 m/s: above this, the victim goes airborne |
| `RAM_COOLDOWN` | 0.6 s per victim |

### Crash damage (sudden deceleration)

| Constant | Value |
|---|---|
| `CRASH_MIN_DELTA_V` | 4.0 m/s |
| `CRASH_MAX_DELTA_V` | 22.0 m/s |
| `CRASH_DAMAGE_SPAN` | 2–35 HP |
| `CRASH_COOLDOWN` | 0.5 s |
| `CRASH_HARDNESS_CHARACTER` | 0.15 (soft: characters absorb less crash force) |
| `CRASH_HARDNESS_VEHICLE` | 0.8 (walls and props are 1.0, passed inline) |

### Health-based damage states

| Health threshold | Effect |
|---|---|
| ≤ 50% | Engine power scale starts lerping down toward 0.4 |
| ≤ 50% | Malfunction audio swaps in |
| ≤ 50% | Smoke appears |
| ≤ 30% | Fire appears |

> **Note:** The vehicle names itself as `AttackData.attacker` in crash damage: never the `VehicleDamage` node. This is intentional: `VehicleAI` checks `attacker == vehicle` to tell a self-inflicted landing apart from a real attack (so customer NPCs don't flee after spawning above the road).

---

## Ground Effects (VehicleGroundFX)

Tunable exports on the component node:

| Field | Default | Notes |
|---|---|---|
| `skid_grip_threshold` | 0.55 | Wheel slip ratio above which skid trails appear |
| `squeal_min_slide` | 2.0 m/s | Minimum lateral slide to trigger tyre squeal |
| `dust_speed_size` | (0.7, 1.3) | Particle size range mapped to speed |
| `dust_speed_life` | (0.8, 1.25) | Particle lifetime range mapped to speed |

Ground type is sampled every `GROUND_SAMPLE_TIME = 0.25` s. The two dust banks (`dust_left/right` and `dust_left_alt/right_alt`) alternate to keep colours stable.

---

## AI Steering (VehicleSteering)

Two exports set the speed profile. Everything else is constants that rarely need touching.

| Export | Default | Notes |
|---|---|---|
| `cruise_speed` | 7.0 m/s | Normal driving speed |
| `corner_speed` | 3.0 m/s | Speed when turning. Delivery truck overrides to 6.0/2.5 |

Key behaviour constants (for reference):

| Constant | Value | Role |
|---|---|---|
| `ARRIVE_DISTANCE` | 2.5 m | Considered arrived at waypoint |
| `SLOW_DISTANCE` | 8.0 m | Starts slowing down |
| `BRAKE_DISTANCE` | 12.0 m | Starts braking hard |
| `STUCK_TIME` | 2.5 s | Time without movement before attempting unstick |
| `UNSTICK_ATTEMPTS` | 4 | Reverse attempts before giving up |
| `YIELD_RANGE` | 12.0 m | Distance at which vehicles yield to each other |

---

## Creating a New Vehicle

1. Duplicate `data/vehicles/car.tres` as a starting point.
2. Set `name` and optionally a `storage` grid for the trunk (null = no trunk).
3. Tune the knobs: remember **50 = original car**. Use it as a baseline and adjust from there:
   - More mass needs more engine power to compensate.
   - Higher speed usually needs higher brake force.
   - Handling and drift interact: a high-handling car with low drift is grippy; low handling with high drift is loose.
4. Assign audio streams if the vehicle needs a distinct engine sound.
5. Duplicate the `car.tscn` scene, assign the new `.tres` to the `data` property.
6. If it's an AI vehicle, configure `VehicleSteering`'s `cruise_speed` and `corner_speed` on the component node in the scene.
