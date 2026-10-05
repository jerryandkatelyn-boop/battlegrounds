#!/usr/bin/env python3
"""Build the original Tiny Town model. Python standard library only.

The checked-in .rbxmx is Rojo-managed and visible before Play. All geometry is
made of Roblox primitives; there are no external meshes, textures or asset IDs.
"""
from pathlib import Path
import math
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
GEOMETRY = []
REF = 0

WHITE = (237, 241, 236)
DARK = (42, 54, 63)
STONE = (207, 217, 207)
ROAD = (85, 104, 107)
GRASS = (137, 182, 145)
WOOD = (176, 137, 103)
GLASS = (146, 201, 211)
BLUE = (86, 172, 255)
CORAL = (255, 145, 111)
PURPLE = (177, 149, 255)
MINT = (103, 219, 176)


def node(parent, kind, name):
    global REF
    REF += 1
    item = ET.SubElement(parent, "Item", {"class": kind, "referent": f"RBX{REF}"})
    props = ET.SubElement(item, "Properties")
    prop(props, "string", "Name", name)
    return item


def prop(props, kind, name, value):
    element = ET.SubElement(props, kind, {"name": name})
    if kind in ("Vector3", "Vector2"):
        for axis, component in zip(("X", "Y", "Z"), value):
            ET.SubElement(element, axis).text = f"{component:.6f}"
    elif kind == "Color3":
        for axis, component in zip(("R", "G", "B"), value):
            ET.SubElement(element, axis).text = f"{component / 255:.6f}"
    elif kind == "CoordinateFrame":
        position, yaw = value
        c, s = math.cos(yaw), math.sin(yaw)
        numbers = (*position, c, 0, s, 0, 1, 0, -s, 0, c)
        names = ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")
        for key, component in zip(names, numbers):
            ET.SubElement(element, key).text = f"{component:.6f}"
    elif kind == "UDim2":
        for key, component in zip(("XS", "XO", "YS", "YO"), value):
            ET.SubElement(element, key).text = str(component)
    elif kind == "bool":
        element.text = "true" if value else "false"
    else:
        element.text = str(value)


def part(parent, name, size, position, color, yaw=0, material=272,
         transparency=0, collide=True, kind="Part", shape=1):
    item = node(parent, kind, name)
    props = item.find("Properties")
    for tag, key, value in [
        ("bool", "Anchored", True), ("bool", "CanCollide", collide),
        ("bool", "CanTouch", False), ("bool", "CastShadow", transparency < 0.5),
        ("bool", "CanQuery", transparency < 1), ("Vector3", "size", size),
        ("CoordinateFrame", "CFrame", (position, math.radians(yaw))),
        ("Color3", "Color", color), ("token", "Material", material),
        ("float", "Transparency", transparency), ("token", "TopSurface", 0),
        ("token", "BottomSurface", 0),
    ]:
        prop(props, tag, key, value)
    if kind == "Part":
        prop(props, "token", "shape", shape)
    GEOMETRY.append({"name": name, "size": size, "pos": position, "color": color,
                     "yaw": yaw, "transparent": transparency, "kind": kind, "shape": shape})
    return item


def builder(parent, origin, angle):
    def build(name, size, pos, color, yaw=0, **options):
        a = math.radians(angle)
        x, y, z = pos
        ox, oy, oz = origin
        world = (ox + x * math.cos(a) + z * math.sin(a), oy + y,
                 oz - x * math.sin(a) + z * math.cos(a))
        return part(parent, name, size, world, color, angle + yaw, **options)
    return build


def tree(parent, x, z, scale=1, color=(74, 133, 111), angle=0):
    model = node(parent, "Model", "FacetedTree")
    b = builder(model, (x, 0, z), angle)
    b("Trunk", (1.3 * scale, 7 * scale, 1.3 * scale), (0, 3.5 * scale, 0), WOOD)
    # A pair of wedges forms an angular A-frame canopy with a crisp ridge.
    for y, w, h in [(7.5, 8, 5), (10.5, 6, 4), (13, 3.8, 3)]:
        for sign in [-1, 1]:
            shade = tuple(min(255, c + (10 if sign == 1 else 0)) for c in color)
            b("FoliageFacet", (w * scale, h * scale, w * scale / 2),
              (0, y * scale, sign * w * scale / 4), shade,
              yaw=0 if sign == -1 else 180, kind="WedgePart", collide=False)


