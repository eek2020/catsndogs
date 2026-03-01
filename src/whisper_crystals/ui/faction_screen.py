"""Faction status screen — overlay showing all faction standings."""

from __future__ import annotations

import math

from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType
from whisper_crystals.entities.faction import DiplomaticState

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData
    from whisper_crystals.systems.faction_system import FactionSystem

# Colours
BG = (8, 14, 28)
PANEL = (14, 24, 44)
BORDER = (56, 132, 196)
TEXT = (236, 245, 255)
DIM = (132, 162, 190)
HIGHLIGHT = (110, 214, 255)

STATE_COLORS = {
    DiplomaticState.HOSTILE: (220, 50, 40),
    DiplomaticState.WARY: (220, 180, 40),
    DiplomaticState.NEUTRAL: (140, 140, 140),
    DiplomaticState.FRIENDLY: (60, 200, 80),
    DiplomaticState.ALLIED: (80, 140, 255),
}


class FactionScreenState(GameState):
    """Overlay screen showing faction standings and details."""

    state_type = GameStateType.PAUSE  # Reuse PAUSE type for overlay

    def __init__(
        self,
        machine: GameStateMachine,
        game_state: GameStateData,
        faction_system: FactionSystem,
    ) -> None:
        super().__init__(machine)
        self.game_state = game_state
        self.faction_system = faction_system
        self._selected = 0
        self._standings: list[dict] = []

    def enter(self) -> None:
        self._standings = self.faction_system.get_all_standings(self.game_state)
        self._selected = 0

    def exit(self) -> None:
        pass

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if action in (Action.MOVE_UP, Action.MENU_UP):
                self._selected = (self._selected - 1) % max(1, len(self._standings))
            elif action in (Action.MOVE_DOWN, Action.MENU_DOWN):
                self._selected = (self._selected + 1) % max(1, len(self._standings))
            elif action in (Action.CANCEL, Action.PAUSE):
                self.machine.pop()

    def update(self, dt: float) -> None:
        pass

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()

        # Semi-transparent dark overlay
        renderer.draw_rect((0, 0, sw, sh), (8, 12, 24, 230))
        
        # Ambient central glow
        renderer.draw_glow((sw // 2, sh // 2), 400, (18, 54, 86))

        # Title
        title_y = 30
        renderer.draw_glow((sw // 2, title_y + 15), 100, (26, 84, 124))
        renderer.draw_text("FACTION STATUS PROTOCOL", (sw // 2 - 160, title_y), size=28, color=HIGHLIGHT)
        renderer.draw_line((sw // 2 - 200, title_y + 40), (sw // 2 + 200, title_y + 40), BORDER, 2)

        standings = self.faction_system.get_all_standings(self.game_state)
        if not standings:
            renderer.draw_text("No faction data available.", (60, 120), size=20, color=DIM)
            renderer.draw_text("ESC CLOSE", (sw - 120, sh - 30), size=14, color=DIM)
            return

        # Draw list of factions
        list_x = 60
        list_y = 100
        list_w = 400
        
        # Left panel background
        renderer.draw_rect((list_x - 20, list_y - 20, list_w + 40, sh - list_y - 40), PANEL)
        renderer.draw_rect((list_x - 20, list_y - 20, list_w + 40, sh - list_y - 40), BORDER, width=1)
        
        # Decorative corners
        renderer.draw_line((list_x - 20, list_y - 20), (list_x, list_y - 20), HIGHLIGHT, 2)
        renderer.draw_line((list_x - 20, list_y - 20), (list_x - 20, list_y), HIGHLIGHT, 2)

        for i, stand in enumerate(standings):
            y = list_y + i * 50
            if i == self._selected:
                # Selected item glow and highlight
                renderer.draw_rect((list_x - 10, y - 5, list_w + 20, 45), (20, 48, 74, 200))
                renderer.draw_rect((list_x - 10, y - 5, 4, 45), HIGHLIGHT)
                # Animated cursor
                offset = int((math.sin(self.game_state.playtime_seconds * 5) + 1) * 3)
                renderer.draw_polygon(
                    [(list_x + offset, y + 17), (list_x + 10 + offset, y + 17), (list_x + 5 + offset, y + 23)],
                    HIGHLIGHT,
                )
                color = (255, 255, 255)
                text_x = list_x + 20
            else:
                color = DIM
                text_x = list_x + 5

            renderer.draw_text(stand["name"], (text_x, y + 5), size=20, color=color)

            # Reputation value and status text
            rep = stand["reputation"]
            rep_text = f"Rep: {rep}"
            
            # Status colors
            state = stand["state"]
            state_str = state.name
            scolor = STATE_COLORS.get(state, DIM)
            
            renderer.draw_text(state_str, (text_x + list_w - 180, y + 8), size=14, color=scolor)
            renderer.draw_text(rep_text, (text_x + list_w - 70, y + 8), size=14, color=color)

        # Draw details for selected faction
        det_x = 540
        det_y = 100
        det_w = sw - det_x - 40
        
        # Right panel background
        renderer.draw_rect((det_x - 20, det_y - 20, det_w + 40, sh - det_y - 40), (12, 20, 36, 220))
        renderer.draw_rect((det_x - 20, det_y - 20, det_w + 40, sh - det_y - 40), BORDER, width=1)

        sel = standings[self._selected]
        fac_id = sel["faction_id"]
        faction = self.game_state.faction_registry[fac_id]

        # Huge faction name
        renderer.draw_glow((det_x + 100, det_y + 10), 80, (26, 84, 124))
        renderer.draw_text(faction.name.upper(), (det_x, det_y), size=36, color=TEXT)
        renderer.draw_line((det_x, det_y + 45), (det_x + det_w, det_y + 45), HIGHLIGHT, 1)

        # Status block
        state = sel["state"]
        state_str = state.name
        scolor = STATE_COLORS.get(state, DIM)
        renderer.draw_text("STATUS:", (det_x, det_y + 60), size=16, color=DIM)
        renderer.draw_text(state_str, (det_x + 80, det_y + 58), size=20, color=scolor)

        renderer.draw_text("REPUTATION:", (det_x + 250, det_y + 60), size=16, color=DIM)
        renderer.draw_text(str(sel["reputation"]), (det_x + 370, det_y + 58), size=20, color=TEXT)

        # Visual Rep Bar
        bar_y = det_y + 100
        renderer.draw_rect((det_x, bar_y, 400, 15), (40, 35, 55))
        # Map -100..100 to 0..400
        fill_w = int(((sel["reputation"] + 100) / 200) * 400)
        renderer.draw_rect((det_x, bar_y, fill_w, 15), scolor)
        renderer.draw_rect((det_x, bar_y, 400, 15), BORDER, width=1)
        # Center marker (0 rep)
        renderer.draw_line((det_x + 200, bar_y - 5), (det_x + 200, bar_y + 20), (200, 200, 200), 2)

        # Abilities
        renderer.draw_text("FACTION ABILITIES:", (det_x, det_y + 150), size=18, color=HIGHLIGHT)
        for i, ab in enumerate(faction.abilities):
            # Ability card look
            ay = det_y + 180 + i * 65
            renderer.draw_rect((det_x, ay, det_w - 20, 55), (14, 26, 42, 150))
            renderer.draw_rect((det_x, ay, 4, 55), HIGHLIGHT)
            renderer.draw_text(ab.name, (det_x + 15, ay + 5), size=18, color=TEXT)
            renderer.draw_text(ab.description, (det_x + 15, ay + 30), size=14, color=DIM)

        # Footer
        renderer.draw_text("↑/↓ SELECT   |   ESC CLOSE", (sw // 2 - 120, sh - 30), size=14, color=DIM)
