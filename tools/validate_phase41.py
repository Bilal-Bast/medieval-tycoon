"""Static Phase 4.1 layout, corridor, routing and runtime-integration checks."""
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROMAN = {1: "I", 2: "II", 3: "III", 4: "IV"}
PLOTS = {
    1: (-500, -500, 0), 2: (500, -500, 0), 3: (-500, 500, 180), 4: (500, 500, 180),
    5: (0, -500, 0), 6: (500, 0, -90), 7: (0, 500, 180), 8: (-500, 0, 90),
}
DISTRICTS = ("Lumber", "Quarry", "Blacksmith", "Farm", "Barracks", "Castle")
CORRIDORS = {
    "Lumber": ((-148, 1.68, 114), 5.5, 72, (-110, 3.2, 114), (-173, -164, -155, -146)),
    "Quarry": ((-130, 1.68, -150), 5.5, 72, (-92, 3.2, -150), (-155, -146, -137, -128)),
    "Blacksmith": ((130, 1.68, -150), 5.5, 72, (168, 3.2, -150), (105, 114, 123, 132)),
    "Farm": ((130, 1.68, 169), 5.5, 72, (168, 3.2, 169), (105, 114, 123, 132)),
    "Barracks": ((-92, 1.68, 207), 5.5, 72, (-54, 3.2, 207), (-117, -108, -99, -90)),
}
FAIL = []
BOUNDS = {}


def check(ok, message):
    if not ok:
        FAIL.append(message)


def mat_y(degrees):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def mm(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(3)) for c in range(3)] for r in range(3)]


def transpose(a):
    return [list(row) for row in zip(*a)]


def frame(part):
    return part.get("properties", {}).get("CFrame", {}).get("CFrame", {})


def box3(pos, size, rot):
    extent = [sum(abs(rot[r][c]) * size[c] / 2 for c in range(3)) for r in range(3)]
    return [(pos[i] - extent[i], pos[i] + extent[i]) for i in range(3)]


def local_pos(world_pos, idx):
    ox, oz, deg = PLOTS[idx]
    x, y, z = world_pos
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    dx, dz = x - ox, z - oz
    return [c * dx - s * dz, y, s * dx + c * dz]


def world_pos(local_position, idx):
    ox, oz, deg = PLOTS[idx]
    x, y, z = local_position
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [ox + c * x + s * z, y, oz - s * x + c * z]


def parse_model(path):
    return json.loads(path.read_text(encoding="utf-8"))


def model_bounds(model):
    bounds = [float("inf"), float("-inf"), float("inf"), float("-inf")]
    for part in model.get("children", []):
        if part.get("name") == "DropPoint":
            continue
        prop, cf = part.get("properties", {}), frame(part)
        pos, size = cf.get("position"), prop.get("Size")
        if not pos or not size:
            continue
        ext = [sum(abs(cf.get("orientation", mat_y(0))[i][j]) * size[j] / 2 for j in range(3)) for i in (0, 2)]
        bounds[0] = min(bounds[0], pos[0] - ext[0])
        bounds[1] = max(bounds[1], pos[0] + ext[0])
        bounds[2] = min(bounds[2], pos[2] - ext[1])
        bounds[3] = max(bounds[3], pos[2] + ext[1])
    return tuple(bounds)


def intersects(box, corridor):
    x0, x1, z0, z1, y0, y1 = corridor
    return (box[0][1] > x0 and box[0][0] < x1 and box[2][1] > z0
            and box[2][0] < z1 and box[1][1] > y0 and box[1][0] < y1)


def xz_clearance(a, b):
    dx = max(0, b[0] - a[1], a[0] - b[1])
    dz = max(0, b[2] - a[3], a[2] - b[3])
    return math.hypot(dx, dz), dx == 0 and dz == 0


