"""Aperçu approximatif des fantômes (vue de face 3/4), à partir de tools/export_ghosts.luau.
Usage : python3 tools/preview_ghosts.py ghosts.json sortie.png
"""
import json, math, sys
from PIL import Image, ImageDraw, ImageFont

RARITY_COLORS = {"Common": (190,196,210), "Rare": (70,160,255), "Epic": (175,90,255),
                 "Legendary": (255,190,40), "Mythic": (255,60,130), "Halloween": (255,125,20)}

def local_points(shape, sx, sy, sz):
    pts = []
    if shape == "Ball":
        r = min(sx, sy, sz) / 2
        for i in range(12):
            for j in range(1, 8):
                th, ph = 2*math.pi*i/12, math.pi*j/8
                pts.append((r*math.sin(ph)*math.cos(th), r*math.cos(ph), r*math.sin(ph)*math.sin(th)))
        pts += [(0, r, 0), (0, -r, 0)]
    elif shape == "Cylinder":
        r = min(sy, sz) / 2
        for x in (-sx/2, sx/2):
            for i in range(16):
                th = 2*math.pi*i/16
                pts.append((x, r*math.cos(th), r*math.sin(th)))
    elif shape == "Wedge":
        for x in (-sx/2, sx/2):
            pts += [(x, -sy/2, -sz/2), (x, -sy/2, sz/2), (x, sy/2, sz/2)]
    else:
        for x in (-sx/2, sx/2):
            for y in (-sy/2, sy/2):
                for z in (-sz/2, sz/2):
                    pts.append((x, y, z))
    return pts

def to_world(cf, p):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf
    lx, ly, lz = p
    return (x + r00*lx + r01*ly + r02*lz, y + r10*lx + r11*ly + r12*lz, z + r20*lx + r21*ly + r22*lz)

def view(p, yaw=math.radians(25), pitch=math.radians(12)):
    x, y, z = p
    x, z = x*math.cos(yaw) + z*math.sin(yaw), -x*math.sin(yaw) + z*math.cos(yaw)
    y, z = y*math.cos(pitch) - z*math.sin(pitch), y*math.sin(pitch) + z*math.cos(pitch)
    return (-x, y, z)  # vue depuis l'avant (-Z)

def hull(points):
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts
    def cross(o, a, b):
        return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]

def render(ghost, size=260):
    polys = []
    for part in ghost["parts"]:
        pts = [view(to_world(part["cf"], p)) for p in local_points(part["shape"], *part["size"])]
        depth = sum(p[2] for p in pts) / len(pts)  # tri approximatif (peintre)
        polys.append((depth, pts, part))
    allpts = [p for _, pts, _ in polys for p in pts]
    minx, maxx = min(p[0] for p in allpts), max(p[0] for p in allpts)
    miny, maxy = min(p[1] for p in allpts), max(p[1] for p in allpts)
    scale = (size - 50) / max(maxx - minx, maxy - miny, 1)
    cx, cy = (minx + maxx) / 2, (miny + maxy) / 2
    img = Image.new("RGB", (size, size), (34, 24, 52))
    draw = ImageDraw.Draw(img, "RGBA")
    for depth, pts, part in sorted(polys, key=lambda t: -t[0]):
        poly = hull([(round(size/2 + (p[0]-cx)*scale, 1), round(size/2 - 12 - (p[1]-cy)*scale, 1)) for p in pts])
        r, g, b = [int(c*255) for c in part["color"]]
        alpha = int(255 * (1 - part["transparency"]))
        if len(poly) >= 3:
            draw.polygon(poly, fill=(r, g, b, alpha), outline=(0, 0, 0, min(alpha, 90)))
    rc = RARITY_COLORS.get(ghost["rarity"], (255, 255, 255))
    draw.rectangle([0, size-26, size, size], fill=(20, 12, 30))
    draw.text((8, size-22), ghost["name"], fill=rc, font=FONT)
    return img

def load_font():
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(path, 16)
        except OSError:
            pass
    return ImageFont.load_default()

FONT = load_font()

if __name__ == "__main__":
    ghosts = json.load(open(sys.argv[1]))
    cols, cell = 8, 260
    rows = math.ceil(len(ghosts) / cols)
    sheet = Image.new("RGB", (cols*cell, rows*cell), (20, 12, 30))
    for i, g in enumerate(ghosts):
        sheet.paste(render(g, cell), ((i % cols)*cell, (i // cols)*cell))
    sheet.save(sys.argv[2])
    print("OK", sys.argv[2])
