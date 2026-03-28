import sys
from PIL import Image
from collections import Counter

try:
    img = Image.open('godot/assets/sprites/aristotle_spritesheet.png').convert("RGBA")
    c = Counter(img.getdata())
    print("Number of unique colors:", len(c))
    print("Top 10 colors:")
    for color, count in c.most_common(10):
        print(f"Color {color}: {count} pixels")
except Exception as e:
    print(e)
