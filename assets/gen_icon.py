from PIL import Image, ImageDraw
import math

SIZE = 1024

# ---------- Warna tema hacker ----------
PURPLE = (106, 0, 255)
CYAN = (0, 229, 255)
GREEN = (0, 255, 170)

# ---------- Diagonal gradient background ----------
def make_gradient(size=SIZE):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            # ungu -> biru -> cyan, lalu sedikit gelap di pinggir kanan-bawah
            r = int(PURPLE[0] * (1 - t) + (0) * t)
            g = int(PURPLE[1] * (1 - t) + (229) * t)
            b = int(PURPLE[2] * (1 - t) + (255) * t)
            px[x, y] = (r, g, b)
    return img

# ---------- Grafis teknis ----------
def add_matrix_pixels(img, size=SIZE):
    draw = ImageDraw.Draw(img, "RGBA")
    # grid kecil "digital matrix" (dedaunan biner) di area atas
    cell = 16
    for gy in range(2, 10):
        for gx in range(2, 10):
            if (gx + gy) % 3 == 0:
                x1 = gx * cell * 3.3
                y1 = gy * cell * 3.3
                w = cell * 1.4
                h = cell * 1.4
                col = (0, 229, 255, 110) if (gx % 2 == 0) else (106, 0, 255, 110)
                draw.rectangle([x1, y1, x1 + w, y1 + h], fill=col)
    return draw

def add_waveform(img, y_center, size=SIZE):
    draw = ImageDraw.Draw(img, "RGBA")
    n = 24
    start = size * 0.20
    gap = (size * 0.60) / (n - 1)
    for i in range(n):
        x = int(start + i * gap)
        amp = int(size * 0.10 * (0.5 + 0.5 * abs(math.sin(i * 0.55))))
        hh = max(6, amp)
        top = y_center - hh // 2
        bot = y_center + hh // 2
        col = CYAN if i % 2 == 0 else GREEN
        draw.rectangle([x, top, x + 18, bot], fill=col + (235,))
    return draw

def add_play_button(img, size=SIZE):
    cx, cy = size * 0.5, size * 0.5
    r = int(size * 0.16)
    draw = ImageDraw.Draw(img, "RGBA")
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(20, 20, 40, 220),
                 outline=(0, 229, 255, 255), width=6)
    # segitiga play
    pts = [(cx - r * 0.38, cy - r * 0.62),
           (cx - r * 0.38, cy + r * 0.62),
           (cx + r * 0.72, cy)]
    draw.polygon(pts, fill=(0, 255, 170, 255))
    return draw

# ============ ICON UTAMA (legacy, full bg) ============
img = make_gradient()
add_matrix_pixels(img)
add_waveform(img, y_center=img.height * 0.32)
add_play_button(img)
img = img.resize((SIZE, SIZE), Image.LANCZOS)
img.save("assets/icon/icon.png")
print("icon.png OK", img.size)

# ============ ICON FOREGROUND (transparan, utk adaptive) ============
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
add_waveform(fg, y_center=fg.height * 0.32)
add_play_button(fg)
fg.save("assets/icon/icon_foreground.png")
print("icon_foreground.png OK", fg.size)
