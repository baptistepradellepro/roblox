"""Images de publication (icône, miniatures, Game Pass, produits, badges) faites avec
les vrais modèles du jeu. Petit moteur de lancer de rayons (numpy) avec ombres,
contours cartoon et halo des pièces néon.

Usage :
    lune run tools/export_scene.luau scene.json
    python3 tools/render_publication.py scene.json docs/publication
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

EPS = 1e-3
F32 = np.float32

# ------------------------------------------------------------------ repères (CFrame)

def cf_list(c):
    x, y, z, *r = c
    return (np.array([x, y, z], dtype=float), np.array(r, dtype=float).reshape(3, 3))

def cf_new(x=0.0, y=0.0, z=0.0):
    return (np.array([x, y, z], dtype=float), np.eye(3))

def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])

def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])

def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])

def cf_angles(rx=0.0, ry=0.0, rz=0.0):
    return (np.zeros(3), rot_x(rx) @ rot_y(ry) @ rot_z(rz))

def mul(a, b):
    return (a[0] + a[1] @ b[0], a[1] @ b[1])

def chain(*cfs):
    out = cf_new()
    for c in cfs:
        out = mul(out, c)
    return out

def normalize(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)

# ------------------------------------------------------------------ scène

class Prim:
    __slots__ = ("shape", "pos", "R", "size", "color", "alpha", "neon", "group", "radius", "shadow")

    def __init__(self, shape, cf, size, color, alpha=1.0, neon=False, group=0, shadow=True):
        self.shape = shape
        self.pos, self.R = cf
        self.size = np.array(size, dtype=float)
        self.color = np.array(color, dtype=float)
        self.alpha = alpha
        self.neon = neon
        self.group = group
        self.shadow = shadow
        self.radius = float(np.linalg.norm(self.size)) / 2


class Scene:
    def __init__(self):
        self.prims = []
        self.next_group = 1
        self.highlights = {}  # groupe -> (couleur de remplissage, opacité, couleur du contour)

    def group(self):
        g = self.next_group
        self.next_group += 1
        return g

    def add_parts(self, parts, place=None, group=None, tint=None, skip=(), shadow=True):
        """Ajoute les pièces exportées par export_scene.luau, déplacées par "place"."""
        g = group if group is not None else self.group()
        for p in parts:
            if p.get("name") in skip:
                continue
            cf = cf_list(p["cf"])
            if place is not None:
                cf = mul(place, cf)
            color = p["color"]
            if tint is not None:
                color = [c * (1 - tint[3]) + t * tint[3] for c, t in zip(color, tint[:3])]
            self.prims.append(Prim(p["shape"], cf, p["size"], color, 1 - p["transparency"], p.get("neon", False), g, shadow))
        return g

    def box(self, cf, size, color, **kw):
        self.prims.append(Prim("Block", cf, size, color, **kw))

    def ball(self, cf, d, color, **kw):
        self.prims.append(Prim("Ball", cf, (d, d, d), color, **kw))

    def cyl(self, cf, size, color, **kw):
        self.prims.append(Prim("Cylinder", cf, size, color, **kw))

# ------------------------------------------------------------------ caméras

class Camera:
    def __init__(self, pos, target, w, h, fov=40.0, ortho=None, up=(0, 1, 0)):
        self.pos = np.array(pos, dtype=float)
        self.forward = normalize(np.array(target, dtype=float) - self.pos)
        self.right = normalize(np.cross(self.forward, up))
        self.up = np.cross(self.right, self.forward)
        self.w, self.h = w, h
        self.fov = fov
        self.ortho = ortho  # largeur visible en studs (caméra orthographique)
        if ortho:
            self.scale = ortho / w
        else:
            self.f = (h / 2) / math.tan(math.radians(fov) / 2)

    def scaled(self, k):
        return Camera(self.pos, self.pos + self.forward, self.w * k, self.h * k, self.fov, self.ortho, self.up)

    def rays(self, x0, x1, y0, y1):
        px = np.arange(x0, x1, dtype=float) + 0.5 - self.w / 2
        py = self.h / 2 - (np.arange(y0, y1, dtype=float) + 0.5)
        u, v = np.meshgrid(px, py)
        u, v = u.ravel(), v.ravel()
        if self.ortho:
            origins = self.pos + np.outer(u * self.scale, self.right) + np.outer(v * self.scale, self.up)
            dirs = np.broadcast_to(self.forward, origins.shape)
        else:
            dirs = self.forward * self.f + np.outer(u, self.right) + np.outer(v, self.up)
            dirs = dirs / np.linalg.norm(dirs, axis=1, keepdims=True)
            origins = np.broadcast_to(self.pos, dirs.shape)
        return origins, dirs

    def bounds(self, center, radius):
        """Rectangle de pixels qui peut contenir la sphère (ou None)."""
        rel = center - self.pos
        z = rel @ self.forward
        x = rel @ self.right
        y = rel @ self.up
        if self.ortho:
            cx, cy, r = x / self.scale + self.w / 2, self.h / 2 - y / self.scale, radius / self.scale + 1
            lx, hx, ly, hy = cx - r, cx + r, cy - r, cy + r
        else:
            if z < -radius:
                return None

            def extent(a):
                dist = math.hypot(a, z)
                if dist <= radius * 1.001:
                    return -1e9, 1e9
                ang, da = math.atan2(a, z), math.asin(radius / dist)
                lo, hi = ang - da, ang + da
                plo = -1e9 if lo <= -math.pi / 2 + 1e-3 else math.tan(lo) * self.f
                phi = 1e9 if hi >= math.pi / 2 - 1e-3 else math.tan(hi) * self.f
                return plo, phi

            ex0, ex1 = extent(x)
            ey0, ey1 = extent(y)
            lx, hx = ex0 + self.w / 2 - 1, ex1 + self.w / 2 + 1
            ly, hy = self.h / 2 - ey1 - 1, self.h / 2 - ey0 + 1
        x0, x1 = int(max(0, math.floor(lx))), int(min(self.w, math.ceil(hx)))
        y0, y1 = int(max(0, math.floor(ly))), int(min(self.h, math.ceil(hy)))
        if x0 >= x1 or y0 >= y1:
            return None
        return (x0, x1, y0, y1)

# ------------------------------------------------------------------ intersections (repère de la pièce)

def hit_convex(o, d, planes):
    n_rays = len(o)
    tin = np.full(n_rays, -np.inf)
    tout = np.full(n_rays, np.inf)
    nin = np.zeros((n_rays, 3))
    for n, c in planes:
        den = d @ n
        num = c - o @ n
        with np.errstate(divide="ignore", invalid="ignore"):
            t = num / den
        entering = den < -1e-12
        upd = entering & (t > tin)
        tin = np.where(upd, t, tin)
        nin[upd] = n
        exiting = den > 1e-12
        tout = np.where(exiting & (t < tout), t, tout)
        parallel_out = (np.abs(den) <= 1e-12) & (num < 0)
        tout = np.where(parallel_out, -np.inf, tout)
    hit = (tin <= tout) & (tin > EPS)
    return np.where(hit, tin, np.inf), nin


def box_planes(size):
    hx, hy, hz = size / 2
    return [
        (np.array([1.0, 0, 0]), hx), (np.array([-1.0, 0, 0]), hx),
        (np.array([0, 1.0, 0]), hy), (np.array([0, -1.0, 0]), hy),
        (np.array([0, 0, 1.0]), hz), (np.array([0, 0, -1.0]), hz),
    ]


def hit_part(prim, o, d):
    size = prim.size
    if prim.shape == "Ball":
        r = size.min() / 2
        b = np.einsum("ij,ij->i", o, d)
        c = np.einsum("ij,ij->i", o, o) - r * r
        disc = b * b - c
        ok = disc >= 0
        sq = np.sqrt(np.where(ok, disc, 0))
        t = -b - sq
        t = np.where(ok & (t > EPS), t, np.inf)
        p = o + d * np.where(np.isfinite(t), t, 0)[:, None]
        return t, p / r
    if prim.shape == "Cylinder":
        r = min(size[1], size[2]) / 2
        hx = size[0] / 2
        a = d[:, 1] ** 2 + d[:, 2] ** 2
        b = o[:, 1] * d[:, 1] + o[:, 2] * d[:, 2]
        c = o[:, 1] ** 2 + o[:, 2] ** 2 - r * r
        disc = b * b - a * c
        ok = (disc >= 0) & (a > 1e-12)
        with np.errstate(divide="ignore", invalid="ignore"):
            ts = (-b - np.sqrt(np.where(ok, disc, 0))) / a
        xs = o[:, 0] + ts * d[:, 0]
        side = ok & (ts > EPS) & (np.abs(xs) <= hx)
        t = np.where(side, ts, np.inf)
        normal = np.zeros_like(o)
        ps = o + d * np.where(side, ts, 0)[:, None]
        normal[:, 1] = ps[:, 1] / r
        normal[:, 2] = ps[:, 2] / r
        for sgn in (-1.0, 1.0):
            with np.errstate(divide="ignore", invalid="ignore"):
                tc = (sgn * hx - o[:, 0]) / d[:, 0]
            yc = o[:, 1] + tc * d[:, 1]
            zc = o[:, 2] + tc * d[:, 2]
            cap = (tc > EPS) & (yc * yc + zc * zc <= r * r) & (tc < t)
            t = np.where(cap, tc, t)
            normal[cap] = [sgn, 0, 0]
        return t, normal
    planes = box_planes(size)
    if prim.shape == "Wedge":
        n = normalize([0, size[2], -size[1]])
        planes.append((n, 0.0))
    return hit_convex(o, d, planes)

# ------------------------------------------------------------------ rendu

class Look:
    """Réglages de lumière d'une image."""

    def __init__(self, light=(-0.45, 0.8, -0.55), ambient=0.42, key=0.75, fill=0.18, rim=0.35,
                 rim_color=(0.75, 0.6, 1.0), shadows=True, outline=(0.08, 0.04, 0.14), outline_px=2.0,
                 glow=0.9, fog=None, fog_color=(0.55, 0.42, 0.7), fog_start=60.0, sky=None):
        self.light = normalize(light)
        self.ambient, self.key, self.fill, self.rim = ambient, key, fill, rim
        self.rim_color = np.array(rim_color)
        self.shadows = shadows
        self.outline = outline
        self.outline_px = outline_px
        self.glow = glow
        self.fog = fog
        self.fog_color = np.array(fog_color)
        self.fog_start = fog_start
        self.sky = sky


