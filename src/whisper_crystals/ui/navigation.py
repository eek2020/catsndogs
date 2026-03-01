"""Navigation state — player flies ship through space, triggers encounters."""

from __future__ import annotations

import math
import random
from pathlib import Path
from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType
from whisper_crystals.engine.camera import Camera
from whisper_crystals.engine.starfield import Starfield
from whisper_crystals.ui.hud import HUD

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData
    from whisper_crystals.core.interfaces import InputInterface
    from whisper_crystals.systems.encounter_engine import EncounterEngine
    from whisper_crystals.systems.narrative import NarrativeSystem

SHIP_SPEED = 300.0
SHIP_COLOR = (180, 50, 220)  # Felid Corsair purple
SHIP_SIZE = 18
SHIP_SPRITE_MAX_EDGE = 140

# How often (in seconds) we check for encounter triggers
ENCOUNTER_CHECK_INTERVAL = 1.5


class NavigationState(GameState):
    """Core gameplay state: flying the ship through space."""

    state_type = GameStateType.NAVIGATION

    def __init__(
        self,
        machine: GameStateMachine,
        camera: Camera,
        input_handler: InputInterface,
        game_state: GameStateData | None = None,
        encounter_engine: EncounterEngine | None = None,
        narrative: NarrativeSystem | None = None,
        on_encounter: callable | None = None,
        on_arc_complete: callable | None = None,
    ) -> None:
        super().__init__(machine)
        self.camera = camera
        self.input_handler = input_handler
        self.game_state_data = game_state
        self.encounter_engine = encounter_engine
        self.narrative = narrative
        self._on_encounter = on_encounter
        self._on_arc_complete = on_arc_complete

        self.starfield = Starfield(num_stars=300, seed=42)
        self.hud = HUD()

        # Player ship state
        self.ship_x: float = game_state.position_x if game_state else 0.0
        self.ship_y: float = game_state.position_y if game_state else 0.0
        self.ship_angle: float = 0.0

        # Trail particles
        self._trail: list[tuple[float, float, float, float]] = []

        # Encounter check timer
        self._encounter_timer: float = 0.0
        self._distance_moved: float = 0.0

        # Optional sprite ship rendering (loaded lazily via engine)
        self._ship_sprite: object | None = None
        self._ship_sprite_points_up = False
        self._sprite_loaded = False

    def _ensure_sprite_loaded(self) -> None:
        """Lazily load ship artwork using engine image utilities."""
        if self._sprite_loaded:
            return
        self._sprite_loaded = True

        from whisper_crystals.engine.image_utils import (
            load_image_alpha,
            remove_background_by_corners,
        )

        project_root = Path(__file__).resolve().parents[3]
        ships_dir = project_root / "design" / "ships"
        candidates = [
            (ships_dir / "ship_r_side.png", False),
            (ships_dir / "ship_up_side.png", True),
        ]

        for image_path, points_up in candidates:
            if not image_path.exists():
                continue
            image = load_image_alpha(str(image_path))
            if image is None:
                continue
            image = remove_background_by_corners(image)
            self._ship_sprite = image
            self._ship_sprite_points_up = points_up
            return

    def _render_vector_ship(self, renderer: RenderInterface, sx: int, sy: int, a: float) -> None:
        """Fallback ship rendering when sprite art is unavailable."""
        s = SHIP_SIZE

        points_shadow = [
            (sx + math.cos(a) * s + 5, sy + math.sin(a) * s + 10),
            (sx + math.cos(a + 2.5) * s * 0.7 + 5, sy + math.sin(a + 2.5) * s * 0.7 + 10),
            (sx + math.cos(a - 2.5) * s * 0.7 + 5, sy + math.sin(a - 2.5) * s * 0.7 + 10),
        ]
        renderer.draw_polygon(points_shadow, (0, 0, 0, 150))

        points = [
            (sx + math.cos(a) * s, sy + math.sin(a) * s),
            (sx + math.cos(a + 2.5) * s * 0.7, sy + math.sin(a + 2.5) * s * 0.7),
            (sx + math.cos(a - 2.5) * s * 0.7, sy + math.sin(a - 2.5) * s * 0.7),
        ]
        renderer.draw_polygon(points, SHIP_COLOR)

        inner_points = [
            (sx + math.cos(a) * s * 0.7, sy + math.sin(a) * s * 0.7),
            (sx + math.cos(a + 2.5) * s * 0.4, sy + math.sin(a + 2.5) * s * 0.4),
            (sx + math.cos(a - 2.5) * s * 0.4, sy + math.sin(a - 2.5) * s * 0.4),
        ]
        renderer.draw_polygon(inner_points, (220, 100, 255))

        renderer.draw_circle(
            (int(sx + math.cos(a) * s * 0.2), int(sy + math.sin(a) * s * 0.2)),
            4,
            (200, 240, 255),
        )

    def enter(self) -> None:
        self._encounter_timer = 0.0
        self._trail.clear()

    def exit(self) -> None:
        pass

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if action == Action.PAUSE:
                pass  # Handled by GameSession.tick() before reaching here

    def update(self, dt: float) -> None:
        dx, dy = 0.0, 0.0
        is_moving = False

        if self.input_handler.is_action_held(Action.MOVE_UP):
            dy -= 1.0
            is_moving = True
        if self.input_handler.is_action_held(Action.MOVE_DOWN):
            dy += 1.0
            is_moving = True
        if self.input_handler.is_action_held(Action.MOVE_LEFT):
            dx -= 1.0
            is_moving = True
        if self.input_handler.is_action_held(Action.MOVE_RIGHT):
            dx += 1.0
            is_moving = True

        length = math.sqrt(dx * dx + dy * dy)
        if length > 0:
            dx /= length
            dy /= length
            target_angle = math.atan2(dy, dx)
            diff = (target_angle - self.ship_angle + math.pi) % (2 * math.pi) - math.pi
            self.ship_angle += diff * min(1.0, dt * 10.0)

        move = SHIP_SPEED * dt
        if is_moving:
            self.ship_x += dx * move
            self.ship_y += dy * move
            self._distance_moved += abs(dx * move) + abs(dy * move)

            if random.random() < 0.6:
                ex = self.ship_x - math.cos(self.ship_angle) * SHIP_SIZE * 0.8
                ey = self.ship_y - math.sin(self.ship_angle) * SHIP_SIZE * 0.8
                spread_x = random.uniform(-3, 3)
                spread_y = random.uniform(-3, 3)
                life = random.uniform(0.5, 1.2)
                self._trail.append((ex + spread_x, ey + spread_y, life, life))

        new_trail = []
        for tx, ty, life, max_life in self._trail:
            life -= dt
            if life > 0:
                new_trail.append((tx, ty, life, max_life))
        self._trail = new_trail

        if self.game_state_data:
            self.game_state_data.position_x = self.ship_x
            self.game_state_data.position_y = self.ship_y
            self.game_state_data.playtime_seconds += dt

        self.camera.follow((self.ship_x, self.ship_y), dt, smoothing=8.0)
        self.hud.update(dt)

        self._encounter_timer += dt
        if self._encounter_timer >= ENCOUNTER_CHECK_INTERVAL and self._distance_moved > 50:
            self._encounter_timer = 0.0
            self._distance_moved = 0.0
            self._check_encounters()

    def _check_encounters(self) -> None:
        if not self.encounter_engine or not self.game_state_data:
            return
        encounter = self.encounter_engine.check_triggers(self.game_state_data)
        if encounter and self._on_encounter:
            self._on_encounter(encounter)

    def _check_arc_exit(self) -> None:
        if not self.narrative or not self.game_state_data:
            return
        if self.narrative.check_arc_exit(self.game_state_data):
            if self._on_arc_complete:
                self._on_arc_complete()

    def on_return_from_encounter(self) -> None:
        self._encounter_timer = 0.0
        self._distance_moved = 0.0
        self._check_arc_exit()

    def render(self, renderer: RenderInterface) -> None:
        self._ensure_sprite_loaded()

        # Starfield
        self.starfield.draw(renderer, self.camera.x, self.camera.y)

        # Engine trail
        for tx, ty, life, max_life in self._trail:
            sx, sy = self.camera.world_to_screen((tx, ty))
            alpha = int((life / max_life) * 200)
            radius = int(2 + (life / max_life) * 4)
            renderer.draw_circle((sx, sy), radius, (100, 180, 255, alpha))

        # Ship body
        sx, sy = self.camera.world_to_screen((self.ship_x, self.ship_y))
        a = self.ship_angle
        s = SHIP_SIZE

        if self._ship_sprite is not None:
            angle_degrees = math.degrees(a)
            if self._ship_sprite_points_up:
                angle_degrees += 90.0
            # Scale sprite if needed
            iw, ih = renderer.get_image_size(self._ship_sprite)
            max_edge = max(iw, ih)
            size = None
            if max_edge > SHIP_SPRITE_MAX_EDGE:
                scale = SHIP_SPRITE_MAX_EDGE / max_edge
                size = (max(1, int(iw * scale)), max(1, int(ih * scale)))
            renderer.draw_image(
                self._ship_sprite, (sx, sy), size=size, rotation=angle_degrees, centered=True
            )
        else:
            self._render_vector_ship(renderer, sx, sy, a)

        # Engine glow
        engine_x = int(sx - math.cos(a) * s * 0.4)
        engine_y = int(sy - math.sin(a) * s * 0.4)

        pulse = 1.0
        if (
            self.input_handler.is_action_held(Action.MOVE_UP)
            or self.input_handler.is_action_held(Action.MOVE_DOWN)
            or self.input_handler.is_action_held(Action.MOVE_LEFT)
            or self.input_handler.is_action_held(Action.MOVE_RIGHT)
        ):
            pulse = 1.0 + 0.5 * math.sin(
                self.game_state_data.playtime_seconds * 20 if self.game_state_data else 0
            )
            renderer.draw_glow((engine_x, engine_y), int(15 * pulse), (100, 200, 255))

        renderer.draw_circle((engine_x, engine_y), int(4 * pulse), (200, 240, 255))

        # HUD
        if self.game_state_data:
            arc_title = ""
            if self.narrative:
                arc_title = self.narrative.get_arc_title(self.game_state_data.current_arc)
            self.hud.draw(renderer, self.game_state_data, arc_title)
            sw, sh = renderer.get_screen_size()

            renderer.draw_rect((sw // 2 - 280, sh - 38, 560, 38), (16, 12, 26, 160))
            renderer.draw_line(
                (sw // 2 - 280, sh - 38), (sw // 2 + 280, sh - 38), (70, 44, 110), 1
            )

            renderer.draw_text(
                "WASD: MOVE   |   E: FACTIONS   |   SPACE: SHIP   |   ESC: PAUSE",
                (sw // 2 - 245, sh - 28),
                size=16,
                color=(160, 160, 170),
            )
        else:
            renderer.draw_text("WASD to move", (10, 34), size=14, color=(80, 80, 80))
