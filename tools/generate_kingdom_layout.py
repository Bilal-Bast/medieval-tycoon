"""Build the 480-stud eight-kingdom world, roads, and production lanes."""
import json, math, pathlib, shutil, xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parents[1]
PLOTS={
 # 3x3 ring: the middle cell stays open for the shared plaza. Full-size plots
 # sit 20 studs apart, so eight players are much closer without plot overlap.
 1:(-500,-500,0), 2:(500,-500,0), 3:(-500,500,180), 4:(500,500,180),
 5:(0,-500,0), 6:(500,0,-90), 7:(0,500,180), 8:(-500,0,90),
}
REALM_COLORS=[(.72,.29,.21),(.25,.48,.68),(.40,.58,.31),(.75,.57,.22),(.58,.37,.68),(.22,.58,.52),(.72,.40,.31),(.36,.45,.70)]
CORRIDORS={
 "Lumber":((-148,1.68,114),5.5,72,(-110,3.2,114),(-173,-164,-155,-146)),
 "Quarry":((-130,1.68,-150),5.5,72,(-92,3.2,-150),(-155,-146,-137,-128)),
 "Blacksmith":((130,1.68,-150),5.5,72,(168,3.2,-150),(105,114,123,132)),
 "Farm":((130,1.68,169),5.5,72,(168,3.2,169),(105,114,123,132)),
 "Barracks":((-92,1.68,207),5.5,72,(-54,3.2,207),(-117,-108,-99,-90)),
}
THEME={"Lumber":((.36,.24,.13),"WoodPlanks"),"Quarry":((.36,.37,.37),"Slate"),"Blacksmith":((.27,.29,.31),"Metal"),"Farm":((.46,.34,.16),"WoodPlanks"),"Barracks":((.30,.30,.28),"Metal")}

def mat(deg):
 a=math.radians(deg); c=math.cos(a); s=math.sin(a)
 return [[c,0,s],[0,1,0],[-s,0,c]]
def mul(a,b): return [[sum(a[r][k]*b[k][c] for k in range(3)) for c in range(3)] for r in range(3)]
def local_to_world(x,y,z,i):
 ox,oz,deg=PLOTS[i]; a=math.radians(deg); c=math.cos(a); s=math.sin(a)
 return [round(ox+c*x+s*z,4),round(y,4),round(oz-s*x+c*z,4)]
def part(name,p,size,color=(.4,.35,.25),material="Ground",collide=True,touch=False,trans=0,rot=None,shape="Block"):
 return {"name":name,"className":"Part","properties":{"Anchored":True,"CanCollide":collide,"CanQuery":False,"CanTouch":touch,"CastShadow":True,"CFrame":{"CFrame":{"position":p,"orientation":rot or [[1,0,0],[0,1,0],[0,0,1]]}},"Color":color,"Material":material,"Size":[float(x) for x in size],"Transparency":trans,"Shape":shape,"TopSurface":"Smooth","BottomSurface":"Smooth"},"children":[]}
def road_part(name,a,b,width,i):
 x1,z1=a; x2,z2=b; dx=x2-x1; dz=z2-z1; ang=math.degrees(math.atan2(dx,dz))
 center=((x1+x2)/2,(z1+z2)/2); pos=local_to_world(center[0],1.12,center[1],i); rot=mul(mat(PLOTS[i][2]),mat(ang))
 return part(name,pos,(width,.28,math.hypot(dx,dz)),(.38,.32,.25),"Ground",True,rot=rot)
def add_box(parts,name,x,y,z,sx,sy,sz,color=(.35,.25,.17),material="Wood",collide=True,rot=None,trans=0):
 parts.append(part(name,local_to_world(x,y,z,idx),(sx,sy,sz),color,material,collide,False,trans,mul(mat(PLOTS[idx][2]),rot) if rot else mat(PLOTS[idx][2])))

template_plot=ROOT/"src/Workspace/Tycoons/Tycoon4"
for idx in PLOTS:
 plot_path=ROOT/f"src/Workspace/Tycoons/Tycoon{idx}"
 if idx > 4 and not plot_path.exists(): shutil.copytree(template_plot,plot_path)

