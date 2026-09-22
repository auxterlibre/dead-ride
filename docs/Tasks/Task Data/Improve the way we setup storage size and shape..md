---
status: Done
kanban_order: V2t
---
The current way to draw the storage in the inspector is a bit finicky. I wonder if there is an easier way to set this up. For instance: setting a rectangle size that draws checkboxes matching the size and I can check them on/off. Or anything that is easier to visualize and edit.

*Done (Claude, 2026-08-12 night): a StorageData's layout now shows in the inspector as width/height spinners and a checkbox grid — check a cell to open it, resize to reshape (new ground starts open, shrinking drops what falls off). Undo works. Under the hood the same ASCII string is stored, so every existing resource and its diffs stay as they were.*
