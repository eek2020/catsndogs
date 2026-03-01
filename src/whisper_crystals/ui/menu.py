"""Main menu state — title screen with New Game / Load Game / Quit."""

from __future__ import annotations

import math
from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType
from whisper_crystals.engine.starfield import Starfield

if TYPE_CHECKING:
    from whisper_crystals.core.save_manager import SaveManager


class MenuState(GameState):
    """Initial state: handles New Game / Load Game / Quit."""

    state_type = GameStateType.MENU

    def __init__(
        self,
        machine: GameStateMachine,
        on_new_game: callable,
        on_quit: callable,
        on_load_game: callable | None = None,
        splash_art: object | None = None,
        save_manager: SaveManager | None = None,
    ) -> None:
        super().__init__(machine)
        self._on_new_game = on_new_game
        self._on_load_game = on_load_game
        self._on_quit = on_quit
        self._splash_art = splash_art
        self._save_manager = save_manager

        self._options: list[str] = ["New Game"]
        # Show load slots inline: "Load Slot 1 — Aristotle (Arc 1)"
        self._load_slots: list[dict | None] = []
        self._load_start_index = 1  # index where load slots begin in _options
        self._quit_index = 1
        self._selected_index = 0

        self._starfield = Starfield(num_stars=200, seed=123)
        self._time = 0.0

    def _build_options(self) -> None:
        """Rebuild menu options list based on available save slots."""
        self._options = ["New Game"]
        self._load_slots = []
        self._load_start_index = 1

        if self._save_manager and self._on_load_game:
            infos = self._save_manager.get_save_info()
            for info in infos:
                if info is not None:
                    mins = int(info["playtime"] // 60)
                    label = f"Load Slot {info['slot'] + 1} — {info['character_name']} ({mins}m)"
                    self._options.append(label)
                    self._load_slots.append(info)

        self._quit_index = len(self._options)
        self._options.append("Quit")

    def enter(self) -> None:
        self._build_options()
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
                elif self._selected_index == self._quit_index:
                    self._on_quit()
                elif self._on_load_game:
                    # Load slot selection
                    slot_idx = self._selected_index - self._load_start_index
                    if 0 <= slot_idx < len(self._load_slots):
                        slot_info = self._load_slots[slot_idx]
                        if slot_info:
                            self._on_load_game(slot_info["slot"])

    def update(self, dt: float) -> None:
        self._time += dt

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()

        if self._splash_art is not None:
            iw, ih = renderer.get_image_size(self._splash_art)
            scale = max(sw / iw, sh / ih)
            renderer.draw_image(
                self._splash_art,
                (sw // 2, sh // 2),
                size=(int(iw * scale), int(ih * scale)),
                centered=True,
            )
        else:
            renderer.draw_rect((0, 0, sw, sh), (7, 12, 26))
            pan_x = self._time * 10.0
            pan_y = self._time * 4.0
            self._starfield.draw(renderer, pan_x, pan_y)

        # Atmospheric overlays
        renderer.draw_rect((0, 0, sw, sh), (6, 14, 34, 115))
        renderer.draw_rect((0, int(sh * 0.55), sw, int(sh * 0.45)), (4, 10, 24, 170))

        panel_w = min(560, sw - 80)
        panel_h = 70 + len(self._options) * 60
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
                renderer.draw_rect(
                    (panel_x + 35, y - 8, glow_w, 42), (20, 72, 120, int(110 * pulse))
                )
                renderer.draw_text(">", (panel_x + 46, y), size=26, color=(145, 233, 255))
                color = (232, 250, 255)
            else:
                color = (152, 187, 210)

            renderer.draw_text(opt.upper(), (panel_x + 86, y), size=28, color=color)

        renderer.draw_text(
            "v0.1.0  |  Arrow Keys / WASD to select  |  Enter to confirm",
            (sw // 2 - 260, sh - 34),
            size=14,
            color=(146, 187, 214),
        )