def trace(prims, cam, want_normals=True):
    """Premier impact de chaque rayon : distance, normale, numéro de pièce."""
    W, H = cam.w, cam.h
    zbuf = np.full((H, W), np.inf)
    nbuf = np.zeros((H, W, 3)) if want_normals else None
    ibuf = np.full((H, W), -1, dtype=np.int32)
    for i, prim in enumerate(prims):
        rect = cam.bounds(prim.pos, prim.radius)
        if rect is None:
            continue
        x0, x1, y0, y1 = rect
        origins, dirs = cam.rays(x0, x1, y0, y1)
        o = (origins - prim.pos) @ prim.R
        d = dirs @ prim.R
        t, n_local = hit_part(prim, o, d)
        t = t.reshape(y1 - y0, x1 - x0)
        sub = zbuf[y0:y1, x0:x1]
        closer = t < sub
        if not closer.any():
            continue
        sub[closer] = t[closer]
        ibuf[y0:y1, x0:x1][closer] = i
        if want_normals:
            n_world = (n_local @ prim.R.T).reshape(y1 - y0, x1 - x0, 3)
            nbuf[y0:y1, x0:x1][closer] = n_world[closer]
    return zbuf, nbuf, ibuf


def shadow_factor(prims, points, look):
    """1 = au soleil, 0 = à l'ombre (carte d'ombre orthographique)."""
    casters = [p for p in prims if p.alpha > 0.6 and p.shadow and not p.neon]
    if not casters or len(points) == 0:
        return np.ones(len(points))
    lo, hi = points.min(axis=0), points.max(axis=0)
    center = (lo + hi) / 2
    extent = float(np.linalg.norm(hi - lo)) + 4
    res = 2048
    cam = Camera(center + look.light * (extent + 200), center, res, res, ortho=extent,
                 up=(0, 0, 1) if abs(look.light[1]) > 0.99 else (0, 1, 0))
    # on ne garde que les pièces qui peuvent faire de l'ombre sur la zone visible
    depth, _, _ = trace(casters, cam, want_normals=False)
    rel = points - cam.pos
    u = rel @ cam.right / cam.scale + res / 2
    v = res / 2 - rel @ cam.up / cam.scale
    z = rel @ cam.forward
    lit = np.zeros(len(points))
    taps = [(-1.5, -1.5), (0, -1.5), (1.5, -1.5), (-1.5, 0), (0, 0), (1.5, 0), (-1.5, 1.5), (0, 1.5), (1.5, 1.5)]
    bias = 0.08 + cam.scale * 2
    for du, dv in taps:
        iu = np.clip((u + du).astype(int), 0, res - 1)
        iv = np.clip((v + dv).astype(int), 0, res - 1)
        lit += (z <= depth[iv, iu] + bias)
    return lit / len(taps)


