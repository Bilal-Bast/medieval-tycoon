# Phase 4 — Living Kingdom

## Architecture

`TycoonService` remains responsible for claims, purchases, cash, prerequisites, production, and resets. It calls the single `KingdomNPCService` module when an owner claims a plot, buys an upgrade, or releases the plot. The NPC service reconciles the active population from purchased upgrade levels and stores each worker under that plot's `KingdomNPCs` folder.

Workers are editable, anchored Roblox part rigs with medieval clothing colors and profession tools. They have no scripts of their own, no collision, and no authority over cash. One server scheduler advances their work, carry, rest, and patrol states every 0.2 seconds using predefined plot-local routes. Workers are staggered by their initial work timers. Saw blades, log feeders, quarry carts, forge light, and smoke use the same centralized scheduler/effects folder.

Cash remains generated and awarded by the existing server production scheduler and collector validation. Prosperity is a deterministic score of 10 points plus 5 points per upgrade level for each purchased upgrade. It is exposed as the owning player's `Prosperity` attribute. The server sets the `Population` attribute to the number of live NPCs in that owner's plot. Both values are shown in the existing compact Cash panel and are cleared when the plot is released.

## Worker counts by district level

| District | I | II | III | IV |
| --- | ---: | ---: | ---: | ---: |
| Lumber | 1 | 2 | 3 | 5 |
| Quarry | 1 | 2 | 3 | 4 |
| Blacksmith | 1 | 2 | 3 | 4 |
| Farm | 1 | 2 | 3 | 4 |
| Barracks | 1 | 2 | 3 | 4 |
| Walls (guards) | 0 | 0 | 1 | 2 |
| Towers (guards) | 1 | 2 | 3 | 3 |
| Castle (guards/attendants) | 1 | 1 | 2 | 2 |

Villagers appear at Farm II (1) and Barracks I (2); their count remains at 2 through Castle IV. A fully developed plot therefore has 30 NPCs, and the service enforces the configured cap. Upgrade reconciliation preserves matching workers and removes obsolete ones.

## Activities

- Lumberjacks swing an axe at a work point. Timber workers visibly carry a log between storage and the yard. Sawmill workers swing a hammer; saw blades/log feeders animate from Lumber III onward.
- Miners swing pickaxes. Stone workers and cart workers carry stone between work and storage. The quarry cart and cutting wheels animate.
- Blacksmiths, apprentices, and armorers swing hammers at forge points and carry a finished-metal prop toward storage. Forge light pulses; higher levels add chimney smoke.
- Farmers and harvesters work crop-side points and carry produce; the herder carries a staff. Each farmer follows a short route between the field and storage.
- Recruits, soldiers, and trainers swing wooden practice swords around barracks work points and carry equipment toward storage.
- Wall, tower, and castle guards follow fixed perimeter/courtyard patrol points and pause at observation points. Castle attendants move around the courtyard.
- Villagers walk short, predefined kingdom-road routes. NPCs are anchored and non-colliding, so they cannot block pads, entrances, resource paths, fall through terrain, or wander into a neighboring plot.

## Audio and animation assets

No external animation assets or unverified audio IDs were added. Tool and limb movement is procedural. `Config.KingdomLife.ActivitySoundIds` is the optional audio hook; every value is blank, so the project is silent until verified assets are assigned. Sound slots awaiting approved assets: lumber chop, saw, wood creak, pickaxe, stone impact, forge, hammer, sparks, farm/rural ambience, animals, training, footsteps, and courtyard ambience.

## Roblox Studio playtest checklist

1. Open the Rojo-built place in Studio with the existing Rojo workflow. Confirm the original Cash panel remains and now shows Cash, Prosperity, and Population.
2. Claim one plot. Verify Prosperity and Population begin at 0 and that no workers appear before an upgrade is purchased.
3. Buy Lumber I. Verify exactly one lumberjack appears in that plot, swings an axe, and moves between work/rest points. Check Population becomes 1 and Prosperity becomes 15.
4. Upgrade Lumber through II, III, and IV. Confirm counts reconcile to 2, 3, and 5 (rather than duplicating workers), workers carry logs, and sawmill activity begins at III.
5. Continue through Quarry, Blacksmith, Farm, Barracks, Walls, Towers, and Castle. Verify each district's worker count from the table, actions, carts/saw/forge feedback, patrols, villagers, and monotonic Prosperity.
6. Walk through the settlement and stand on purchase pads and production paths. Confirm NPCs do not block the player or resources, stay within the kingdom, and the navigation guidance still points to the current pad.
7. Allow several production cycles for each unlocked production district. Verify Cash increases only when server-generated money blocks reach the correct plot's collector; NPCs and Prosperity never award Cash.
8. In an eight-player Studio server, claim separate plots and advance all eight. Confirm workers and HUD attributes remain owner-specific and no NPC crosses to or appears in the other kingdom.
9. Reset/release a plot by leaving. Verify its workers, effects, attributes, and money blocks are removed; have another player claim it and confirm only the new owner's progression repopulates it.
10. With `DevelopmentNPCDebug = true`, inspect each worker's role, state, district, and target label; restore it to `false` afterward.
