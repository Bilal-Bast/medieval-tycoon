# Medieval Tycoon

This repository contains the imported Roblox place hierarchy, configured for Rojo 7.7.1 through Aftman.

The world includes eight independently claimable 480-stud kingdoms arranged around a colorful central plaza and royal fountain. Realm-colored lanterns mark each approach, and eight flowered groves frame the outer landscape. New-player guidance points to the next upgrade, and defeating a zombie pays 40 gold. Prosperity and zombie defeats are visible in the player leaderboard. See [the eight-player layout and release checklist](docs/eight-player-world.md) for the map plan and the Roblox Creator Dashboard player-cap setting.

Each kingdom also has a royal armory by its barracks. Players can spend kingdom Cash on a Knight's Sword, Force Laser, or Plasma Sword; see the layout guide for prices and playtest notes.

The Royal Shop UI is included for Robux gold packs and permanent cosmetic/production passes. Roblox Creator Dashboard item IDs are intentionally left as `0`; create the three Developer Products and two Passes, then configure their IDs before release. See [Roblox shop setup](docs/roblox-shop-setup.md). Digital purchases use Roblox checkout; the place does not collect card details or process external payments.

`default.project.json` maps the imported Roblox services to `src/`. `migration.project.json` retains the syncback configuration for future place-file imports. Binary `.rbxm` assets preserve imported instance groups and their properties.

Build a local test place with:

```powershell
rojo build default.project.json -o MedievalTycoon-Rojo-Test.rbxl
```

When ready to start the local Rojo server, run this from the repository root:

```powershell
C:\Users\bilal\.aftman\bin\rojo.exe serve default.project.json
```

Place backups and build outputs are ignored by Git.
