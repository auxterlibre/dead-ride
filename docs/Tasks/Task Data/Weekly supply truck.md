---
status: Done
kanban_order: VK
---

Truck arrives on a weekly cycle to refill the pump stock (for a price) and buy provisions and scavenged trinkets. The main trading beat of the loop. Depends on currency from [[Pump economy]] and a day counter from [[Day night cycle]].

Built DAILY rather than weekly: `DeliveryService` sends the truck in at 08:00 and it leaves at 15:00, parking at the DeliveryArea. Two counters while it stands there: drop goods on its cargo grid and it buys them at item price, or buy fuel for the pump at wholesale. Change `arrive_hour`/`leave_hour` on the node for the cadence; a weekly beat would just need a day guard beside the existing date guard.
