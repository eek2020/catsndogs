"""Entry point for Whisper Crystals: python -m whisper_crystals"""

from __future__ import annotations

import os

import pygame

from whisper_crystals.core.config import FPS, SCREEN_HEIGHT, SCREEN_WIDTH
from whisper_crystals.core.logger import setup_logging
from whisper_crystals.core.session import GameSession
from whisper_crystals.core.state_machine import GameStateMachine
from whisper_crystals.engine.camera import Camera
from whisper_crystals.engine.image_utils import load_image, load_image_alpha, remove_near_white_bg
from whisper_crystals.engine.input_handler import PygameInputHandler
from whisper_crystals.engine.renderer import PygameRenderer
from whisper_crystals.engine.startup import show_loading_frame, show_startup_splash
from whisper_crystals.engine.audio import PygameAudio
from whisper_crystals.engine.sprite_manager import SpriteManager


def _resolve_project_root() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(os.path.dirname(here))


def _load_art(root: str) -> tuple:
    """Load all artwork assets. Returns (splash, intro_title, aristotle, dave, combat_bg)."""
    splash = load_image(os.path.join(root, "design", "artwork", "wc_splash_screen.png"))
    combat_bg = load_image(os.path.join(root, "design", "ui_ux", "combat_background.png"))
    paths = {
        "intro_title": os.path.join(root, "design", "artwork", "whisper_crystals_title.png"),
        "aristotle": os.path.join(root, "design", "charcters", "aristotle.png"),
        "dave": os.path.join(root, "design", "charcters", "dave.png"),
    }
    images = {}
    for key, path in paths.items():
        img = load_image_alpha(path)
        images[key] = remove_near_white_bg(img) if img is not None else None
    return splash, images["intro_title"], images["aristotle"], images["dave"], combat_bg


def main() -> None:
    setup_logging()
    root = _resolve_project_root()
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("Whisper Crystals")
    clock = pygame.time.Clock()

    splash_art, intro_title, aristotle, dave, combat_bg = _load_art(root)

    if not show_startup_splash(screen, splash_art):
        pygame.quit()
        return

    camera = Camera(SCREEN_WIDTH, SCREEN_HEIGHT)
    renderer = PygameRenderer(screen, camera)
    input_handler = PygameInputHandler()
    audio = PygameAudio(root)
    sprites = SpriteManager(root)
    sprites.preload_all()

    session = GameSession(
        data_root=os.path.join(root, "data"),
        camera=camera,
        input_handler=input_handler,
        state_machine=GameStateMachine(),
        audio_subsystem=audio,
        sprite_manager=sprites,
        combat_bg=combat_bg,
    )

    # Wire loading screen into new-game flow
    original_start = session.start_new_game
    session.start_new_game = lambda: original_start(
        on_loading_frame=lambda msg, prog: show_loading_frame(screen, splash_art, msg, prog),
        intro_title_art=intro_title,
        aristotle_art=aristotle,
        dave_art=dave,
    )
    session.push_menu(splash_art=splash_art)

    while session.running:
        dt = min(clock.tick(FPS) / 1000.0, 0.1)  # Cap dt to prevent jumps after hitches
        events = pygame.event.get()
        input_handler.process_events(events)
        if input_handler.should_quit():
            break
        if not session.tick(dt):
            break
        session.render(renderer)

    pygame.quit()


if __name__ == "__main__":
    main()
