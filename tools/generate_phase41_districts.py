"""Regenerate Phase 4.1 Level I-IV production and fortification models."""
import json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"src/ServerStorage"
ROMAN={1:"I",2:"II",3:"III",4:"IV"}
COLORS={
 "stone":(0.39,0.38,0.35),"stone2":(0.52,0.50,0.45),"rock":(0.34,0.35,0.34),"rock2":(0.46,0.47,0.45),
 "wood":(0.27,0.15,0.08),"wood2":(0.42,0.27,0.15),"plank":(0.49,0.35,0.21),"roof":(0.28,0.22,0.18),
 "metal":(0.31,0.33,0.35),"gold":(0.67,0.49,0.22),"coal":(0.13,0.13,0.12),"glow":(1.0,0.28,0.035),
 "grass":(0.31,0.44,0.24),"field":(0.42,0.39,0.19),"field2":(0.52,0.45,0.23),"crop":(0.55,0.61,0.25),
 "water":(0.20,0.43,0.55),"hay":(0.68,0.55,0.26),"red":(0.58,0.16,0.12),"blue":(0.17,0.30,0.48),"white":(0.75,0.72,0.64)
}
MATS={"stone":"Slate","stone2":"Cobblestone","rock":"Rock","rock2":"Slate","wood":"Wood","wood2":"Wood","plank":"WoodPlanks","roof":"Slate","metal":"Metal","gold":"Metal","coal":"Slate","glow":"Neon","grass":"Grass","field":"Ground","field2":"Ground","crop":"Grass","water":"Water","hay":"Grass","red":"Fabric","blue":"Fabric","white":"Fabric"}
def ry(a):
 c,s=math.cos(a),math.sin(a); return [[c,0,s],[0,1,0],[-s,0,c]]
def rx(a):
 c,s=math.cos(a),math.sin(a); return [[1,0,0],[0,c,-s],[0,s,c]]
def rz(a):
 c,s=math.cos(a),math.sin(a); return [[c,-s,0],[s,c,0],[0,0,1]]
def mul(a,b): return [[sum(a[r][k]*b[k][c] for k in range(3)) for c in range(3)] for r in range(3)]
class Model:
 def __init__(self): self.parts=[]
 def part(self,n,p,s,color="wood",rot=None,collide=True,trans=0,shape="Block",material=None):
  self.parts.append({"name":n,"className":"Part","properties":{"Anchored":True,"CanCollide":collide,"CanQuery":False,"CanTouch":False,"CastShadow":True,"CFrame":{"CFrame":{"position":[round(float(v),4) for v in p],"orientation":rot or [[1,0,0],[0,1,0],[0,0,1]]}},"Color":COLORS[color],"Material":material or MATS[color],"Size":[float(v) for v in s],"Transparency":trans,"Shape":shape,"TopSurface":"Smooth","BottomSurface":"Smooth"},"children":[]})
 def box(self,n,x,y,z,sx,sy,sz,c="wood",**kw): self.part(n,(x,y,z),(sx,sy,sz),c,**kw)
 def cyl(self,n,x,y,z,sx,sy,sz,c="wood",**kw): self.part(n,(x,y,z),(sx,sy,sz),c,shape="Cylinder",**kw)
 def model(self): return {"className":"Model","properties":{"WorldPivotData":{"OptionalCFrame":{"position":[0,0,0],"orientation":[[1,0,0],[0,1,0],[0,0,1]]}}},"children":self.parts}

