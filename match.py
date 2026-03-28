from PIL import Image
import sys

try:
    img = Image.open('godot/assets/sprites/aristotle_spritesheet.png').convert("RGBA")
    w, h = img.size
    p = img.load()
    
    bg_colors = {
        (24, 20, 36, 255),
        (28, 24, 42, 255),
        (20, 18, 30, 255),
        (21, 18, 32, 209)
    }
    
    # We will compute sum of absolute differences to find where Frame 1, 2, 3 are relative to Frame 0
    # Let's assume Frame 0 is centered around X=211. Let's take [160, 260] as the template string.
    
    Y = 82
    def get_template(x_start):
        # return a list of lists of alpha/intensity?
        # Let's just use a simple binary mask: 1 if pixel is character, 0 if bg
        mask = []
        for x in range(x_start, x_start + 100):
            col = []
            for y in range(Y, Y+120):
                r,g,b,a = p[x,y]
                col.append(1 if a > 10 and (r,g,b,a) not in bg_colors else 0)
            mask.append(col)
        return mask
        
    t0 = get_template(160) # Frame 0 template
    
    # Search for Frame 1, which should be around X=290
    for frame_idx in range(1, 4):
        best_diff = 999999
        best_x = 0
        search_start = 160 + frame_idx * 120
        search_end = 160 + frame_idx * 140
        for x in range(search_start, search_end):
            t1 = get_template(x)
            diff = 0
            for i in range(100):
                for j in range(120):
                    if t0[i][j] != t1[i][j]:
                        diff += 1
            if diff < best_diff:
                best_diff = diff
                best_x = x
        print(f"Frame {frame_idx} best match relative to x=160 happens at x={best_x}. Distance: {best_x - 160}")

except Exception as e:
    print(e)