def render(scene, cam, look, ss=2):
    """Rend la scène. Renvoie une image RGBA (fond transparent si look.sky est None)."""
    big = cam.scaled(ss)
    W, H = big.w, big.h
    opaque = [p for p in scene.prims if p.alpha > 0.97]
    clear = sorted([p for p in scene.prims if p.alpha <= 0.97],
                   key=lambda p: -np.linalg.norm(p.pos - cam.pos))

    zbuf, nbuf, ibuf = trace(opaque, big)
    hit = ibuf >= 0
    color = np.zeros((H, W, 3))
    emis = np.zeros((H, W, 3))
    gbuf = np.full((H, W), -1, dtype=np.int32)

    # fond
    if look.sky is not None:
        color[:] = look.sky(W, H)
    alpha = hit.astype(float)

    # éclairage des pièces opaques
    ys, xs = np.nonzero(hit)
    if len(ys):
        idx = ibuf[ys, xs]
        origins, dirs = big.rays(0, W, 0, H)
        flat = ys * W + xs
        dirs_hit = dirs[flat]
        org_hit = origins[flat] if big.ortho else np.broadcast_to(big.pos, dirs_hit.shape)
        t = zbuf[ys, xs]
        points = org_hit + dirs_hit * t[:, None]
        normals = nbuf[ys, xs]
        normals /= np.linalg.norm(normals, axis=1, keepdims=True) + 1e-9
        flip = np.einsum("ij,ij->i", normals, dirs_hit) > 0
        normals[flip] *= -1
        base = np.array([opaque[i].color for i in range(len(opaque))])[idx]
        neon = np.array([opaque[i].neon for i in range(len(opaque))])[idx]
        groups = np.array([opaque[i].group for i in range(len(opaque))])[idx]
        gbuf[ys, xs] = groups

        sun = shadow_factor(opaque, points + normals * 0.05, look) if look.shadows else np.ones(len(points))
        ndl = np.clip(normals @ look.light, 0, 1) * (0.25 + 0.75 * sun)
        fill_dir = normalize([-look.light[0], 0.3, -look.light[2]])
        ndf = np.clip(normals @ fill_dir, 0, 1)
        sky_up = np.clip(normals[:, 1] * 0.5 + 0.5, 0, 1)
        view = -dirs_hit
        facing = np.clip(np.einsum("ij,ij->i", normals, view), 0, 1)
        rim = (1 - facing) ** 3
        half = normalize(look.light)[None, :] + view
        half /= np.linalg.norm(half, axis=1, keepdims=True)
        spec = np.clip(np.einsum("ij,ij->i", normals, half), 0, 1) ** 40 * sun

        shade = look.ambient * (0.75 + 0.25 * sky_up) + look.key * ndl + look.fill * ndf
        lit = base * shade[:, None] + spec[:, None] * 0.25 + rim[:, None] * look.rim * look.rim_color * 0.5
        glow_col = np.clip(base * 1.1 + 0.12, 0, 1)
        lit[neon] = glow_col[neon]
        emis_vals = np.where(neon[:, None], base, 0)
        if look.fog is not None:
            k = np.clip((t - look.fog_start) / look.fog, 0, 0.85)[:, None]
            lit = lit * (1 - k) + look.fog_color * k
            emis_vals = emis_vals * (1 - k)
        color[ys, xs] = lit
        emis[ys, xs] = emis_vals

    # pièces transparentes (de la plus loin à la plus proche)
    for prim in clear:
        rect = big.bounds(prim.pos, prim.radius)
        if rect is None:
            continue
        x0, x1, y0, y1 = rect
        origins, dirs = big.rays(x0, x1, y0, y1)
        o = (origins - prim.pos) @ prim.R
        d = dirs @ prim.R
        t, n_local = hit_part(prim, o, d)
        t = t.reshape(y1 - y0, x1 - x0)
        mask = t < zbuf[y0:y1, x0:x1]
        if not mask.any():
            continue
        n_world = (n_local @ prim.R.T).reshape(y1 - y0, x1 - x0, 3)[mask]
        n_world /= np.linalg.norm(n_world, axis=1, keepdims=True) + 1e-9
        dd = dirs.reshape(y1 - y0, x1 - x0, 3)[mask]
        flip = np.einsum("ij,ij->i", n_world, dd) > 0
        n_world[flip] *= -1
        ndl = np.clip(n_world @ look.light, 0, 1)
        rim = (1 - np.clip(np.einsum("ij,ij->i", n_world, -dd), 0, 1)) ** 2
        if prim.neon:
            c = np.clip(prim.color * 1.1 + 0.12, 0, 1)[None, :].repeat(len(ndl), 0)
            emis[y0:y1, x0:x1][mask] += prim.color * prim.alpha
        else:
            c = prim.color[None, :] * (look.ambient + look.key * ndl)[:, None] + rim[:, None] * 0.25
        a = prim.alpha
        sub = color[y0:y1, x0:x1]
        sub[mask] = sub[mask] * (1 - a) + c * a
        asub = alpha[y0:y1, x0:x1]
        asub[mask] = np.maximum(asub[mask], a)
        gsub = gbuf[y0:y1, x0:x1]
        gsub[mask & (gsub < 0)] = prim.group

    # contours cartoon : bord d'un objet, ou saut de profondeur
    if look.outline is not None and look.outline_px > 0:
        z = np.where(np.isfinite(zbuf), zbuf, 1e9)
        edge = np.zeros((H, W), dtype=bool)
        for dy, dx in ((0, 1), (1, 0), (1, 1), (1, -1)):
            g2 = np.roll(np.roll(gbuf, dy, 0), dx, 1)
            z2 = np.roll(np.roll(z, dy, 0), dx, 1)
            diff = (gbuf != g2) & ((gbuf >= 0) | (g2 >= 0))
            jump = (gbuf >= 0) & (g2 >= 0) & (np.abs(z - z2) > 0.04 * np.minimum(z, z2) + 0.3)
            e = diff | jump
            edge |= e
            edge |= np.roll(np.roll(e, -dy, 0), -dx, 1)
        thick = max(1, int(round(look.outline_px * ss / 2)))
        grown = edge.copy()
        for _ in range(thick - 1):
            grown = grown | np.roll(grown, 1, 0) | np.roll(grown, -1, 0) | np.roll(grown, 1, 1) | np.roll(grown, -1, 1)
        oc = np.array(look.outline)
        k = 0.9
        color[grown] = color[grown] * (1 - k) + oc * k
        alpha[grown] = 1.0

    # surlignage façon "Highlight" de Roblox (le voleur en rouge)
    for g, (fill, opacity, line) in scene.highlights.items():
        mask = gbuf == g
        if not mask.any():
            continue
        color[mask] = color[mask] * (1 - opacity) + np.array(fill) * opacity
        ring = mask.copy()
        for _ in range(max(1, int(round(look.outline_px * ss * 1.2)))):
            ring = ring | np.roll(ring, 1, 0) | np.roll(ring, -1, 0) | np.roll(ring, 1, 1) | np.roll(ring, -1, 1)
        ring &= ~mask
        color[ring] = np.array(line)
        alpha[ring] = 1.0

    rgb = np.clip(color, 0, 1)
    if look.sky is not None:
        alpha[:] = 1
    img = Image.fromarray((np.dstack([rgb, alpha]) * 255).astype(np.uint8), "RGBA")
    img = img.resize((cam.w, cam.h), Image.LANCZOS)

    # halo des pièces néon
    if look.glow and emis.any():
        glow = Image.fromarray((np.clip(emis, 0, 1) * 255).astype(np.uint8), "RGB").resize((cam.w, cam.h), Image.BILINEAR)
        glow = glow.filter(ImageFilter.GaussianBlur(cam.w / 90))
        g = np.asarray(glow).astype(float) / 255 * look.glow
        arr = np.asarray(img).astype(float) / 255
        arr[..., :3] = 1 - (1 - arr[..., :3]) * (1 - g)
        arr[..., 3] = np.maximum(arr[..., 3], np.clip(g.max(axis=2) * 1.4, 0, 1))
        img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
    return img


