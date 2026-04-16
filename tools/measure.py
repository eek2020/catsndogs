from PIL import Image

try:
    img = Image.open(
        "godot/assets/sprites/aristotle_spritesheet.png"
    ).convert("RGBA")
    frame = img.crop((130, 80, 130 + 128, 80 + 120))
    w, h = frame.size
    p = frame.load()

    # We found bg_color before: (12, 10, 20, 255)
    bg_color = (12, 10, 20, 255)

    # Find active columns
    active_cols = []
    for x in range(w):
        has_pixel = False
        for y in range(h):
            r, g, b, a = p[x, y]
            if a > 128 and (r, g, b, a) != bg_color:
                has_pixel = True
                break
        if has_pixel:
            active_cols.append(x)

    # Find contiguous blobs of active columns
    blobs = []
    start = None
    for x in active_cols:
        if start is None:
            start = x
            curr = x
        elif x == curr + 1:
            curr = x
        else:
            blobs.append((start, curr))
            start = x
            curr = x
    if start is not None:
        blobs.append((start, curr))

    print("Contiguous objects in X direction in an expected 128-width frame:")
    for b in blobs:
        print(f"X-range: {b[0]} to {b[1]}")

except Exception as e:
    print(e)
