#!/usr/bin/env python3
"""Renders the app icon and splash PNGs from the jump-pin artwork using headless Chrome.

Run from the project root, then apply them with:
  dart run flutter_launcher_icons && dart run flutter_native_splash:create
"""
import os
import subprocess
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEAL_50 = "#E1F5EE"
TEAL_100 = "#9FE1CB"
TEAL_400 = "#1D9E75"
TEAL_600 = "#0F6E56"
TEAL_800 = "#085041"
TEAL_900 = "#04342C"
WHITE = "#FFFFFF"

# Artwork in a 112-unit design box, drawn around its visual center (58.5, 56.5).
ART_CENTER = (58.5, 56.5)
PIN = "M0,-30 C-17,-30 -28,-17 -28,-3 C-28,15 0,34 0,34 C0,34 28,15 28,-3 C28,-17 17,-30 0,-30 Z"
# Hole as a reversed subpath so it is cut out with evenodd and shows whatever is behind.
HOLE = "M0,-13.5 A10,10 0 1,0 0,6.5 A10,10 0 1,0 0,-13.5 Z"


def jump_pin(pin=WHITE, trail=TEAL_100):
    return f"""
  <circle cx="28" cy="84" r="7" fill="none" stroke="{trail}" stroke-width="3"/>
  <path d="M35,73 C41,54 52,46 60,46" fill="none" stroke="{trail}" stroke-width="3"
        stroke-dasharray="2 6" stroke-linecap="round"/>
  <g transform="translate(72 48) scale(0.85)">
    <path d="{PIN} {HOLE}" fill="{pin}" fill-rule="evenodd"/>
  </g>"""


def svg(size, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size[0]}" height="{size[1]}" viewBox="0 0 {size[0]} {size[1]}">{body}</svg>'


def centered_art(canvas, scale, **colors):
    cx, cy = canvas / 2, canvas / 2
    tx, ty = cx - ART_CENTER[0] * scale, cy - ART_CENTER[1] * scale
    return f'<g transform="translate({tx} {ty}) scale({scale})">{jump_pin(**colors)}</g>'


def legacy_icon():
    # Full-bleed square for Android versions without adaptive icons.
    return svg((1024, 1024), f'<rect width="1024" height="1024" rx="230" fill="{TEAL_600}"/>' + centered_art(1024, 8))


def adaptive_foreground(monochrome=False):
    # flutter_launcher_icons insets this image by 16% per side, so the canvas maps to the
    # central ~73dp of the 108dp icon; the art stays inside the 66dp safe circle (~90%).
    colors = dict(pin=WHITE, trail=WHITE if monochrome else TEAL_100)
    return svg((1024, 1024), centered_art(1024, 9, **colors))


def splash_android12(dark=False):
    # 1152px image whose visible area is the central 768px circle.
    trail = TEAL_50 if dark else TEAL_100
    return svg((1152, 1152), centered_art(1152, 6, pin=WHITE, trail=trail))


def splash_legacy(dark=False):
    # Pre-Android 12 splashes have no icon background, so the circle is drawn in.
    circle = TEAL_400 if dark else TEAL_600
    trail = TEAL_50 if dark else TEAL_100
    return svg((768, 768), f'<circle cx="384" cy="384" r="300" fill="{circle}"/>' + centered_art(768, 4.6, pin=WHITE, trail=trail))


def branding(dark=False):
    color = TEAL_100 if dark else TEAL_800
    return svg((800, 320), f"""
  <text x="400" y="190" text-anchor="middle" fill="{color}"
        font-family="Roboto, 'Helvetica Neue', Arial, sans-serif" font-size="88" font-weight="500">Fake Location</text>""")


ASSETS = {
    "assets/icon/icon_legacy": legacy_icon(),
    "assets/icon/icon_foreground": adaptive_foreground(),
    "assets/icon/icon_monochrome": adaptive_foreground(monochrome=True),
    "assets/splash/splash_android12": splash_android12(),
    "assets/splash/splash_android12_dark": splash_android12(dark=True),
    "assets/splash/splash_legacy": splash_legacy(),
    "assets/splash/splash_legacy_dark": splash_legacy(dark=True),
    "assets/splash/branding": branding(),
    "assets/splash/branding_dark": branding(dark=True),
}


def render(name, markup):
    out_svg = os.path.join(ROOT, name + ".svg")
    out_png = os.path.join(ROOT, name + ".png")
    os.makedirs(os.path.dirname(out_svg), exist_ok=True)
    with open(out_svg, "w") as f:
        f.write(markup)
    width = markup.split('width="')[1].split('"')[0]
    height = markup.split('height="')[1].split('"')[0]
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as page:
        page.write(f"<html><body style='margin:0;background:transparent'>{markup}</body></html>")
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
         "--force-device-scale-factor=1", "--default-background-color=00000000",
         f"--window-size={width},{height}", f"--screenshot={out_png}", "file://" + page.name],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    os.unlink(page.name)
    print(f"{name}.png  {width}x{height}")


if __name__ == "__main__":
    for name, markup in ASSETS.items():
        render(name, markup)
