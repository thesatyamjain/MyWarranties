from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math

def create_full_text_icon():
    size = 1024
    
    # Base: Apple HIG Grouped Mesh Canvas (same as app's backdrop)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y in range(size):
        for x in range(size):
            nx = x / size
            ny = y / size
            diag = (nx + ny) / 2.0
            if diag < 0.5:
                t = diag / 0.5
                r = int(222 + (242 - 222) * t)
                g = int(236 + (242 - 236) * t)
                b = int(255 + (247 - 255) * t)
            else:
                t = (diag - 0.5) / 0.5
                r = int(242 + (252 - 242) * t)
                g = int(242 + (233 - 242) * t)
                b = int(247 + (240 - 247) * t)
            img.putpixel((x, y), (r, g, b, 255))
            
    # Floating Frosted Liquid Glass Card inside icon
    lens_size = 780
    lens_offset = (size - lens_size) // 2
    
    # Shadow for glass card
    shadow_lens = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_lens)
    s_draw.rounded_rectangle(
        [lens_offset, lens_offset + 20, lens_offset + lens_size, lens_offset + lens_size + 20],
        radius=175,
        fill=(0, 20, 60, 36)
    )
    shadow_lens = shadow_lens.filter(ImageFilter.GaussianBlur(34))
    img = Image.alpha_composite(img, shadow_lens)
    
    # Glass Body
    lens = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    lens_draw = ImageDraw.Draw(lens)
    lens_draw.rounded_rectangle(
        [lens_offset, lens_offset, lens_offset + lens_size, lens_offset + lens_size],
        radius=175,
        fill=(255, 255, 255, 215),
        outline=(255, 255, 255, 250),
        width=3
    )
    img = Image.alpha_composite(img, lens)
    
    # Text: "MY" and "WARRANTIES" in Apple HIG Editorial Scale
    font_small = ImageFont.truetype(r"C:\Windows\Fonts\seguibl.ttf", 96) # "MY"
    font_large = ImageFont.truetype(r"C:\Windows\Fonts\seguibl.ttf", 380) # Big prominent "W" monogram
    font_sub = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 72) # "WARRANTIES"
    
    # Layout inside card:
    # 1. "MY" (Muted blue pill or pure text)
    # 2. Big tactile "W"
    # 3. "WARRANTIES" at bottom with tight letter spacing
    
    t_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    t_draw = ImageDraw.Draw(t_layer)
    
    # "MY" top text
    my_text = "MY"
    bbox_my = font_small.getbbox(my_text)
    my_w = bbox_my[2] - bbox_my[0]
    my_x = (size - my_w) // 2 - bbox_my[0]
    my_y = 210
    
    # Large "W"
    w_text = "W"
    bbox_w = font_large.getbbox(w_text)
    w_w = bbox_w[2] - bbox_w[0]
    w_h = bbox_w[3] - bbox_w[1]
    w_x = (size - w_w) // 2 - bbox_w[0]
    w_y = 310
    
    # "WARRANTIES" bottom
    sub_text = "WARRANTIES"
    bbox_sub = font_sub.getbbox(sub_text)
    sub_w = bbox_sub[2] - bbox_sub[0]
    sub_x = (size - sub_w) // 2 - bbox_sub[0]
    sub_y = 705
    
    # Soft drop shadows for typography
    t_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ts_draw = ImageDraw.Draw(t_shadow)
    ts_draw.text((my_x, my_y + 4), my_text, font=font_small, fill=(0, 122, 255, 60))
    ts_draw.text((w_x, w_y + 12), w_text, font=font_large, fill=(0, 122, 255, 70))
    ts_draw.text((sub_x, sub_y + 4), sub_text, font=font_sub, fill=(108, 108, 112, 60))
    t_shadow = t_shadow.filter(ImageFilter.GaussianBlur(14))
    img = Image.alpha_composite(img, t_shadow)
    
    # Top "MY" in Apple Blue (Pal.blue #007AFF)
    t_draw.text((my_x, my_y), my_text, font=font_small, fill=(0, 122, 255, 255))
    
    # Big "W" with Apple Sapphire Gradient
    # Mask for W
    w_mask = Image.new("L", (size, size), 0)
    wm_draw = ImageDraw.Draw(w_mask)
    wm_draw.text((w_x, w_y), w_text, font=font_large, fill=255)
    
    w_grad = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    wg_draw = ImageDraw.Draw(w_grad)
    for y in range(size):
        factor = y / size
        # #007AFF to #004BB5
        wg_draw.line([(0, y), (size, y)], fill=(0, int(122 * (1 - factor) + 75 * factor), int(255 * (1 - factor) + 181 * factor), 255))
    w_comp = Image.composite(w_grad, Image.new("RGBA", (size, size), (0, 0, 0, 0)), w_mask)
    
    # Bottom "WARRANTIES" in Pal.ink / Pal.muted
    t_draw.text((sub_x, sub_y), sub_text, font=font_sub, fill=(28, 28, 30, 240))
    
    img = Image.alpha_composite(img, w_comp)
    img = Image.alpha_composite(img, t_layer)
    
    out_path = r"C:\Users\hp\.gemini\antigravity\brain\c099322e-3bac-4fcc-a62f-23875d73a270\apple_text_brand_icon.png"
    img.save(out_path, "PNG")
    print("Saved text brand icon to:", out_path)

if __name__ == "__main__":
    create_full_text_icon()
