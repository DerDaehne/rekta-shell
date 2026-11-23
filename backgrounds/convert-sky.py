"""Derives rekta-sky/contents/images/1920x1080.webp from the 3840x2160 Display P3 original.

Usage: python3 convert-sky.py <original.png> <out.webp>   (needs numpy, Pillow with WebP)
The original is not in the repository; this records how the shipped file was made.
"""
import sys

import numpy as np
from PIL import Image

WIDTH, HEIGHT = 1920, 1080
# Linear Display P3 to linear sRGB (D65).
P3_TO_SRGB = np.array(
    [[1.2249401, -0.2249404, 0], [-0.0420569, 1.0420571, 0], [-0.0196376, -0.0786361, 1.0982735]]
)


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def from_linear(l):
    return np.where(l <= 0.0031308, l * 12.92, 1.055 * np.clip(l, 0, None) ** (1 / 2.4) - 0.055)


def main(source, target):
    original = np.asarray(Image.open(source).convert("RGB")) / 255
    srgb = np.clip(from_linear(to_linear(original) @ P3_TO_SRGB.T), 0, 1) * 255
    channels = [
        np.asarray(Image.fromarray(srgb[:, :, c].astype(np.float32), "F").resize((WIDTH, HEIGHT), Image.LANCZOS))
        for c in range(3)
    ]
    scaled = np.stack(channels, -1)
    noise = np.random.default_rng(1)
    triangular = noise.random(scaled.shape) + noise.random(scaled.shape) - 1
    pixels = np.clip(np.floor(scaled + 0.5 + triangular * 0.5), 0, 255).astype(np.uint8)
    Image.fromarray(pixels).save(target, lossless=True, quality=100, method=6, exact=True)


main(*sys.argv[1:3])
