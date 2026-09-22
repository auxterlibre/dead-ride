Genre: Vehicular action / Looter with RPG progression

# Dead Ride

You drive a truck through a lawless desert. Your crew rides in the bed and shoots at anything hostile that gets close. Enemies come at you on foot and in vehicles of their own, and what they drop is yours to take.

The player only ever drives. Aiming and firing belong to the crew: each character in the truck bed picks targets and fires on their own, so the player's skill is in where the truck goes, how fast, and which fights to take. Between runs the loot goes into three things: upgrading the truck, levelling the characters, and equipping them with better weapons and gear.

## Core loop

1. **Drive.** Pick a route into the desert. Enemies engage as you pass through their territory.
2. **Fight.** The crew auto-fires from the back of the truck. The player positions the truck to give them lines of fire, run enemies down, or get out of trouble.
3. **Loot.** Dead enemies and wrecked vehicles drop weapons, gear, and parts.
4. **Upgrade.** Back at base, spend the haul on the truck, the crew's levels, and their loadouts. Then drive out further.

## Pillars

- **The truck is the character.** Speed, armour, handling, and how many crew fit in the bed are the player's main stats.
- **The crew does the shooting.** Their weapons, levels, and gear decide how a fight goes. The player decides where the fight happens.
- **Loot is the reward for every kill.** No farming, no shopkeeping between fights.
- **No ammo.** Guns never run out. A gunfight is decided by fire rate and reload time, and loot goes to the truck and the crew, never to bullets.

## Carried over from Nowhere

The codebase started as a copy of Nowhere, a gas station survival prototype. These systems keep their role:

- **Weapons and ammo**: the ranged and melee weapon set, the four ammo types, and throwables. See [[Items]].
- **Vehicles**: the drivable truck, damage, and the vehicle AI that will drive enemy vehicles. See [[Vehicles]].
- **Characters**: the shared character base and the enemy brain, which will become the auto-firing crew and the enemies they fight. See [[Enemies]].
- **Inventory**: the grid inventory, now used for the loot haul and character loadouts.
- **Loot boxes**: containers found in the desert. See [[Loot Boxes]].

## Legacy, out of scope

Crops, the gas pump economy, the weekly delivery truck, the energy and heat survival mechanics, and recruiting NPCs for chores are Nowhere's design, not this game's. Their docs stay in the vault until the systems are removed or repurposed: [[Crops]], [[Gas Stop]], [[Fuel]], [[NPCs]].

## Open questions

- What is "base"? A fixed garage, or the truck itself between runs?
- Do enemies fight mostly on foot, mostly in vehicles, or a mix per territory?
- Can the player ever leave the driver's seat during a run?

---

## Design Docs

- [[Game Loop]]
- [[Items]]
- [[Vehicles]]
- [[Enemies]]
- [[Loot Boxes]]
