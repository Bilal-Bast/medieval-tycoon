"""Generate the four hand-authored Lumber progression snapshots as editable Roblox model JSON."""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "src" / "ServerStorage"
DROP_X = {1: -103.0, 2: -94.0, 3: -85.0, 4: -76.0}
ROMAN = {1: "I", 2: "II", 3: "III", 4: "IV"}

COLORS = {
    "stone": (0.39, 0.37, 0.32), "stone_light": (0.54, 0.50, 0.42),
    "wood": (0.29, 0.16, 0.08), "wood_light": (0.43, 0.27, 0.13),
    "plank": (0.48, 0.33, 0.18), "dark": (0.20, 0.12, 0.07),
    "roof": (0.28, 0.19, 0.14), "roof_light": (0.38, 0.26, 0.18),
    "grass": (0.31, 0.43, 0.22), "dirt": (0.39, 0.29, 0.19),
    "water": (0.20, 0.42, 0.52), "metal": (0.31, 0.32, 0.30),
    "gold": (0.61, 0.46, 0.20), "leaf": (0.23, 0.34, 0.18),
}

def mat_key(k):
    return {"stone": "Slate", "stone_light": "Cobblestone", "wood": "Wood",
            "wood_light": "Wood", "plank": "WoodPlanks", "dark": "Wood",
            "roof": "Slate", "roof_light": "Slate", "grass": "Grass",
            "dirt": "Ground", "water": "Water", "metal": "Metal",
            "gold": "Metal", "leaf": "Grass"}[k]

def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]

def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]

def mul(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(3)) for c in range(3)] for r in range(3)]

class Model:
    def __init__(self): self.parts = []
    def part(self, name, pos, size, color="wood", *, rx=0, ry=0, rz=0,
             collide=True, material=None, transparency=0, shape="Block"):
        # Euler rotations are composed X, Y, Z and kept explicit in the editable source.
        matrix = mul(mul(rot_y(ry), rot_x(rx)), [[math.cos(rz), -math.sin(rz), 0], [math.sin(rz), math.cos(rz), 0], [0, 0, 1]])
        self.parts.append({"name": name, "className": "Part", "properties": {
            "Anchored": True, "CanCollide": collide, "CanQuery": False,
            "CanTouch": False, "CastShadow": True,
            "CFrame": {"CFrame": {"position": [round(v, 4) for v in pos], "orientation": matrix}},
            "Color": COLORS[color], "Material": material or mat_key(color),
            "Size": [float(v) for v in size], "Transparency": transparency,
            "Shape": shape, "TopSurface": "Smooth", "BottomSurface": "Smooth"
        }, "children": []})
    def box(self, name, x,y,z,sx,sy,sz,color="wood",**kw): self.part(name,(x,y,z),(sx,sy,sz),color,**kw)
    def cylinder(self, name, x,y,z,sx,sy,sz,color="wood",**kw): self.part(name,(x,y,z),(sx,sy,sz),color,shape="Cylinder",**kw)