# ------------------------------------------------------------------ cadrage

def corners(prims):
    """Points sur la surface des pièces (pour cadrer au plus juste)."""
    pts = []
    for p in prims:
        h = p.size / 2
        if p.shape == "Ball":
            r = p.size.min() / 2
            for v in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
                pts.append(p.pos + np.array(v) * r)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    for sz in (-1, 1):
                        pts.append(p.pos + np.array([sx, sy, sz]) * r * 0.577)
        elif p.shape == "Cylinder":
            r = min(p.size[1], p.size[2]) / 2
            for x in (-h[0], h[0]):
                for i in range(12):
                    a = 2 * math.pi * i / 12
                    pts.append(p.pos + p.R @ np.array([x, r * math.cos(a), r * math.sin(a)]))
        else:
            for sx in (-1, 1):
                for sy in (-1, 1):
                    for sz in (-1, 1):
                        pts.append(p.pos + p.R @ (h * [sx, sy, sz]))
    return np.array(pts)


def fit_camera(prims, direction, w, h, fov=30.0, margin=0.08, lift=0.0, up=(0, 1, 0)):
    """Caméra qui cadre toutes les pièces, vues depuis "direction" (vers la caméra)."""
    pts = corners(prims)
    direction = normalize(direction)
    center = (pts.min(axis=0) + pts.max(axis=0)) / 2
    for _ in range(3):
        lo, hi = 0.5, 5000.0
        for _ in range(40):
            dist = (lo + hi) / 2
            cam = Camera(center + direction * dist, center, w, h, fov, up=up)
            rel = pts - cam.pos
            z = rel @ cam.forward
            if (z <= 0.1).any():
                lo = dist
                continue
            px = rel @ cam.right / z * cam.f
            py = rel @ cam.up / z * cam.f
            if np.abs(px).max() <= w / 2 * (1 - margin) and np.abs(py).max() <= h / 2 * (1 - margin):
                hi = dist
            else:
                lo = dist
        cam = Camera(center + direction * hi, center, w, h, fov, up=up)
        rel = pts - cam.pos
        z = rel @ cam.forward
        px = rel @ cam.right / z
        py = rel @ cam.up / z
        # recentre l'image sur les pièces
        mx = (px.max() + px.min()) / 2
        my = (py.max() + py.min()) / 2
        depth = float(np.median(z))
        center = center + cam.right * mx * depth + cam.up * my * depth
    center = center + np.array([0, lift, 0])
    return Camera(center + direction * hi, center, w, h, fov, up=up)


