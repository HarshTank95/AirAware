"""Generate AirAware app icons — the original "Gauge orb" concept (Pillow).

The app's signature gauge: a 270 degree AQI-scale arc (green -> amber ->
orange -> red) around a soft glowing core on a dark background. Produces:
  assets/icon/app_icon.png             (1024, dark background, for iOS/legacy)
  assets/icon/app_icon_foreground.png  (1024, transparent, Android adaptive + splash)

Run:  python tool/generate_icon.py
"""
import math
import os
from PIL import Image, ImageDraw

SS = 4                     # supersample factor for smooth edges
OUT = 1024
SIZE = OUT * SS
DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")

DARK_BG = (12, 16, 24, 255)

# AQI palette stops (green -> amber -> orange -> red).
STOPS = [
    (0.00, (76, 175, 80)),
    (0.40, (255, 193, 7)),
    (0.70, (255, 152, 0)),
    (1.00, (244, 67, 54)),
]


def grad(t):
    t = max(0.0, min(1.0, t))
    for i in range(len(STOPS) - 1):
        p0, c0 = STOPS[i]
        p1, c1 = STOPS[i + 1]
        if p0 <= t <= p1:
            f = (t - p0) / (p1 - p0)
            return tuple(int(c0[j] + (c1[j] - c0[j]) * f) for j in range(3))
    return STOPS[-1][1]


def draw_orb(base, cx, cy, R):
    d = ImageDraw.Draw(base)

    # soft radial glow core
    glow_r = int(R * 0.82)
    mask = Image.new("L", base.size, 0)
    md = ImageDraw.Draw(mask)
    for r in range(glow_r, 0, -1):
        v = int(210 * (1 - r / glow_r) ** 1.3)
        md.ellipse([cx - r, cy - r, cx + r, cy + r], fill=v)
    glow_color = (130, 235, 180)
    solid = Image.new("RGBA", base.size, glow_color + (255,))
    base.paste(solid, (0, 0), mask)

    # gauge arc
    start, sweep = 135.0, 270.0
    width = int(64 * SS)
    box = [cx - R, cy - R, cx + R, cy + R]
    steps = 360
    for i in range(steps):
        a0 = start + sweep * i / steps
        a1 = start + sweep * (i + 1) / steps + 1.0
        d.arc(box, a0, a1, fill=grad(i / steps) + (255,), width=width)

    # rounded caps
    rr = width / 2
    for ang, t in [(start, 0.0), (start + sweep, 1.0)]:
        ex = cx + R * math.cos(math.radians(ang))
        ey = cy + R * math.sin(math.radians(ang))
        d.ellipse([ex - rr, ey - rr, ex + rr, ey + rr], fill=grad(t) + (255,))

    # bright center pip
    pr = int(R * 0.10)
    d.ellipse([cx - pr, cy - pr, cx + pr, cy + pr], fill=(255, 255, 255, 255))


def build(transparent, scale):
    bg = (0, 0, 0, 0) if transparent else DARK_BG
    img = Image.new("RGBA", (SIZE, SIZE), bg)
    cx = cy = SIZE // 2
    R = int(SIZE * 0.5 * scale)
    draw_orb(img, cx, cy, R)
    return img.resize((OUT, OUT), Image.LANCZOS)


def main():
    os.makedirs(DIR, exist_ok=True)
    build(False, 0.74).save(os.path.join(DIR, "app_icon.png"))
    build(True, 0.62).save(os.path.join(DIR, "app_icon_foreground.png"))
    print("Wrote Gauge app_icon.png and app_icon_foreground.png to", os.path.abspath(DIR))


if __name__ == "__main__":
    main()
