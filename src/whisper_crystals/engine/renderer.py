"""Pygame renderer — implements RenderInterface with advanced effects."""

import math
import random

import pygame

from whisper_crystals.core.interfaces import RenderInterface
from whisper_crystals.engine.camera import Camera


class PygameRenderer(RenderInterface):
    """Draws to a Pygame display surface via the Camera viewport."""

    def __init__(self, screen: pygame.Surface, camera: Camera) -> None:
        self.screen = screen
        self.camera = camera
        self._font_cache: dict[tuple[str | None, int], pygame.font.Font] = {}
        # Cache surfaces for glowing effects to save FPS
        self._glow_cache: dict[tuple[int, tuple], pygame.Surface] = {}

    def _get_font(self, font_id: str | None, size: int) -> pygame.font.Font:
        key = (font_id, size)
        if key not in self._font_cache:
            self._font_cache[key] = pygame.font.Font(font_id, size)
        return self._font_cache[key]

    # -- RenderInterface implementation --

    def clear(self) -> None:
        self.screen.fill((6, 12, 24))  # Deep navy base inspired by splash art

    def draw_sprite(self, sprite_id: str, world_pos: tuple[float, float]) -> None:
        screen_pos = self.camera.world_to_screen(world_pos)
        pygame.draw.circle(self.screen, (255, 255, 255), screen_pos, 10)

    def draw_text(
        self,
        text: str,
        pos: tuple[int, int],
        font_id: str | None = None,
        color: tuple[int, int, int] = (255, 255, 255),
        size: int = 24,
        shadow: bool = True,
    ) -> None:
        font = self._get_font(font_id, size)

        # Keep body text crisp; only add a subtle shadow on larger headings.
        antialias = size >= 16
        if shadow and size >= 26:
            shadow_surf = font.render(text, antialias, (8, 16, 30))
            shadow_surf.set_alpha(110)
            self.screen.blit(shadow_surf, (pos[0] + 1, pos[1] + 1))

        surface = font.render(text, antialias, color)
        self.screen.blit(surface, pos)

    def draw_rect(
        self,
        rect: tuple[int, int, int, int],
        color: tuple[int, int, int, int] | tuple[int, int, int],
        width: int = 0,
    ) -> None:
        if len(color) == 4 and color[3] < 255:
            # Alpha rectangle
            surf = pygame.Surface((rect[2], rect[3]), pygame.SRCALPHA)
            pygame.draw.rect(surf, color, (0, 0, rect[2], rect[3]), width)
            self.screen.blit(surf, (rect[0], rect[1]))
        else:
            pygame.draw.rect(self.screen, color[:3], pygame.Rect(*rect), width)

    def draw_polygon(
        self,
        points: list[tuple[float, float]],
        color: tuple[int, int, int, int] | tuple[int, int, int],
        width: int = 0,
    ) -> None:
        if len(color) == 4 and color[3] < 255:
            # Alpha polygon - need a bounding box
            min_x = min(p[0] for p in points)
            max_x = max(p[0] for p in points)
            min_y = min(p[1] for p in points)
            max_y = max(p[1] for p in points)
            surf = pygame.Surface((max_x - min_x, max_y - min_y), pygame.SRCALPHA)
            local_points = [(p[0] - min_x, p[1] - min_y) for p in points]
            pygame.draw.polygon(surf, color, local_points, width)
            self.screen.blit(surf, (min_x, min_y))
        else:
            pygame.draw.polygon(self.screen, color[:3], points, width)

    def draw_circle(
        self,
        center: tuple[int, int],
        radius: int,
        color: tuple[int, int, int, int] | tuple[int, int, int],
        width: int = 0,
    ) -> None:
        if len(color) == 4 and color[3] < 255:
            surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(surf, color, (radius, radius), radius, width)
            self.screen.blit(surf, (center[0] - radius, center[1] - radius))
        else:
            pygame.draw.circle(self.screen, color[:3], center, radius, width)

    def draw_image(
        self,
        image: object,
        pos: tuple[int, int],
        size: tuple[int, int] | None = None,
        rotation: float | None = None,
        centered: bool = False,
    ) -> None:
        surf = image
        if size is not None:
            surf = pygame.transform.smoothscale(surf, (max(1, size[0]), max(1, size[1])))
        if rotation is not None:
            surf = pygame.transform.rotozoom(surf, -rotation, 1.0)
        if centered:
            rect = surf.get_rect(center=pos)
            self.screen.blit(surf, rect)
        else:
            self.screen.blit(surf, pos)

    def get_image_size(self, image: object) -> tuple[int, int]:
        return image.get_size()

    def measure_text(self, text: str, size: int = 24) -> tuple[int, int]:
        font = self._get_font(None, size)
        return font.size(text)

    def get_screen_size(self) -> tuple[int, int]:
        return self.screen.get_size()

    def present(self) -> None:
        pygame.display.flip()

    # --- Advanced Extensions (Engine Specific for phase 1) ---

    def draw_glow(self, center: tuple[int, int], radius: int, color: tuple[int, int, int]) -> None:
        """Draws an additive-blended soft glow."""
        key = (radius, color)
        if key not in self._glow_cache:
            surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            for r in range(radius, 0, -2):
                alpha = int(255 * (1 - (r / radius))**2)
                pygame.draw.circle(surf, (*color, alpha), (radius, radius), r)
            self._glow_cache[key] = surf
            
        self.screen.blit(self._glow_cache[key], (center[0] - radius, center[1] - radius), special_flags=pygame.BLEND_RGB_ADD)

    def draw_nebula(self, center: tuple[int, int], radius: int, color: tuple[int, int, int], timer: float) -> None:
        """Draws a soft-edged nebula cloud with slightly noisy texture, cyan glow and darker vortex."""
        # 1. Background Cyan Glow
        self.draw_glow(center, radius, (0, 255, 255))
        
        # 2. Main Body with Noise
        # Create or fetch a cached surface for the noise/texture so we don't recalculate it every frame
        key = ("nebula_cloud", radius)
        if key not in self._glow_cache:
            surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            
            # Darker center vortex
            pygame.draw.circle(surf, (0, 10, 30, 180), (radius, radius), int(radius * 0.5))
            pygame.draw.circle(surf, (0, 5, 15, 250), (radius, radius), int(radius * 0.2))
            
            # Noisy texture using overlapping alpha circles
            for _ in range(int(radius * 2)):
                rad = random.uniform(0, radius * 0.9)
                ang = random.uniform(0, math.pi * 2)
                cx = radius + int(math.cos(ang) * rad)
                cy = radius + int(math.sin(ang) * rad)
                size = random.randint(1, max(3, int(radius * 0.15)))
                alpha = random.randint(20, 100)
                # Scatter in the main color
                pygame.draw.circle(surf, (*color, alpha), (cx, cy), size)
                
            self._glow_cache[key] = surf
            
        # Draw and slowly rotate the nebula
        surf = self._glow_cache[key]
        # Rotate by timer (e.g. 5 degrees per second)
        angle = timer * 15.0
        rotated = pygame.transform.rotate(surf, angle)
        rect = rotated.get_rect(center=center)
        self.screen.blit(rotated, rect.topleft)

    def draw_line(self, start: tuple[int, int], end: tuple[int, int], color: tuple[int, int, int], width: int = 1) -> None:
        pygame.draw.line(self.screen, color, start, end, width)