def planter(b, x, z, width=6):
    b("Planter", (width, 1.2, 3), (x, 0.9, z), STONE)
    b("Hedge", (width - 0.6, 2.4, 2.4), (x, 2.2, z), (87, 148, 112), collide=False)


def lamp(parent, x, z):
    model = node(parent, "Model", "StreetLamp")
    part(model, "Foot", (2.2, 0.4, 2.2), (x, 0.6, z), STONE)
    part(model, "Post", (0.6, 10, 0.6), (x, 5.8, z), DARK)
    part(model, "Lamp", (3, 0.4, 3), (x, 11, z), (255, 239, 192), material=288)
    part(model, "Cap", (3.4, 0.3, 3.4), (x, 11.4, z), DARK)


def bench(parent, x, z, angle):
    model = node(parent, "Model", "Bench")
    b = builder(model, (x, 0, z), angle)
    for sign in [-1, 1]:
        b("Leg", (0.6, 2, 2), (sign * 3.5, 1.3, 0), DARK)
    for zz in [-0.75, 0, 0.75]:
        b("SeatSlat", (9, 0.3, 0.55), (0, 2.4, zz), WOOD)
    for yy in [3.3, 4]:
        b("BackSlat", (9, 0.55, 0.3), (0, yy, 1.1), WOOD)


def bake_sign(board, title, subtitle, accent):
    gui = node(board, "SurfaceGui", "TownSign")
    props = gui.find("Properties")
    prop(props, "token", "Face", 5)
    prop(props, "Vector2", "CanvasSize", (1000, 210))
    prop(props, "float", "LightInfluence", 0)
    for name, text, y, height, color, font in [
        ("Heading", title, 0.08, 0.57, WHITE, 19),
        ("Detail", subtitle, 0.70, 0.22, accent, 18),
    ]:
        label = node(gui, "TextLabel", name)
        props = label.find("Properties")
        prop(props, "string", "Text", text)
        prop(props, "float", "BackgroundTransparency", 1)
        prop(props, "bool", "TextScaled", True)
        prop(props, "token", "Font", font)
        prop(props, "Color3", "TextColor3", color)
        prop(props, "UDim2", "Position", (0.04, 0, y, 0))
        prop(props, "UDim2", "Size", (0.92, 0, height, 0))