# ------------------------------------------------------------------ décor 2D (fonds, textes)

FONT_DIR = "/usr/share/fonts/opentype/inter/"


def font(size, italic=True):
    name = "InterDisplay-BlackItalic.otf" if italic else "InterDisplay-Black.otf"
    try:
        return ImageFont.truetype(FONT_DIR + name, size)
    except OSError:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)


def rgb(c):
    return np.array(c, dtype=float) / 255


def sunburst(w, h, c1, c2, glow, rays=20, center=None, twist=0.0):
    cx, cy = center if center else (w / 2, h / 2)
    y, x = np.mgrid[0:h, 0:w].astype(float)
    ang = np.arctan2(y - cy, x - cx) + twist
    band = (np.floor((ang + math.pi) / (2 * math.pi / rays)) % 2)[..., None]
    base = rgb(c1) * band + rgb(c2) * (1 - band)
    dist = np.hypot(x - cx, y - cy) / math.hypot(w, h) * 2
    t = np.clip(dist, 0, 1)[..., None] ** 0.7
    img = rgb(glow) * (1 - t) + base * t
    vignette = np.clip(1 - (dist[..., None] - 0.6) * 0.6, 0.55, 1)
    return np.clip(img * vignette, 0, 1)


def night_sky(top=(22, 12, 48), mid=(70, 34, 110), horizon=(190, 95, 150), stars=160, seed=3):
    def paint(w, h):
        y = np.linspace(0, 1, h)[:, None, None]
        a = np.clip(y / 0.55, 0, 1)
        b = np.clip((y - 0.55) / 0.45, 0, 1)
        img = rgb(top) * (1 - a) + rgb(mid) * a
        img = img * (1 - b) + rgb(horizon) * b
        img = np.broadcast_to(img, (h, w, 3)).copy()
        rng = np.random.default_rng(seed)
        for _ in range(stars):
            sx, sy = rng.integers(0, w), rng.integers(0, int(h * 0.55))
            r = max(1, int(w / 900 * rng.uniform(0.6, 1.6)))
            img[max(0, sy - r):sy + r, max(0, sx - r):sx + r] = 0.95
        return img
    return paint


