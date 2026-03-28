from PIL import Image
import sys

try:
    img = Image.open('godot/assets/sprites/aristotle_spritesheet.png').convert("RGBA")
    w, h = img.size
    p = img.load()
    
    # We will find which columns are COMPLETELY empty (or completely background)
    # This will let us see where the frames ACTUALLY are.
    
    # First find the most common color (probably background)
    from collections import Counter
    c = Counter(img.getdata())
    bg = c.most_common(1)[0][0]
    
    def is_pixel_empty(x, y):
        r, g, b, a = p[x, y]
        if a < 10: return True
        if (r, g, b, a) == bg: return True
        return False

    empty_cols = []
    for x in range(w):
        is_empty = True
        for y in range(h):
            if not is_pixel_empty(x, y):
                is_empty = False
                break
        if is_empty:
            empty_cols.append(x)
            
    print("Empty columns:", empty_cols)

except Exception as e:
    print(e)
