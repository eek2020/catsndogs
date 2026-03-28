from collections import Counter
import sys
from PIL import Image

try:
    img = Image.open('godot/assets/sprites/aristotle_spritesheet.png').convert("L")
    
    # We want to look at region (132, 82, 128, 120)
    # Let's resize it to 64x30 for terminal display
    frame = img.crop((130, 80, 130+130*3, 80+120))
    # resize proportional to terminal characters (roughly 1:2 aspect ratio)
    frame = frame.resize((100, 40), Image.NEAREST)
    
    w, h = frame.size
    p = frame.load()
    
    chars = "@%#*+=-:. "
    
    for y in range(h):
        line = ""
        for x in range(w):
            val = p[x, y]
            idx = int(val / 256.0 * len(chars))
            line += chars[idx]
        print(line)
        
except Exception as e:
    print(e)