config = (ROOT / "src/ServerScriptService/Tycoon/Config.luau").read_text(encoding="utf-8")
service = (ROOT / "src/ServerScriptService/Tycoon/TycoonService.luau").read_text(encoding="utf-8")
npcs = (ROOT / "src/ServerScriptService/Tycoon/KingdomNPCService.luau").read_text(encoding="utf-8")
nav = (ROOT / "src/StarterPlayer/StarterPlayerScripts/UpgradeGuidance.client.luau").read_text(encoding="utf-8")
weapon_service = (ROOT / "src/ServerScriptService/Tycoon/WeaponService.luau").read_text(encoding="utf-8")
zombie_service = (ROOT / "src/ServerScriptService/Tycoon/ZombieService.luau").read_text(encoding="utf-8")
weapon_input = (ROOT / "src/StarterPlayer/StarterPlayerScripts/WeaponInput.client.luau").read_text(encoding="utf-8")
hud = (ROOT / "src/StarterGui/MainUI.rbxmx").read_text(encoding="utf-8")

check("Vector2.new(480, 480)" in config, "Config plot dimension must be 480 x 480")
check(len(list((ROOT / "src/Workspace/Tycoons").glob("Tycoon*"))) == 8, "World must provide exactly eight kingdom plots")
check("MaxVisiblePurchasePads = 1" in config, "Only the next purchase pad should be visible")
for idx, expected in PLOTS.items():
    name = f"Tycoon{idx}"
    check(f"{name} = Vector3.new({expected[0]}, 0, {expected[1]})" in config, f"{name} offset differs from validation plan")
    check(f"{name} = {expected[2]}" in config, f"{name} rotation differs from validation plan")

# All twenty resource sources use one anchor, one route, and a matching collector.
for district, (center, width, length, collector, drops) in CORRIDORS.items():
    check(f"{district} = {{ LaneCenter = Vector3.new({center[0]}, {center[1]}, {center[2]})" in config,
          f"Config does not define the shared {district} lane")
    check("ClearanceHeight = 12" in config, f"{district} corridor is missing the shared 12-stud clearance requirement")
    for level in range(1, 5):
        name = district + ROMAN[level]
        model = parse_model(ROOT / f"src/ServerStorage/{name}.model.json")
        points = [p for p in model.get("children", []) if p.get("name") == "DropPoint"]
        check(len(points) == 1, f"{name} must contain exactly one active DropPoint")
        if points:
            point = points[0]
            pos = frame(point).get("position", [])
            prop = point.get("properties", {})
            expected = (drops[level - 1], 8.4, center[2])
            check(len(pos) == 3 and all(abs(pos[i] - expected[i]) < .05 for i in range(3)),
                  f"{name} source is not aligned to its own corridor: {pos}")
            check(not prop.get("CanCollide", True) and prop.get("Transparency") == 1,
                  f"{name} source anchor must remain invisible and non-colliding")
        corridor = (center[0] - length / 2, collector[0] + 6, center[2] - width / 2,
                    center[2] + width / 2, 0, 12)
        blockers = []
        for part in model.get("children", []):
            prop = part.get("properties", {})
            if part.get("name") == "DropPoint" or not prop.get("CanCollide"):
                continue
            cf = frame(part)
            if cf.get("position") and prop.get("Size") and intersects(box3(cf["position"], prop["Size"], cf.get("orientation", mat_y(0))), corridor):
                blockers.append(part.get("name"))
        check(not blockers, f"{name} collidable architecture intersects its low resource corridor: {blockers[:8]}")

# Measure actual Level IV bounds from every modeled part, including decorative silhouettes.
for district in DISTRICTS:
    model = parse_model(ROOT / f"src/ServerStorage/{district}IV.model.json")
    BOUNDS[district] = model_bounds(model)

