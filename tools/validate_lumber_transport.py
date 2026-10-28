"""Static checks for Lumber production anchors and the four rotated resource lanes."""
import json
import math
import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
ROMAN={1:"I",2:"II",3:"III",4:"IV"}
PLOTS={1:(-430,-430,45),2:(430,-430,-45),3:(-430,430,135),4:(430,430,-135)}
LANE=(-78,1.68,114); WIDTH=5.5; LENGTH=72; COLLECTOR=(-40,3.2,114); COLLECTOR_SIZE=(12,6.21,11)
DROP_X=(-103,-94,-85,-76); DROP_Y=8.4
CORRIDOR=(-114,-42,111.25,116.75,1.5,4.2)
FAIL=[]

def check(ok,msg):
    if not ok: FAIL.append(msg)

def matrix_y(degrees):
    a=math.radians(degrees); c=math.cos(a); s=math.sin(a)
    return [[c,0,s],[0,1,0],[-s,0,c]]

def transpose(a): return [list(row) for row in zip(*a)]
def mm(a,b): return [[sum(a[r][k]*b[k][c] for k in range(3)) for c in range(3)] for r in range(3)]
def local_pos(p,idx):
    ox,oz,ang=PLOTS[idx]; dx=p[0]-ox; dz=p[2]-oz; a=math.radians(ang); c=math.cos(a); s=math.sin(a)
    return [c*dx-s*dz,p[1],s*dx+c*dz]
def cframe(part): return part.get("properties",{}).get("CFrame",{}).get("CFrame",{})
def aabb(pos,size,rot):
    ext=[sum(abs(rot[r][c])*size[c]/2 for c in range(3)) for r in range(3)]
    return [(pos[i]-ext[i],pos[i]+ext[i]) for i in range(3)]
def intersects(box,c):
    x0,x1,z0,z1,y0,y1=c
    return box[0][1]>x0 and box[0][0]<x1 and box[2][1]>z0 and box[2][0]<z1 and box[1][1]>y0 and box[1][0]<y1

config=(ROOT/"src/ServerScriptService/Tycoon/Config.luau").read_text(encoding="utf-8")
check("LaneCenter = Vector3.new(-78, 1.68, 114)" in config,"Config lane center differs from validated corridor")
check("DropXs = { -103, -94, -85, -76 }" in config,"Config Lumber drop sequence differs from expected producers")

for level in range(1,5):
    path=ROOT/f"src/ServerStorage/Lumber{ROMAN[level]}.model.json"
    model=json.loads(path.read_text(encoding="utf-8"))
    points=[p for p in model["children"] if p["name"]=="DropPoint"]
    check(len(points)==1,f"{path.name}: expected exactly one current DropPoint")
    if points:
        p=points[0]; prop=p["properties"]; pos=cframe(p).get("position",[])
        check(all(abs(pos[i]-v)<.05 for i,v in enumerate((DROP_X[level-1],DROP_Y,114))),f"{path.name}: producer anchor is misaligned: {pos}")
        check(prop.get("Anchored") is True and prop.get("CanCollide") is False and prop.get("CanTouch") is False and prop.get("Transparency")==1,
              f"{path.name}: producer anchor must be anchored, invisible, and non-colliding")
    blockers=[]
    for part in model["children"]:
        prop=part.get("properties",{})
        if part.get("className") not in ("Part","MeshPart","UnionOperation") or prop.get("CanCollide") is not True: continue
        cf=cframe(part); pos=cf.get("position",[0,0,0]); size=prop.get("Size",[0,0,0]); rot=cf.get("orientation",[[1,0,0],[0,1,0],[0,0,1]])
        if intersects(aabb(pos,size,rot),CORRIDOR): blockers.append(part["name"])
    check(not blockers,f"{path.name}: collidable Lumber art intersects transport corridor: {blockers}")
    if level>=3:
        wheel=[p for p in model["children"] if p["name"].startswith("LumberWaterWheel")]
        check(len(wheel)>=20,f"{path.name}: expected complete rotating water wheel")