def building(parent, name, origin, angle, accent, style):
    model = node(parent, "Model", name)
    b = builder(model, origin, angle)
    w, d = 30, 26
    h = 18 if style != "rooftops" else 23
    b("Foundation", (w + 4, 0.6, d + 4), (0, 0.3, 0), STONE)
    b("Floor", (w, 0.3, d), (0, 0.75, 0), WHITE)
    # Split facade: every entrance stays open and the queue area is walkable.
    b("BackWall", (w, h, 0.8), (0, h / 2 + 0.9, d / 2), WHITE)
    for sign in [-1, 1]:
        b("SideWall", (0.8, h, d), (sign * w / 2, h / 2 + 0.9, 0), WHITE)
        b("FacadeColumn", (2.2, h, 1.2), (sign * 13.9, h / 2 + 0.9, -13), DARK)
        b("WindowBase", (8.5, 2.5, 0.6), (sign * 9.7, 2.2, -13), WHITE)
        b("FrontGlass", (8.5, 8.5, 0.25), (sign * 9.7, 7.6, -13.15), GLASS,
          transparency=0.45, material=1568)
        b("WindowMullion", (0.3, 8.6, 0.5), (sign * 9.7, 7.6, -13.3), DARK)
        b("EntryLight", (0.25, 9, 0.5), (sign * 5.2, 5.7, -13.3), accent, material=288, collide=False)
    b("FacadeHeader", (w, h - 10, 0.8), (0, 10.9 + (h - 10) / 2, -13), WHITE)
    b("RoofSlab", (w + 2, 1, d + 2), (0, h + 1.4, 0), DARK)
    board = b("SignBoard", (24, 3.8, 0.4), (0, 14.6, -13.65), DARK)
    titles = {"arena": "01  ARENA", "dojo": "02  DOJO", "rooftops": "03  ROOFTOPS", "training": "04  TRAINING LAB"}
    bake_sign(board, titles[style], "WALK IN TO JOIN YOUR NEXT ADVENTURE", accent)
    b("SignAccent", (24, 0.22, 0.46), (0, 12.6, -13.7), accent, material=288)
    b("Canopy", (14, 0.6, 6), (0, 10.6, -15), accent)
    b("WelcomeMat", (9.5, 0.08, 7), (0, 0.98, -11), accent, collide=False)
    b("QueuePad", (8.8, 0.12, 7), (0, 1, -5.6), DARK)
    for sign in [-1, 1]:
        b("QueuePadEdge", (0.2, 0.14, 7), (sign * 4.35, 1.12, -5.6), accent, material=288, collide=False)
    b("QueueAnchor", (0.4, 0.4, 0.4), (0, 3, -10), accent, transparency=1, collide=False)
    b("QueueZone", (8, 8, 6), (0, 5.1, -5.5), accent, transparency=1, collide=False)
    display = b("QueueDisplay", (10, 3.6, 0.35), (0, 6.6, 8.5), DARK)
    bake_sign(display, "WALK IN TO QUEUE", "PLAY TO PREVIEW DEPARTURES", accent)
    b("Desk", (11, 3, 3), (0, 2.4, 10), accent)
    # Interior strips and angular ceiling beams add depth without imported assets.
    for xx in [-10, 10]:
        b("CeilingLight", (0.35, 0.15, 18), (xx, h + 0.7, 0), (255, 244, 211), material=288, collide=False)
    for xx in [-11, 11]:
        b("InteriorSeat", (3, 1.4, 6), (xx, 1.6, 4), WOOD)
    for xx in [-10, 10]:
        planter(b, xx, -18, 6)

    if style == "arena":
        b("Clerestory", (22, 3, 13), (0, h + 3.4, 2), GLASS, transparency=0.28, material=1568)
        b("FloatingRoof", (25, 0.8, 15), (0, h + 5.2, 2), WHITE)
        for xx in [-10, -5, 0, 5, 10]:
            b("RoofRib", (0.35, 3.2, 13.2), (xx, h + 3.4, 2), DARK)
    elif style == "dojo":
        for sign in [-1, 1]:
            b("GabledRoof", (36, 5, 15), (0, h + 4.2, sign * 7.5), (85, 101, 102),
              yaw=0 if sign == -1 else 180, kind="WedgePart")
        b("RoofRidge", (37, 0.4, 0.6), (0, h + 6.8, 0), WOOD)
        for xx in [-13, -11.5, 11.5, 13]:
            b("TimberSlat", (0.5, 10, 0.7), (xx, 6.2, -13.8), WOOD)
    elif style == "rooftops":
        b("UpperBand", (30, 2.2, 0.9), (0, 21.3, -13.4), accent)
        for xx in [-10, 0, 10]:
            b("UpperWindow", (7, 4, 0.25), (xx, 18.2, -13.5), GLASS, transparency=0.25, material=1568)
        b("Penthouse", (18, 7, 15), (2, h + 5.4, 3), WHITE)
        b("PenthouseGlass", (12, 4.5, 0.3), (2, h + 5.5, -4.6), GLASS, transparency=0.3, material=1568)
        b("TerraceRoof", (20, 0.5, 17), (2, h + 9.1, 3), accent)
        for xx in [-13, 13]:
            b("TerraceRail", (0.4, 2.8, 26), (xx, h + 3, 0), DARK)
        b("TerraceFrontRail", (26, 2.8, 0.4), (0, h + 3, -12.5), DARK)
        for xx in [-10, 10]:
            b("RoofPlanter", (4, 1, 4), (xx, h + 2.4, 9), WOOD)
            b("RoofShrub", (3.2, 2.4, 3.2), (xx, h + 4, 9), MINT, yaw=45, collide=False)
    else:
        b("TechRoof", (24, 2, 20), (0, h + 3, 0), WHITE)
        for xx in [-6.5, 6.5]:
            b("SolarPanel", (10, 0.35, 14), (xx, h + 4.2, 0), (43, 82, 117))
            for zz in [-5, 0, 5]:
                b("SolarCellGrid", (10, 0.08, 0.15), (xx, h + 4.45, zz), (110, 174, 192), collide=False)
        b("AntennaBase", (2, 1, 2), (11, h + 4.1, 8), DARK)
        b("Antenna", (0.3, 5, 0.3), (11, h + 6.5, 8), WHITE)
        b("AntennaTip", (0.8, 0.8, 0.8), (11, h + 9, 8), accent, material=288)
    return model