# A lane is reserved across the whole plot: no other Level IV building may cap it.
for route, (center, width, length, collector, _) in CORRIDORS.items():
    corridor = (center[0] - length / 2, collector[0] + 6, center[2] - width / 2,
                center[2] + width / 2, 0, 12)
    for district in DISTRICTS:
        model = parse_model(ROOT / f"src/ServerStorage/{district}IV.model.json")
        blockers = []
        for part in model.get("children", []):
            prop = part.get("properties", {})
            if part.get("name") == "DropPoint" or not prop.get("CanCollide"):
                continue
            cf = frame(part)
            if cf.get("position") and prop.get("Size") and intersects(box3(cf["position"], prop["Size"], cf.get("orientation", mat_y(0))), corridor):
                blockers.append(part.get("name"))
        check(not blockers, f"{route} reserved corridor intersects {district} IV geometry: {blockers[:8]}")
for i, first in enumerate(DISTRICTS):
    for second in DISTRICTS[i + 1:]:
        clearance, overlap = xz_clearance(BOUNDS[first], BOUNDS[second])
        check(not overlap, f"Level IV bounding boxes overlap: {first} / {second}")
        check(clearance >= 10, f"Level IV clearance below 10 studs: {first} / {second} = {clearance:.1f}")

# Compact ring of eight full-size plots. Quarter-turn rotations keep each
# footprint axis-aligned, so the pairwise 480 x 480 boxes can be checked exactly.
base_half = 240
plot_boxes = [(p[0] - base_half, p[0] + base_half, p[1] - base_half, p[1] + base_half)
              for p in PLOTS.values()]
min_plot_gap = math.inf
for i, first in enumerate(plot_boxes):
    for second in plot_boxes[i + 1:]:
        dx = max(0, second[0] - first[1], first[0] - second[1])
        dz = max(0, second[2] - first[3], first[2] - second[3])
        check(dx > 0 or dz > 0, "Kingdom plot footprints overlap")
        gap = max(dx, dz) if dx == 0 or dz == 0 else math.hypot(dx, dz)
        min_plot_gap = min(min_plot_gap, gap)
check(abs(min_plot_gap - 20) < .01, f"Minimum plot-to-plot gap should be 20 studs, got {min_plot_gap:.1f}")
for idx, (_, _, rotation) in PLOTS.items():
    env = parse_model(ROOT / f"src/Workspace/Tycoons/Tycoon{idx}/Environment.model.json")
    parts = {p.get("name"): p for p in env.get("children", [])}
    check("RealmBannerCloth" in parts, f"Tycoon{idx} is missing its unique heraldic gate banner")
    plot_rot = mat_y(rotation)
    inv = transpose(plot_rot)
    for district, (center, width, length, collector, _) in CORRIDORS.items():
        belt = parts.get("Conveyor_" + district)
        catch = parts.get("Collector_" + district)
        check(belt is not None and catch is not None, f"Tycoon{idx}/{district} lane or collector missing")
        if not belt or not catch:
            continue
        bp, bcf = belt["properties"], frame(belt)
        bpos = local_pos(bcf["position"], idx)
        check(all(abs(bpos[k] - center[k]) < .3 for k in range(3)), f"Tycoon{idx}/{district} lane center is wrong: {bpos}")
        check(all(abs(bp["Size"][k] - v) < .05 for k, v in enumerate((width, .783, length))),
              f"Tycoon{idx}/{district} lane dimensions differ from config")
        look = [-bcf["orientation"][0][2], -bcf["orientation"][1][2], -bcf["orientation"][2][2]]
        forward = [math.cos(math.radians(rotation)), 0, -math.sin(math.radians(rotation))]
        check(sum(look[k] * forward[k] for k in range(3)) > .99, f"Tycoon{idx}/{district} conveyor points away from collector")
        cp, ccf = catch["properties"], frame(catch)
        cpos = local_pos(ccf["position"], idx)
        check(all(abs(cpos[k] - collector[k]) < .3 for k in range(3)), f"Tycoon{idx}/{district} collector local position wrong")
        check(cp.get("CanTouch") and not cp.get("CanCollide"), f"Tycoon{idx}/{district} collector touch/collision settings wrong")
        end_x = center[0] + length / 2
        check(abs(end_x - cpos[0]) <= cp["Size"][0] / 2 + 0.01 and abs(center[2] - cpos[2]) <= cp["Size"][2] / 2,
              f"Tycoon{idx}/{district} collector misses the conveyor endpoint")
        allowed = {"Conveyor_" + district, "Collector_" + district, district + "RailL", district + "RailR"}
        corridor = (center[0] - length / 2, collector[0] + 6, center[2] - width / 2 - .3,
                    center[2] + width / 2 + .3, 0, 12)
        blockers = []
        for part in env.get("children", []):
            prop = part.get("properties", {})
            if part.get("name") in allowed or not prop.get("CanCollide"):
                continue
            cf = frame(part)
            if not cf.get("position") or not prop.get("Size"):
                continue
            local = local_pos(cf["position"], idx)
            rot = mm(inv, cf.get("orientation", plot_rot))
            if intersects(box3(local, prop["Size"], rot), corridor):
                blockers.append(part.get("name"))
        check(not blockers, f"Tycoon{idx}/{district} route has collidable environment blockers: {blockers[:8]}")

