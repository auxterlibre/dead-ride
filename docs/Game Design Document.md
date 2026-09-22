Genre: Vehicular action / Looter with RPG progression

```table-of-contents
```
# Brief

You drive a truck through a lawless desert. Your crew rides in the bed and shoots at anything hostile that gets close. Enemies come at you on foot and in vehicles of their own, and what they drop is yours to take.

The player only ever drives. Aiming and firing belong to the crew: each character in the truck bed picks targets and fires on their own, so the player's skill is in where the truck goes, how fast, and which fights to take. Between runs the loot goes into three things: upgrading the truck, levelling the characters, and equipping them with better weapons and gear.

## Core loop

1. **Drive.** Pick a route into the desert. Enemies engage as you pass through their territory.
2. **Fight.** The crew auto-fires from the back of the truck. The player positions the truck to give them lines of fire, run enemies down, or get out of trouble.
3. **Loot.** Dead enemies and wrecked vehicles drop weapons, ammo, gear, and parts.
4. **Upgrade.** Back at base, spend the haul on the truck, the crew's levels, and their loadouts. Then drive out further.

## Pillars

- **The truck is the character.** Speed, armour, handling, and how many crew fit in the bed are the player's main stats.
- **The crew does the shooting.** Their weapons, levels, and gear decide how a fight goes. The player decides where the fight happens.
- **Loot is the reward for every kill.** No farming, no shopkeeping between fights.

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

# Game Loop

### A run

The player drives out from base with a crew in the truck bed. Enemies engage along the route and the crew auto-fires at them while the player drives. Kills drop loot, which the truck carries back. A run ends when the player returns to base or the truck is destroyed.

### Between runs

The haul is spent three ways: truck upgrades (armour, engine, bed capacity, mounted gear), character levels, and character loadouts (weapons, gear). Better crew and a better truck open routes with tougher enemies and better drops.

### Progression

Early: one or two crew with weak weapons, short runs near base. Mid: a full bed, weapon variety, enemy vehicles. Late: open questions. Is there an end goal such as a final territory or a destination, or is it open-ended?

---
# Gas Stop

The player home base. Fully ready to receive upgrades and new equipment to make life easier. Also comes with a plot to start a brand new garden to grow ammo and other useful things.

It is also equipped with a self-service gas pump, that allows customer to purchase fuel even when the player is not around.

--- 
# Items
There are 4 main categories of items: weapons, throwables, consumables and wearables.

## Weapons

Weapons come in all shapes and sizes. From small pistols to automatic rifles. They rely on 4 types of ammo: light, medium, heavy and shell. Although you can find some ammo on enemy corpses or random containers, the main source is your growing crops.


```table
| Weapon type | Ammo | Fire rate | Damage | Reload time |
| --- | --- | --- | --- | --- |
| Pistol | Light | Medium | Low | Fast |
| Revolver | Heavy | Slow | High | Slow |
| SMG | Light | Fast | Low | Fast |
| Shotgun | Shell | Slow | High | Slow |
| Rifle | Heavy | Slow | High | Slow |
| Assault rifle | Medium | Fast | Medium | Medium |
<!-- tk:cols=135,105,98,107,140;rows=48,48,48,48,48,48,48 -->
```
## Throwables

Grenades literally grow on trees and are very useful for crowd control and destroying things.

```table
| Item name | Area of effect | Effect |
| --- | --- | --- |
| Frag grenade | Small | Physical damage |
| Incendiary grenade | Medium | Fire damage |
| Flash grenade | Medium | Temporary blindness |
| Dynamite | Large | Physical damage |
<!-- tk:cols=185,166,244;rows=48,48,48,48,48 -->
```

## Consumables

Mainly items to recover health or give some temporary buff.


## Wearables

Items that need to placed in specific slots to grant bonuses and upgrades. Hats, glasses, coats and, mostly important, backpacks.


### Backpacks

By default the player has 1 weapon slot and 2 pocket slots. Backpacks add inventory space and more weapon and item slots. Different backpacks have different attributes. 

The inventory system is based on shape and size and not weight, similar to Dredge (see image below). So as long as the player can fit the items in the inventory they can carry them. So organizing the inventory becomes a puzzle.

Some items can stack, ammo being the main example. Different ammo types have different caps for the amount that can be stacked.


![[Dredge Inventory.png|Dredge Inventory]]


---
# Vehicles

A very important tool to explore the desert is a good car. Not only it speeds up your travels, it also comes with trunk space to unload your inventory.

```table
| Vehicle | Trunk | Tank | Speed | Accel | Mass |
| --- | :---: | :---: | :---: | :---: | :---: |
| Car 01 | 16 | 35 | 64 | 68 | 20 |
|     |     |     |     |     |     |
<!-- tk:cols=268,62,71,67,74,57;rows=48,48,48 -->
```

---

# Enemies

The weak presence of law enforcement makes the area very attractive to scavengers and other low life criminals. And they will not hesitate to shoot you to collect any loot you could be carrying. Of course you can do the same to them.

---

# NPCs

Not everyone is out there to get you. Some folks could be useful or have important tasks (with great rewards).

You might be able to convince some of them to move to your home base and help you automate or improve your daily tasks.

---

# Crops

The main purpose of crops is to harvest ammunitions for your weapons. Every plant needs to be watered every day. Skipping one day will only  stagger the growth. But skipping two days will be fatal for the plant.

## Light Ammo Bush

A fast growing bush that wields Light Ammo if watered daily.

**Harvest:** every 3 days
**Produce:** 15-30 projectiles
**Seed cost:** $50


## Medium Ammo Plant

This plant takes a bit longer to grow but once it is fully grown it gives fruits every day.

**Harvest:** every day (after 6 days)
**Produce:** 8-15 projectiles
**Seed cost:** $240


## Heavy Ammo Vines

Takes a long time to grow and does not wield a lot of fruits.

**Harvest:** every 5 days
**Produce:** 5-10 projectiles
**Seed cost:** $560

## Pizza Plant

Grows from old tomato sauce cans.

**Produce:** Pizza: recovers energy. *(Additional bonuses TBD)*

## Lollipop Flower

Grows from used plastic sticks.

**Produce:** Lollipops: recovers energy. *(Additional bonuses TBD)*

## Pretzel Cactus

Grows from salt packets.

**Produce:** Pretzels: recovers energy. *(Additional bonuses TBD)*

## Noodle Vines

Grows from ramen seasoning packets.

**Produce:** Noodles: recovers energy. *(Additional bonuses TBD)*

## Root Beer

An underground root crop. Grows from old root beer bottle caps buried in the soil.

**Produce:** Root Beer: recovers energy. *(Additional bonuses TBD)*

---
# Loot Boxes

While roaming the desert the the player will find many containers with precious loot (some not so precious). They are divided in category and size.

## Cardboard Boxes

Contain mostly trash and common parts.


## Army Crates

Can contain some ammo, weapons and rarer parts.


