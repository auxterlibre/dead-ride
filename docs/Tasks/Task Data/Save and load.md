---
status: Done
kanban_order: VK
---

Persist player state, inventory, money, garden growth, day count and world state. Worth building early once inventory and the day cycle exist, before systems multiply.

*Done (Claude, 2026-08-06): one versioned JSON save plus a rolling backup; anything scene-authored in the `persistent` group contributes its own state. Decisions locked: one slot, death loads the last save, enemies reset every load, and SLEEPING IS THE ONLY WAY TO SAVE — so a day cannot be banked without spending it.*
