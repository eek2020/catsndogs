"""Pause menu — overlay state with Resume / Save / Load / Settings / Quit."""

from __future__ import annotations

import math
from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData
    from whisper_crystals.core.save_manager import SaveManager

# Colours
BG_OVERLAY = (6, 10, 22, 210)
PANEL_BG = (12, 22, 42, 230)
PANEL_BORDER = (56, 132, 196)
TEXT_NORMAL = (160, 190, 215)
TEXT_SELECTED = (235, 250, 255)
HIGHLIGHT = (110, 214, 255)
DIM = (100, 130, 160)
SAVE_SUCCESS = (80, 220, 120)
SAVE_FAIL = (220, 60, 60)


class PauseMenuState(GameState):
    """Overlay pause menu pushed on top of navigation."""

    state_type = GameStateType.PAUSE

    def __init__(
        self,
        machine: GameStateMachine,
        game_state: GameStateData,
        save_manager: SaveManager,
        on_resume: callable,
        on_load_game: callable,
        on_settings: callable,
        on_quit: callable,
    ) -> None:
        super().__init__(machine)
        self.game_state = game_state
        self.save_manager = save_manager
        self._on_resume = on_resume
        self._on_load_game = on_load_game
        self._on_settings = on_settings
        self._on_quit = on_quit

        self._options = ["Resume", "Save Game", "Load Game", "Settings", "Quit to Menu"]
        self._selected = 0
        self._time = 0.0

        # Flash message for save feedback
        self._flash_msg: str = ""
        self._flash_timer: float = 0.0
        self._flash_color: tuple[int, int, int] = SAVE_SUCCESS

    def enter(self) -> None:
        self._selected = 0
        self._time = 0.0

    def exit(self) -> None:
        pass

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if action in (Action.CANCEL, Action.PAUSE):
                self._on_resume()
                return
            if action in (Action.MOVE_UP, Action.MENU_UP):
                self._selected = (self._selected - 1) % len(self._options)
            elif action in (Action.MOVE_DOWN, Action.MENU_DOWN):
                self._selected = (self._selected + 1) % len(self._options)
            elif action == Action.CONFIRM:
                self._select_option()

    def _select_option(self) -> None:
        """Handle menu selection."""
        match self._selected:
            case 0:  # Resume
                self._on_resume()
            case 1:  # Save Game
                self._do_save()
            case 2:  # Load Game
                self._on_load_game()
            case 3:  # Settings
                self._on_settings()
            case 4:  # Quit to Menu
                self._on_quit()

    def _do_save(self) -> None:
        """Quick save to the current slot."""
        slot = self.game_state.save_slot
        if self.save_manager.save_game(self.game_state, slot):
            self._flash_msg = f"Saved to slot {slot + 1}!"
            self._flash_color = SAVE_SUCCESS
        else:
            self._flash_msg = "Save failed!"
            self._flash_color = SAVE_FAIL
        self._flash_timer = 2.0

    def update(self, dt: float) -> None:
        self._time += dt
        if self._flash_timer > 0:
            self._flash_timer -= dt

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()

        # Semi-transparent overlay
        renderer.draw_rect((0, 0, sw, sh), BG_OVERLAY)

        # Central panel
        panel_w = 420
        panel_h = 380
        px = (sw - panel_w) // 2
        py = (sh - panel_h) // 2

        renderer.draw_rect((px, py, panel_w, panel_h), PANEL_BG)
        renderer.draw_rect((px, py, panel_w, panel_h), PANEL_BORDER, width=1)

        # Title
        renderer.draw_glow((sw // 2, py + 30), 80, (26, 84, 124))
        renderer.draw_text("PAUSED", (sw // 2 - 45, py + 18), size=32, color=HIGHLIGHT)
        renderer.draw_line((px + 20, py + 60), (px + panel_w - 20, py + 60), PANEL_BORDER, 1)

        # Menu options
        start_y = py + 85
        for i, opt in enumerate(self._options):
            y = start_y + i * 52
            if i == self._selected:
                pulse = 0.5 + 0.3 * (math.sin(self._time * 6.0) + 1.0)
                renderer.draw_rect(
                    (px + 20, y - 6, panel_w - 40, 40),
                    (20, 60, 100, int(140 * pulse)),
                )
                renderer.draw_rect((px + 20, y - 6, 3, 40), HIGHLIGHT)
                renderer.draw_text(
                    ">", (px + 32, y + 2), size=22, color=HIGHLIGHT,
                )
                color = TEXT_SELECTED
            else:
                color = TEXT_NORMAL

            renderer.draw_text(opt.upper(), (px + 55, y + 2), size=22, color=color)

        # Flash message (save feedback)
        if self._flash_timer > 0 and self._flash_msg:
            alpha = min(255, int(self._flash_timer * 200))
            renderer.draw_text(
                self._flash_msg,
                (sw // 2 - 80, py + panel_h - 45),
                size=18,
                color=self._flash_color,
            )

        # Footer hint
        renderer.draw_text(
            "↑/↓ SELECT   |   ENTER CONFIRM   |   ESC RESUME",
            (sw // 2 - 200, py + panel_h + 15),
            size=13,
            color=DIM,
        )
