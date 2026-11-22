"""Génère les icônes PNG de la web app (Python pur, aucune dépendance).

Usage : python tools/make_icons.py
"""
import math
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "web"


def png_bytes(w, h, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(tag, data):
        return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack("!IIBBBBB", w, h, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def sd_round_rect(px, py, cx, cy, hw, hh, r):
    qx = abs(px - cx) - (hw - r)
    qy = abs(py - cy) - (hh - r)
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)
    return outside + inside - r


def cover(d, px_size):
    """Couverture anti-aliasée d'une distance signée (en unités) -> [0, 1]."""
    return max(0.0, min(1.0, 0.5 - d * px_size))


def blend(c, col, a):
    return [c[i] + (col[i] - c[i]) * a for i in range(3)]


def render(size):
    top = (59, 108, 255)    # bleu
    bot = (139, 92, 246)    # violet
    white = (255, 255, 255)
    rows = []
    s = size
    for y in range(s):
        row = bytearray()
        for x in range(s):
            u = (x + 0.5) / s
            v = (y + 0.5) / s
            t = min(1.0, max(0.0, (u * 0.35 + v * 0.65)))
            c = [top[i] + (bot[i] - top[i]) * t for i in range(3)]
            # pavé tactile
            d = sd_round_rect(u, v, 0.5, 0.43, 0.30, 0.235, 0.075)
            c = blend(c, white, 0.16 * cover(d, s))
            c = blend(c, white, 0.95 * cover(abs(d) - 0.017, s))
            # point de contact
            df = math.hypot(u - 0.585, v - 0.455) - 0.062
            c = blend(c, white, 0.28 * cover(df - 0.05, s))
            c = blend(c, white, cover(df, s))
            # boutons
            for bx in (0.345, 0.655):
                db = sd_round_rect(u, v, bx, 0.77, 0.145, 0.05, 0.035)
                c = blend(c, white, 0.92 * cover(db, s))
            row += bytes(int(round(max(0, min(255, ch)))) for ch in c)
        rows.append(row)
    return png_bytes(s, s, rows)


IOS_ICON = OUT.parent / "ios" / "PadRemote" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"

if __name__ == "__main__":
    import sys

    OUT.mkdir(exist_ok=True)
    if "--ios-only" not in sys.argv:
        for size in (180, 512):
            (OUT / f"icon-{size}.png").write_bytes(render(size))
            print(f"web/icon-{size}.png")
    IOS_ICON.parent.mkdir(parents=True, exist_ok=True)
    IOS_ICON.write_bytes(render(1024))
    print("ios/.../icon-1024.png")
