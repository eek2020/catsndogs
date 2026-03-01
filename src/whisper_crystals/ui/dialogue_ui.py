"""Dialogue state — presents encounter text and player choices."""

from __future__ import annotations

import os

import pygame

from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType
from whisper_crystals.entities.encounter import Encounter

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData
    from whisper_crystals.systems.encounter_engine import EncounterEngine


# Colour palette
BG_COLOR = (8, 14, 28)
PANEL_COLOR = (14, 24, 44)
BORDER_COLOR = (56, 132, 196)
TEXT_COLOR = (236, 245, 255)
HIGHLIGHT_COLOR = (110, 214, 255)
DIM_COLOR = (132, 162, 190)
OUTCOME_COLOR = (120, 226, 200)


def _resolve_character_head_path(character_id: str) -> str:
    """Resolve character portrait path relative to repo root."""
    here = os.path.abspath(__file__)
    project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(here))))
    return os.path.join(project_root, "design", "charcters", f"{character_id}_head.png")


def _load_character_head(character_id: str) -> pygame.Surface | None:
    """Load a character portrait image for dialogue UI if available."""
    path = _resolve_character_head_path(character_id)
    if not os.path.exists(path):
        return None
    try:
        image = pygame.image.load(path)
        try:
            return image.convert_alpha()
        except pygame.error:
            return image
    except pygame.error:
        return None


def _remove_near_white_background(
    surface: pygame.Surface,
    hard_threshold: int = 234,
    soft_threshold: int = 200,
) -> pygame.Surface:
    """Convert bright near-white background pixels to transparency with soft edge feathering."""
    cleaned = surface.copy().convert_alpha()
    width, height = cleaned.get_size()
    for x in range(width):
        for y in range(height):
            r, g, b, a = cleaned.get_at((x, y))
            whiteness = min(r, g, b)
            if whiteness >= hard_threshold:
                cleaned.set_at((x, y), (r, g, b, 0))
            elif whiteness >= soft_threshold:
                span = max(1, hard_threshold - soft_threshold)
                alpha_scale = (hard_threshold - whiteness) / span
                cleaned.set_at((x, y), (r, g, b, int(a * alpha_scale)))
            else:
                cleaned.set_at((x, y), (r, g, b, a))
    return cleaned


