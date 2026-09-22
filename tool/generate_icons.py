"""Generates the original app icon, adaptive icon layers and splash logo.

Design: an indigo rounded tile with the four arithmetic operators drawn as
geometric strokes in a 2×2 grid (no fonts, no third-party artwork).

Run: D:\\NEW AI WORK\\.venv\\Scripts\\python.exe tool/generate_icons.py
"""
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IOS_ICON = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
IOS_LAUNCH = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset")

TOP = (63, 81, 181)      # indigo 500
BOTTOM = (40, 53, 147)   # indigo 800
ACCENT = (255, 193, 7)   # amber for "="
WHITE = (255, 255, 255)


def gradient(size):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        c = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
        d.line([(0, y), (size, y)], fill=c)
    return img


def draw_symbols(d, cx, cy, span, stroke):
    """Draws + − × = in a 2×2 grid centred on (cx, cy) spanning `span` px."""
    cell = span / 2
    arm = cell * 0.30
    w = max(1, round(stroke))

    def centre(ix, iy):
        return cx - span / 2 + cell * (ix + 0.5), cy - span / 2 + cell * (iy + 0.5)

    def line(p, q, color):
        d.line([p, q], fill=color, width=w)
        r = w / 2
        for (x, y) in (p, q):
            d.ellipse([x - r, y - r, x + r, y + r], fill=color)

    x, y = centre(0, 0)  # plus
    line((x - arm, y), (x + arm, y), WHITE)
    line((x, y - arm), (x, y + arm), WHITE)
    x, y = centre(1, 0)  # minus
    line((x - arm, y), (x + arm, y), WHITE)
    x, y = centre(0, 1)  # times
    a = arm * 0.78
    line((x - a, y - a), (x + a, y + a), WHITE)
    line((x - a, y + a), (x + a, y - a), WHITE)
    x, y = centre(1, 1)  # equals (accent)
    gap = arm * 0.58
    line((x - arm, y - gap), (x + arm, y - gap), ACCENT)
    line((x - arm, y + gap), (x + arm, y + gap), ACCENT)


def full_icon(size, rounded=True):
    scale = 4
    big = size * scale
    img = gradient(big).convert("RGBA")
    d = ImageDraw.Draw(img)
    draw_symbols(d, big / 2, big / 2, big * 0.62, big * 0.075)
    if rounded:
        mask = Image.new("L", (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=big * 0.22, fill=255)
        img.putalpha(mask)
    return img.resize((size, size), Image.LANCZOS)


def foreground(size):
    """Adaptive-icon foreground: symbols inside the 66/108 safe zone."""
    scale = 4
    big = size * scale
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_symbols(d, big / 2, big / 2, big * 0.40, big * 0.048)
    return img.resize((size, size), Image.LANCZOS)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def main():
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, k in densities.items():
        save(full_icon(round(48 * k)), os.path.join(RES, f"mipmap-{name}", "ic_launcher.png"))
        save(foreground(round(108 * k)), os.path.join(RES, f"mipmap-{name}", "ic_launcher_foreground.png"))
        save(foreground(round(108 * k)), os.path.join(RES, f"mipmap-{name}", "ic_launcher_monochrome.png"))
        # Splash logo (drawn on the indigo splash background).
        logo = full_icon(round(96 * k))
        save(logo, os.path.join(RES, f"drawable-{name}", "splash_logo.png"))

    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@drawable/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
            '</adaptive-icon>\n'
        )
    bg = os.path.join(RES, "drawable", "ic_launcher_background.xml")
    with open(bg, "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n'
            '    <gradient android:angle="270" android:startColor="#3F51B5" android:endColor="#283593"/>\n'
            '</shape>\n'
        )

    # iOS app icons (opaque, no transparency allowed).
    contents_path = os.path.join(IOS_ICON, "Contents.json")
    with open(contents_path, encoding="utf-8") as f:
        contents = json.load(f)
    for img in contents["images"]:
        pts = float(img["size"].split("x")[0])
        scale = int(img["scale"].replace("x", ""))
        px = round(pts * scale)
        name = img.get("filename") or f"Icon-App-{img['size']}@{img['scale']}.png"
        img["filename"] = name
        full_icon(px, rounded=False).convert("RGB").save(os.path.join(IOS_ICON, name))
    with open(contents_path, "w", encoding="utf-8") as f:
        json.dump(contents, f, indent=2)

    for scale, suffix in ((1, ""), (2, "@2x"), (3, "@3x")):
        full_icon(96 * scale).save(os.path.join(IOS_LAUNCH, f"LaunchImage{suffix}.png"))

    # In-app copy of the icon (onboarding, About).
    save(full_icon(512), os.path.join(ROOT, "assets", "icon", "app_icon.png"))

    # Full-resolution masters for documentation and store listings.
    docs = os.path.join(ROOT, "docs", "branding")
    save(full_icon(1024), os.path.join(docs, "app_icon_1024_rounded.png"))
    full_icon(1024, rounded=False).convert("RGB").save(os.path.join(docs, "app_icon_1024_square.png"))
    save(full_icon(512, rounded=False).convert("RGB"), os.path.join(docs, "play_store_icon_512.png"))
    save(foreground(1024), os.path.join(docs, "adaptive_foreground_1024.png"))
    save(gradient(1024), os.path.join(docs, "adaptive_background_1024.png"))
    print("icons generated")


if __name__ == "__main__":
    main()