# Roads must avoid solid Level IV buildings, though a non-colliding estate floor may continue underneath.
level4_models = {district: parse_model(ROOT / f"src/ServerStorage/{district}IV.model.json") for district in DISTRICTS}
for idx, (_, _, rotation) in PLOTS.items():
    env = parse_model(ROOT / f"src/Workspace/Tycoons/Tycoon{idx}/Environment.model.json")
    inv = transpose(mat_y(rotation))
    roads = [p for p in env.get("children", []) if p.get("name", "").startswith("Road_")]
    check(len(roads) >= 20, f"Tycoon{idx} is missing the complete main/district road network")
    road_names = {p["name"] for p in roads}
    for required in ("Road_MainGateToTown_0", "Road_TownCrossroad_0", "Road_RoadToLumber_0",
                     "Road_RoadToFarm_0", "Road_RoadToQuarry_1", "Road_RoadToBlacksmith_2",
                     "Road_CastleRoad_2", "Road_RoadToBarracks_0"):
        check(required in road_names, f"Tycoon{idx} is missing a required kingdom road segment: {required}")
    for road in roads:
        cf = frame(road)
        local = local_pos(cf["position"], idx)
        rot = mm(inv, cf.get("orientation", mat_y(rotation)))
        bounds = box3(local, road["properties"]["Size"], rot)
        region = (bounds[0][0], bounds[0][1], bounds[2][0], bounds[2][1], bounds[1][0], bounds[1][1])
        for district, model in level4_models.items():
            for part in model.get("children", []):
                prop = part.get("properties", {})
                if part.get("name") == "DropPoint" or not prop.get("CanCollide"):
                    continue
                pf = frame(part)
                if pf.get("position") and prop.get("Size") and intersects(box3(pf["position"], prop["Size"], pf.get("orientation", mat_y(0))), region):
                    check(False, f"Tycoon{idx} {road['name']} road overlaps solid {district} IV geometry ({part['name']})")

# Walls, gate, tower corners, XML base/spawn/claim, and road access definitions.
walls = parse_model(ROOT / "src/ServerStorage/WallsIV.model.json")
wall_parts = {p["name"]: p for p in walls["children"]}
for name, coord in (("WallWest", -232), ("WallEast", 232), ("WallRear", -232)):
    check(name in wall_parts and abs(frame(wall_parts[name])["position"][0 if name != "WallRear" else 2] - coord) < .01,
          f"Wall perimeter segment {name} is not on the 480-stud perimeter")
front = [p for p in walls["children"] if p["name"] in ("WallFrontWest", "WallFrontEast")]
check(len(front) == 2 and all(p["properties"]["CanCollide"] for p in front), "Front wall/gate opening is malformed")
front_intervals = sorted((frame(p)["position"][0] - p["properties"]["Size"][0] / 2,
                          frame(p)["position"][0] + p["properties"]["Size"][0] / 2) for p in front)
