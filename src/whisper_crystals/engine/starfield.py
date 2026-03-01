"""Simple parallax starfield background."""

import random

from whisper_crystals.core.interfaces import RenderInterface


class Star:
    __slots__ = ("x", "y", "brightness", "depth")

    def __init__(self, x: float, y: float, brightness: int, depth: float) -> None:
        self.x = x
        self.y = y
        self.brightness = brightness
        self.depth = depth  # 0.1 (far) to 1.0 (near) — parallax multiplier


class Starfield:
    """Generates and draws a parallax star layer."""

    def __init__(
        self,
        num_stars: int = 200,
        area_width: int = 4000,
        area_height: int = 4000,
        seed: int | None = None,
    ) -> None:
        self.area_width = area_width
        self.area_height = area_height
        rng = random.Random(seed)
        self.stars: list[Star] = []
        for _ in range(num_stars):
            depth = rng.choice([0.15, 0.3, 0.5, 0.8, 1.0])
            brightness = int(80 + depth * 175)
            self.stars.append(
                Star(
                    x=rng.uniform(-area_width / 2, area_width / 2),
                    y=rng.uniform(-area_height / 2, area_height / 2),
                    brightness=min(brightness, 255),
                    depth=depth,
                )
            )

    def draw(
        self,
        renderer: RenderInterface,
        camera_x: float,
        camera_y: float,
    ) -> None:
        """Draw stars with parallax offset relative to camera."""
        sw, sh = renderer.get_screen_size()
        for star in self.stars:
            sx = int((star.x - camera_x * star.depth) % self.area_width - self.area_width / 2 + sw / 2)
            sy = int((star.y - camera_y * star.depth) % self.area_height - self.area_height / 2 + sh / 2)
            if 0 <= sx < sw and 0 <= sy < sh:
                c = star.brightness
                size = max(1, int(star.depth * 3))
                renderer.draw_circle((sx, sy), size, (c, c, c))
