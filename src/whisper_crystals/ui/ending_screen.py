"""Ending screen — displays the outcome of the player's journey.

Shows the ending title, narrative description, voyage statistics,
faction standings, and a scrollable decision history.
"""

from __future__ import annotations

import math
from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData


# Arc display names for the decision summary
ARC_NAMES: dict[str, str] = {
    "arc_1": "Arc I: Discovery",
    "arc_2": "Arc II: Escalation",
    "arc_3": "Arc III: Reckoning",
    "arc_4": "Arc IV: Endgame",
}


class EndingState(GameState):
    """Calculates and displays the final ending with a full decision summary."""

    state_type = GameStateType.CUTSCENE

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
        self._scroll_offset = 0
        self._ending_title = ""
        self._ending_desc = ""
        self._ending_color = (255, 255, 255)

        self._calculate_ending()
        self._summary_lines = self._build_summary()

    # ------------------------------------------------------------------
    # Ending calculation
    # ------------------------------------------------------------------

    def _calculate_ending(self) -> None:
        """Determine ending based on faction reputation and story flags."""
        canis_rep = 0
        felid_rep = 0
        if "canis_league" in self.game_state.faction_registry:
            canis_rep = self.game_state.faction_registry[
                "canis_league"
            ].reputation_with_player
        if "felid_corsairs" in self.game_state.faction_registry:
            felid_rep = self.game_state.faction_registry[
                "felid_corsairs"
            ].reputation_with_player

        final_choice = self.game_state.story_flags.get("final_choice", "none")

        if final_choice == "destroy":
            self._ending_title = "THE CRYSTALS SHATTERED"
            self._ending_desc = (
                "You destroyed the Whisper Crystals, plunging the multiverse "
                "into a dark but free age."
            )
            self._ending_color = (220, 60, 40)
        elif final_choice == "share" or (canis_rep > 50 and felid_rep > 50):
            self._ending_title = "A SHARED MULTIVERSE"
            self._ending_desc = (
                "You distributed the crystals' power equally, forcing an uneasy "
                "peace between the factions."
            )
            self._ending_color = (60, 200, 80)
        else:
            self._ending_title = "POWER CONSOLIDATED"
            self._ending_desc = (
                "You kept the crystals' power for yourself, ruling the Corsair "
                "fleets with an iron paw."
            )
            self._ending_color = (180, 50, 220)

    # ------------------------------------------------------------------
    # Decision summary builder
    # ------------------------------------------------------------------

    def _build_summary(self) -> list[tuple[str, tuple[int, int, int]]]:
        """Build the scrollable summary lines as (text, colour) pairs."""
        white = (220, 230, 255)
        dim = (150, 160, 180)
        accent = self._ending_color
        gold = (200, 170, 40)
        lines: list[tuple[str, tuple[int, int, int]]] = []

        # --- Voyage Stats ---
        lines.append(("--- VOYAGE STATISTICS ---", accent))
        mins = int(self.game_state.playtime_seconds // 60)
        hrs = mins // 60
        remaining_mins = mins % 60
        if hrs > 0:
            lines.append((f"  Voyage Duration: {hrs}h {remaining_mins}m", white))
        else:
            lines.append((f"  Voyage Duration: {mins} minutes", white))
        lines.append((
            f"  Crystals Hoarded: {self.game_state.crystal_inventory}", white
        ))
        lines.append((f"  Salvage Collected: {self.game_state.salvage}", white))
        lines.append((
            f"  Encounters Completed: {len(self.game_state.completed_encounters)}",
            white,
        ))
        lines.append((
            f"  Decisions Made: {len(self.game_state.player_decisions)}",
            white,
        ))
        ship = self.game_state.player_ship
        lines.append((
            f"  Ship: {ship.name} ({ship.current_hull}/{ship.max_hull} hull)",
            white,
        ))
        lines.append(("", dim))

        # --- Faction standings ---
        if self.game_state.faction_registry:
            lines.append(("--- FACTION STANDINGS ---", accent))
            sorted_factions = sorted(
                self.game_state.faction_registry.values(),
                key=lambda f: f.reputation_with_player,
                reverse=True,
            )
            for faction in sorted_factions:
                rep = faction.reputation_with_player
                if rep > 50:
                    tag = "Allied"
                    tag_color = (60, 200, 80)
                elif rep > 0:
                    tag = "Friendly"
                    tag_color = (100, 180, 120)
                elif rep == 0:
                    tag = "Neutral"
                    tag_color = dim
                elif rep > -50:
                    tag = "Hostile"
                    tag_color = (200, 120, 40)
                else:
                    tag = "At War"
                    tag_color = (220, 60, 40)
                lines.append((
                    f"  {faction.name}: {rep:+d} ({tag})",
                    tag_color,
                ))
            lines.append(("", dim))

        # --- Side missions ---
        completed_missions = [
            m for m in self.game_state.side_missions.values()
            if m.status == "completed"
        ]
        failed_missions = [
            m for m in self.game_state.side_missions.values()
            if m.status == "failed"
        ]
        if completed_missions or failed_missions:
            lines.append(("--- SIDE MISSIONS ---", accent))
            lines.append((
                f"  Completed: {len(completed_missions)}  |  "
                f"Failed: {len(failed_missions)}",
                white,
            ))
            for m in completed_missions:
                lines.append((f"    + {m.title}", (60, 200, 80)))
            for m in failed_missions:
                lines.append((f"    x {m.title}", (200, 80, 60)))
            lines.append(("", dim))

        # --- Decision history by arc ---
        if self.game_state.player_decisions:
            lines.append(("--- DECISION HISTORY ---", accent))
            decisions_by_arc: dict[str, list] = {}
            for d in self.game_state.player_decisions:
                arc = d.arc_id
                if arc not in decisions_by_arc:
                    decisions_by_arc[arc] = []
                decisions_by_arc[arc].append(d)

            for arc_id in sorted(decisions_by_arc.keys()):
                arc_label = ARC_NAMES.get(arc_id, arc_id)
                lines.append((f"  {arc_label}", gold))
                for decision in decisions_by_arc[arc_id]:
                    weight = decision.outcome_weight
                    if weight > 0:
                        indicator = "+"
                        color = (100, 180, 120)
                    elif weight < 0:
                        indicator = "-"
                        color = (200, 120, 80)
                    else:
                        indicator = "~"
                        color = dim
                    choice_label = decision.choice_id.replace("_", " ").title()
                    lines.append((
                        f"    {indicator} {choice_label}",
                        color,
                    ))
            lines.append(("", dim))

        lines.append(("--- END OF VOYAGE ---", accent))
        return lines

    # ------------------------------------------------------------------
    # GameState ABC
    # ------------------------------------------------------------------

    def enter(self) -> None:
        self._time = 0.0
        self._scroll_offset = 0

    def exit(self) -> None:
        pass

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if action == Action.CONFIRM and self._time > 2.0:
                self._on_return()
            elif action == Action.MENU_UP or action == Action.MOVE_UP:
                self._scroll_offset = max(0, self._scroll_offset - 1)
            elif action == Action.MENU_DOWN or action == Action.MOVE_DOWN:
                max_scroll = max(0, len(self._summary_lines) - 8)
                self._scroll_offset = min(max_scroll, self._scroll_offset + 1)

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

            # Ending title glow + text
            renderer.draw_glow(
                (sw // 2, 80), 150, (*self._ending_color, min(100, text_alpha))
            )
            title_x = sw // 2 - len(self._ending_title) * 10
            renderer.draw_text(
                self._ending_title, (title_x, 65), size=36, color=color
            )

            # Description
            desc_color = (220, 230, 255, text_alpha)
            desc_lines = _wrap_text(self._ending_desc, 50)
            y = 130
            for line in desc_lines:
                line_x = sw // 2 - len(line) * 6
                renderer.draw_text(line, (line_x, y), size=22, color=desc_color)
                y += 30

            # Summary panel
            panel_top = y + 20
            panel_left = 60
            panel_width = sw - 120
            panel_height = sh - panel_top - 90
            renderer.draw_rect(
                (panel_left, panel_top, panel_width, panel_height),
                (12, 18, 32, min(200, text_alpha)),
            )
            renderer.draw_rect(
                (panel_left, panel_top, panel_width, panel_height),
                (*self._ending_color, min(80, text_alpha)),
                width=1,
            )

            # Render visible summary lines
            line_height = 26
            visible_count = max(1, panel_height // line_height)
            visible_lines = self._summary_lines[
                self._scroll_offset:self._scroll_offset + visible_count
            ]

            ly = panel_top + 10
            for text, line_color in visible_lines:
                if text:
                    renderer.draw_text(
                        text,
                        (panel_left + 16, ly),
                        size=18,
                        color=(*line_color, text_alpha),
                    )
                ly += line_height

            # Scroll indicators
            if self._scroll_offset > 0:
                renderer.draw_text(
                    "^ Scroll Up ^",
                    (sw // 2 - 50, panel_top - 16),
                    size=14,
                    color=(150, 180, 210, text_alpha),
                )
            if self._scroll_offset + visible_count < len(self._summary_lines):
                renderer.draw_text(
                    "v Scroll Down v",
                    (sw // 2 - 55, panel_top + panel_height + 2),
                    size=14,
                    color=(150, 180, 210, text_alpha),
                )

        if self._time > 3.0:
            pulse = int(127 + 127 * math.sin(self._time * 4))
            renderer.draw_text(
                ">> PRESS ENTER TO RETURN TO MENU <<",
                (sw // 2 - 200, sh - 50),
                size=20,
                color=(100, 150, 200, pulse),
            )


def _wrap_text(text: str, max_chars: int) -> list[str]:
    """Word-wrap text to lines of at most max_chars characters."""
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        if current and len(current) + len(word) + 1 > max_chars:
            lines.append(current.strip())
            current = word + " "
        else:
            current += word + " "
    if current.strip():
        lines.append(current.strip())
    return lines
