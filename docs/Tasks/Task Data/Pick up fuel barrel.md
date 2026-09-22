---
status: Done
kanban_order: V2V
---
Fuel barrels are too big to fit the player's inventory. So they need to be picked up and carried around. While the player is carrying them they cannot shoot or use items. So the quick bar is hidden until the barrel is dropped.

The barrel is limited by the grid like any other object being placed. 

While a barrel is being moved it has no coolant effect. The target grid lost where the barrel will be place needs to be highlighted. Once it is placed the ground gets cold slowly and the grass grows around it.

If a barrel is removed the coolant effect slowly fades out and the grass slowly disappears.

We can use the arms position of the running_holding_rifle animation for the carrying animation. The barrel can just be position slightly in front of the player.

*Done (Claude, 2026-08-12 night): pick up with the interact key (a fuelled can in hand still pours instead — the hand picks the point's job), carry with the running_holding_rifle arms and the drum in front, place through the build ghost's green/red cell on the same grid. Carrying empties the hands, hides the bar and refuses every draw, drink and build. The cold arrives and leaves over ~5 seconds and the grass follows it both ways; a carried barrel cools nothing. Sleeping and entering a car set the barrel down first.*
