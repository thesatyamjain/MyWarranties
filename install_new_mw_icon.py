from PIL import Image, ImageDraw, ImageFilter
import os

src_path = r"C:\Users\hp\.gemini\antigravity\brain\c099322e-3bac-4fcc-a62f-23875d73a270\.user_uploaded\media_1791283312650.png"
img = Image.open(src_path).convert("RGBA")
w, h = img.size

# 1. Detect and flood fill/replace the grey outer corners with the background color
# The inner background is approx (236, 240, 249)
bg_color = (236, 240, 249, 255)

# Create a clean full-bleed canvas
full_bleed = Image.new("RGBA", (w, h), bg_color)

# Replace any dark grey pixels (the outer preview border where grey is (96, 96, 96))
for y in range(h):
    for x in range(w):
        pix = img.getpixel((x, y))
        # If it's the dark grey mock background (around 96, 96, 96)
        if pix[0] < 140 and pix[1] < 140 and pix[2] < 140:
            full_bleed.putpixel((x, y), bg_color)
        else:
            full_bleed.putpixel((x, y), pix)

# Save high-res master in project assets
assets_dir = r"e:\My Warranties\assets\brand_icons"
os.makedirs(assets_dir, exist_ok=True)
master_path = os.path.join(assets_dir, "my_warranties_mw_icon.png")
full_bleed.save(master_path, "PNG")
print("Saved clean full-bleed master to:", master_path)

# Update all Android mipmap resolutions
mipmaps = {
    r"e:\My Warranties\android\app\src\main\res\mipmap-mdpi": 48,
    r"e:\My Warranties\android\app\src\main\res\mipmap-hdpi": 72,
    r"e:\My Warranties\android\app\src\main\res\mipmap-xhdpi": 96,
    r"e:\My Warranties\android\app\src\main\res\mipmap-xxhdpi": 144,
    r"e:\My Warranties\android\app\src\main\res\mipmap-xxxhdpi": 192,
}

for folder, px in mipmaps.items():
    os.makedirs(folder, exist_ok=True)
    resized = full_bleed.resize((px, px), Image.Resampling.LANCZOS)
    resized.save(os.path.join(folder, "ic_launcher.png"), "PNG")
    print(f"Updated Android {folder} ({px}x{px})")

# Update Web icons & favicon
web_fav = r"e:\My Warranties\web\favicon.png"
full_bleed.resize((32, 32), Image.Resampling.LANCZOS).save(web_fav, "PNG")

web_icons = {
    r"e:\My Warranties\web\icons\Icon-192.png": 192,
    r"e:\My Warranties\web\icons\Icon-512.png": 512,
    r"e:\My Warranties\web\icons\Icon-maskable-192.png": 192,
    r"e:\My Warranties\web\icons\Icon-maskable-512.png": 512,
}
for path, px in web_icons.items():
    full_bleed.resize((px, px), Image.Resampling.LANCZOS).save(path, "PNG")
    print(f"Updated web icon {path} ({px}x{px})")

print("New MW icon successfully installed across Android and Web!")
