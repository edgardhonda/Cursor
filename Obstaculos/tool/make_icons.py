from PIL import Image
import os

src = r"C:\Users\Edgard Honda\Documents\Cursor\Obstaculos\assets\obstaculos_icon.png"
res = r"C:\Users\Edgard Honda\Documents\Cursor\Obstaculos\android\app\src\main\res"
img = Image.open(src).convert("RGBA")


def make_foreground(size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    content = int(size * 0.72)
    icon = img.resize((content, content), Image.Resampling.LANCZOS)
    off = (size - content) // 2
    canvas.paste(icon, (off, off), icon)
    return canvas


def make_legacy(size: int) -> Image.Image:
    bg = Image.new("RGBA", (size, size), (46, 125, 50, 255))
    content = int(size * 0.82)
    icon = img.resize((content, content), Image.Resampling.LANCZOS)
    off = (size - content) // 2
    bg.paste(icon, (off, off), icon)
    return bg.convert("RGB")


densities = {
    "mipmap-mdpi": (48, 108),
    "mipmap-hdpi": (72, 162),
    "mipmap-xhdpi": (96, 216),
    "mipmap-xxhdpi": (144, 324),
    "mipmap-xxxhdpi": (192, 432),
}

for folder, (legacy, fg) in densities.items():
    d = os.path.join(res, folder)
    os.makedirs(d, exist_ok=True)
    make_legacy(legacy).save(os.path.join(d, "ic_launcher.png"), "PNG")
    make_foreground(fg).save(os.path.join(d, "ic_launcher_foreground.png"), "PNG")
    print(folder, "ok")

anydpi = os.path.join(res, "mipmap-anydpi-v26")
os.makedirs(anydpi, exist_ok=True)
with open(os.path.join(anydpi, "ic_launcher.xml"), "w", encoding="utf-8") as f:
    f.write(
        """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    )

values = os.path.join(res, "values")
os.makedirs(values, exist_ok=True)
with open(os.path.join(values, "colors.xml"), "w", encoding="utf-8") as f:
    f.write(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#2E7D32</color>
</resources>
"""
    )
print("done")