def flat_sky(color_top, color_bottom):
    def paint(w, h):
        y = np.linspace(0, 1, h)[:, None, None]
        img = rgb(color_top) * (1 - y) + rgb(color_bottom) * y
        return np.broadcast_to(img, (h, w, 3)).copy()
    return paint


def to_image(arr):
    return Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")


def moon(img, cx, cy, r):
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse([cx - r * 2.2, cy - r * 2.2, cx + r * 2.2, cy + r * 2.2], fill=(255, 230, 200, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(r * 0.8))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 244, 214, 255))
    for ox, oy, rr in ((-0.35, -0.2, 0.18), (0.3, 0.25, 0.13), (0.1, -0.45, 0.09)):
        d.ellipse([cx + ox * r - rr * r, cy + oy * r - rr * r, cx + ox * r + rr * r, cy + oy * r + rr * r], fill=(236, 222, 190, 255))


def title(text, size, top=(255, 236, 90), bottom=(255, 150, 20), stroke=(40, 14, 60), stroke_w=None,
          italic=True, angle=0.0, shadow=True):
    """Gros texte façon jeu : dégradé, contour épais et ombre."""
    f = font(size, italic)
    stroke_w = stroke_w if stroke_w is not None else max(4, size // 9)
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    x0, y0, x1, y1 = probe.textbbox((0, 0), text, font=f, stroke_width=stroke_w)
    pad = stroke_w * 2 + 10
    w, h = x1 - x0 + pad * 2, y1 - y0 + pad * 2
    origin = (pad - x0, pad - y0)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    if shadow:
        sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((origin[0] + size * 0.05, origin[1] + size * 0.07), text, font=f,
                                fill=(20, 5, 30, 200), stroke_width=stroke_w, stroke_fill=(20, 5, 30, 200))
        out.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size * 0.03)))
    ImageDraw.Draw(out).text(origin, text, font=f, fill=stroke + (255,), stroke_width=stroke_w, stroke_fill=stroke + (255,))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text(origin, text, font=f, fill=255)
    grad = np.zeros((h, w, 4))
    yy = np.clip((np.arange(h)[:, None] - origin[1] - (y0 + size * 0.15)) / (size * 0.75), 0, 1)
    grad[..., :3] = (rgb(top) * (1 - yy[..., None]) + rgb(bottom) * yy[..., None])
    grad[..., 3] = 1
    gimg = Image.fromarray((grad * 255).astype(np.uint8), "RGBA")
    out.paste(gimg, (0, 0), mask)
    # petit reflet en haut des lettres
    shine = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shine).text((origin[0], origin[1] - size * 0.04), text, font=f, fill=90)
    shine = Image.fromarray((np.asarray(shine) * (np.asarray(mask) > 0) * (yy < 0.35)).astype(np.uint8))
    white = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    out.paste(white, (0, 0), shine)
    if angle:
        out = out.rotate(angle, resample=Image.BICUBIC, expand=True)
    return out


