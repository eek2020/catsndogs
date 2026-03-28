import sys
from PIL import Image

try:
    img = Image.open('godot/assets/sprites/aristotle_spritesheet.png').convert("RGBA")
    print(f"Size: {img.width}x{img.height}")

    # Let's check some pixels in the first row
    # x = 132, y = 82, w = 128, h = 120
    frame1 = img.crop((132, 82, 132+128, 82+120))
    bbox = frame1.getbbox()
    print(f"Frame 1 (132, 82) content bounding box: {bbox}")

    # let's check distance between frames
    row1 = img.crop((132, 82, 1172, 82+120))
    alpha = row1.split()[-1]
    non_empty_cols = []
    for x in range(alpha.width):
        col = alpha.crop((x, 0, x+1, alpha.height))
        if col.getbbox() is not None:
            non_empty_cols.append(x)

    # find contiguous segments
    segments = []
    start = None
    for i, x in enumerate(non_empty_cols):
        if start is None:
            start = x
        if i == len(non_empty_cols) - 1 or non_empty_cols[i+1] > x + 5: # gap of >5px
            segments.append((start, x))
            start = None
    print("Non-empty segments in row 1 (x-offsets from 132):", segments)
except Exception as e:
    print(e)
