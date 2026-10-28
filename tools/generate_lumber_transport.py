"""Place the Lumber belt and collector in a clear, rotated-safe loading corridor."""
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OFFSETS={1:(-430,-430,45),2:(430,-430,-45),3:(-430,430,135),4:(430,430,-135)}

def matrix(angle):
    a=math.radians(angle); c=math.cos(a); s=math.sin(a)
    return [[c,0,s],[0,1,0],[-s,0,c]]

def world(x,y,z,idx):
    ox,oz,angle=OFFSETS[idx]; a=math.radians(angle); c=math.cos(a); s=math.sin(a)
    return [ox+c*x+s*z,y,oz-s*x+c*z]

def part(name):
    for p in model["children"]:
        if p["name"]==name: return p
    return None

for i in range(1,5):
    path=ROOT/f"src/Workspace/Tycoons/Tycoon{i}/Environment.model.json"
    model=json.loads(path.read_text(encoding="utf-8"))
    belt=part("Conveyor_Lumber"); collector=part("Collector_Lumber")
    assert belt and collector, f"Missing Lumber environment parts in {path}"
    belt["properties"]["Size"]=[5.5,.783,72.0]
    belt["properties"]["CFrame"]["CFrame"]["position"]=world(-78,1.68,114,i)
    belt["properties"]["CFrame"]["CFrame"]["orientation"]=matrix(OFFSETS[i][2]-90)
    collector["properties"]["CFrame"]["CFrame"]["position"]=world(-40,3.2,114,i)
    collector["properties"]["CFrame"]["CFrame"]["orientation"]=matrix(OFFSETS[i][2])
    collector["properties"]["CanCollide"]=False
    collector["properties"]["CanTouch"]=True
    # Narrow side guides retain resources while leaving the central 5.5-stud belt open.
    for rail_name,local_z in (("LumberRailL",111),("LumberRailR",117)):
        rail=part(rail_name)
        assert rail, f"Missing Lumber lane rail {rail_name} in {path}"
        props=rail["properties"]
        props["Size"]=[.5,1.35,72.0]
        props["CanCollide"]=True
        props["CanTouch"]=False
        props["CFrame"]["CFrame"]["position"]=world(-78,2.48,local_z,i)
        props["CFrame"]["CFrame"]["orientation"]=matrix(OFFSETS[i][2]-90)
    path.write_text(json.dumps(model,indent=2)+"\n",encoding="utf-8")
    print(f"relocated Lumber transport lane in Tycoon{i}")
