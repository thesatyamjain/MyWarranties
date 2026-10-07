import os
from PIL import Image, ImageDraw
from collections import deque

def main():
    src_path = r"C:\Users\hp\.gemini\antigravity\brain\c099322e-3bac-4fcc-a62f-23875d73a270\.user_uploaded\media_1791283312650.png"
    if not os.path.exists(src_path):
        raise FileNotFoundError(f"Source artwork not found at {src_path}")

    img = Image.open(src_path).convert("RGBA")
    w, h = img.size

    # 1. Unblend outer grey corners to create authentic iOS squircle with transparent corners
    squircle = img.copy()
    visited = set()
    queue = deque([(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)])
    for pt in list(queue):
        visited.add(pt)

    while queue:
        x, y = queue.popleft()
        r, g, b, _ = img.getpixel((x, y))
        if r < 235:
            if r <= 98 and g <= 98 and b <= 98:
                squircle.putpixel((x, y), (0, 0, 0, 0))
            else:
                alpha = max(0, min(255, int(round(255.0 * (r - 96.0) / (236.0 - 96.0)))))
                squircle.putpixel((x, y), (236, 240, 249, alpha))

            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                    nr, ng, nb, _ = img.getpixel((nx, ny))
                    if nr < 235:
                        visited.add((nx, ny))
                        queue.append((nx, ny))

    # 2. Create full bleed canvas (#ECF0F9)
    full_bleed = Image.new("RGBA", (w, h), (236, 240, 249, 255))
    full_bleed.alpha_composite(squircle)

    # 3. Create clean circular icon (for roundIcon)
    circle_mask_hi = Image.new("L", (w * 4, h * 4), 0)
    draw_hi = ImageDraw.Draw(circle_mask_hi)
    pad_hi = 12 * 4
    draw_hi.ellipse([pad_hi, pad_hi, (w * 4) - pad_hi, (h * 4) - pad_hi], fill=255)
    circle_mask = circle_mask_hi.resize((w, h), Image.Resampling.LANCZOS)

    round_icon = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    round_icon.paste(full_bleed, (0, 0), circle_mask)

    # 4. Create adaptive icon foreground (108dp canvas where inner 70dp is safe)
    scale_factor = 0.70
    scaled_w = int(w * scale_factor)
    scaled_h = int(h * scale_factor)
    scaled_art = full_bleed.resize((scaled_w, scaled_h), Image.Resampling.LANCZOS)

    fg_icon = Image.new("RGBA", (w, h), (236, 240, 249, 255))
    offset_x = (w - scaled_w) // 2
    offset_y = (h - scaled_h) // 2
    fg_icon.paste(scaled_art, (offset_x, offset_y))

    # Save high-res masters to assets
    assets_dir = r"e:\My Warranties\assets\brand_icons"
    os.makedirs(assets_dir, exist_ok=True)
    squircle.save(os.path.join(assets_dir, "my_warranties_mw_icon.png"), "PNG")
    round_icon.save(os.path.join(assets_dir, "my_warranties_mw_icon_round.png"), "PNG")
    fg_icon.save(os.path.join(assets_dir, "my_warranties_mw_icon_foreground.png"), "PNG")
    print("Saved high-res masters to assets/brand_icons")

    # Android mipmap densities:
    # legacy ic_launcher (squircle) & ic_launcher_round (circle)
    legacy_densities = {
        r"e:\My Warranties\android\app\src\main\res\mipmap-mdpi": (48, 108),
        r"e:\My Warranties\android\app\src\main\res\mipmap-hdpi": (72, 162),
        r"e:\My Warranties\android\app\src\main\res\mipmap-xhdpi": (96, 216),
        r"e:\My Warranties\android\app\src\main\res\mipmap-xxhdpi": (144, 324),
        r"e:\My Warranties\android\app\src\main\res\mipmap-xxxhdpi": (192, 432),
    }

    for folder, (legacy_px, fg_px) in legacy_densities.items():
        os.makedirs(folder, exist_ok=True)
        # 1. ic_launcher.png (iOS squircle with transparent corners)
        squircle.resize((legacy_px, legacy_px), Image.Resampling.LANCZOS).save(
            os.path.join(folder, "ic_launcher.png"), "PNG"
        )
        # 2. ic_launcher_round.png (Circular)
        round_icon.resize((legacy_px, legacy_px), Image.Resampling.LANCZOS).save(
            os.path.join(folder, "ic_launcher_round.png"), "PNG"
        )
        # 3. ic_launcher_foreground.png (Adaptive foreground)
        fg_icon.resize((fg_px, fg_px), Image.Resampling.LANCZOS).save(
            os.path.join(folder, "ic_launcher_foreground.png"), "PNG"
        )
        print(f"Updated Android {folder}: legacy={legacy_px}px, fg={fg_px}px")

    # Android 8.0+ Adaptive Icon XMLs
    v26_dir = r"e:\My Warranties\android\app\src\main\res\mipmap-anydpi-v26"
    os.makedirs(v26_dir, exist_ok=True)

    adaptive_xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/splash_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n'
    )

    with open(os.path.join(v26_dir, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(adaptive_xml)

    with open(os.path.join(v26_dir, "ic_launcher_round.xml"), "w", encoding="utf-8") as f:
        f.write(adaptive_xml)

    print("Created mipmap-anydpi-v26/ic_launcher.xml and ic_launcher_round.xml")

    # Web & Favicon
    web_fav = r"e:\My Warranties\web\favicon.png"
    squircle.resize((32, 32), Image.Resampling.LANCZOS).save(web_fav, "PNG")

    web_squircle_icons = {
        r"e:\My Warranties\web\icons\Icon-192.png": 192,
        r"e:\My Warranties\web\icons\Icon-512.png": 512,
    }
    for path, px in web_squircle_icons.items():
        squircle.resize((px, px), Image.Resampling.LANCZOS).save(path, "PNG")

    web_maskable_icons = {
        r"e:\My Warranties\web\icons\Icon-maskable-192.png": 192,
        r"e:\My Warranties\web\icons\Icon-maskable-512.png": 512,
    }
    for path, px in web_maskable_icons.items():
        fg_icon.resize((px, px), Image.Resampling.LANCZOS).save(path, "PNG")

    print("Updated web icons and favicon")

if __name__ == "__main__":
    main()