def build(level):
    m = Model()
    # Work-yard bounds and a compact gravel approach from the local +Z entrance.
    m.box("LumberYardTurf", -80,0.78,61, 65,.3,56,"grass")
    for i in range(5):
        m.box(f"MillApproachStone{i+1}",-81,0.98,78+i*4,8,.18,3.5,"dirt",collide=False)
    # Main hall grows by tier without changing its entrance or worker stations.
    half_x = {1:14,2:19,3:23,4:25}[level]
    half_z = {1:13,2:16,3:18,4:20}[level]
    cx, cz = -81, 56
    m.box("MillStoneFoundation",cx,1.15,cz,2*half_x+2,.75,2*half_z+2,"stone")
    m.box("MillInteriorFloor",cx,1.58,cz,2*half_x,.16,2*half_z,"plank",collide=False)
    # Low stone wall, timber frame and an open south-facing entrance.
    for x in (cx-half_x,cx+half_x):
        m.box("MillStoneSideWall",x,3.05,cz,1,3,2*half_z,"stone")
    for z in (cz-half_z, cz+half_z):
        if z == cz+half_z:
            side_wall_width=half_x-7.5
            side_wall_offset=(half_x+7.5)/2
            m.box("MillStoneFrontLeft",cx-side_wall_offset,3.05,z,side_wall_width,3,1,"stone")
            m.box("MillStoneFrontRight",cx+side_wall_offset,3.05,z,side_wall_width,3,1,"stone")
        else: m.box("MillStoneRearWall",cx,3.05,z,2*half_x,3,1,"stone")
    for x in (cx-half_x+1,cx+half_x-1):
        for z in (cz-half_z+1,cz+half_z-1): m.box("MillOakPost",x,8,z,1.1,14,1.1,"wood")
    for z in (cz-half_z+1,cz+half_z-1): m.box("MillOakSill",cx,4,z,2*half_x,1,1.15,"wood_light")
    for x in (cx-half_x+1,cx+half_x-1): m.box("MillOakWallPlate",x,10,cz,1.1,1,2*half_z,"wood_light")
    # Window openings are left in side walls above the stone base; frame each in timber.
    for side in (-1,1):
        wx = cx + side*(half_x-.48)
        for wz in (cz-5,cz+5):
            m.box("WindowSill",wx,4.15,wz,1.15,.28,4.2,"wood_light")
            m.box("WindowLintel",wx,7.2,wz,1.15,.28,4.2,"wood_light")
            for dz in (-2,2): m.box("WindowJamb",wx,5.65,wz+dz,1.15,3, .28,"wood")
            m.box("WindowMullion",wx,5.65,wz,1.15,3,.22,"wood_light")
    # Open, pitched roof, built as individual shingled panels with exposed rafters.
    slope = math.radians(23)
    roof_y = 17.8 if level < 3 else 19.2
    for side, zoff in ((-1,-half_z/2),(1,half_z/2)):
        angle = -slope if side < 0 else slope
        m.box("PitchedRoofShinglePanel",cx,roof_y,cz+zoff,2*half_x+3,1.1,half_z+1,"roof",rx=angle)
        # Parallel shingle seams keep the roof visually layered and readable.
        for k in range(1,5):
            z = cz + zoff + side*(k*(half_z/5))
            y = roof_y + (k*(half_z/5))*math.sin(slope)
            m.box("RoofShingleCourse",cx,y,z,2*half_x+3,.22,.42,"roof_light",rx=angle,collide=False)
    m.box("RoofRidgeCap",cx,roof_y+(half_z/2)*math.sin(slope),cz,2*half_x+5,1.2,1.2,"dark",collide=False)
    for x in (cx-half_x+2,cx+half_x-2):
        for side in (-1,1):
            z=cz+side*(half_z*.52)
            m.box("RoofRafter",x,roof_y,z,1,1.5,half_z+1,"wood_light",rx=-slope if side<0 else slope)
    # Work benches, log cradles, hand tools, organized timber stacks and barrels.
    for i in range(2 + level//2):
        x=-99+i*11
        m.box("CarpenterBenchTop",x,3.2,49,7,.55,2,"plank")
        for dx in (-2.7,2.7): m.box("CarpenterBenchLeg",x+dx,2.35,49, .45,1.6,1.6,"wood")
        for j in range(3): m.cylinder("BenchTimberBlank",x,3.65+j*.44,49,5.4,.34,.34,"wood_light",collide=False)
    # Exterior log yard and hand carts, safely north of the separate loading lane.
    for row in range(3):
        z=81+row*4.2
        x=-104+row*1.8
        m.box("LogRackBase",x,2,z,12,.5,1.4,"wood")
        for dx in (-5,5): m.box("LogRackUpright",x+dx,3.5,z, .55,3.5,1.2,"wood_light")
        for j in range(3): m.cylinder("StackedOakLog",x,3.2+j*.62,z,10,.55,.55,"wood_light",ry=math.pi/2,collide=False)
    for x,z in ((-108,49),(-104,42),(-54,82),(-45,74)):
        m.cylinder("OakStump",x,2,z,1.4,1.6,1.6,"wood_light",collide=False)
        m.cylinder("StumpCutFace",x,2.83,z,1.48,.12,1.48,"stone_light",collide=False)
    for x,z in ((-111,87),(-101,93),(-54,91)):
        m.cylinder("OakBarrelBody",x,2.5,z,2.2,2.7,2.2,"wood_light",collide=False)
        for y in (1.65,3.1): m.cylinder("OakBarrelHoop",x,y,z,2.28,.16,2.28,"metal",collide=False)
    # Stage-specific machinery and roofed timber store.
    if level >= 2:
        m.box("CoveredTimberStoreFloor",-47,1.2,94,19,.35,17,"stone")
        for x in (-55,-39):
            for z in (87,101): m.box("TimberStorePost",x,6,z,.8,10,.8,"wood")
        m.box("TimberStoreBeam",-47,10,87,18,1,1,"wood_light")
        m.box("TimberStoreBeam",-47,10,101,18,1,1,"wood_light")
        m.box("TimberStoreRoof",-47,11.1,94,20,.8,17,"roof",collide=False)
        for j in range(3): m.cylinder("FinishedBoardStack",-47,2.1+j*.72,93,13,.55,.55,"plank",ry=math.pi/2,collide=False)
    if level >= 3:
        # Side-mounted water wheel: all named members rotate around its X-axis pivot in runtime.
        center=(-58.7,8.3,59)
        m.cylinder("LumberWaterWheelHub",*center,2.2,2.8,2.8,"metal",collide=False)
        for i in range(12):
            a=2*math.pi*i/12
            rim_y=center[1]+math.sin(a)*6.35
            rim_z=center[2]+math.cos(a)*6.35
            m.box("LumberWaterWheelRimSegment",center[0],rim_y,rim_z,1.0,.95,3.45,"wood_light",rx=-a,collide=False)
            inner_y=center[1]+math.sin(a)*5.45
            inner_z=center[2]+math.cos(a)*5.45
            m.box("LumberWaterWheelRimInnerSegment",center[0],inner_y,inner_z,1.0,.58,2.9,"dark",rx=-a,collide=False)
            m.box("LumberWaterWheelSpoke",center[0],center[1]+math.sin(a)*3.8,center[2]+math.cos(a)*3.8,.75,9.2,.7,"wood_light",rx=math.pi/2-a,collide=False)
            m.box("LumberWaterWheelPaddle",center[0],center[1]+math.sin(a)*6.2,center[2]+math.cos(a)*6.2,1.1,1.4,3.1,"wood",rx=-a,collide=False)
        m.cylinder("LumberWaterWheelAxle",-57,8.3,59,7,1.2,1.2,"metal")
        for z in (51.2,66.8): m.box("WaterWheelSupport",-58.8,4.1,z,1.1,5.6,1.1,"wood")
        m.box("WaterTrough",-51,1.5,67,15,.5,3,"water",collide=False)
        m.box("WaterTroughSide",-51,2.1,65.5,15,1.2,.35,"wood")
        m.box("WaterTroughSide",-51,2.1,68.5,15,1.2,.35,"wood")
        for j in range(2):
            x=-84+j*10
            m.box("SawmillMachineFrame",x,4,55,7,5,4,"wood")
            m.box("MainCircularSawGuard",x,7,55,5,.6,4,"metal",collide=False)
            m.cylinder("MainCircularSaw",x,6.4,55,.65,3.2,3.2,"metal",collide=False)
            for b in range(8):
                a=2*math.pi*b/8
                m.box("SawBladeTooth",x,6.4+math.sin(a)*1.5,55+math.cos(a)*1.5,.7,.42,.32,"metal",rx=-a,collide=False)
    if level >= 4:
        m.box("ForemanOfficeFloor",-60,1.5,82,12,.3,10,"stone")
        for x in (-65,-55):
            for z in (78,86): m.box("ForemanOfficePost",x,4.5,z,.6,6,.6,"wood_light")
        m.box("ForemanOfficeRoof",-60,7.7,82,13,.65,11,"roof")
        m.box("MillSignBoard",-81,11,cz+half_z+.25,12,2,.35,"wood_light",collide=False)
        m.box("MillSignTextPlaque",-81,11,cz+half_z+.48,8,1.1,.12,"gold",collide=False)
    # Moving feeder stays beside the machinery, well clear of the route.
    if level >= 2:
        m.box("LogFeeder",-70,4,73,7,.65,8,"wood_light")
    # The production source is the only active drop point in this tier snapshot.
    m.box("DropPoint",DROP_X[level],8.4,114,2,.2,2,"gold",collide=False,transparency=1,material="SmoothPlastic")
    return {"className":"Model","properties":{"WorldPivotData":{"OptionalCFrame":{"position":[0,0,0],"orientation":[[1,0,0],[0,1,0],[0,0,1]]}}},"children":m.parts}

for level in range(1,5):
    path=OUT/f"Lumber{ROMAN[level]}.model.json"
    model=build(level)
    for part in model["children"]:
        cf=part["properties"]["CFrame"]["CFrame"]
        cf["position"][0]=round(cf["position"][0]-70,4)
    path.write_text(json.dumps(model,indent=2)+"\n",encoding="utf-8")
    print(f"wrote {path.name}: {len(build(level)['children'])} editable parts")