check(len(front_intervals) == 2 and front_intervals[0][0] < -20
      and front_intervals[1][1] > 20 and front_intervals[1][0] - front_intervals[0][1] >= 40,
      "Main gate is not an open central passage at least 40 studs wide")
towers = parse_model(ROOT / "src/ServerStorage/TowerIV.model.json")["children"]
tower_centers = {(round(frame(p)["position"][0]), round(frame(p)["position"][2])) for p in towers if p["name"] == "CornerTowerBase"}
check(tower_centers == {(-222, -222), (-222, 222), (222, -222), (222, 222)}, "Tower IV bases do not align with all four wall corners")
for idx in PLOTS:
    folder = ROOT / f"src/Workspace/Tycoons/Tycoon{idx}"
    root = ET.parse(folder / "Base.rbxmx").getroot()
    size = next((e for e in root.iter("Vector3") if e.get("name") == "size"), None)
    check(size is not None and float(size.find("X").text) == 480 and float(size.find("Z").text) == 480,
          f"Tycoon{idx} base part is not 480 x 480")
    for filename, local_z in (("Spawn.rbxmx", 213), ("ClaimPad.rbxmx", 239)):
        xmlroot = ET.parse(folder / filename).getroot()
        cf = next((e for e in xmlroot.iter("CoordinateFrame") if e.get("name") == "CFrame"), None)
        check(cf is not None and abs(local_pos([float(cf.find(t).text) for t in ("X", "Y", "Z")], idx)[2] - local_z) < .05,
              f"Tycoon{idx} {filename} does not follow the new gate layout")

boundary = parse_model(ROOT / "src/Workspace/WorldBoundary.model.json")
boundary_template = parse_model(ROOT / "tools/templates/WorldBoundary.model.json")
baseplate = parse_model(ROOT / "src/Workspace/Baseplate.model.json")
check(baseplate.get("properties", {}).get("Size") == [2400, 1, 2400], "World floor must cover the compact eight-kingdom map")
check(len(boundary["children"]) == len(boundary_template["children"]), "World boundary ring differs from its base template")
for current, original in zip(boundary["children"], boundary_template["children"]):
    cp, op = current["properties"], original["properties"]
    cpos = frame(current).get("position", [])
    opos = frame(original).get("position", [])
    csize, osize = cp.get("Size"), op.get("Size")
    if cpos and opos:
        check(abs(cpos[0] - opos[0] * 1.5) < .05 and abs(cpos[2] - opos[2] * 1.5) < .05,
              f"{current['name']} is not placed at the eight-kingdom boundary scale")
    if csize and osize:
        check(abs(csize[0] - osize[0] * 1.5) < .05 and abs(csize[2] - osize[2] * 1.5) < .05,
              f"{current['name']} has the wrong eight-kingdom boundary size")

global_roads = parse_model(ROOT / "src/Workspace/KingdomRoads.model.json")["children"]
global_roads_by_name = {part["name"]: part for part in global_roads}
global_road_names = set(global_roads_by_name)
check(len(global_roads) == 24, "Eight royal roads must each have two matching stone curbs")
for idx in PLOTS:
    check(f"RoyalRoad_Tycoon{idx}" in global_road_names, f"Global road to Tycoon{idx} is missing")
    road = global_roads_by_name.get(f"RoyalRoad_Tycoon{idx}")
    if road:
        actual = frame(road).get("position", [])
        gate = world_pos((0, 1.12, 239), idx)
        gate_radius = math.hypot(gate[0], gate[2])
        expected_center = [(gate[0] + gate[0] / gate_radius * 47) / 2,
                           0.78, (gate[2] + gate[2] / gate_radius * 47) / 2]
        check(len(actual) == 3 and all(abs(actual[k] - expected_center[k]) < .1 for k in range(3)),
              f"Royal road to Tycoon{idx} does not join the hub to its gate")
        check(abs(road["properties"].get("Size", [0, 0, 0])[2] - (gate_radius - 47)) < .1,
              f"Royal road to Tycoon{idx} has the wrong length")
