#!/usr/bin/env python3
"""Generate an original, scalable news-reader Android launcher icon.

Run after 'flutter create --platforms=android'.
Requires Pillow. Writes Android legacy and adaptive resources.
"""
from pathlib import Path
from math import hypot
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android" / "app" / "src" / "main" / "res"
SIZE = 768


def gradient_background():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            t = 0.60 * x / SIZE + 0.40 * (1 - y / SIZE)
            glow = max(0, 1 - hypot(x - 540, y - 170) / 530)
            px[x, y] = (
                min(255, int(34 + t * 45 + glow * 5)),
                min(255, int(68 + t * 24 + glow * 50)),
                min(255, int(188 + t * 45 + glow * 2)), 255,
            )
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    art = ImageDraw.Draw(overlay)
    art.ellipse((430, -150, 900, 320), fill=(16, 216, 225, 74))
    art.ellipse((-280, 490, 380, 1030), fill=(161, 64, 233, 90))
    overlay = overlay.filter(ImageFilter.GaussianBlur(76))
    return Image.alpha_composite(img, overlay)


def foreground():
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    s = ImageDraw.Draw(shadow)
    s.rounded_rectangle((154, 237, 576, 612), radius=56, fill=(11, 24, 77, 120))
    s.polygon(((224, 301), (671, 152), (529, 537)), fill=(11, 24, 77, 110))
    fg = Image.alpha_composite(fg, shadow.filter(ImageFilter.GaussianBlur(24)))
    d = ImageDraw.Draw(fg)

    # News sheet: light paper, colored header, and journalistic columns.
    d.rounded_rectangle((151, 220, 557, 601), radius=48, fill=(255, 255, 255, 255))
    d.rounded_rectangle((188, 262, 458, 296), radius=12, fill=(48, 100, 223, 255))
    d.rounded_rectangle((188, 321, 495, 336), radius=7, fill=(177, 188, 215, 255))
    d.rounded_rectangle((188, 349, 486, 363), radius=7, fill=(197, 205, 225, 255))
    d.rounded_rectangle((188, 376, 410, 390), radius=7, fill=(197, 205, 225, 255))
    for offset in (0, 112, 224):
        d.rounded_rectangle((188+offset, 430, 275+offset, 543), radius=10,
                            fill=(234, 240, 254, 255))
        for yy in (457, 477, 497, 517):
            d.rounded_rectangle((199+offset, yy, 265+offset, yy+7),
                                radius=3, fill=(172, 188, 219, 255))

    # Fast-moving paper plane, never reliant on a font glyph.
    d.polygon([(213, 290), (664, 138), (502, 561), (435, 389)],
              fill=(255, 255, 255, 255))
    d.polygon([(435, 389), (664, 138), (401, 442)],
              fill=(210, 237, 255, 255))
    d.polygon([(435, 389), (502, 561), (465, 460)],
              fill=(151, 204, 245, 255))
    d.line([(213, 290), (664, 138), (502, 561)], fill=(227, 243, 255, 255), width=5)

    return fg


def save_png(img, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((size, size), Image.Resampling.LANCZOS).save(
        path, "PNG", optimize=True)


def main():
    bg = gradient_background()
    fg = foreground()
    merged = Image.alpha_composite(bg, fg)
    # Legacy icon uses a continuous rounded-square tile.
    rounded = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(rounded).rounded_rectangle((0, 0, SIZE-1, SIZE-1),
                                             radius=170, fill=255)
    merged.putalpha(rounded)
    save_png(merged, ROOT / "assets" / "icon" / "app_icon.png", 1024)

    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                 "xxhdpi": 144, "xxxhdpi": 192}
    for name, pixels in densities.items():
        folder = ANDROID / ("mipmap-" + name)
        save_png(merged, folder / "ic_launcher.png", pixels)
        save_png(merged, folder / "ic_launcher_round.png", pixels)

    # Android 8+ adaptive icon: separate foreground and gradient background.
    save_png(fg, ANDROID / "drawable-nodpi" / "ic_launcher_foreground.png", 432)
    save_png(bg, ANDROID / "drawable-nodpi" / "ic_launcher_background.png", 432)
    adaptive = ANDROID / "mipmap-anydpi-v26"
    adaptive.mkdir(parents=True, exist_ok=True)
    config = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '  <background android:drawable="@drawable/ic_launcher_background"/>\n'
        '  <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    (adaptive / "ic_launcher.xml").write_text(config, encoding="utf-8")
    (adaptive / "ic_launcher_round.xml").write_text(config, encoding="utf-8")
    print("Generated all legacy and adaptive launcher icons.")


if __name__ == "__main__":
    main()