for idx in PLOTS:
 parts=[]
 add_box(parts,"DistrictPlaza",0,1.02,90,40,.12,32,(.43,.37,.28),"Ground",False)
 # Raised stone segments are kept below the resource corridor's clearance band.
 road_paths={
  "MainGateToTown":[(0,240),(0,223),(75,223),(75,86)],
  "TownCrossroad":[(75,86),(-80,86)],
  "RoadToBarracks":[(75,86),(0,100)],
  "RoadToLumber":[(-80,86),(-90,86),(-90,137)],
  "RoadToFarm":[(75,86),(75,145)],
  "CastleRoad":[(-80,86),(-66,86),(-66,-55),(0,-55),(65,-55)],
  "RoadToQuarry":[(-80,86),(-63,86),(-63,-180),(-138,-180),(-138,-166)],
  "RoadToBlacksmith":[(75,86),(65,86),(65,0),(215,0),(215,-55),(215,-171),(126,-171),(126,-165)],
 }
 for rname,points in road_paths.items():
  for j,(a,b) in enumerate(zip(points,points[1:])):
   parts.append(road_part(f"Road_{rname}_{j}",a,b,12,idx))
 # District junction stones and readable wayfinding signs.
 for name,x,z in (("TownJunction",75,86),("WestJunction",-80,86),("RoyalJunction",-66,-55)):
  add_box(parts,name,x,1.28,z,16,.15,16,(.48,.42,.32),"Cobblestone",False)
 signs=(("Lumber",-105,145),("Quarry",-67,-108),("Blacksmith",67,-108),("Farm",75,152),("Barracks",0,108),("Castle",65,-64))
 for name,x,z in signs:
  add_box(parts,f"{name}RoadSignPost",x,3,z,.8,4,.8,(.29,.18,.09),"Wood")
  add_box(parts,f"{name}RoadSignBoard",x,4.6,z,8.5,1.4,.5,(.48,.34,.19),"WoodPlanks")
 # Gate pillars and a low bridge runway align to the approach road.
 for x in (-21,21):
  add_box(parts,"GatePillar",x,5,232,4,10,5,(.48,.46,.41),"Slate")
  add_box(parts,"GateTorch",x,10.5,232,1.2,1.2,1.2,(1,.48,.12),"Neon",False)
 # A warm heraldic entry arch gives each kingdom a clear, unique identity.
 add_box(parts,"GateLintel",0,11,232,48,2.4,5,(.46,.43,.37),"Slate",False)
 add_box(parts,"RealmBannerPole",0,15,231,0.7,7,0.7,(.56,.42,.22),"Wood",False)
 add_box(parts,"RealmBannerCloth",0,10.5,230.5,8,8,0.25,REALM_COLORS[idx-1],"Fabric",False)
 add_box(parts,"RealmBannerCrest",0,16.3,231,2.4,2.4,0.6,(.79,.64,.32),"Metal",False)
 add_box(parts,"GateBridge",0,1.03,242,36,.2,20,(.47,.41,.33),"Cobblestone",False)
 # Decorative edge trees kept outside the developed district footprints and lanes.
 for t,(x,z) in enumerate(((-194,-185),(194,-185),(-194,185),(194,185),(-206,0),(206,0))):
  add_box(parts,f"BoundaryOakTrunk{t}",x,4,z,3,8,3,(.25,.16,.08),"Wood")
  parts.append(part(f"BoundaryOakCrown{t}",local_to_world(x,10,z,idx),(12,11,12),(.22,.34,.17),"Grass",False,shape="Ball"))
 # The collector remains touch-active, while resources are physically transported on a ruled track.
 for district,(center,width,length,collector,drops) in CORRIDORS.items():
  theme,material=THEME[district]; (x,y,z)=center; (cx,cy,cz)=collector
  orient=mat(PLOTS[idx][2]-90)
  parts.append(part(f"Conveyor_{district}",local_to_world(x,y,z,idx),(width,.783,length),theme,material,True,True,0,orient))
  for name,rz in ((f"{district}RailL",z-width/2-.25),(f"{district}RailR",z+width/2+.25)):
   parts.append(part(name,local_to_world(x,2.48,rz,idx),(.5,1.35,length),(.28,.2,.1),"Wood",True,False,0,orient))
  parts.append(part(f"Collector_{district}",local_to_world(cx,cy,cz,idx),(12,6.21,11),(1,1,1),"SmoothPlastic",False,True,1,mat(PLOTS[idx][2])))
  # Treasure hoard is behind the collector along the same axis but clear of block approach.
  add_box(parts,f"{district}TreasuryBase",cx+11,1.3,cz+5,9,1.0,7,(.31,.25,.16),"Wood",True)
  add_box(parts,f"{district}TreasuryChest",cx+11,2.5,cz+5,7,2.2,5,(.45,.29,.13),"WoodPlanks",True)
  add_box(parts,f"{district}TreasuryBand",cx+11,2.5,cz+5,7.4,.28,5.4,(.63,.46,.18),"Metal",False)
 # District greens anchor the four separated production estates; no platform crosses a belt.
 for name,x,z,sx,sz,color in (
  ("LumberEstate",-145,72,80,90,(.31,.43,.23)),("QuarryEstate",-138,-100,128,132,(.37,.37,.35)),
  ("ForgeEstate",126,-84,120,110,(.36,.34,.29)),("FarmEstate",136,90,120,130,(.31,.43,.23)),
  ("BarracksEstate",0,150,130,80,(.31,.43,.23)),("RoyalEstate",0,-119,122,132,(.36,.35,.32))):
  add_box(parts,name,x,.82,z,sx,.22,sz,color,"Grass",False)
 # Local ground spawn markers and walls/pads are separate instances.
 env={"className":"Model","properties":{"WorldPivotData":{"OptionalCFrame":{"position":[0,0,0],"orientation":[[1,0,0],[0,1,0],[0,0,1]]}}},"children":parts}
 path=ROOT/f"src/Workspace/Tycoons/Tycoon{idx}/Environment.model.json"
 path.write_text(json.dumps(env,indent=2)+"\n",encoding="utf-8")
 # Resize and reposition the world-space base, spawn and claim trigger in their XML source.
 theta=PLOTS[idx][2]; m=mat(theta)
 for filename,local in (("Base.rbxmx",(0,.5,0)),("Spawn.rbxmx",(0,1,213)),("ClaimPad.rbxmx",(0,1.5,239))):
  xml=ET.parse(ROOT/f"src/Workspace/Tycoons/Tycoon{idx}/{filename}"); root=xml.getroot()
  for cf in root.iter("CoordinateFrame"):
   if cf.get("name")=="CFrame":
    x,y,z=local_to_world(*local,idx)
    for tag,val in zip(("X","Y","Z"),(x,y,z)): cf.find(tag).text=str(val)
    for r in range(3):
     for c in range(3): cf.find(f"R{r}{c}").text=f"{m[r][c]:.6f}"
  if filename=="Base.rbxmx":
   for size in root.iter("Vector3"):
    if size.get("name")=="size":
     size.find("X").text="480"; size.find("Z").text="480"
  xml.write(ROOT/f"src/Workspace/Tycoons/Tycoon{idx}/{filename}",encoding="utf-8",xml_declaration=True)
 print(f"rebuilt Tycoon{idx} roads, corridors, and 480-stud base")