class DialogueState(GameState):
    """Displays encounter description, NPC dialogue, and player choices."""

    state_type = GameStateType.DIALOGUE

    def __init__(
        self,
        machine: GameStateMachine,
        encounter: Encounter,
        encounter_engine: EncounterEngine,
        game_state: GameStateData,
        on_complete: callable,
        on_combat: callable | None = None,
    ) -> None:
        super().__init__(machine)
        self.encounter = encounter
        self.encounter_engine = encounter_engine
        self.game_state = game_state
        self._on_complete = on_complete
        self._on_combat = on_combat

        self._selected = 0
        self._phase = "choosing"  # "choosing" or "outcome"
        self._outcome_text = ""

        # Typewriter effect
        self._description_chars = 0.0
        self._char_speed = 60.0  # chars per second
        self._description_done = False
        self._npc_heads: dict[str, pygame.Surface] = {}
        for character_id in ("aristotle", "dave"):
            head = _load_character_head(character_id)
            if head is not None:
                self._npc_heads[character_id] = _remove_near_white_background(head)

    def enter(self) -> None:
        self._selected = 0
        self._phase = "choosing"
        self._outcome_text = ""
        self._description_chars = 0.0
        self._description_done = False

    def exit(self) -> None:
        pass

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if self._phase == "choosing":
                if not self._description_done:
                    # Skip typewriter on any confirm/interact
                    if action in (Action.CONFIRM, Action.INTERACT, Action.FIRE):
                        self._description_done = True
                        self._description_chars = float(len(self.encounter.description))
                    continue

                if action in (Action.MOVE_UP, Action.MENU_UP):
                    self._selected = (self._selected - 1) % len(self.encounter.choices)
                elif action in (Action.MOVE_DOWN, Action.MENU_DOWN):
                    self._selected = (self._selected + 1) % len(self.encounter.choices)
                elif action == Action.CONFIRM:
                    self._resolve_choice()
            elif self._phase == "outcome":
                if action == Action.CONFIRM:
                    self._on_complete()

    def _resolve_choice(self) -> None:
        """Apply the selected choice and transition to outcome or combat."""
        choice = self.encounter.choices[self._selected]
        is_fight = (
            self.encounter.encounter_type == "combat"
            and choice.choice_id in ("fight", "fight_pirates")
            and self._on_combat is not None
        )
        if is_fight:
            self._on_combat(self.encounter, self._selected)
            return

        self._outcome_text = self.encounter_engine.apply_choice_outcome(
            self.game_state,
            self.encounter,
            self._selected,
        )
        self._phase = "outcome"

    def update(self, dt: float) -> None:
        if not self._description_done:
            self._description_chars += self._char_speed * dt
            if self._description_chars >= len(self.encounter.description):
                self._description_chars = float(len(self.encounter.description))
                self._description_done = True

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()

        # Dark overlay with slight tint
        renderer.draw_rect((0, 0, sw, sh), (8, 12, 24, 220))

        # Ambient glow behind main dialogue area
        renderer.draw_glow((sw // 2, sh // 2), 320, (18, 54, 86))

        # Title bar
        title_y = 40
        renderer.draw_rect((40, title_y, sw - 80, 50), PANEL_COLOR)
        # Glowing top border
        renderer.draw_rect((40, title_y, sw - 80, 2), HIGHLIGHT_COLOR)
        renderer.draw_rect((40, title_y + 48, sw - 80, 2), BORDER_COLOR)
        renderer.draw_text(self.encounter.title, (60, title_y + 10), size=28, color=HIGHLIGHT_COLOR)

        # Encounter type badge
        badge_text = f"// {self.encounter.encounter_type.upper()} \\\\"
        renderer.draw_text(badge_text, (sw - 280, title_y + 15), size=16, color=DIM_COLOR)

        # Main panel with decorative corners
        main_y = title_y + 70
        main_h = sh - main_y - 40
        renderer.draw_rect((40, main_y, sw - 80, main_h), (12, 20, 36, 240))
        renderer.draw_rect((40, main_y, sw - 80, main_h), BORDER_COLOR, width=1)
        
        # Corner accents
        cx = [40, sw - 40]
        cy = [main_y, main_y + main_h]
        for x in cx:
            for y in cy:
                w_dir = 1 if x == 40 else -1
                h_dir = 1 if y == main_y else -1
                renderer.draw_line((x, y), (x + 15 * w_dir, y), HIGHLIGHT_COLOR, 2)
                renderer.draw_line((x, y), (x, y + 15 * h_dir), HIGHLIGHT_COLOR, 2)

        # NPC portrait area with a glowing border and backdrop
        desc_x = 60
        if self.encounter.npc_ids:
            npc_id = self.encounter.npc_ids[0]
            npc_name = npc_id.upper()
            cx, cy = 130, main_y + 90
            
            # Complex character portrait frame
            renderer.draw_glow((cx, cy), 60, (26, 78, 124))
            renderer.draw_circle((cx, cy), 55, (8, 16, 30))
            renderer.draw_circle((cx, cy), 55, HIGHLIGHT_COLOR, width=2)
            renderer.draw_circle((cx, cy), 48, BORDER_COLOR, width=1)

            speaker_head = self._npc_heads.get(npc_id.lower())
            if speaker_head is not None and hasattr(renderer, "screen"):
                iw, ih = speaker_head.get_size()
                max_size = 108
                scale = min(max_size / iw, max_size / ih)
                render_w = max(1, int(iw * scale))
                render_h = max(1, int(ih * scale))
                portrait = pygame.transform.smoothscale(speaker_head, (render_w, render_h))
                renderer.screen.blit(portrait, (cx - render_w // 2, cy - render_h // 2))
            else:
                # Character silhouette placeholder
                renderer.draw_circle((cx, cy + 10), 30, (80, 60, 120))
                renderer.draw_polygon(
                    [(cx - 20, cy + 40), (cx + 20, cy + 40), (cx + 40, cy + 80), (cx - 40, cy + 80)],
                    (40, 30, 70),
                )
            
            renderer.draw_text(npc_name, (cx - 30, cy - 80), size=16, color=HIGHLIGHT_COLOR)
            desc_x = 230

        # Description with typewriter effect
        desc_y = main_y + 30
        desc_w = sw - desc_x - 60
        visible_text = self.encounter.description[:int(self._description_chars)]
        
        # Fancy text presentation
        renderer.draw_line((desc_x - 15, desc_y), (desc_x - 15, desc_y + 100), HIGHLIGHT_COLOR, 3)
        self._render_wrapped_text(renderer, visible_text, desc_x, desc_y, desc_w, TEXT_COLOR, 22)

        if self._phase == "choosing" and self._description_done:
            # Choices section
            choice_y = main_y + 200
            
            # Horizontal divider
            renderer.draw_line((desc_x, choice_y - 20), (sw - 80, choice_y - 20), BORDER_COLOR, 1)
            renderer.draw_text("RESPONSE PROTOCOL", (desc_x + 10, choice_y - 28), size=12, color=DIM_COLOR)

            for i, choice in enumerate(self.encounter.choices):
                y = choice_y + i * 55
                if i == self._selected:
                    # Selected choice styling
                    renderer.draw_rect((desc_x, y - 5, desc_w, 45), (20, 48, 74, 180))
                    renderer.draw_rect((desc_x, y - 5, 4, 45), HIGHLIGHT_COLOR)
                    
                    # Animated selection cursor
                    time_mod = (self.game_state.playtime_seconds * 5) % 1.0
                    offset = int(time_mod * 5)
                    renderer.draw_polygon(
                        [(desc_x + 15 + offset, y + 17), (desc_x + 25 + offset, y + 17), (desc_x + 20 + offset, y + 23)],
                        HIGHLIGHT_COLOR,
                    )
                    color = (255, 255, 255)
                    text_x = desc_x + 40
                else:
                    color = DIM_COLOR
                    text_x = desc_x + 20
                
                renderer.draw_text(f"[{i + 1}] {choice.text}", (text_x, y + 10), size=18, color=color)

            # Instructions
            footer_h = 34
            footer_y = sh - footer_h - 10
            renderer.draw_rect((40, footer_y, sw - 80, footer_h), (10, 28, 42, 210))
            renderer.draw_line((40, footer_y), (sw - 40, footer_y), BORDER_COLOR, 1)
            renderer.draw_text(
                "↑/↓ SELECT   |   ENTER CONFIRM",
                (sw // 2 - 170, footer_y + 6),
                size=20,
                color=HIGHLIGHT_COLOR,
            )

        elif self._phase == "outcome":
            # Outcome display
            outcome_y = main_y + 200
            
            # Decorative outcome box
            renderer.draw_rect((desc_x, outcome_y - 10, desc_w, 140), (14, 36, 38, 200))
            renderer.draw_rect((desc_x, outcome_y - 10, desc_w, 140), OUTCOME_COLOR, width=1)
            renderer.draw_rect((desc_x, outcome_y - 10, 4, 140), OUTCOME_COLOR)
            
            self._render_wrapped_text(
                renderer, self._outcome_text, desc_x + 20, outcome_y + 10, desc_w - 40, TEXT_COLOR, 20,
            )

            # Show resource/faction changes with icons (using text for now)
            choice = self.encounter.choices[self._selected]
            info_y = outcome_y + 100
            
            x_offset = desc_x + 20
            for res, delta in choice.outcome.resource_changes.items():
                sign = "+" if delta > 0 else ""
                color = (146, 228, 255) if delta > 0 else (255, 120, 120)
                text = f"♦ {res.replace('_', ' ').title()}: {sign}{delta}"
                renderer.draw_text(text, (x_offset, info_y), size=20, color=color)
                info_y += 28
                
            for fid, delta in choice.outcome.faction_changes.items():
                sign = "+" if delta > 0 else ""
                color = (140, 255, 180) if delta > 0 else (255, 120, 120)
                text = f"★ {fid.replace('_', ' ').title()} Rep: {sign}{delta}"
                renderer.draw_text(text, (x_offset, info_y), size=20, color=color)
                info_y += 28

            footer_h = 34
            footer_y = sh - footer_h - 10
            renderer.draw_rect((40, footer_y, sw - 80, footer_h), (10, 28, 42, 210))
            renderer.draw_line((40, footer_y), (sw - 40, footer_y), BORDER_COLOR, 1)
            renderer.draw_text(
                ">> PRESS ENTER TO CONTINUE <<",
                (sw // 2 - 175, footer_y + 6),
                size=20,
                color=OUTCOME_COLOR,
            )

    def _render_wrapped_text(
        self,
        renderer: RenderInterface,
        text: str,
        x: int,
        y: int,
        max_width: int,
        color: tuple[int, int, int],
        size: int,
    ) -> None:
        """Word-wrap renderer using font metrics for accurate line width."""
        words = text.split()
        lines: list[str] = []
        current_line = ""
        font = pygame.font.Font(None, size)

        for word in words:
            test = f"{current_line} {word}".strip()
            if font.size(test)[0] > max_width:
                if current_line:
                    lines.append(current_line)
                current_line = word
            else:
                current_line = test
        if current_line:
            lines.append(current_line)

        for i, line in enumerate(lines):
            renderer.draw_text(line, (x, y + i * (size + 6)), size=size, color=color)
