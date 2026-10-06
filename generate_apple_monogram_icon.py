from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_apple_monogram_icon():
    size = 1024
    
    # Full bleed background: Apple Mesh Canvas (#DCEBFF -> #F3F3F8 -> #FCE7EE)
    # Matching app's exact glassBackdrop
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y in range(size):
        for x in range(size):
            nx = x / size
            ny = y / size
            diag = (nx + ny) / 2.0
            if diag < 0.5:
                t = diag / 0.5
                r = int(220 + (243 - 220) * t)
                g = int(235 + (243 - 235) * t)
                b = int(255 + (248 - 255) * t)
            else:
                t = (diag - 0.5) / 0.5
                r = int(243 + (252 - 243) * t)
                g = int(243 + (231 - 243) * t)
                b = int(248 + (238 - 248) * t)
            img.putpixel((x, y), (r, g, b, 255))
            
    # Central Tactile Monogram: "W" (in Apple SF Pro heavy display style)
    # Exactly like Apple News ('N'), Stocks, Translate, Shortcuts
    font_size = 560
    font = ImageFont.truetype(r"C:\Windows\Fonts\seguibl.ttf", font_size)
    text = "W"
    
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (size - tw) // 2 - bbox[0]
    ty = (size - th) // 2 - bbox[1] - 8
    
    # 1. Soft ambient elevation shadow (Apple iOS layer depth)
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    # Deep contact shadow + soft blue ambient bloom
    s_draw.text((tx, ty + 24), text, font=font, fill=(0, 122, 255, 65))
    s_draw.text((tx, ty + 36), text, font=font, fill=(15, 23, 42, 40))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    img = Image.alpha_composite(img, shadow)
    
    # 2. Main Letter Body: Apple Sapphire Gradient (#007AFF -> #0050B8)
    w_mask = Image.new("L", (size, size), 0)
    wm_draw = ImageDraw.Draw(w_mask)
    wm_draw.text((tx, ty), text, font=font, fill=255)
    
    grad = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(grad)
    for y in range(size):
        factor = y / size
        # #007AFF to #0052BF
        r = 0
        g = int(122 * (1 - factor) + 82 * factor)
        b = int(255 * (1 - factor) + 191 * factor)
        g_draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
        
    letter_body = Image.composite(grad, Image.new("RGBA", (size, size), (0, 0, 0, 0)), w_mask)
    img = Image.alpha_composite(img, letter_body)
    
    # 3. Specular Upper Rim Highlight (simulate physical bevel / glass reflection)
    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    r_draw = ImageDraw.Draw(rim)
    r_draw.text((tx, ty - 3), text, font=font, fill=(255, 255, 255, 140))
    rim = rim.filter(ImageFilter.GaussianBlur(3))
    rim_clipped = Image.composite(rim, Image.new("RGBA", (size, size), (0, 0, 0, 0)), w_mask)
    img = Image.alpha_composite(img, rim_clipped)
    
    # 4. Save high-res master
    master_path = r"C:\Users\hp\.gemini\antigravity\brain\c099322e-3bac-4fcc-a62f-23875d73a270\apple_monogram_w_icon.png"
    img.save(master_path, "PNG")
    print("Saved master monogram icon to:", master_path)

if __name__ == "__main__":
    create_apple_monogram_icon()