def quarry(level):
 m=Model(); stone="rock" if level<3 else "rock2"
 # Quarry rim surrounds a clear opening so the lowered excavation stays visible.
 m.box("QuarryWestRim",-193,.82,-100,22,.3,132,"rock",collide=False)
 m.box("QuarryEastYard",-92,.82,-100,30,.3,132,"rock",collide=False)
 m.box("QuarryNorthYard",-145,.82,-50,76,.3,32,"rock",collide=False)
 m.box("QuarrySouthYard",-145,.82,-150,76,.3,32,"rock",collide=False)
 m.box("ExcavationPitFloor",-145,-2.2,-99,76,.35,68,"rock2",collide=False)
 # Terraces rise around three sides, leaving the southern cart ramp clear.
 for side in (-1,1):
  x=-145+side*40
  for tier in range(4):
   y=.2+tier*3.0; inset=tier*5
   m.box("TerracedQuarryFace",x,y,-99,5.5,3.2,68-inset*2,stone,collide=True)
   m.box("TerraceLedge",x+side*3.1,y+1.55,-99,2.6,.55,68-inset*2, "stone2")
 for side in (-1,1):
  z=-99+side*34
  for tier in range(3):
   x=-145; inset=tier*5
   m.box("QuarryBackFace",x,.2+tier*3,z,76-inset*2,3.2,5.5,stone)
 # Staged ramps switchback down the open west slope.
 for i in range(1,level+2):
  x=-195+i*8; z=-143+i*18
  m.box("QuarrySwitchbackRamp",x,1.3-i*.75,z,18,.45,8,"stone2",collide=False,rot=mul(ry(math.radians(-12)),rx(math.radians(7))))
  for side in (-1,1): m.box("RampRetainingStone",x,2.0-i*.75,z+side*4.2,18,1.2,.55,stone)
 # Stone-cutting shed on the east side of the excavation.
 m.box("CuttingShedFoundation",-91,1.15,-75,36,.65,48,"stone")
 for x in (-108,-74):
  for z in (-97,-53): m.box("QuarryShedPost",x,7,z,1.5,12,1.5,"wood")
 for z in (-97,-53): m.box("QuarryShedBeam",-91,12,z,35,1.4,1.4,"wood2")
 for x in (-108,-74): m.box("QuarryShedSideWall",x,4,-75,1,6,40,"stone")
 m.box("QuarryShedRearWall",-91,4,-97,34,6,1,"stone")
 for side in (-1,1): m.box("QuarryWorkshopRoof",-91,14,-75+side*11,38,1.2,24,"roof",rot=rx(math.radians(-22 if side<0 else 22)))
 # Giant timber gantry and hoist dominate the excavation.
 crane_height=24+level*3
 for x in (-200,-88):
  for z in (-122,-78): m.box("QuarryCraneLeg",x,crane_height/2,z,3,crane_height,3,"wood")
 for z in (-122,-78): m.box("QuarryCraneGantry",-144,crane_height,z,116,3,3,"wood2")
 m.box("QuarryCraneCrossBrace",-144,crane_height-7,-100,4,14,44,"wood")
 m.box("QuarryHoistTrolley",-144,crane_height-2,-100,10,3,8,"metal")
 for x in (-147,-141):
  m.box("QuarryHoistChain",x,crane_height/2,-100,.18,crane_height-5,.18,"metal",collide=False)
 m.box("QuarryStoneHook",-144,4,-100,3,1,2,"metal")
 # Yard: masonry saw, cart, blocks and covered storage.
 for i in range(3):
  x=-86-i*9; z=-45-i*8
  m.box("CutStonePallet",x,1.5,z,8,.55,6,"wood")
  for row in range(2+i%2): m.box("CutLimestoneBlock",x,2.1+row*2,z,6,1.8,4,"stone2")
  m.cyl("QuarryCartWheel",x-3,1.7,z+5,1.1,2.3,2.3,"wood2",collide=False)
  m.cyl("QuarryCartWheel",x+3,1.7,z+5,1.1,2.3,2.3,"wood2",collide=False)
  m.box("QuarryHandcart",x,2.7,z+5,6,1.1,8,"wood")
 # shelters and tool racks scale up with the quarry.
 for i in range(level):
  x=-196+i*10; z=-48
  m.box("QuarryWorkerShelter",x,4,z,9,5,8,"wood2",collide=False)
  m.box("ShelterCanopy",x,7,z,11,.7,10,"roof",collide=False)
  m.box("QuarryPickRack",x,2.7,z+5,.35,3,.35,"wood")
  for dx in (-1,1): m.box("QuarryToolHandle",x+dx,3,z+5,.16,2.5,.16,"wood2",collide=False)
 # Proper resource source anchors: lane is the low south-side conveyor corridor.
 x=(-155,-146,-137,-128)[level-1]
 m.box("DropPoint",x,8.4,-150,2,.2,2,"gold",collide=False,trans=1,material="SmoothPlastic")
 for part in m.parts:
  if part["name"] != "DropPoint": part["properties"]["CFrame"]["CFrame"]["position"][0] -= 4
 return m.model()

