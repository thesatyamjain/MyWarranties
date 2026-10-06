from PIL import Image
import os

# Source images
opt1_path = r"C:\Users\hp\.gemini\antigravity\brain\c099322e-3bac-4fcc-a62f-23875d73a270\apple_monogram_w_icon.png"
opt4_path = r"C:\Users\hp\.gemini\antigravity\brain\c099322e-3bac-4fcc-a62f-23875d73a270\apple_text_icon_light.png"

# Target export folder for high-res master assets
assets_dir = r"e:\My Warranties\assets\brand_icons"
os.makedirs(assets_dir, exist_ok=True)

# Copy high-res masters to project assets
img1 = Image.open(opt1_path).convert("RGBA")
img4 = Image.open(opt4_path).convert("RGBA")

img1.save(os.path.join(assets_dir, "apple_icon_option1_monogram.png"), "PNG")
img4.save(os.path.join(assets_dir, "apple_icon_option4_liquid_glass.png"), "PNG")
print("Saved high-res masters to assets/brand_icons")

# Define target mipmap directories & dimensions
mipmaps = {
    r"e:\My Warranties\android\app\src\main\res\mipmap-mdpi": 48,
    r"e:\My Warranties\android\app\src\main\res\mipmap-hdpi": 72,
    r"e:\My Warranties\android\app\src\main\res\mipmap-xhdpi": 96,
    r"e:\My Warranties\android\app\src\main\res\mipmap-xxhdpi": 144,
    r"e:\My Warranties\android\app\src\main\res\mipmap-xxxhdpi": 192,
}

# 1. Update active app icon to Option 4 (Frosted Liquid Glass Card 'W')
# (and keep Option 1 available as alternative launcher icon: ic_launcher_alt.png)
for folder, px in mipmaps.items():
    os.makedirs(folder, exist_ok=True)
    
    # Primary: Option 4
    resized_4 = img4.resize((px, px), Image.Resampling.LANCZOS)
    resized_4.save(os.path.join(folder, "ic_launcher.png"), "PNG")
    
    # Alternate: Option 1
    resized_1 = img1.resize((px, px), Image.Resampling.LANCZOS)
    resized_1.save(os.path.join(folder, "ic_launcher_alt.png"), "PNG")
    print(f"Updated {folder} ({px}x{px})")

# 2. Update Web Icons
web_fav = r"e:\My Warranties\web\favicon.png"
img4.resize((32, 32), Image.Resampling.LANCZOS).save(web_fav, "PNG")

web_icons = {
    r"e:\My Warranties\web\icons\Icon-192.png": 192,
    r"e:\My Warranties\web\icons\Icon-512.png": 512,
    r"e:\My Warranties\web\icons\Icon-maskable-192.png": 192,
    r"e:\My Warranties\web\icons\Icon-maskable-512.png": 512,
}
for path, px in web_icons.items():
    img4.resize((px, px), Image.Resampling.LANCZOS).save(path, "PNG")
    print(f"Updated web icon {path} ({px}x{px})")

print("All Android and Web icons successfully updated!")
