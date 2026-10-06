from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math

def create_apple_typography_icons():
    size = 1024
    
    # ==========================================
    # VARIANT A: The Apple System "W" (Sapphire / Paper)
    # Inspired by Apple News, Shortcuts, Translate
    # Clean frosted liquid glass card hovering on ambient mesh
    # ==========================================
    img_a = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y in range(size):
        for x in range(size):
            nx = x / size
            ny = y / size
            diag = (nx + ny) / 2.0
            # Soft Apple Mesh: #DCEBFF -> #F2F2F7 -> #FCE7EE
            if diag < 0.5:
                t = diag / 0.5
                r = int(220 + (242 - 220) * t)
                g = int(235 + (242 - 235) * t)
                b = int(255 + (247 - 255) * t)
            else:
                t = (diag - 0.5) / 0.5
                r = int(242 + (252 - 242) * t)
                g = int(242 + (231 - 242) * t)
                b = int(247 + (238 - 247) * t)
            img_a.putpixel((x, y), (r, g, b, 255))
            
    # Add subtle central frosted squircle lens
    lens_size = 760
    lens_offset = (size - lens_size) // 2
    lens = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    lens_draw = ImageDraw.Draw(lens)
    
    # Shadow for glass lens
    shadow_lens = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_lens)
    s_draw.rounded_rectangle(
        [lens_offset, lens_offset + 18, lens_offset + lens_size, lens_offset + lens_size + 18],
        radius=175,
        fill=(0, 17, 51, 35)
    )
    shadow_lens = shadow_lens.filter(ImageFilter.GaussianBlur(32))
    img_a = Image.alpha_composite(img_a, shadow_lens)
    
    # Lens body: frosted translucent white
    lens_draw.rounded_rectangle(
        [lens_offset, lens_offset, lens_offset + lens_size, lens_offset + lens_size],
        radius=175,
        fill=(255, 255, 255, 205),
        outline=(255, 255, 255, 245),
        width=3
    )
    img_a = Image.alpha_composite(img_a, lens)
    
    # Letter "W" inside lens
    font = ImageFont.truetype(r"C:\Windows\Fonts\seguibl.ttf", 460)
    text = "W"
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (size - tw) // 2 - bbox[0]
    ty = (size - th) // 2 - bbox[1] - 10
    
    # Letter drop shadow
    w_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    w_s_draw = ImageDraw.Draw(w_shadow)
    w_s_draw.text((tx, ty + 12), text, font=font, fill=(0, 122, 255, 60))
    w_shadow = w_shadow.filter(ImageFilter.GaussianBlur(16))
    img_a = Image.alpha_composite(img_a, w_shadow)
    
    # Letter gradient (#007AFF -> #0051B3)
    grad = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(grad)
    for y in range(size):
        factor = y / size
        g_draw.line([(0, y), (size, y)], fill=(0, int(122 * (1 - factor) + 80 * factor), int(255 * (1 - factor) + 180 * factor), 255))
    mask = Image.new("L", (size, size), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.text((tx, ty), text, font=font, fill=255)
    w_color = Image.composite(grad, Image.new("RGBA", (size, size), (0, 0, 0, 0)), mask)
    img_a = Image.alpha_composite(img_a, w_color)
    
    # ==========================================
    # VARIANT B: Dark Sapphire "WARRANTIES" / Vault Monogram
    # Deep Emerald (#0A1B15 -> #102820) substrate matching app's Vault Hero Card
    # With frosted luminous neon-emerald / platinum typography
    # ==========================================
    img_b = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y in range(size):
        for x in range(size):
            factor = y / size
            r = int(10 * (1 - factor) + 16 * factor)
            g = int(27 * (1 - factor) + 40 * factor)
            b = int(21 * (1 - factor) + 32 * factor)
            img_b.putpixel((x, y), (r, g, b, 255))
            
    # Floating emerald glass badge
    lens_b = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    l_draw_b = ImageDraw.Draw(lens_b)
    l_draw_b.rounded_rectangle(
        [lens_offset, lens_offset, lens_offset + lens_size, lens_offset + lens_size],
        radius=175,
        fill=(255, 255, 255, 18),
        outline=(110, 231, 183, 100), # Emerald rim
        width=2
    )
    img_b = Image.alpha_composite(img_b, lens_b)
    
    # Glowing "W" monogram in Emerald / White
    w_shadow_b = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    w_sb_draw = ImageDraw.Draw(w_shadow_b)
    w_sb_draw.text((tx, ty), text, font=font, fill=(110, 231, 183, 160)) # Emerald glow
    w_shadow_b = w_shadow_b.filter(ImageFilter.GaussianBlur(30))
    img_b = Image.alpha_composite(img_b, w_shadow_b)
    
    # Foreground letter in crisp white with emerald gradient
    grad_b = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gb_draw = ImageDraw.Draw(grad_b)
    for y in range(size):
        factor = y / size
        gb_draw.line([(0, y), (size, y)], fill=(int(240 * (1 - factor) + 110 * factor), 255, int(240 * (1 - factor) + 183 * factor), 255))
    w_color_b = Image.composite(grad_b, Image.new("RGBA", (size, size), (0, 0, 0, 0)), mask)
    img_b = Image.alpha_composite(img_b, w_color_b)
    
    # Save both variants
    path_a = r"C:\Users\hp\.gemini\antigravity\brain\c099322e-3bac-4fcc-a62f-23875d73a270\apple_text_icon_light.png"
    path_b = r"C:\Users\hp\.gemini\antigravity\brain\c099322e-3bac-4fcc-a62f-23875d73a270\apple_text_icon_dark.png"
    img_a.save(path_a, "PNG")
    img_b.save(path_b, "PNG")
    print("Saved variants:", path_a, path_b)

if __name__ == "__main__":
    create_apple_typography_icons()
