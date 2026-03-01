"""Ending screen — displays the outcome of the player's journey."""

from __future__ import annotations

import math
from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData


class EndingState(GameState):
    """Calculates and displays the final ending based on player stats."""

    state_type = GameStateType.CUTSCENE  # Use cutscene type for general UI layering

    def __init__(
        self,
        machine: GameStateMachine,
        game_state: GameStateData,
        on_return_to_menu: callable,
    ) -> None:
        super().__init__(machine)
        self.game_state = game_state
        self._on_return = on_return_to_menu
        
        self._time = 0.0
        self._ending_title = ""
        self._ending_desc = ""
        self._ending_color = (255, 255, 255)
        
        self._calculate_ending()

    def _calculate_ending(self) -> None:
        """Determine ending based on faction reputation and story flags."""
        canis_rep = self.game_state.faction_registry.get("canis_league").reputation if "canis_league" in self.game_state.faction_registry else 0
        felid_rep = self.game_state.faction_registry.get("felid_corsairs").reputation if "felid_corsairs" in self.game_state.faction_registry else 0
        
        # Simple ending logic based on PRD: Hold, Share, Destroy
        # For prototype, we use reputation as a proxy for the 'Hold/Share/Destroy' choice if a specific flag isn't set
        final_choice = self.game_state.story_flags.get("final_choice", "none")
        
        if final_choice == "destroy":
            self._ending_title = "THE CRYSTALS SHATTERED"
            self._ending_desc = "You destroyed the Whisper Crystals, plunging the multiverse into a dark but free age."
            self._ending_color = (220, 60, 40)
        elif final_choice == "share" or (canis_rep > 50 and felid_rep > 50):
            self._ending_title = "A SHARED MULTIVERSE"
            self._ending_desc = "You distributed the crystals' power equally, forcing an uneasy peace between the factions."
            self._ending_color = (60, 200, 80)
        else:
            self._ending_title = "POWER CONSOLIDATED"
            self._ending_desc = "You kept the crystals' power for yourself, ruling the Corsair fleets with an iron paw."
            self._ending_color = (180, 50, 220)

    def enter(self) -> None:
        self._time = 0.0

    def exit(self) -> None:
        pass

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if action == Action.CONFIRM and self._time > 2.0:
                self._on_return()

    def update(self, dt: float) -> None:
        self._time += dt

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()

        # Fade in background
        alpha = min(255, int(self._time * 100))
        renderer.draw_rect((0, 0, sw, sh), (8, 12, 20, alpha))
        
        if self._time > 1.0:
            text_alpha = min(255, int((self._time - 1.0) * 150))
            color = (*self._ending_color, text_alpha)
            
            renderer.draw_glow((sw // 2, sh // 3), 150, (*self._ending_color, min(100, text_alpha)))
            renderer.draw_text(self._ending_title, (sw // 2 - len(self._ending_title) * 10, sh // 3), size=36, color=color)
            
            desc_color = (220, 230, 255, text_alpha)
            # Rough text wrap
            words = self._ending_desc.split()
            lines = []
            curr = ""
            for w in words:
                if len(curr) + len(w) > 40:
                    lines.append(curr)
                    curr = w + " "
                else:
                    curr += w + " "
            if curr:
                lines.append(curr)
                
            y = sh // 2
            for line in lines:
                renderer.draw_text(line.strip(), (sw // 2 - len(line) * 6, y), size=24, color=desc_color)
                y += 35
                
            # Stats
            stats_y = y + 40
            mins = int(self.game_state.playtime_seconds // 60)
            renderer.draw_text(f"Voyage Time: {mins} minutes", (sw // 2 - 120, stats_y), size=20, color=(150, 180, 210, text_alpha))
            renderer.draw_text(f"Crystals Hoarded: {self.game_state.crystal_inventory}", (sw // 2 - 120, stats_y + 30), size=20, color=(150, 180, 210, text_alpha))
            
        if self._time > 3.0:
            pulse = int(127 + 127 * math.sin(self._time * 4))
            renderer.draw_text(">> PRESS ENTER TO RETURN TO MENU <<", (sw // 2 - 200, sh - 80), size=20, color=(100, 150, 200, pulse))