def paste_center(img, layer, cx, cy):
    img.alpha_composite(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)))


def sparkle(img, cx, cy, r, color=(255, 255, 220)):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pts = []
    for i in range(8):
        a = math.pi / 4 * i
        rr = r if i % 2 == 0 else r * 0.28
        pts.append((cx + rr * math.cos(a - math.pi / 2), cy + rr * math.sin(a - math.pi / 2)))
    d.polygon(pts, fill=color + (255,))
    glow = layer.filter(ImageFilter.GaussianBlur(r * 0.35))
    img.alpha_composite(glow)
    img.alpha_composite(layer)


def drop_shadow(layer, blur=12, offset=(0, 10), opacity=150):
    a = np.asarray(layer)[..., 3]
    sh = Image.new("RGBA", layer.size, (15, 5, 25, 0))
    sh.putalpha(Image.fromarray((a * (opacity / 255)).astype(np.uint8)))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", (layer.width + abs(offset[0]) * 2, layer.height + abs(offset[1]) * 2), (0, 0, 0, 0))
    out.alpha_composite(sh, (abs(offset[0]) + offset[0], abs(offset[1]) + offset[1]))
    out.alpha_composite(layer, (abs(offset[0]), abs(offset[1])))
    return out

# ------------------------------------------------------------------ personnages et objets