def forge(level):
 m=Model(); cx,cz=142,-84; halfx=58; halfz=53
 m.box("RoyalForgeYard",cx,.84,-99,120,.3,132,"stone",collide=False)
 m.box("ForgeFoundation",cx,1.25,cz,2*halfx,.8,2*halfz,"stone")
 m.box("ForgeInteriorFloor",cx,1.7,cz,2*halfx-2,.18,2*halfz-2,"plank",collide=False)
 # South-facing open entrance; divided stone and timber walls.
 for x in (cx-halfx,cx+halfx): m.box("ForgeSideWall",x,5,cz,1.4,7,2*halfz,"stone")
 m.box("ForgeRearWall",cx,5,cz-halfz,2*halfx,7,1.4,"stone")
 door=10
 wall_width=halfx-door/2; wall_offset=(halfx+door/2)/2
 for x in (cx-wall_offset,cx+wall_offset): m.box("ForgeFrontWall",x,5,cz+halfz,wall_width,7,1.4,"stone")
 for x in (cx-halfx+1,cx+halfx-1):
  for z in (cz-halfz+1,cz+halfz-1): m.box("ForgeTimberPost",x,9,z,1.5,16,1.5,"wood")
 for z in (cz-halfz+1,cz+halfz-1): m.box("ForgeCrossbeam",cx,13,z,2*halfx,1.5,1.5,"wood2")
 # Pitched, shingled roof halves with timber braces.
 slope=math.radians(25); ry0=19
 for side in (-1,1):
  m.box("ForgePitchedRoof",cx,ry0,cz+side*halfz/2,2*halfx+4,1.3,halfz+2,"roof",rot=rx(-slope if side<0 else slope))
  for x in range(int(cx-halfx+6),int(cx+halfx),14):
   m.box("ForgeRoofRafter",x,ry0,cz+side*halfz/2,1.0,1.5,halfz+2,"wood2",rot=rx(-slope if side<0 else slope))
 m.box("ForgeRidge",cx,ry0+halfz*.22,cz,2*halfx+6,1.4,1.5,"wood")
 # Multiple stone furnaces with warm emissive cores and tall chimneys.
 for i in range(2+level):
  x=cx-halfx+14+i*min(18,(2*halfx-28)/(1+level))
  z=cz+halfz-13
  m.box("ForgeFurnaceBase",x,2.7,z,11,3.2,9,"stone2")
  m.box("ForgeFurnaceArch",x,5,z,8,3.5,7,"stone")
  m.box("ForgeFireGlow",x,3.8,z+4.1,4.8,2.6,.2,"glow",collide=False)
  m.box("ForgeChimney",x,12,z,4,16,4,"stone")
  m.box("ChimneyCap",x,20,z,5.4,1.1,5.4,"stone2")
  if i<level+1:
   for dx in (-15,15):
    m.box("ForgeAnvilBlock",x+dx,2.1,cz+5,5,1.2,4,"stone")
    m.box("ForgeAnvil",x+dx,3,cz+5,3.7,.8,2.2,"metal")
 # Covered work yard and smithy benches.
 for x in (cx-halfx+4,cx+halfx-4):
  for z in (cz-halfz-7,cz+halfz+7): m.box("ForgeYardPost",x,6,z,.8,10,.8,"wood")
 m.box("ForgeYardCanopy",cx,11,cz+halfz+7,2*halfx,1,18,"roof",collide=False)
 for i in range(3):
  x=cx-20+i*20; z=cz+10
  m.box("ForgeWorkbench",x,3.5,z,12,1,3,"wood2")
  for dx in (-4,4): m.box("WorkbenchLeg",x+dx,2.4,z,1,2,2,"wood")
  m.box("MetalStockRack",x,5,z-7,9,4,.8,"wood")
  for j in range(3): m.box("MetalBar",x,3.7+j*.55,z-7,8,.25,.3,"metal",collide=False)
 # Weapon, coal and metal storage outside the main walk-in floor.
 for i in range(4):
  x=cx+halfx+4; z=cz-halfz+8+i*12
  m.box("WeaponRack",x,4,z,2,7,10,"wood")
  for j in range(3): m.box("RackWeapon",x-1,4,z-3+j*3,.25,5,.45,"metal",collide=False)
 for j in range(level+1):
  x=cx+halfx-7+j*3; z=cz-halfz-5
  m.box("CoalPile",x,1.7,z,4,1.7,4,"coal",collide=False)
 # Production drop points live on a separate south service track (z=-150).
 x=(105,114,123,132)[level-1]; m.box("DropPoint",x,8.4,-150,2,.2,2,"gold",collide=False,trans=1,material="SmoothPlastic")
 for part in m.parts:
  if part["name"] != "DropPoint": part["properties"]["CFrame"]["CFrame"]["position"][0] -= 16
 return m.model()