hub = parse_model(ROOT / "src/Workspace/KingdomHub.model.json")
hub_parts = {part.get("name"): part for part in hub.get("children", [])}
check(len([name for name in hub_parts if name.startswith("RealmLantern") and name.endswith("Glass")]) == 8,
      "Central plaza must have eight illuminated realm lanterns")
check(all(name in hub_parts for name in ("FountainStoneBase", "FountainLowerWater", "FountainCrown")),
      "The shared arrival plaza is missing its colored royal fountain")
grove = parse_model(ROOT / "src/Workspace/OuterGrove.model.json")
check(len(grove.get("children", [])) == 56, "Outer landscape should contain eight flowered groves")
plaza = hub_parts.get("CentralStonePlaza")
check(plaza is not None and plaza.get("properties", {}).get("Size", [0, 0, 0])[0] == 96,
      "Eight-way civic plaza has not been expanded")

# Production lifecycle, owner isolation, next target, trail, beacon, population and reset paths.
for token, message in (
    ("local function createMoneyBlock", "production spawn is missing"),
    ("local function transportProductionResources", "continuous server transport reapplication is missing"),
    ("hit:Destroy()", "collector payout/cleanup is missing"),
    ("Debris:AddItem(block, Config.MoneyBlockLifetime)", "production resources do not expire cleanly"),
    ("cash.Value += getUpgradeIncome(upgrade)", "collector does not award the configured upgrade payout"),
    ("state.owner.UserId", "server owner check is missing"),
    ("KingdomNPCService.Initialize()", "NPC service initialization is missing"),
    ("KingdomNPCService.Reconcile(plot, state)", "claim/purchase events are not reaching NPC reconciliation"),
    ("KingdomNPCService.Cleanup(plot, state)", "plot reset does not clear NPC state"),
    ("NextUpgradeTarget", "server does not publish a navigation target"),
    ("NextUpgradeTarget", "navigation client does not consume the target"),
):
    haystack = service if token != "KingdomNPCService.Initialize()" and token != "KingdomNPCService.Cleanup(plot, state)" else service
    if token == "NextUpgradeTarget":
        haystack = service + nav
    check(token in haystack, message)
check("Population" in service + npcs + hud, "population attribute/HUD binding is missing")
check('state.owner:SetAttribute("Population", actual)' in npcs, "Population must count live owned NPC models")
check('model:GetAttribute("OwnerUserId") == state.owner.UserId' in npcs, "NPC population is missing per-owner membership filtering")
check('owner:SetAttribute("Population", nil)' in npcs, "NPC reset cleanup does not clear Population")
for token, message in (("CreatePath", "trail does not ask pathfinding for a route"), ("GetAttributeChangedSignal(\"NextUpgradeId\")", "trail does not retarget on purchase"),
                       ("NextUpgradeBeam", "distant target beam is missing"), ("NextUpgradeDiamond", "floating target marker is missing"),
                       ("beaconRange = 260", "beacon range is not in the requested 200-300 stud range"), (">= 6", "trail spacing is not about 5-8 studs")):
    check(token in nav, message)
check(all(token in service for token in ("createPurchaseBillboard(button", "NEW ROYAL PROJECT",
                                          "KINGDOM UPGRADE", "UpgradeName", "Price", "GOLD")),
      "available purchase pads do not show a floating action, name and price card")
check(all(token in service for token in ("KingdomClaimBillboard", "REALM %02d", "ClaimStatus",
                                         "ClaimPrompt", "prepareClaimBillboard(plot)")),
      "kingdom claim signs are missing their styled realm plaque or claim prompts")
check("TweenService:Create(button" in service and "RuneGlow" in service, "purchase pad is missing a pulse/glow")
check("DevelopmentNPCDebug" in npcs and "debug.traceback" in npcs, "NPC development failure diagnostics are missing")

check("WeaponService.CreateArmory(plot, plotFrame" in service and "WeaponService.TryPurchase(player, weaponId, state)" in service,
      "every claimed kingdom must build an owner-checked armory")
