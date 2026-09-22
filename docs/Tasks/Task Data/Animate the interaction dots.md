---
status: Done
kanban_order: V1
---
The interaction dots that appear on top of interactive objects should have a snappy animation when appearing and disappearing. The ring should also animate in and out nicely.

The dot should scale up with a back ease out.

The ring should scale down and fade in.

*Done (Claude, 2026-08-12): the dot pops in on a back-ease overshoot, the ring opens wide and closes onto it as it fades in, and both run backwards on the way out. The visibility flags stay instant — only scale and fade animate — so everything reading the dot per frame is unaffected.*
