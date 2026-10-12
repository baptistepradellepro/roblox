"""Vue de dessus approximative d'une base (rez-de-chaussée). Usage : preview_base.py base.json sortie.png"""
import json, sys
from PIL import Image, ImageDraw, ImageFont

parts = json.load(open(sys.argv[1]))
S, W, H = 16, 44, 48  # pixels par stud, zone en studs
img = Image.new("RGB", (W * S, H * S), (30, 22, 40))
draw = ImageDraw.Draw(img, "RGBA")
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)

def to_px(x, z):
    # avant de la base (-Z, côté chemin) en bas de l'image
    return ((x + W / 2) * S, (H / 2 - z) * S)

def corners(p):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p["cf"]
    sx, sy, sz = p["size"]
    pts = []
    for dx in (-sx / 2, sx / 2):
        for dy in (-sy / 2, sy / 2):
            for dz in (-sz / 2, sz / 2):
                wx = x + r00 * dx + r01 * dy + r02 * dz
                wz = z + r20 * dx + r21 * dy + r22 * dz
                pts.append(to_px(wx, wz))
    xs, zs = [q[0] for q in pts], [q[1] for q in pts]
    return min(xs), min(zs), max(xs), max(zs)

order = sorted(parts, key=lambda p: p["cf"][1])  # du bas vers le haut
for p in order:
    if p["cf"][1] > 13:  # on ne montre que le rez-de-chaussée
        continue
    r, g, b = [int(c * 255) for c in p["color"]]
    a = int(255 * (1 - p["transparency"]))
    box = corners(p)
    if p["shape"] in ("Ball", "Cylinder") and abs(box[2] - box[0] - (box[3] - box[1])) < 4:
        draw.ellipse(box, fill=(r, g, b, a), outline=(0, 0, 0, 120))
    else:
        draw.rectangle(box, fill=(r, g, b, a), outline=(0, 0, 0, 120))
for p in parts:
    if p["name"] in ("LockButton", "UpPad", "Mat", "Spawn") or p["name"].startswith("P") and p["name"][1:].isdigit() and int(p["name"][1:]) <= 10:
        box = corners(p)
        draw.text((box[0], box[1] - 16), p["name"], fill=(255, 255, 255), font=font)
draw.text((10, H * S - 24), "avant (chemin)", fill=(255, 220, 120), font=font)
draw.text((10, 6), "fond", fill=(255, 220, 120), font=font)
img.save(sys.argv[2])
print("OK")
