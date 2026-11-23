#!/usr/bin/env python3
"""Render the app icons in site/icons/ from one SVG design.

The mark is the readout's own 0-100 axis: the four severity bands with the
needle sitting in the high zone, under "PBI" set in EB Garamond, on
UChicago Phoenix Maroon.

Needs Playwright with Chromium (pip install playwright && playwright install chromium).
Only rerun this if you change the icon design; the PNGs are committed.
"""
import base64
import os

from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "site", "icons")

BG = "#800000"    # Phoenix Maroon
INK = "#ffffff"
# Light Greystone, Light Goldenrod, Light Terracotta, Light Brick: legible on maroon
SEV = ["#d9d9d9", "#f3d03e", "#eca154", "#d9877a"]
FONT = os.path.join(ROOT, "site", "fonts", "EBGaramond.woff2")


def mark(with_text: bool) -> str:
    """Artwork on a 100x100 canvas, kept inside the central 80% safe zone."""
    # Band widths are stylized (the real 25/6/5/64 split is unreadable at 16px).
    x, y, h = 20, 61 if with_text else 46, 10
    widths = [22, 10, 10, 18]
    parts, cx = [], x
    for w, c in zip(widths, SEV):
        parts.append(f'<rect x="{cx}" y="{y}" width="{w}" height="{h}" fill="{c}"/>')
        cx += w
    needle_x = x + 22 + 10 + 10 + 8
    parts.append(
        f'<rect x="{needle_x - 2}" y="{y - 6}" width="4" height="{h + 12}" rx="1.5" '
        f'fill="{INK}" stroke="{BG}" stroke-width="1.4"/>'
    )
    if with_text:
        parts.append(
            f'<text x="50" y="48" text-anchor="middle" fill="{INK}" '
            'font-family="EB Garamond" font-weight="600" '
            'font-size="31" letter-spacing="1.5">PBI</text>'
        )
    return "\n".join(parts)


def svg(*, rounded: bool, with_text: bool, scale: float = 1.0) -> str:
    radius = 22 if rounded else 0
    inner = mark(with_text)
    if scale != 1.0:
        off = 50 * (1 - scale)
        inner = f'<g transform="translate({off} {off}) scale({scale})">{inner}</g>'
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        f'<rect width="100" height="100" rx="{radius}" fill="{BG}"/>{inner}</svg>'
    )


# name -> (pixel size, rounded corners, wordmark, artwork scale)
TARGETS = {
    "icon-192.png": (192, True, True, 1.0),
    "icon-512.png": (512, True, True, 1.0),
    # Maskable: full bleed, artwork shrunk so launcher masks never clip it.
    "icon-maskable-512.png": (512, False, True, 0.82),
    # iOS applies its own corner mask and rejects transparency.
    "apple-touch-icon.png": (180, False, True, 1.0),
}


def main():
    os.makedirs(OUT, exist_ok=True)

    with open(os.path.join(OUT, "favicon.svg"), "w", encoding="utf-8") as fh:
        fh.write(svg(rounded=True, with_text=False))

    with open(FONT, "rb") as fh:
        font_b64 = base64.b64encode(fh.read()).decode()

    with sync_playwright() as p:
        browser = p.chromium.launch()
        for name, (size, rounded, text, scale) in TARGETS.items():
            page = browser.new_page(viewport={"width": size, "height": size})
            body = svg(rounded=rounded, with_text=text, scale=scale)
            page.set_content(
                "<style>@font-face{font-family:'EB Garamond';font-weight:400 800;"
                f"src:url(data:font/woff2;base64,{font_b64}) format('woff2')}}"
                "html,body{margin:0;background:transparent}svg{display:block;"
                f"width:{size}px;height:{size}px}}</style>{body}"
            )
            page.evaluate("document.fonts.ready")
            page.screenshot(path=os.path.join(OUT, name), omit_background=True)
            page.close()
            print("wrote", name)
        browser.close()


if __name__ == "__main__":
    main()
