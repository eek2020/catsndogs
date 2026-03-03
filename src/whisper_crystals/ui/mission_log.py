"""Mission log overlay — shows active, completed, and failed side missions."""

from __future__ import annotations

import math
from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData
    from whisper_crystals.entities.side_mission import SideMission
    from whisper_crystals.systems.side_mission import SideMissionSystem

# Colours
BG = (8, 14, 28)
PANEL = (14, 24, 44)
BORDER = (56, 132, 196)
TEXT = (236, 245, 255)
DIM = (132, 162, 190)
HIGHLIGHT = (110, 214, 255)
AMBER = (220, 180, 50)
GREEN = (60, 200, 80)
RED = (220, 50, 40)

STATUS_COLORS = {
    "active": AMBER,
    "completed": GREEN,
    "failed": RED,
    "available": DIM,
}


class MissionLogState(GameState):
    """Overlay screen showing the player's mission log."""

    state_type = GameStateType.MISSION_LOG

    def __init__(
        self,
        machine: GameStateMachine,
        game_state: GameStateData,
        side_mission_system: SideMissionSystem,
        on_close: callable | None = None,
    ) -> None:
        super().__init__(machine)
        self.game_state = game_state
        self.side_mission_system = side_mission_system
        self._on_close = on_close
        self._selected = 0
        self._missions: list[SideMission] = []
        self._scroll_offset = 0

    def enter(self) -> None:
        """Build the mission list sorted by status priority."""
        self._build_mission_list()
        self._selected = 0
        self._scroll_offset = 0

    def exit(self) -> None:
        pass

    def _build_mission_list(self) -> None:
        """Gather all missions, sorted: active first, then completed, then failed."""
        status_order = {"active": 0, "available": 1, "completed": 2, "failed": 3}
        self._missions = sorted(
            self.game_state.side_missions.values(),
            key=lambda m: (status_order.get(m.status, 9), -m.priority),
        )

    def handle_input(self, actions: list[Action]) -> None:
        count = max(1, len(self._missions))
        for action in actions:
            if action in (Action.MOVE_UP, Action.MENU_UP):
                self._selected = (self._selected - 1) % count
            elif action in (Action.MOVE_DOWN, Action.MENU_DOWN):
                self._selected = (self._selected + 1) % count
            elif action in (Action.CANCEL, Action.PAUSE, Action.MISSION_LOG):
                if self._on_close:
                    self._on_close()
                else:
                    self.machine.pop()

    def update(self, dt: float) -> None:
        pass

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()

        # Dark overlay
        renderer.draw_rect((0, 0, sw, sh), (8, 12, 24, 230))
        renderer.draw_glow((sw // 2, sh // 2), 400, (18, 44, 66))

        # Title
        title_y = 30
        renderer.draw_glow((sw // 2, title_y + 15), 100, (44, 36, 14))
        renderer.draw_text(
            "MISSION LOG", (sw // 2 - 80, title_y), size=28, color=AMBER,
        )
        renderer.draw_line(
            (sw // 2 - 200, title_y + 40), (sw // 2 + 200, title_y + 40),
            BORDER, 2,
        )

        if not self._missions:
            renderer.draw_text(
                "No missions discovered yet.", (60, 120), size=20, color=DIM,
            )
            renderer.draw_text(
                "Explore the multiverse to find side missions.",
                (60, 150), size=16, color=DIM,
            )
            renderer.draw_text(
                "ESC CLOSE", (sw - 120, sh - 30), size=14, color=DIM,
            )
            return

        # Left panel — mission list
        list_x = 60
        list_y = 100
        list_w = 380
        max_visible = (sh - list_y - 60) // 50

        # Panel background
        renderer.draw_rect(
            (list_x - 20, list_y - 20, list_w + 40, sh - list_y - 40), PANEL,
        )
        renderer.draw_rect(
            (list_x - 20, list_y - 20, list_w + 40, sh - list_y - 40),
            BORDER, width=1,
        )

        # Decorative corner
        renderer.draw_line(
            (list_x - 20, list_y - 20), (list_x, list_y - 20), HIGHLIGHT, 2,
        )
        renderer.draw_line(
            (list_x - 20, list_y - 20), (list_x - 20, list_y), HIGHLIGHT, 2,
        )

        # Ensure selected is visible
        if self._selected < self._scroll_offset:
            self._scroll_offset = self._selected
        elif self._selected >= self._scroll_offset + max_visible:
            self._scroll_offset = self._selected - max_visible + 1

        for idx in range(self._scroll_offset,
                         min(len(self._missions),
                             self._scroll_offset + max_visible)):
            mission = self._missions[idx]
            row = idx - self._scroll_offset
            y = list_y + row * 50

            if idx == self._selected:
                renderer.draw_rect(
                    (list_x - 10, y - 5, list_w + 20, 45), (20, 48, 74, 200),
                )
                renderer.draw_rect((list_x - 10, y - 5, 4, 45), AMBER)
                pulse = self.game_state.playtime_seconds
                offset = int((math.sin(pulse * 5) + 1) * 3)
                renderer.draw_polygon(
                    [
                        (list_x + offset, y + 17),
                        (list_x + 10 + offset, y + 17),
                        (list_x + 5 + offset, y + 23),
                    ],
                    AMBER,
                )
                name_color = (255, 255, 255)
                text_x = list_x + 20
            else:
                name_color = DIM
                text_x = list_x + 5

            renderer.draw_text(
                mission.title, (text_x, y + 5), size=18, color=name_color,
            )

            # Status badge
            scolor = STATUS_COLORS.get(mission.status, DIM)
            status_text = mission.status.upper()
            renderer.draw_text(
                status_text,
                (text_x + list_w - 120, y + 8),
                size=14,
                color=scolor,
            )

        # Right panel — selected mission details
        det_x = 500
        det_y = 100
        det_w = sw - det_x - 40

        renderer.draw_rect(
            (det_x - 20, det_y - 20, det_w + 40, sh - det_y - 40),
            (12, 20, 36, 220),
        )
        renderer.draw_rect(
            (det_x - 20, det_y - 20, det_w + 40, sh - det_y - 40),
            BORDER, width=1,
        )

        sel = self._missions[self._selected]

        # Mission title
        renderer.draw_glow((det_x + 100, det_y + 10), 80, (44, 36, 14))
        renderer.draw_text(
            sel.title.upper(), (det_x, det_y), size=28, color=TEXT,
        )
        renderer.draw_line(
            (det_x, det_y + 38), (det_x + det_w, det_y + 38), AMBER, 1,
        )

        # Status and type
        scolor = STATUS_COLORS.get(sel.status, DIM)
        renderer.draw_text("STATUS:", (det_x, det_y + 52), size=14, color=DIM)
        renderer.draw_text(
            sel.status.upper(), (det_x + 70, det_y + 50), size=18, color=scolor,
        )
        renderer.draw_text(
            f"TYPE: {sel.mission_type.upper()}",
            (det_x + 200, det_y + 52),
            size=14,
            color=DIM,
        )

        # Description
        desc_y = det_y + 85
        renderer.draw_text(
            sel.description, (det_x, desc_y), size=16, color=TEXT,
        )

        # Objectives
        obj_y = desc_y + 50
        renderer.draw_text(
            "OBJECTIVES:", (det_x, obj_y), size=18, color=HIGHLIGHT,
        )
        for i, obj in enumerate(sel.objectives):
            oy = obj_y + 30 + i * 35
            renderer.draw_rect(
                (det_x, oy, det_w - 20, 28), (14, 26, 42, 150),
            )

            if obj.completed:
                marker_color = GREEN
                marker = "[X]"
            else:
                marker_color = DIM
                marker = "[ ]"

            renderer.draw_text(
                marker, (det_x + 8, oy + 5), size=16, color=marker_color,
            )
            obj_color = GREEN if obj.completed else TEXT
            renderer.draw_text(
                obj.description, (det_x + 40, oy + 5), size=16, color=obj_color,
            )

        # Rewards section
        reward_y = obj_y + 30 + len(sel.objectives) * 35 + 20
        if sel.rewards or sel.faction_rewards:
            renderer.draw_text(
                "REWARDS:", (det_x, reward_y), size=18, color=HIGHLIGHT,
            )
            ry = reward_y + 28
            for resource, amount in sel.rewards.items():
                renderer.draw_text(
                    f"{resource.capitalize()}: +{amount}",
                    (det_x + 10, ry),
                    size=16,
                    color=AMBER,
                )
                ry += 24
            for faction_id, delta in sel.faction_rewards.items():
                sign = "+" if delta > 0 else ""
                renderer.draw_text(
                    f"{faction_id}: {sign}{delta} rep",
                    (det_x + 10, ry),
                    size=16,
                    color=GREEN if delta > 0 else RED,
                )
                ry += 24

        # Footer
        renderer.draw_text(
            "↑/↓ SELECT   |   ESC/M CLOSE",
            (sw // 2 - 120, sh - 30),
            size=14,
            color=DIM,
        )