def farm(level):
 m=Model();
 # Broad estate turf and four independently fenced crop plots.
 m.box("EstateGrass",140,.82,90,120,.3,130,"grass",collide=False)
 fields=[(100,65,36,43),(146,56,42,50),(102,119,40,43),(151,123,46,42)]
 for fi,(cx,cz,sx,sz) in enumerate(fields):
  m.box("PlowedField",cx,1.02,cz,sx,.16,sz,"field" if fi%2==0 else "field2",collide=False)
  for row in range(5+level*2):
   z=cz-sz/2+4+row*(sz-8)/(4+level*2)
   m.box("CropFurrow",cx,1.16,z,sx-4,.12,.34,"stone",collide=False)
   for col in range(2+level):
    x=cx-sx/2+5+col*(sx-10)/(1+level)
    m.box("CropStalk",x,1.75,z,.35,1.25,.35,"crop",collide=False)
    m.cyl("CropHead",x,2.42,z,.45,.55,.55,"hay",collide=False)
 # Field service lanes and irrigation channels.
 for z in (88,91): m.box("IrrigationDitch",135,.98,z,78,.22,.8,"water",collide=False)
 m.box("FarmCrossingBridge",106,1.25,89,8,.5,5,"wood2")
 # Farmhouse with open front porch, timber frame and steep roof.
 hx,hz=168,67
 m.box("FarmhouseFoundation",hx,1.2,hz,44,.7,34,"stone")
 m.box("FarmhouseFloor",hx,1.62,hz,41,.16,31,"plank",collide=False)
 for x in (hx-22,hx+22): m.box("FarmhouseSideWall",x,5,hz,1,7,34,"wood2")
 m.box("FarmhouseRearWall",hx,5,hz-17,44,7,1,"wood2")
 for x in (hx-22,hx-7,hx+7,hx+22): m.box("FarmhouseFrontPost",x,5,hz+17,.9,7,.9,"wood")
 for x in (hx-22,hx+22): m.box("FarmhouseFrontWall",x,4.8,hz+17,15,6.6,1,"plank")
 m.box("FarmhouseFrontLintel",hx,8.5,hz+17,44,1,1,"wood")
 for side in (-1,1): m.box("FarmhouseRoofSlope",hx,10.5,hz+side*9,48,1.0,19,"roof",rot=rx(math.radians(28 if side<0 else -28)))
 m.box("FarmhouseRidge",hx,15,hz,49,1.2,1.2,"wood2")
 # Barn, loft, hay storage and open equipment shed.
 bx,bz=130,143
 m.box("EstateBarnFoundation",bx,1.2,bz,55,.7,22,"stone")
 for x in (bx-27,bx+27): m.box("BarnSideWall",x,7,bz,1,12,22,"wood2")
 for z in (bz-11,bz+11): m.box("BarnEndWall",bx,7,z,55,12,1,"wood2")
 m.box("BarnDoubleDoorL",bx-8,5,bz+11,.7,8,1,"wood")
 m.box("BarnDoubleDoorR",bx+8,5,bz+11,.7,8,1,"wood")
 m.box("BarnLoft",bx,13,bz,56,1,24,"wood")
 for x in (bx-30,bx+30):
  for side in (-1,1): m.box("BarnRoofSlope",x,15,bz+side*6,2,1,14,"roof",rot=rx(math.radians(35 if side<0 else -35)))
 for j in range(4): m.box("StoredHayBale",bx-18+j*12,2.2,bz-15,9,2.2,6,"hay",collide=False)
 # Animal paddocks, fence rails and troughs.
 for cx,cz in ((178,121),(184,147)):
  for x in (cx-13,cx+13):
   for z in (cz-10,cz+10): m.box("PaddockFencePost",x,2.2,z,.65,2.8,.65,"wood")
   m.box("PaddockRail",x,2.3,cz,.4,1,20,"wood2")
  for z in (cz-10,cz+10): m.box("PaddockRail",cx,2.3,z,26,1,.4,"wood2")
  m.box("AnimalTrough",cx,1.5,cz,7,.8,2,"stone2")
 # Mill, scarecrow, carts, crates, silos and wheelbarrow.
 if level>=2:
  m.cyl("FarmSilo",154,7,48,14,8,8,"stone2")
  m.cyl("SiloRoof",154,14,48,5,10,10,"roof",collide=False)
 for j in range(2):
  x=88+j*42; z=144
  m.box("FarmCartBed",x,2,z,9,1,6,"wood2")
  for dx in (-3.5,3.5): m.cyl("FarmCartWheel",x+dx,1.6,z+3,1,2.5,2.5,"wood",collide=False)
  for k in range(3): m.box("FarmProduceCrate",x,2.8+k*1.1,z,3,1,3,"hay",collide=False)
 m.box("ScarecrowPost",86,4.5,44,.35,7,.35,"wood")
 m.box("ScarecrowArms",86,5.8,44,6,.35,.35,"wood")
 m.box("ScarecrowCoat",86,5.2,44,2,2.4,.5,"red",collide=False,material="Fabric")
 if level>=3:
  m.box("WindmillTower",192,9,55,8,18,8,"stone2")
  m.cyl("WindmillHub",192,19,55,2,2,2,"wood2",collide=False)
  for i in range(4):
   a=math.pi/4+i*math.pi/2
   m.box("WindmillSail",192+math.cos(a)*5,19+math.sin(a)*5,55,.7,13,1.0,"wood2",rot=rz(a),collide=False)
 # Harvest source on north service corridor; it is above the clear conveyor lane.
 x=(105,114,123,132)[level-1]; m.box("DropPoint",x,8.4,169,2,.2,2,"gold",collide=False,trans=1,material="SmoothPlastic")
 for part in m.parts:
  if part["name"] != "DropPoint": part["properties"]["CFrame"]["CFrame"]["position"][0] -= 4
 return m.model()

