# Medieval Tycoon

This repository contains the imported Roblox place hierarchy, configured for Rojo 7.7.1 through Aftman.

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
