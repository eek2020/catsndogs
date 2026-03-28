import sys
from PIL import Image

try:
    img = Image.open('godot/assets/sprites/aristotle_spritesheet.png').convert("RGBA")
    w, h = img.size
    
    # Background color seems to be (12, 10, 20, 255) based on previous check, or transparent
    bg_color = (12, 10, 20, 255)
    
    # Let's find the bounding box of the actual characters in the first row
    # We will scan y from 82 to 210, x from 0 to w
    # and print the x-coordinates where character pixels are found.
    
    pixels = img.load()
    
    col_has_pixels = [False] * w
    row_has_pixels = [False] * h
    
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a > 0 and (r, g, b, a) != bg_color:
                col_has_pixels[x] = True
                row_has_pixels[y] = True
                
    # Find contiguous ranges of columns with pixels
    segments = []
    start = None
    for x in range(w):
        if col_has_pixels[x] and start is None:
            start = x
        elif not col_has_pixels[x] and start is not None:
            segments.append((start, x - 1))
            start = None
    if start is not None:
        segments.append((start, w - 1))
        
    print("X sequences of character pixels:")
    print(segments[:15]) # Print first few
    
    # Find contiguous ranges of rows with pixels
    y_segments = []
    start = None
    for y in range(h):
        if row_has_pixels[y] and start is None:
            start = y
        elif not row_has_pixels[y] and start is not None:
            y_segments.append((start, y - 1))
            start = None
    if start is not None:
        y_segments.append((start, h - 1))
        
    print("Y sequences of character pixels:")
    print(y_segments[:15])
    
except Exception as e:
    print("Error:", e)
