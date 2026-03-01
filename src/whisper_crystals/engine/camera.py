"""Camera / viewport system for 2D scrolling."""


class Camera:
    """Tracks a target position and converts world coords to screen coords."""

    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.x: float = 0.0
        self.y: float = 0.0

    def world_to_screen(self, world_pos: tuple[float, float]) -> tuple[int, int]:
        """Convert a world position to a screen position."""
        return (int(world_pos[0] - self.x), int(world_pos[1] - self.y))

    def follow(
        self,
        target_pos: tuple[float, float],
        dt: float,
        smoothing: float = 5.0,
    ) -> None:
        """Smoothly follow a target position."""
        self.x += (target_pos[0] - self.width / 2 - self.x) * smoothing * dt
        self.y += (target_pos[1] - self.height / 2 - self.y) * smoothing * dt