# Eight royal roads connect the central civic plaza to every kingdom gate.
roads=[]
for idx,(ox,oz,theta) in PLOTS.items():
 gate=local_to_world(0,1.12,239,idx)
 distance=math.hypot(gate[0],gate[2])
 start=[gate[0]/distance*47,1.0,gate[2]/distance*47]
 dx=gate[0]-start[0]; dz=gate[2]-start[2]; ang=math.degrees(math.atan2(dx,dz))
 center=[(start[0]+gate[0])/2,0.78,(start[2]+gate[2])/2]
 length=math.hypot(dx,dz)
 roads.append(part(f"RoyalRoad_Tycoon{idx}",center,(18,.32,length),(.39,.37,.32),"Cobblestone",True,rot=mat(ang)))
 # Low stone curbs frame the roads without narrowing their walkable deck.
 for side in (-1,1):
  perp=(math.cos(math.radians(ang)), -math.sin(math.radians(ang)))
  edge=[center[0]+perp[0]*10,0.99,center[2]+perp[1]*10]
  roads.append(part(f"RoyalRoadEdge_T{idx}_{side}",edge,(.65,.35,length),(.48,.46,.42),"Slate",True,rot=mat(ang)))
roadmodel={"className":"Model","properties":{"WorldPivotData":{"OptionalCFrame":{"position":[0,0,0],"orientation":[[1,0,0],[0,1,0],[0,0,1]]}}},"children":roads}
(ROOT/"src/Workspace/KingdomRoads.model.json").write_text(json.dumps(roadmodel,indent=2)+"\n",encoding="utf-8")