SKIN_YELLOW = (0.96, 0.80, 0.19)
SKIN_LIGHT = (0.92, 0.72, 0.57)
SKIN_BROWN = (0.62, 0.42, 0.28)


def avatar(scene, place, shirt, pants, skin=SKIN_YELLOW, arm_l=0.0, arm_r=0.0, leg_l=0.0, leg_r=0.0,
           hair=None, group=None, mouth="smile"):
    """Personnage Roblox en blocs (R6). place = repère du torse ; il regarde vers -Z.
    Angles en degrés : bras levé vers l'avant = positif."""
    g = group if group is not None else scene.group()

    def add(shape, local, size, color):
        scene.prims.append(Prim(shape, mul(place, local), size, color, group=g))

    add("Block", cf_new(), (2, 2, 1), shirt)
    add("Cylinder", (np.array([0, 1.6, 0]), rot_z(math.pi / 2)), (1.2, 1.25, 1.25), skin)
    eye_z = -math.sqrt(0.625 ** 2 - 0.22 ** 2) + 0.03
    for x in (-0.22, 0.22):
        add("Ball", cf_new(x, 1.74, eye_z), (0.2, 0.2, 0.2), (0.07, 0.06, 0.1))
    if mouth == "smile":
        for i in range(7):
            a = math.radians(-60 + i * 20)
            x = 0.27 * math.sin(a)
            y = 1.5 - 0.13 * math.cos(a)
            add("Ball", cf_new(x, y, -math.sqrt(max(0.0, 0.625 ** 2 - x * x)) + 0.03), (0.08, 0.08, 0.08), (0.07, 0.06, 0.1))
    else:  # bouche ouverte (surpris, en colère)
        add("Ball", cf_new(0, 1.42, -0.6), (0.26, 0.26, 0.26), (0.25, 0.05, 0.08))
    if hair:
        add("Cylinder", (np.array([0, 2.12, 0.05]), rot_z(math.pi / 2)), (0.3, 1.32, 1.32), hair)
        add("Block", cf_new(0, 1.85, 0.42), (1.3, 0.75, 0.45), hair)
    for side, angle in ((-1, arm_l), (1, arm_r)):
        pivot = (np.array([side * 1.5, 0.5, 0]), rot_x(math.radians(angle)))
        add("Block", mul(pivot, cf_new(0, -0.5, 0)), (1, 2, 1), skin)
        add("Block", mul(pivot, cf_new(0, 0.1, 0)), (1.04, 0.85, 1.04), shirt)  # manche
    for side, angle in ((-1, leg_l), (1, leg_r)):
        pivot = (np.array([side * 0.5, -1, 0]), rot_x(math.radians(angle)))
        add("Block", mul(pivot, cf_new(0, -1, 0)), (1, 2, 1), pants)
    return g


def hand(place, side, angle):
    """Repère de la main d'un bras (pour y mettre un objet)."""
    pivot = mul(place, (np.array([side * 1.5, 0.5, 0]), rot_x(math.radians(angle))))
    return mul(pivot, cf_new(0, -1.5, 0))


def coin(scene, place, size=2.0, group=None):
    g = group if group is not None else scene.group()
    gold, light = (1.0, 0.76, 0.12), (1.0, 0.9, 0.38)
    face = mul(place, (np.zeros(3), rot_y(math.pi / 2)))
    scene.prims.append(Prim("Cylinder", face, (size * 0.18, size, size), gold, group=g))
    scene.prims.append(Prim("Cylinder", face, (size * 0.24, size * 0.72, size * 0.72), light, group=g))
    return g


def add_ghost(scene, data, key, place, **kw):
    ghost = data["ghosts"][key]
    return scene.add_parts(ghost["parts"], place, **kw)


def ghost_on(data, key, at):
    """Repère pour poser un fantôme debout sur un point (le bas du fantôme sur "at")."""
    bottom = data["ghosts"][key]["bottom"]
    return mul(at, cf_new(0, bottom, 0))


def render_object(data_parts_list, size, direction=(0.35, 0.3, -1), look=None, margin=0.1, fov=26):
    scene = Scene()
    for parts, place in data_parts_list:
        scene.add_parts(parts, place)
    cam = fit_camera(scene.prims, direction, size, size, fov=fov, margin=margin)
    return render(scene, cam, look or Look(shadows=False, outline_px=3))
