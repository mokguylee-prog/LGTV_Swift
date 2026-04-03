"""
Generate PNG and ICNS assets for the LG NetCast app.
"""

from pathlib import Path
import shutil
import subprocess

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "assets"
ICONSET = ASSETS / "LGNetCast.iconset"
LG_RED = (177, 35, 75, 255)
LG_RED_DARK = (141, 27, 60, 255)
WHITE = (255, 255, 255, 255)

try:
    RESAMPLE = Image.Resampling.LANCZOS
except AttributeError:
    RESAMPLE = Image.LANCZOS


def draw_icon(size: int) -> Image.Image:
    scale = 8
    large = size * scale
    canvas = Image.new("RGBA", (large, large), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    margin = int(large * 0.08)
    stroke = max(6, int(large * 0.036))

    # Base emblem.
    draw.ellipse(
        [margin, margin, large - margin, large - margin],
        fill=LG_RED,
        outline=LG_RED_DARK,
        width=max(4, stroke // 2),
    )

    # Face dot.
    dot_r = int(large * 0.055)
    dot_x = int(large * 0.31)
    dot_y = int(large * 0.29)
    draw.ellipse(
        [dot_x - dot_r, dot_y - dot_r, dot_x + dot_r, dot_y + dot_r],
        fill=WHITE,
    )

    # "L"
    lx = int(large * 0.47)
    ly_top = int(large * 0.24)
    ly_bottom = int(large * 0.64)
    l_right = int(large * 0.60)
    draw.line((lx, ly_top, lx, ly_bottom), fill=WHITE, width=stroke)
    draw.line((lx, ly_bottom, l_right, ly_bottom), fill=WHITE, width=stroke)

    # "G" outer sweep and inner bar.
    g_box = [
        int(large * 0.44),
        int(large * 0.22),
        int(large * 0.86),
        int(large * 0.76),
    ]
    draw.arc(g_box, start=288, end=138, fill=WHITE, width=stroke)
    bar_y = int(large * 0.46)
    bar_inner = int(large * 0.63)
    bar_right = int(large * 0.79)
    bar_bottom = int(large * 0.64)
    draw.line((bar_inner, bar_y, bar_right, bar_y), fill=WHITE, width=stroke)
    draw.line((bar_right, bar_y, bar_right, bar_bottom), fill=WHITE, width=stroke)

    return canvas.resize((size, size), RESAMPLE)


def main():
    ASSETS.mkdir(exist_ok=True)
    if ICONSET.exists():
        shutil.rmtree(ICONSET)
    ICONSET.mkdir(parents=True)

    icon_sizes = [16, 32, 64, 128, 256, 512, 1024]
    for size in icon_sizes:
        image = draw_icon(size)
        image.save(ASSETS / f"lg_remote_{size}.png")

    iconset_targets = {
        16: "icon_16x16.png",
        32: "icon_16x16@2x.png",
        32.1: "icon_32x32.png",
        64: "icon_32x32@2x.png",
        128: "icon_128x128.png",
        256: "icon_128x128@2x.png",
        256.1: "icon_256x256.png",
        512: "icon_256x256@2x.png",
        512.1: "icon_512x512.png",
        1024: "icon_512x512@2x.png",
    }
    source_lookup = {
        16: ASSETS / "lg_remote_16.png",
        32: ASSETS / "lg_remote_32.png",
        32.1: ASSETS / "lg_remote_32.png",
        64: ASSETS / "lg_remote_64.png",
        128: ASSETS / "lg_remote_128.png",
        256: ASSETS / "lg_remote_256.png",
        256.1: ASSETS / "lg_remote_256.png",
        512: ASSETS / "lg_remote_512.png",
        512.1: ASSETS / "lg_remote_512.png",
        1024: ASSETS / "lg_remote_1024.png",
    }
    for key, name in iconset_targets.items():
        shutil.copy2(source_lookup[key], ICONSET / name)

    menu_icon = draw_icon(64).resize((22, 22))
    menu_icon.save(ASSETS / "lg_menu_icon.png")

    try:
        subprocess.run(
            ["iconutil", "-c", "icns", str(ICONSET), "-o", str(ASSETS / "LGNetCast.icns")],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        # The menu bar app can still use the PNG asset even if .icns generation
        # is unavailable on this machine.
        pass


if __name__ == "__main__":
    main()