# Expand the grassy world floor and landscape ring around all eight realms.
basepath=ROOT/"src/Workspace/Baseplate.model.json"
base=json.loads(basepath.read_text(encoding="utf-8")); base.setdefault("properties",{})["Size"]=[2400,1,2400]
basepath.write_text(json.dumps(base,indent=2)+"\n",encoding="utf-8")
worldpath=ROOT/"src/Workspace/WorldBoundary.model.json"
boundary=json.loads((ROOT/"tools/templates/WorldBoundary.model.json").read_text(encoding="utf-8"))
for p in boundary.get("children",[]):
 prop=p.get("properties",{}); cf=prop.get("CFrame",{}).get("CFrame",{}); pos=cf.get("position")
 if pos:
  pos[0]=round(pos[0]*1.5,4); pos[2]=round(pos[2]*1.5,4)
  size=prop.get("Size")
  if size: size[0]=round(size[0]*1.5,4); size[2]=round(size[2]*1.5,4)
worldpath.write_text(json.dumps(boundary,indent=2)+"\n",encoding="utf-8")
print("rebuilt compact 3x3 kingdom roads, 2400-stud world floor, and outer boundary ring")

# A ring of small, colored groves softens the open ground between the realms
# and the distant hills. The trees sit in the 22.5-degree gaps between plots.
grove_parts=[]
grove_leaf=[(.24,.43,.22),(.29,.50,.26),(.20,.40,.35),(.34,.48,.25)]
grove_flowers=[(.93,.42,.43),(.97,.73,.25),(.67,.47,.88),(.98,.56,.24)]
for i in range(8):
 angle=math.radians(22.5+i*45); x=math.cos(angle)*845; z=math.sin(angle)*845
 leaf=grove_leaf[i%len(grove_leaf)]; flower=grove_flowers[i%len(grove_flowers)]
 grove_parts.append(part(f"OuterOakTrunk{i+1}",[round(x,3),4,round(z,3)],[2.1,8,2.1],(.30,.19,.10),"Wood",False))
 grove_parts.append(part(f"OuterOakCanopy{i+1}",[round(x,3),9,round(z,3)],[10,9,10],leaf,"Grass",False,shape="Ball"))
 for j,offset in enumerate(((-3,7,1),(3,7,-1))):
  grove_parts.append(part(f"OuterOakBough{i+1}_{j+1}",[round(x+offset[0],3),offset[1],round(z+offset[2],3)],
   [6.4,6.3,6.4],grove_leaf[(i+j+1)%len(grove_leaf)],"Grass",False,shape="Ball"))
 for j in range(3):
  petal_angle=math.radians(j*120+i*17); px=x+math.cos(petal_angle)*6.1; pz=z+math.sin(petal_angle)*6.1
  grove_parts.append(part(f"OuterWildflower{i+1}_{j+1}",[round(px,3),1.4,round(pz,3)],[1.15,.8,1.15],flower,"SmoothPlastic",False,shape="Ball"))
grove={"className":"Model","properties":{"WorldPivotData":{"OptionalCFrame":{"position":[0,0,0],"orientation":[[1,0,0],[0,1,0],[0,0,1]]}}},"children":grove_parts}
(ROOT/"src/Workspace/OuterGrove.model.json").write_text(json.dumps(grove,indent=2)+"\n",encoding="utf-8")
print("added eight flowered outer groves between the realm plots and landscape ring")