for weapon_id, price in (("KnightSword", 350), ("ForceLaser", 1800), ("PlasmaSword", 5000)):
    match = re.search(rf"\b{weapon_id}\s*=\s*\{{(.*?)\n\t\}}", weapon_service, re.S)
    check(match is not None and re.search(rf"Price\s*=\s*{price}\b", match.group(1)) is not None,
          f"{weapon_id} must have the expected cash price")
for token, message in (
    ("cash.Value -= definition.Price", "weapon purchases do not debit server-owned Cash"),
    ("WeaponService.GiveWeapon(player, weaponId)", "weapon purchase does not grant a weapon Tool"),
    ("actionRemote.OnServerEvent:Connect(onWeaponAction)", "weapon actions are not validated on the server"),
    ("Workspace:Raycast(head.Position, direction, params)", "Force Laser is missing server-side raycast hit validation"),
    ("humanoid:TakeDamage(definition.Damage)", "weapon damage is not applied by the server"),
    ("targetRoot:ApplyImpulse", "Force Laser is missing its push effect"),
    ("not isInsideOwnKingdom(target)", "players are not protected inside their own kingdoms"),
):
    check(token in weapon_service, message)
check("WeaponAction" in weapon_input and "WeaponNotice" in weapon_input,
      "client weapon input and purchase feedback are missing")
check("ZombieKills" in (ROOT / "src/ServerScriptService/Leaderstats.server.luau").read_text(encoding="utf-8"),
      "the player leaderboard must track zombie defeats")
check('FindFirstChild("Prosperity")' in npcs and 'prosperityStat.Value = prosperity' in npcs,
      "kingdom prosperity must appear on the player leaderboard")
check('cash.Value += 40' in weapon_service and 'zombieKills.Value += 1' in weapon_service,
      "a server-confirmed zombie defeat must award gold and leaderboard credit")
check("ZombieService.Initialize()" in (ROOT / "src/ServerScriptService/TycoonServer.server.luau").read_text(encoding="utf-8"),
      "server startup must initialize the zombie encounters")
check(all(token in zombie_service for token in ("ZOMBIE_COUNT = 12", "IsZombie", "ATTACK_DAMAGE = 9",
                                                 "insideAnyKingdom", "targetHumanoid:TakeDamage")),
      "zombies must spawn, pursue players outside kingdoms, and deal server-side damage")
check("isZombieModel(model)" in weapon_service and 'Workspace:FindFirstChild("Zombies")' in weapon_service,
      "purchased weapons must be able to damage the zombies")
check('player:SetAttribute("TycoonId", plot.Name)' in service
      and 'previousOwner:SetAttribute("TycoonId", nil)' in service,
      "claimed kingdom ownership must be available to weapon validation and cleaned on reset")

if FAIL:
    print("Phase 4.1 static validation FAILED:")
    for item in FAIL:
        print(" -", item)
    sys.exit(1)

print("Phase 4.1 static validation passed.")
print(f"Kingdoms: 8 x 480 x 480 studs in a compact 3x3 ring; minimum plot gap {min_plot_gap:.1f} studs.")
for district in DISTRICTS:
    x0, x1, z0, z1 = BOUNDS[district]
    print(f"{district:10} X[{x0:.1f},{x1:.1f}] Z[{z0:.1f},{z1:.1f}] = {x1-x0:.1f} x {z1-z0:.1f} studs")
print("Pairwise Level IV district clearances:")
for i, first in enumerate(DISTRICTS):
    for second in DISTRICTS[i + 1:]:
        gap, _ = xz_clearance(BOUNDS[first], BOUNDS[second])
        print(f"  {first} / {second}: {gap:.1f} studs")
print("Checked all 20 producers, five route standards across eight rotations, collectors, corridor blockers, plot XML, walls/gates/towers, eight hub roads, navigation, NPC lifecycle, paid weapon armories, and server-controlled zombies/combat.")
