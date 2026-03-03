"""Cutscene state — narrative text screens with continue prompt."""

from __future__ import annotations

import math

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType

# Colours
BG = (8, 14, 28)
TITLE_COLOR = (118, 220, 255)
TEXT_COLOR = (236, 245, 255)
DIM = (132, 162, 190)
HIGHLIGHT = (110, 214, 255)
BORDER = (56, 132, 196)


class CutsceneState(GameState):
    """Full-screen narrative text display with typewriter and continue."""

    state_type = GameStateType.CUTSCENE

    def __init__(
        self,
        machine: GameStateMachine,
        title: str,
        lines: list[str],
        on_complete: callable,
        subtitle: str = "",
        title_image: object | None = None,
        character_image: object | None = None,
        character_image_left: object | None = None,
        show_narrative_text: bool = True,
    ) -> None:
        super().__init__(machine)
        self._title = title
        self._subtitle = subtitle
        self._lines = lines
        self._on_complete = on_complete
        self._title_image = title_image
        self._character_image = character_image
        self._character_image_left = character_image_left
        self._show_narrative_text = show_narrative_text

        self._current_line = 0
        self._char_progress = 0.0
        self._char_speed = 45.0
        self._line_done = False
        self._all_done = False
        self._fade_in = 0.0
        self._time = 0.0

    def enter(self) -> None:
        self._current_line = 0
        self._char_progress = 0.0
        self._line_done = not self._show_narrative_text
        self._all_done = not self._show_narrative_text
        self._fade_in = 0.0
        self._time = 0.0

    def exit(self) -> None:
        pass

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if action == Action.SKIP and not self._all_done:
                self._current_line = len(self._lines)
                self._line_done = True
                self._all_done = True
            elif action == Action.CONFIRM:
                if self._all_done:
                    self._on_complete()
                elif not self._line_done:
                    self._char_progress = float(len(self._lines[self._current_line]))
                    self._line_done = True
                else:
                    self._current_line += 1
                    self._char_progress = 0.0
                    self._line_done = False
                    if self._current_line >= len(self._lines):
                        self._all_done = True

    def update(self, dt: float) -> None:
        self._fade_in = min(1.0, self._fade_in + dt * 2.0)
        self._time += dt

        if not self._show_narrative_text:
            return

        if not self._all_done and self._current_line < len(self._lines):
            if not self._line_done:
                self._char_progress += self._char_speed * dt
                if self._char_progress >= len(self._lines[self._current_line]):
                    self._char_progress = float(len(self._lines[self._current_line]))
                    self._line_done = True

    def _render_character_in_banner(
        self,
        renderer: RenderInterface,
        image: object,
        banner_h: int,
        sw: int,
        left: bool,
    ) -> None:
        """Render a character portrait into the banner on the left or right side."""
        iw, ih = renderer.get_image_size(image)
        max_h = banner_h - 8
        max_w = int(sw * 0.16)
        scale = min(max_w / iw, max_h / ih)
        char_w = max(1, int(iw * scale))
        char_h = max(1, int(ih * scale))
        if left:
            cx = 16 + char_w // 2
        else:
            cx = sw - char_w // 2 - 16
        cy = banner_h // 2
        renderer.draw_glow((cx, cy), char_w // 2 + 20, (18, 10, 38))
        renderer.draw_image(image, (cx, cy), size=(char_w, char_h), centered=True)

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()

        renderer.draw_rect((0, 0, sw, sh), BG)
        renderer.draw_glow(
            (sw // 2, sh // 2), int(400 + 20 * math.sin(self._time * 2)), (16, 48, 78)
        )

        alpha = int(self._fade_in * 255)

        # Top banner
        banner_h = 130
        renderer.draw_rect((0, 0, sw, banner_h), (10, 20, 34, 220))
        renderer.draw_line((0, banner_h), (sw, banner_h), BORDER, 2)

        if self._title_image is not None:
            iw, ih = renderer.get_image_size(self._title_image)
            char_reserve = int(sw * 0.18) + 24
            max_w = sw - char_reserve * 2
            max_h = banner_h - 8
            scale = min(max_w / iw, max_h / ih)
            title_w = max(1, int(iw * scale))
            title_h = max(1, int(ih * scale))
            renderer.draw_glow((sw // 2, banner_h // 2), title_w // 2 + 40, (18, 56, 100))
            renderer.draw_image(
                self._title_image,
                (sw // 2, banner_h // 2),
                size=(title_w, title_h),
                centered=True,
            )
        else:
            tc = (TITLE_COLOR[0], TITLE_COLOR[1], TITLE_COLOR[2], alpha)
            renderer.draw_text(
                self._title.upper(), (sw // 2 - len(self._title) * 12, 40), size=42, color=tc
            )

        if self._subtitle and self._show_narrative_text:
            sc = (150, 150, 160, alpha)
            renderer.draw_text(
                self._subtitle, (sw // 2 - len(self._subtitle) * 5, 95), size=18, color=sc
            )

        # Characters
        if self._character_image_left is not None:
            self._render_character_in_banner(
                renderer, self._character_image_left, banner_h, sw, left=True
            )
        if self._character_image is not None:
            self._render_character_in_banner(
                renderer, self._character_image, banner_h, sw, left=False
            )

        # Narrative text box
        box_x, box_y = 60, banner_h + 40
        box_w = sw - 120
        box_h = sh - banner_h - 120

        renderer.draw_rect((box_x, box_y, box_w, box_h), (12, 24, 36, 180))
        renderer.draw_rect((box_x, box_y, box_w, box_h), BORDER, width=1)

        # Corner accents
        renderer.draw_line((box_x, box_y), (box_x + 30, box_y), HIGHLIGHT, 2)
        renderer.draw_line((box_x, box_y), (box_x, box_y + 30), HIGHLIGHT, 2)
        renderer.draw_line(
            (box_x + box_w - 30, box_y + box_h), (box_x + box_w, box_y + box_h), HIGHLIGHT, 2
        )
        renderer.draw_line(
            (box_x + box_w, box_y + box_h - 30), (box_x + box_w, box_y + box_h), HIGHLIGHT, 2
        )

        if not self._show_narrative_text and self._title_image is not None:
            iw, ih = renderer.get_image_size(self._title_image)
            max_w = int(box_w * 0.82)
            max_h = int(box_h * 0.78)
            scale = min(max_w / iw, max_h / ih)
            img_w = max(1, int(iw * scale))
            img_h = max(1, int(ih * scale))
            renderer.draw_image(
                self._title_image,
                (box_x + box_w // 2, box_y + box_h // 2),
                size=(img_w, img_h),
                centered=True,
            )
            return

        # Rendered lines (all previous + current with typewriter)
        y = box_y + 30
        for i in range(min(self._current_line + 1, len(self._lines))):
            if i < self._current_line:
                text = self._lines[i]
                color = DIM
            else:
                text = self._lines[i][: int(self._char_progress)]
                color = TEXT_COLOR

                renderer.draw_line((box_x + 20, y + 10), (box_x + 20, y + 30), HIGHLIGHT, 3)

            self._render_wrapped(renderer, text, box_x + 40, y, box_w - 80, 22, color)

            cpl = max(1, (box_w - 80) // (22 * 0.55))
            lines_needed = max(1, len(self._lines[i]) // cpl + 1)
            y += lines_needed * 32 + 20

        # Skip hint
        if not self._all_done:
            renderer.draw_text(
                "TAB  SKIP", (sw - 160, sh - 36), size=16, color=DIM
            )

        # Prompt
        if self._all_done:
            pulse = int(127 + 127 * math.sin(self._time * 4))
            btn_text = "PRESS ENTER TO CONTINUE"
            btn_w = 290
            btn_h = 36
            btn_x = (sw - btn_w) // 2
            btn_y = sh - btn_h - 18
            renderer.draw_glow((sw // 2, btn_y + btn_h // 2), 140, (16, 56, 90))
            renderer.draw_rect((btn_x, btn_y, btn_w, btn_h), (14, 28, 46, 220))
            renderer.draw_rect(
                (btn_x, btn_y, btn_w, btn_h),
                (HIGHLIGHT[0], HIGHLIGHT[1], HIGHLIGHT[2], pulse),
                width=1,
            )
            renderer.draw_text(
                btn_text,
                (btn_x + btn_w // 2 - len(btn_text) * 4, btn_y + 10),
                size=17,
                color=(HIGHLIGHT[0], HIGHLIGHT[1], HIGHLIGHT[2], pulse),
            )
        elif self._line_done:
            ind_text = "ENTER  \u25b6  Next"
            ind_w = 162
            ind_h = 28
            ind_x = box_x + box_w - ind_w - 8
            ind_y = box_y + box_h - ind_h - 8
            renderer.draw_rect((ind_x - 6, ind_y - 4, ind_w + 6, ind_h + 4), (14, 26, 42, 200))
            renderer.draw_rect((ind_x - 6, ind_y - 4, ind_w + 6, ind_h + 4), BORDER, width=1)
            renderer.draw_text(ind_text, (ind_x, ind_y), size=16, color=HIGHLIGHT)

    def _render_wrapped(
        self,
        renderer: RenderInterface,
        text: str,
        x: int,
        y: int,
        max_width: int,
        size: int,
        color: tuple[int, int, int] | tuple[int, int, int, int],
    ) -> None:
        words = text.split()
        lines: list[str] = []
        current = ""
        cpl = max(1, max_width // (size * 0.55))
        for word in words:
            test = f"{current} {word}".strip()
            if len(test) > cpl:
                if current:
                    lines.append(current)
                current = word
            else:
                current = test
        if current:
            lines.append(current)
        for i, line in enumerate(lines):
            renderer.draw_text(line, (x, y + i * (size + 10)), size=size, color=color)
