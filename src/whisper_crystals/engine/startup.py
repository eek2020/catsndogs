"""Pygame startup visuals — splash screen and loading frames."""

from __future__ import annotations

import pygame

from whisper_crystals.core.config import SPLASH_DURATION_SECONDS


def show_startup_splash(screen: pygame.Surface, splash_art: pygame.Surface | None) -> bool:
    """Display startup splash briefly. Returns False if user closed window."""
    start_tick = pygame.time.get_ticks()
    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False
            if event.type in (pygame.KEYDOWN, pygame.MOUSEBUTTONDOWN):
                return True
        elapsed = (pygame.time.get_ticks() - start_tick) / 1000.0
        if elapsed >= SPLASH_DURATION_SECONDS:
            return True
        screen.fill((6, 8, 16))
        if splash_art is not None:
            _blit_scaled(screen, splash_art)
        pygame.display.flip()
        pygame.time.delay(16)


def show_loading_frame(
    screen: pygame.Surface, splash_art: pygame.Surface | None, message: str, progress: float
) -> bool:
    """Render one loading frame. Returns False if user closed window."""
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            return False
    sw, sh = screen.get_size()
    screen.fill((6, 8, 16))
    if splash_art is not None:
        _blit_scaled(screen, splash_art)
    panel = pygame.Surface((sw, sh), pygame.SRCALPHA)
    panel.fill((8, 10, 20, 120))
    screen.blit(panel, (0, 0))
    font = pygame.font.Font(None, 34)
    text_surf = font.render(message, True, (170, 210, 255))
    screen.blit(text_surf, ((sw - text_surf.get_width()) // 2, int(sh * 0.78)))
    pygame.display.flip()
    return True


def _blit_scaled(screen: pygame.Surface, image: pygame.Surface) -> None:
    """Scale an image to fit the screen and blit it centered."""
    iw, ih = image.get_size()
    sw, sh = screen.get_size()
    scale = min(sw / iw, sh / ih)
    scaled = pygame.transform.smoothscale(image, (int(iw * scale), int(ih * scale)))
    screen.blit(scaled, ((sw - scaled.get_width()) // 2, (sh - scaled.get_height()) // 2))
