from PIL import Image

try:
    img = Image.open(
        "godot/assets/sprites/aristotle_spritesheet.png"
    ).convert("RGBA")
    w, h = img.size
    p = img.load()

    # We will ignore the top 4 background colors
    bg_colors = {
        (24, 20, 36, 255),
        (28, 24, 42, 255),
        (20, 18, 30, 255),
        (21, 18, 32, 209),
    }

    # Let's scan row 82 to 82+120 (the y-range of walk_down)
    # and find the horizontal segments of character pixels.
    active_cols = []

    for x in range(130, w):
        is_active = False
        for y in range(82, 82 + 120):
            r, g, b, a = p[x, y]
            if a > 10 and (r, g, b, a) not in bg_colors:
                # To be robust against noise, maybe we need to only count
                # if there is a cluster of pixels?
                # Let's count non-bg pixels in this column and adjacent ones?
                is_active = True
                break
        if is_active:
            active_cols.append(x)

    # segment them into contiguous blocks (allow up to 2px gap)
    segments = []
    start = None
    curr = None
    for x in active_cols:
        if start is None:
            start = x
            curr = x
        elif x <= curr + 5:  # allow 5px gaps inside a character
            curr = x
        else:
            segments.append((start, curr))
            start = x
            curr = x
    if start is not None:
        segments.append((start, curr))

    print("Found character blocks in Y-range 82..202 at X-coords:")
    for i, s in enumerate(segments):
        print(
            f"Frame {i}: X from {s[0]} to {s[1]} "
            f"(width {s[1] - s[0] + 1}), center {(s[0] + s[1]) // 2}"
        )

except Exception as e:
    print(e)
