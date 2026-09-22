Genre: Survival / Farming 

```table-of-contents
```
# Brief

In the middle of the desert lies a lonely gas station. As the owner you have to embrace the solitude and survive. You can start exploring the nearby areas by foot, but to venture further into the desert you are going to need a vehicle.

A truck come every week to refill your gas pump (for a price, of course) and buy any provisions you have to sell. You can scavenge for useful items and trinkets to sell, and Earth will provide ammunition. This land is not like any other, it needs fuel instead of water to grow your unique crops: bullet plants, grenade trees, etc.

But water is still important to refill the player's energy, that is used to walk or perform other strenuous activities.


---

# Game Loop

### First days

Without a vehicle and proper tools to explore the map, the player can only walk around the area near the gas stop. Between 10am and 4pm the sun is too hot and being exposed drains your health pretty fast. 

They can still find some places to scavenge around the Gas Stop and maybe find some values they can sell to the delivery truck that comes once a week.

### Mid game

Once the player has saved up enough from fuel sales and scavenged goods, they can repair or buy their first vehicle, opening up the wider desert map. The garden matures and starts producing higher-tier ammo and consumables. Gas Stop upgrades become affordable: shade structures to reduce heat drain, storage expansions, basic defenses against raiders.

### Late game

With the Gas Stop mostly self-sufficient, the player can recruit NPCs to automate day to day tasks like watering the garden, restocking the pump, or keeping watch. This frees up time to push deeper into the desert with better vehicles and gear. *(Open question: is there a defined end goal here, like paying off a debt on the station or reaching a specific location, or is this meant to stay an open-ended sandbox loop?)*

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