def barracks(level):
 m=Model(); cx,cz=0,150
 m.box("BarracksCompoundTurf",0,.82,150,130,.3,80,"grass",collide=False)
 # Open drill yard is enclosed by a low fence; service track remains south of z=105.
 for x in (-62,62):
  for z in (118,185): m.box("BarracksPerimeterPost",x,3,z,.8,4,.8,"wood")
  m.box("BarracksPerimeterRail",x,2.5,151,.45,1,66,"wood2")
 for z in (118,185): m.box("BarracksPerimeterRail",0,2.5,z,124,1,.45,"wood2")
 # Long garrison hall with a walk-through central doorway and pitched roof.
 m.box("BarracksFoundation",0,1.2,154,90,.7,44,"stone")
 m.box("BarracksFloor",0,1.62,154,87,.16,41,"plank",collide=False)
 for x in (-45,45): m.box("BarracksLongWall",x,6,154,1.2,9,44,"wood2")
 m.box("BarracksRearWall",0,6,132,90,9,1.2,"wood2")
 for x in (-45,-8,8,45): m.box("BarracksFrontPost",x,6,176,.9,9,.9,"wood")
 for x in (-26,26): m.box("BarracksFrontWall",x,5.8,176,37,8.5,1.2,"plank")
 m.box("BarracksFrontBeam",0,10.5,176,90,1.3,1.4,"wood")
 for side in (-1,1):
  m.box("BarracksRoofSlope",0,13.6,154+side*11.5,96,1.1,26,"roof",rot=rx(math.radians(25 if side<0 else -25)))
  for x in range(-40,41,16): m.box("BarracksRafter",x,13.6,154+side*11.5,1,1.5,26,"wood2",rot=rx(math.radians(25 if side<0 else -25)))
 m.box("BarracksRidge",0,19,154,98,1.4,1.4,"wood")
 # Covered training gallery and drill equipment.
 for x in (-58,58):
  for z in (130,160): m.box("TrainingCanopyPost",x,5,z,.8,8,.8,"wood")
 m.box("CoveredTrainingRoof",0,9.3,145,120,1,33,"roof",collide=False)
 for i in range(5):
  x=-42+i*21
  m.box("TrainingDummyPost",x,3,118,.6,4,.6,"wood")
  m.box("TrainingDummyTorso",x,4.2,118,2.2,2.4,.8,"plank")
  m.box("TrainingDummyArms",x,4.5,118,4.6,.55,.6,"wood2")
  m.cyl("TrainingDummyHead",x,6,118,1.1,1.5,1.5,"hay",collide=False)
 for i in range(4):
  x=-36+i*24
  m.box("WeaponRack",x,3,166,8,4,1,"wood")
  for j in range(3): m.box("TrainingSpear",x-3+j*3,5,166,.18,4,.18,"wood2",collide=False)
 # Equipment store and guard posts.
 for x in (-54,54): m.box("BarracksWatchPost",x,7,185,8,12,8,"wood2")
 if level>=2:
  m.box("BarracksQuartermaster",52,4,145,18,6,16,"stone")
  m.box("ArmoryDoor",42,4,145,1,6,6,"wood")
 if level>=3:
  for x in (-28,28):
   m.box("BannerPole",x,13,176,.35,16,.35,"wood")
   m.box("BarracksBanner",x,13,176,4,6,.25,"red" if x<0 else "blue",collide=False,material="Fabric")
 # Active resource source aligns to the dedicated north supply track at z=207.
 x=(-117,-108,-99,-90)[level-1]; m.box("DropPoint",x,8.4,207,2,.2,2,"gold",collide=False,trans=1,material="SmoothPlastic")
 return m.model()

