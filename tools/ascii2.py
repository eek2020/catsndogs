from collections import Counter
from PIL import Image

try:
    img = Image.open(
        "godot/assets/sprites/aristotle_spritesheet.png"
    ).convert("RGBA")
    w, h = img.size
    pixels = img.getdata()

    # most common color as background
    c = Counter(pixels)
    bg_color = c.most_common(1)[0][0]

    # find where the first character starts
    # we scan the region from (100 to 700, 50 to 200) let's say

    p2 = img.load()

    # Print a tiny representation of row 82 to 210, column 130 to 260
    for y in range(80, 200, 2):
        line = ""
        for x in range(130, 260, 2):
            if p2[x, y] == bg_color or p2[x, y][3] < 128:
                line += " "
            else:
                line += "#"
        print(line)
except Exception as e:
    print(e)
