#!/usr/bin/env python3
"""Draws the app icon: a blue gradient with a white ring and a dot.

It writes a 1024 by 1024 RGB PNG with no alpha channel, as App Store
Connect wants. Standard library only, so it runs on the Linux box.
Run it from the repository root:

    python3 scripts/make-icon.py
"""
import math
import struct
import zlib

SIZE = 1024
OUT = "App/LifeOS/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
TOP = (52, 120, 246)
BOTTOM = (28, 58, 150)
WHITE = (255, 255, 255)
CENTER = SIZE / 2
RING_RADIUS = 300
RING_WIDTH = 56
DOT_RADIUS = 96


def coverage(distance: float) -> float:
    """How much of a pixel lies inside an edge at this signed distance."""
    return max(0.0, min(1.0, 0.5 - distance))


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def main() -> None:
    rows = []
    for y in range(SIZE):
        background = mix(TOP, BOTTOM, y / (SIZE - 1))
        row = bytearray([0])  # filter type none
        for x in range(SIZE):
            r = math.hypot(x + 0.5 - CENTER, y + 0.5 - CENTER)
            ring = coverage(abs(r - RING_RADIUS) - RING_WIDTH / 2)
            dot = coverage(r - DOT_RADIUS)
            row.extend(mix(background, WHITE, max(ring, dot)))
        rows.append(bytes(row))
    raw = zlib.compress(b"".join(rows), 9)

    def chunk(kind: bytes, data: bytes) -> bytes:
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)  # 8 bit RGB
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")
    with open(OUT, "wb") as handle:
        handle.write(png)


if __name__ == "__main__":
    main()