def perimeter(level, towers=False):
 m=Model()
 if not towers:
  h={1:7,2:10,3:14,4:18}[level]; z=232; gap=22
  m.box("WallRear",0,h/2,-232,464,h,4,"stone2" if level>=3 else "wood2")
  m.box("WallWest",-232,h/2,0,4,h,464,"stone2" if level>=3 else "wood2")
  m.box("WallEast",232,h/2,0,4,h,464,"stone2" if level>=3 else "wood2")
  m.box("WallFrontWest",(-232-gap)/2,h/2,z,232-gap,h,4,"stone2" if level>=3 else "wood2")
  m.box("WallFrontEast",(232+gap)/2,h/2,z,232-gap,h,4,"stone2" if level>=3 else "wood2")
  # Gatehouse piers and an operable-height, nonblocking wooden portcullis silhouette.
  for x in (-gap,gap):
   m.box("GatehousePier",x,h,212,7,h*2,8,"stone2")
   m.box("GatehouseMerlon",x,h*2+2,212,8,4,9,"stone")
  m.box("GateArchHeader",0,h*2+2,212,gap*2+10,4,9,"stone")
  for x in range(-18,19,6): m.box("GatePortcullisBar",x,h,212,.45,h*2,.45,"wood2",collide=False)
  for z in (-232,232):
   for x in range(-220,221,20): m.box("WallMerlon",x,h+1,z,4,2,5,"stone",collide=False)
  for x in (-232,232):
   for z in range(-220,221,20): m.box("WallMerlon",x,h+1,z,5,2,4,"stone",collide=False)
 else:
  height={1:18,2:24,3:31,4:39}[level]
  for x in (-222,222):
   for z in (-222,222):
    m.box("CornerTowerBase",x,4,z,17,8,17,"stone")
    m.box("CornerTowerShaft",x,height/2+4,z,13,height,13,"stone2")
    m.box("CornerTowerBattlement",x,height+8,z,18,3,18,"stone")
    m.box("CornerTowerRoof",x,height+11,z,15,4,15,"roof")
    for dx in (-5,5): m.box("CornerTowerSlit",x+dx,height/2+4,z+6.6,.7,5,.35,"coal",collide=False)
 return m.model()

for level in range(1,5):
 for name,builder in (("Quarry",quarry),("Blacksmith",forge),("Farm",farm),("Barracks",barracks)):
  data=builder(level); path=OUT/f"{name}{ROMAN[level]}.model.json"; path.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
 for group in ("Walls","Tower"):
  data=perimeter(level,towers=(group=="Tower")); path=OUT/f"{group}{ROMAN[level]}.model.json"; path.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
 # The existing large castle is retained as a dedicated back-center royal district.
 path=OUT/f"Castle{ROMAN[level]}.model.json"; data=json.loads(path.read_text(encoding="utf-8"))
 z_values=[]
 for part in data.get("children",[]):
  prop=part.get("properties",{}); cf=prop.get("CFrame",{}).get("CFrame",{}); pos=cf.get("position")
  if pos:
   half=prop.get("Size",[0,0,0])[2]/2
   z_values.extend((pos[2]-half,pos[2]+half))
 shift=-119-(min(z_values)+max(z_values))/2 if z_values else 0
 for part in data.get("children",[]):
  cf=part.get("properties",{}).get("CFrame",{}).get("CFrame",{})
  if cf.get("position"): cf["position"][2]=round(cf["position"][2]+shift,4)
 path.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
 print(f"wrote Level {ROMAN[level]} district and perimeter assets")
