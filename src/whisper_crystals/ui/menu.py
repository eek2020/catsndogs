"""Main menu state — title screen with New Game / Quit."""

from __future__ import annotations

import math

import pygame

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType
from whisper_crystals.engine.starfield import Starfield


class MenuState(GameState):
    """Initial state: handles New Game / Quit."""

    state_type = GameStateType.MENU

    def __init__(
        self,
        machine: GameStateMachine,
        on_new_game: callable,
        on_quit: callable,
        splash_art: pygame.Surface | None = None,
    ) -> None:
        super().__init__(machine)
        self._on_new_game = on_new_game
        self._on_quit = on_quit
        self._splash_art = splash_art

        self._options = ["New Game", "Quit"]
        self._selected_index = 0
        
        # Decorative background elements
        self._starfield = Starfield(num_stars=200, seed=123)
        self._time = 0.0

    def enter(self) -> None:
        self._selected_index = 0
        self._time = 0.0

    def exit(self) -> None:
        pass

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if action in (Action.MOVE_UP, Action.MENU_UP):
                self._selected_index = (self._selected_index - 1) % len(self._options)
            elif action in (Action.MOVE_DOWN, Action.MENU_DOWN):
                self._selected_index = (self._selected_index + 1) % len(self._options)
            elif action == Action.CONFIRM:
                if self._selected_index == 0:
                    self._on_new_game()
                elif self._selected_index == 1:
                    self._on_quit()

    def update(self, dt: float) -> None:
        self._time += dt
        # Slowly pan the starfield for menu ambiance
        self._starfield.draw  # starfield doesn't have an update method, we pass coordinates in draw

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()

        if self._splash_art is not None and hasattr(renderer, "screen"):
            iw, ih = self._splash_art.get_size()
            scale = max(sw / iw, sh / ih)
            bg = pygame.transform.smoothscale(self._splash_art, (int(iw * scale), int(ih * scale)))
            bx = (sw - bg.get_width()) // 2
            by = (sh - bg.get_height()) // 2
            renderer.screen.blit(bg, (bx, by))
        else:
            renderer.draw_rect((0, 0, sw, sh), (7, 12, 26))
            pan_x = self._time * 10.0
            pan_y = self._time * 4.0
            self._starfield.draw(renderer, pan_x, pan_y)

        # Atmospheric overlays to keep menu legible on the title art
        renderer.draw_rect((0, 0, sw, sh), (6, 14, 34, 115))
        renderer.draw_rect((0, int(sh * 0.55), sw, int(sh * 0.45)), (4, 10, 24, 170))

        panel_w = min(560, sw - 80)
        panel_h = 190
        panel_x = (sw - panel_w) // 2
        panel_y = int(sh * 0.60)
        renderer.draw_rect((panel_x, panel_y, panel_w, panel_h), (8, 22, 48, 170))
        renderer.draw_line((panel_x, panel_y), (panel_x + panel_w, panel_y), (86, 209, 255), 2)
        renderer.draw_line(
            (panel_x, panel_y + panel_h),
            (panel_x + panel_w, panel_y + panel_h),
            (26, 88, 140),
            1,
        )

        renderer.draw_text(
            "Choose Your Course",
            (panel_x + 150, panel_y + 18),
            size=30,
            color=(198, 237, 255),
        )

        start_y = panel_y + 70
        for i, opt in enumerate(self._options):
            y = start_y + i * 60
            if i == self._selected_index:
                pulse = 0.45 + 0.35 * (math.sin(self._time * 6.0) + 1.0)
                glow_w = panel_w - 70
                renderer.draw_rect((panel_x + 35, y - 8, glow_w, 42), (20, 72, 120, int(110 * pulse)))
                renderer.draw_text(">", (panel_x + 46, y), size=26, color=(145, 233, 255))
                color = (232, 250, 255)
            else:
                color = (152, 187, 210)

            renderer.draw_text(opt.upper(), (panel_x + 86, y), size=28, color=color)

        # Footer
        renderer.draw_text(
            "v0.1.0  |  Arrow Keys / WASD to select  |  Enter to confirm",
            (sw // 2 - 260, sh - 34),
            size=14,
            color=(146, 187, 214),
        )