# Grow the central civic plaza into an eight-way arrival square and remove the
# old four-spoke stubs; the world roads now meet the plaza directly.
hubpath=ROOT/"src/Workspace/KingdomHub.model.json"
hub=json.loads(hubpath.read_text(encoding="utf-8"))
hubparts=[]
for p in hub.get("children",[]):
 name=p.get("name",""); prop=p.get("properties",{}); pos=prop.get("CFrame",{}).get("CFrame",{}).get("position"); size=prop.get("Size")
 if name in {"NorthWestRoad","NorthEastRoad","SouthWestRoad","SouthEastRoad"} or "RoadStoneEdge" in name: continue
 if name=="CentralStonePlaza" and size: prop["Size"]=[96,.52,96]
 if name in {"PlazaBorderNorth","PlazaBorderSouth"} and pos and size:
  pos[2]=-48.2 if name.endswith("North") else 48.2; size[0]=96
 if name in {"PlazaBorderEast","PlazaBorderWest"} and pos and size:
  pos[0]=48.2 if name.endswith("East") else -48.2; size[2]=96
 hubparts.append(p)
hub["children"]=hubparts
# Eight realm-colored lanterns make each kingdom route readable at the shared plaza.
realm_lights=[(.80,.32,.23),(.31,.63,.88),(.48,.72,.36),(.96,.68,.24),(.73,.48,.91),(.26,.78,.70),(.91,.45,.34),(.43,.58,.94)]
for i in range(8):
 angle=math.radians(22.5+i*45); x=round(math.cos(angle)*40,4); z=round(math.sin(angle)*40,4)
 realm=realm_lights[i]
 for suffix,y,size,color,material,shape in (
  ("Base",.95,(1.7,.75,1.7),(.30,.27,.21),"Slate","Block"),
  ("Post",3.1,(.48,4.3,.48),(.24,.17,.1),"Wood","Block"),
  ("Glass",5.35,(1.0,1.0,1.0),realm,"Neon","Ball"),
  ("Cap",6.0,(1.4,.28,1.4),(.36,.27,.16),"Metal","Block")):
  hubparts.append(part(f"RealmLantern{i+1}{suffix}",[x,y,z],size,color,material,True,False,0,shape=shape))
 light={"name":f"RealmLantern{i+1}Light","className":"PointLight","properties":{"Brightness":1.25,"Color":realm,"Range":17,"Shadows":True},"children":[]}
 hubparts[-2].setdefault("children",[]).append(light)
# A small, walk-around royal fountain gives the shared spawn a memorable landmark.
fx,fz=-17,-17
for name,pos,size,color,material,shape in (
 ("FountainStoneBase",[fx,1.1,fz],[18,.85,18],(.39,.37,.32),"Cobblestone","Block"),
 ("FountainPedestal",[fx,1.9,fz],[4,1.9,4],(.53,.47,.36),"Marble","Cylinder"),
 ("FountainLowerBowl",[fx,3.0,fz],[11,.7,11],(.55,.49,.38),"Slate","Cylinder"),
 ("FountainLowerWater",[fx,3.38,fz],[9.4,.12,9.4],(.18,.70,.82),"Neon","Cylinder"),
 ("FountainColumn",[fx,4.45,fz],[1.2,2.5,1.2],(.71,.61,.43),"Marble","Cylinder"),
 ("FountainUpperBowl",[fx,5.65,fz],[5.8,.48,5.8],(.63,.54,.40),"Marble","Cylinder"),
 ("FountainCrown",[fx,6.75,fz],[1.35,1.35,1.35],(.32,.87,.91),"Neon","Ball")):
 hubparts.append(part(name,pos,size,color,material,False,False,0,shape=shape))
glow={"name":"FountainGlow","className":"PointLight","properties":{"Brightness":1.3,"Color":[.22,.75,.94],"Range":16,"Shadows":False},"children":[]}
next(p for p in hubparts if p["name"]=="FountainCrown").setdefault("children",[]).append(glow)
hubpath.write_text(json.dumps(hub,indent=2)+"\n",encoding="utf-8")
print("polished civic plaza with realm-colored lanterns, a royal fountain, and eight illuminated approaches")
