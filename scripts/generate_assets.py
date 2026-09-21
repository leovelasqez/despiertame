#!/usr/bin/env python3
"""Genera los recursos binarios de la app sin depender de herramientas externas.

- Despiertame/Resources/Sounds/alarm.wav   : tono de alarma (10 s, se reproduce en bucle)
- Despiertame/Resources/Sounds/silence.wav : silencio (2 s) para mantener la sesión de audio viva
- Despiertame/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png : icono 1024x1024

Solo usa la biblioteca estándar de Python (wave, struct, zlib, math).
"""

from __future__ import annotations

import math
import struct
import wave
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOUNDS_DIR = ROOT / "Despiertame" / "Resources" / "Sounds"
ICON_PATH = ROOT / "Despiertame" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SAMPLE_RATE = 22050


# --------------------------------------------------------------------------- audio

def _write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    for s in samples:
        s = max(-1.0, min(1.0, s))
        frames += struct.pack("<h", int(s * 32767))
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(bytes(frames))


def _tone(freq: float, duration: float, volume: float = 0.9) -> list[float]:
    n = int(SAMPLE_RATE * duration)
    attack = int(SAMPLE_RATE * 0.008)
    release = int(SAMPLE_RATE * 0.02)
    out = []
    for i in range(n):
        env = 1.0
        if i < attack:
            env = i / attack
        elif i > n - release:
            env = max(0.0, (n - i) / release)
        # Onda con algo de armónicos para que se escuche "penetrante" en un bus.
        t = i / SAMPLE_RATE
        v = (
            math.sin(2 * math.pi * freq * t) * 0.75
            + math.sin(2 * math.pi * freq * 2 * t) * 0.20
            + math.sin(2 * math.pi * freq * 3 * t) * 0.05
        )
        out.append(v * env * volume)
    return out


def _silence(duration: float) -> list[float]:
    return [0.0] * int(SAMPLE_RATE * duration)


def build_alarm(total_seconds: float = 10.0) -> list[float]:
    """Patrón clásico de alarma: 4 pitidos rápidos alternando tono, pausa, repetir."""
    pattern: list[float] = []
    for k in range(4):
        pattern += _tone(880.0 if k % 2 == 0 else 1320.0, 0.14)
        pattern += _silence(0.06)
    pattern += _silence(0.45)
    out: list[float] = []
    target = int(SAMPLE_RATE * total_seconds)
    while len(out) + len(pattern) <= target:
        out += pattern
    # Terminar exactamente en un múltiplo del patrón para que el bucle sea limpio.
    return out


# --------------------------------------------------------------------------- icon

def _png_chunk(kind: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(kind + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", crc)


def _write_png(path: Path, width: int, height: int, rows: list[bytes]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = b"".join(b"\x00" + r for r in rows)
    png = b"\x89PNG\r\n\x1a\n"
    png += _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += _png_chunk(b"IDAT", zlib.compress(raw, 9))
    png += _png_chunk(b"IEND", b"")
    path.write_bytes(png)


def _smooth(edge: float, x: float) -> float:
    """1 dentro, 0 fuera, con borde suave de ~1.5 px para antialiasing."""
    w = 1.5
    if x <= edge - w:
        return 1.0
    if x >= edge + w:
        return 0.0
    t = (x - (edge - w)) / (2 * w)
    return 1.0 - (t * t * (3 - 2 * t))


def _blend(base: tuple[float, float, float], color: tuple[float, float, float], a: float):
    return tuple(base[i] * (1 - a) + color[i] * a for i in range(3))


def build_icon(size: int = 1024) -> None:
    cx = cy = size / 2
    top = (30.0, 27.0, 75.0)       # índigo oscuro
    bottom = (67.0, 56.0, 202.0)   # índigo
    white = (255.0, 255.0, 255.0)
    orange = (249.0, 115.0, 22.0)
    rows: list[bytes] = []
    for y in range(size):
        row = bytearray()
        gy = y / (size - 1)
        bg = _blend(top, bottom, gy)
        for x in range(size):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            px = bg
            # Anillo exterior (radio de la alarma) tenue.
            ring_outer = _smooth(24.0, abs(d - size * 0.36))
            px = _blend(px, white, 0.28 * ring_outer)
            # Anillo medio, más marcado.
            ring_mid = _smooth(20.0, abs(d - size * 0.25))
            px = _blend(px, white, 0.85 * ring_mid)
            # Ondas de sonido a la derecha (dos arcos).
            ang = math.degrees(math.atan2(-dy, dx))
            in_wedge = -35.0 <= ang <= 35.0
            if in_wedge:
                for r_mult in (0.44, 0.48):
                    a = _smooth(9.0, abs(d - size * r_mult))
                    px = _blend(px, white, 0.9 * a)
            # Punto central naranja (el destino).
            dot = _smooth(size * 0.11, d)
            px = _blend(px, orange, dot)
            # Brillo sutil en el punto.
            hl = _smooth(size * 0.045, math.hypot(dx + size * 0.03, dy + size * 0.03))
            px = _blend(px, white, 0.35 * hl * dot)
            row += bytes((int(px[0]), int(px[1]), int(px[2]), 255))
        rows.append(bytes(row))
    _write_png(ICON_PATH, size, size, rows)


def main() -> None:
    print("Generando alarm.wav ...")
    _write_wav(SOUNDS_DIR / "alarm.wav", build_alarm(10.0))
    print("Generando silence.wav ...")
    _write_wav(SOUNDS_DIR / "silence.wav", _silence(2.0))
    print("Generando AppIcon.png (puede tardar unos segundos) ...")
    build_icon(1024)
    print("Listo.")
    for p in (SOUNDS_DIR / "alarm.wav", SOUNDS_DIR / "silence.wav", ICON_PATH):
        print(f"  {p.relative_to(ROOT)}  {p.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
