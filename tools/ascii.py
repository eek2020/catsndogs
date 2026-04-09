from PIL import Image

try:
    img = Image.open(
        "godot/assets/sprites/aristotle_spritesheet.png"
    ).convert("RGBA")

    # Let's crop Rect2(132, 82, 128, 120)
    frame = img.crop((132, 82, 132 + 128, 82 + 120))

    bg_color = (12, 10, 20, 255)

    # Scale down for ASCII art: 128x120 -> 64x30
    frame = frame.resize((64, 30), Image.NEAREST)

    w, h = frame.size
    pixels = frame.load()

    for y in range(h):
        line = ""
        for x in range(w):
            r, g, b, a = pixels[x, y]
            # assume transparent or bg_color is background
            if a < 128 or (r, g, b, a) == bg_color:
                line += " "
            else:
                line += "#"
        print(line)
except Exception as e:
    print("Error:", e)