def build():
    global REF
    REF = 0
    GEOMETRY.clear()
    xml = ET.Element("roblox", {"version": "4"})
    ET.SubElement(xml, "External").text = "null"
    ET.SubElement(xml, "External").text = "nil"
    town = node(xml, "Model", "TinyTown")
    landscape = node(town, "Model", "Landscape")
    part(landscape, "TownIsland", (196, 7, 184), (0, -3.5, 0), GRASS)
    part(landscape, "IslandFoundation", (186, 8, 174), (0, -11, 0), (99, 137, 120))
    # Broad boulevard and pedestrian paths with visible curb borders.
    part(landscape, "BoulevardCurb", (182, 0.6, 22), (0, 0.3, 7), STONE)
    part(landscape, "Boulevard", (182, 0.18, 16), (0, 0.69, 7), ROAD)
    part(landscape, "NorthWalkBorder", (22, 0.6, 164), (0, 0.3, 0), STONE)
    part(landscape, "NorthWalk", (16, 0.2, 164), (0, 0.75, 0), (219, 226, 216))
    for x in [-44, 44]:
        part(landscape, "BuildingPath", (14, 0.6, 36), (x, 0.3, -18), STONE)
    for x in [-41, 41]:
        part(landscape, "Sidewalk", (39, 0.6, 12), (x, 0.3, 35), STONE)
    for x in range(-84, 85, 14):
        if abs(x) < 23:
            continue
        part(landscape, "RoadDash", (6, 0.03, 0.22), (x, 0.81, 7), (227, 231, 211), collide=False)
    for x in [-20, 20]:
        for z in [-1, 3, 7, 11, 15]:
            part(landscape, "Crossing", (3, 0.04, 2), (x, 0.82, z), WHITE, collide=False)
    plaza = node(town, "Model", "Plaza")
    part(plaza, "PlazaFloor", (34, 0.8, 30), (0, 0.4, 7), WHITE)
    for z in [-7, 21]:
        part(plaza, "PlazaEdge", (34, 0.1, 0.35), (0, 0.87, z), DARK, collide=False)
    part(plaza, "SculpturePedestal", (7, 1.2, 7), (0, 1.4, 5), STONE, yaw=45)
    part(plaza, "SculptureBase", (4, 6, 4), (0, 5, 5), DARK, yaw=45)
    part(plaza, "SculptureCrown", (6, 1.2, 6), (0, 8.6, 5), MINT, yaw=45, material=288)
    part(plaza, "SculptureTop", (3.3, 2, 3.3), (0, 10.2, 5), WHITE, yaw=45)
    spawn = part(plaza, "TownSpawn", (7, 0.3, 7), (0, 1.1, 30), WHITE,
                 transparency=1, collide=False, kind="SpawnLocation")
    props = spawn.find("Properties")
    prop(props, "bool", "Neutral", True)
    prop(props, "float", "Duration", 0)
    for x in [-11, 11]:
        bench(plaza, x, 12, 90 if x < 0 else -90)
    building(town, "Arena", (-44, 0, -49), 180, BLUE, "arena")
    building(town, "Dojo", (44, 0, -49), 180, CORAL, "dojo")
    building(town, "Rooftops", (-70, 0, 35), -90, PURPLE, "rooftops")
    building(town, "TrainingLab", (70, 0, 35), 90, MINT, "training")
    vegetation = node(town, "Model", "TreesAndGardens")
    for i, (x, z) in enumerate([
        (-85, -72), (-69, -75), (-15, -70), (15, -70), (69, -75), (85, -72),
        (-88, -22), (88, -22), (-28, -29), (28, -29), (-43, 59), (43, 59),
        (-87, 74), (-65, 76), (-35, 76), (-15, 67), (15, 67), (35, 76), (65, 76), (87, 74),
    ]):
        tree(vegetation, x, z, 0.8 + (i % 3) * 0.12, angle=(i * 37) % 180)
    for x in [-26, 26]:
        for z in [-12, 26]:
            lamp(landscape, x, z)
    for x in [-77, 77]:
        lamp(landscape, x, 2)
    for x in [-20, 20]:
        bench(landscape, x, 51, 0)
    # Transparent boundary walls keep the lobby walkable without fatal island falls.
    for x in [-97, 97]:
        part(landscape, "InvisibleBoundary", (1, 45, 184), (x, 20, 0), WHITE, transparency=1)
    for z in [-91, 91]:
        part(landscape, "InvisibleBoundary", (196, 45, 1), (0, 20, z), WHITE, transparency=1)
    ET.indent(xml, space="  ")
    output = ROOT / "src/Workspace/TinyTown.rbxmx"
    output.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(xml).write(output, encoding="utf-8", xml_declaration=True)
    print(f"Built {output.relative_to(ROOT)} ({len(GEOMETRY)} anchored parts)")
    return GEOMETRY


if __name__ == "__main__":
    build()
