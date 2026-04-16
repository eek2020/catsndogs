from PIL import Image

try:
    img = Image.open(
        "godot/assets/sprites/aristotle_spritesheet.png"
    ).convert("RGBA")
    w, h = img.size

    bg_color = (12, 10, 20, 255)

    def get_character_bbox(crop_rect):
        x1, y1, x2, y2 = crop_rect
        frame = img.crop(crop_rect)
        p = frame.load()
        fw, fh = frame.size
        min_x, max_x = fw, -1
        min_y, max_y = fh, -1

        for y in range(fh):
            for x in range(fw):
                r, g, b, a = p[x, y]
                if a > 10 and (r, g, b, a) != bg_color:
                    if x < min_x:
                        min_x = x
                    if x > max_x:
                        max_x = x
                    if y < min_y:
                        min_y = y
                    if y > max_y:
                        max_y = y
        return (min_x, min_y, max_x, max_y)

    print("Bounding boxes in the supposed frames (132, 262, 392, 522):")
    for X in [132, 262, 392, 522]:
        bbox = get_character_bbox((X, 82, X + 128, 82 + 120))
        print(f"X={X} -> internal bbox: {bbox}")

    print("Bounding boxes in 128 px spaced frames (132, 260, 388, 516):")
    for X in [132, 132 + 128, 132 + 128 * 2, 132 + 128 * 3]:
        bbox = get_character_bbox((X, 82, X + 128, 82 + 120))
        print(f"X={X} -> internal bbox: {bbox}")

except Exception as e:
    print(e)
