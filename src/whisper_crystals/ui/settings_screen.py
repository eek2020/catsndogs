"""Settings screen — overlay for game settings (volume, difficulty, etc.)."""

from __future__ import annotations

import json
import logging
import math
import os
from pathlib import Path
from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType

logger = logging.getLogger(__name__)

# Colours
BG_OVERLAY = (6, 10, 22, 220)
PANEL_BG = (12, 22, 42, 230)
PANEL_BORDER = (56, 132, 196)
TEXT = (236, 245, 255)
DIM = (120, 150, 180)
HIGHLIGHT = (110, 214, 255)
BAR_BG = (40, 35, 55)
BAR_FILL = (80, 170, 240)

DIFFICULTY_LEVELS = ["Easy", "Normal", "Hard"]

DEFAULT_SETTINGS: dict = {
    "music_volume": 80,
    "sfx_volume": 80,
    "difficulty": "Normal",
}


def _settings_path() -> str:
    """Return the platform-appropriate settings file path."""
    return str(Path.home() / ".whisper_crystals" / "settings.json")


def load_settings(path: str | None = None) -> dict:
    """Load settings from disk, returning defaults if file is missing."""
    path = path or _settings_path()
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            merged = dict(DEFAULT_SETTINGS)
            merged.update(data)
            return merged
        except (OSError, json.JSONDecodeError):
            logger.exception("Failed to load settings")
    return dict(DEFAULT_SETTINGS)


def save_settings(settings: dict, path: str | None = None) -> bool:
    """Persist settings to disk. Returns True on success."""
    path = path or _settings_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(settings, f, indent=2)
        return True
    except OSError:
        logger.exception("Failed to save settings")
        return False


class SettingsScreenState(GameState):
    """Overlay settings screen with volume sliders and difficulty toggle."""

    state_type = GameStateType.SETTINGS

    def __init__(
        self,
        machine: GameStateMachine,
        settings: dict,
        on_back: callable | None = None,
    ) -> None:
        super().__init__(machine)
        self.settings = settings
        self._on_back = on_back

        self._items = [
            {"label": "Music Volume", "key": "music_volume", "type": "slider"},
            {"label": "SFX Volume", "key": "sfx_volume", "type": "slider"},
            {"label": "Difficulty", "key": "difficulty", "type": "enum",
             "values": DIFFICULTY_LEVELS},
            {"label": "Back", "type": "action"},
        ]
        self._selected = 0
        self._time = 0.0

    def enter(self) -> None:
        self._selected = 0
        self._time = 0.0

    def exit(self) -> None:
        save_settings(self.settings)

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if action in (Action.CANCEL, Action.PAUSE):
                self._go_back()
                return
            if action in (Action.MOVE_UP, Action.MENU_UP):
                self._selected = (self._selected - 1) % len(self._items)
            elif action in (Action.MOVE_DOWN, Action.MENU_DOWN):
                self._selected = (self._selected + 1) % len(self._items)
            elif action in (Action.MOVE_RIGHT, Action.CONFIRM):
                self._adjust(1)
            elif action == Action.MOVE_LEFT:
                self._adjust(-1)

    def _adjust(self, direction: int) -> None:
        """Adjust the currently selected setting value."""
        item = self._items[self._selected]
        if item["type"] == "slider":
            key = item["key"]
            val = self.settings.get(key, 50)
            val = max(0, min(100, val + direction * 5))
            self.settings[key] = val
        elif item["type"] == "enum":
            key = item["key"]
            values = item["values"]
            current = self.settings.get(key, values[0])
            idx = values.index(current) if current in values else 0
            idx = (idx + direction) % len(values)
            self.settings[key] = values[idx]
        elif item["type"] == "action":
            if direction == 1:  # confirm / right
                self._go_back()

    def _go_back(self) -> None:
        """Return to previous screen."""
        if self._on_back:
            self._on_back()
        else:
            self.machine.pop()

    def update(self, dt: float) -> None:
        self._time += dt

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()

        renderer.draw_rect((0, 0, sw, sh), BG_OVERLAY)

        panel_w = 500
        panel_h = 350
        px = (sw - panel_w) // 2
        py = (sh - panel_h) // 2

        renderer.draw_rect((px, py, panel_w, panel_h), PANEL_BG)
        renderer.draw_rect((px, py, panel_w, panel_h), PANEL_BORDER, width=1)

        # Title
        renderer.draw_glow((sw // 2, py + 30), 80, (26, 84, 124))
        renderer.draw_text("SETTINGS", (sw // 2 - 55, py + 18), size=30, color=HIGHLIGHT)
        renderer.draw_line((px + 20, py + 58), (px + panel_w - 20, py + 58), PANEL_BORDER, 1)

        start_y = py + 80
        for i, item in enumerate(self._items):
            y = start_y + i * 62
            is_sel = i == self._selected

            if is_sel:
                pulse = 0.5 + 0.3 * (math.sin(self._time * 6.0) + 1.0)
                renderer.draw_rect(
                    (px + 20, y - 5, panel_w - 40, 50),
                    (20, 60, 100, int(120 * pulse)),
                )
                renderer.draw_rect((px + 20, y - 5, 3, 50), HIGHLIGHT)
                label_color = TEXT
            else:
                label_color = DIM

            renderer.draw_text(
                item["label"].upper(), (px + 40, y + 5), size=20, color=label_color,
            )

            if item["type"] == "slider":
                val = self.settings.get(item["key"], 50)
                bar_x = px + 250
                bar_w = 180
                bar_y = y + 10
                renderer.draw_rect((bar_x, bar_y, bar_w, 14), BAR_BG)
                fill_w = int((val / 100) * bar_w)
                renderer.draw_rect((bar_x, bar_y, fill_w, 14), BAR_FILL)
                renderer.draw_rect((bar_x, bar_y, bar_w, 14), PANEL_BORDER, width=1)
                renderer.draw_text(
                    str(val), (bar_x + bar_w + 12, y + 5), size=18, color=label_color,
                )
                if is_sel:
                    renderer.draw_text(
                        "< >", (bar_x + bar_w + 50, y + 5), size=14, color=HIGHLIGHT,
                    )

            elif item["type"] == "enum":
                val = self.settings.get(item["key"], item["values"][0])
                renderer.draw_text(
                    f"< {val} >", (px + 280, y + 5), size=20, color=label_color,
                )

        # Footer
        renderer.draw_text(
            "↑/↓ SELECT   |   ←/→ ADJUST   |   ESC BACK",
            (sw // 2 - 180, py + panel_h + 15),
            size=13,
            color=DIM,
        )