for idx in range(1,5):
    path=ROOT/f"src/Workspace/Tycoons/Tycoon{idx}/Environment.model.json"
    env=json.loads(path.read_text(encoding="utf-8")); parts={p["name"]:p for p in env["children"]}
    belt=parts.get("Conveyor_Lumber"); collector=parts.get("Collector_Lumber")
    check(belt is not None and collector is not None,f"Tycoon{idx}: missing Lumber conveyor/collector")
    if not belt or not collector: continue
    bp=belt["properties"]; bcf=cframe(belt); bpos=bcf.get("position",[]); brot=bcf.get("orientation")
    expected=local_pos(bpos,idx)
    check(all(abs(expected[i]-LANE[i])<.3 for i in range(3)),f"Tycoon{idx}: conveyor center is misplaced: {expected}")
    check(all(abs(bp["Size"][i]-v)<.05 for i,v in enumerate((WIDTH,.783,LENGTH))),f"Tycoon{idx}: conveyor dimensions are incorrect")
    ox,oz,ang=PLOTS[idx]; expected_forward=[math.cos(math.radians(ang)),0,-math.sin(math.radians(ang))]
    look=[-brot[0][2],-brot[1][2],-brot[2][2]]
    check(sum(look[i]*expected_forward[i] for i in range(3))>.99,f"Tycoon{idx}: conveyor does not point toward collector")
    cp=collector["properties"]; cpos=local_pos(cframe(collector).get("position",[]),idx)
    check(all(abs(cpos[i]-COLLECTOR[i])<.3 for i in range(3)),f"Tycoon{idx}: collector position is incorrect")
    check(cp.get("CanTouch") is True and cp.get("CanCollide") is False,f"Tycoon{idx}: collector cannot collect touch blocks safely")
    check(all(abs(cp["Size"][i]-COLLECTOR_SIZE[i])<.05 for i in range(3)),f"Tycoon{idx}: collector size disagrees with config")
    collector_box=aabb(cpos,cp["Size"],matrix_y(ang))
    lane_end=LANE[0]+LENGTH/2
    check(collector_box[0][0]<=lane_end<=collector_box[0][1] and collector_box[2][0]<=LANE[2]<=collector_box[2][1],f"Tycoon{idx}: collector misses the lane endpoint")
    for rail_name,z in (("LumberRailL",111), ("LumberRailR",117)):
        rail=parts.get(rail_name)
        check(rail is not None,f"Tycoon{idx}: missing {rail_name}")
        if rail:
            rp=rail["properties"]; rloc=local_pos(cframe(rail).get("position",[]),idx)
            check(abs(rloc[0]+78)<.3 and abs(rloc[2]-z)<.3,f"Tycoon{idx}: {rail_name} is misplaced: {rloc}")
            check(rp.get("CanCollide") is True and rp["Size"][2]==72,f"Tycoon{idx}: {rail_name} is not a continuous side guide")
    # Transform environment parts into plot-local coordinates and reject any unrelated
    # collidable geometry in the narrow elevation band above the belt.
    plot_rot=matrix_y(ang); inv=transpose(plot_rot)
    allowed={"Conveyor_Lumber","Collector_Lumber","LumberRailL","LumberRailR"}
    collision_names=[]
    for part in env["children"]:
        if part["name"] in allowed or part.get("className") not in ("Part","MeshPart","UnionOperation"): continue
        prop=part.get("properties",{})
        if prop.get("CanCollide") is not True: continue
        cf=cframe(part); pos=local_pos(cf.get("position",[]),idx); rot=mm(inv,cf.get("orientation",plot_rot))
        if intersects(aabb(pos,prop.get("Size",[0,0,0]),rot),CORRIDOR): collision_names.append(part["name"])
    check(not collision_names,f"Tycoon{idx}: unrelated environment collision in lane: {collision_names}")

if FAIL:
    print("Lumber transport validation failed:")
    for msg in FAIL: print(" -",msg)
    sys.exit(1)
print("Lumber transport static validation passed: 4 producer stages, 4 rotated lanes, collector coverage, and clear collidable corridors.")
