"""Navigation state — player flies ship through space, triggers encounters."""

from __future__ import annotations

import math
import random
from pathlib import Path
from typing import TYPE_CHECKING

import pygame

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType
from whisper_crystals.engine.camera import Camera
from whisper_crystals.engine.starfield import Starfield
from whisper_crystals.ui.hud import HUD

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData
    from whisper_crystals.engine.input_handler import PygameInputHandler
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
        input_handler: PygameInputHandler,
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
        self.ship_x: float = 0.0
        self.ship_y: float = 0.0
        self.ship_angle: float = 0.0
        
        # Trail particles
        self._trail: list[tuple[float, float, float, float]] = []  # x, y, life, max_life

        # Encounter check timer
        self._encounter_timer: float = 0.0
        # Distance since last check (require movement to trigger)
        self._distance_moved: float = 0.0

        # Optional sprite ship rendering (falls back to vector ship if loading fails)
        self._ship_sprite: pygame.Surface | None = None
        self._ship_sprite_points_up = False
        self._load_ship_sprite()

    def _load_ship_sprite(self) -> None:
        """Load ship artwork from design/ships, preferring right-facing sprite."""
        project_root = Path(__file__).resolve().parents[3]
        ships_dir = project_root / "design" / "ships"
        candidates = [
            (ships_dir / "ship_r_side.png", False),
            (ships_dir / "ship_up_side.png", True),
        ]

        for image_path, points_up in candidates:
            if not image_path.exists():
                continue
            try:
                image = pygame.image.load(str(image_path))
                image = image.convert_alpha()
                image = self._apply_background_transparency(image)

                max_edge = max(image.get_width(), image.get_height())
                if max_edge > SHIP_SPRITE_MAX_EDGE:
                    scale = SHIP_SPRITE_MAX_EDGE / max_edge
                    new_size = (
                        max(1, int(image.get_width() * scale)),
                        max(1, int(image.get_height() * scale)),
                    )
                    image = pygame.transform.smoothscale(image, new_size)

                self._ship_sprite = image
                self._ship_sprite_points_up = points_up
                return
            except pygame.error:
                continue

    def _apply_background_transparency(self, image: pygame.Surface) -> pygame.Surface:
        """Remove flat backdrop color from opaque sprite exports.

        Uses the average of corner pixels as the backdrop sample and makes close
        matches transparent. This removes gray export boxes while preserving the
        ship artwork.
        """
        image_alpha = image.convert_alpha()
        width, height = image_alpha.get_size()
        corners = [
            image_alpha.get_at((0, 0)),
            image_alpha.get_at((width - 1, 0)),
            image_alpha.get_at((0, height - 1)),
            image_alpha.get_at((width - 1, height - 1)),
        ]
        if any(c.a < 250 for c in corners):
            return image_alpha

        bg_r = sum(c.r for c in corners) // 4
        bg_g = sum(c.g for c in corners) // 4
        bg_b = sum(c.b for c in corners) // 4
        tolerance = 26

        for y in range(height):
            for x in range(width):
                px = image_alpha.get_at((x, y))
                if (
                    abs(px.r - bg_r) <= tolerance
                    and abs(px.g - bg_g) <= tolerance
                    and abs(px.b - bg_b) <= tolerance
                ):
                    image_alpha.set_at((x, y), (px.r, px.g, px.b, 0))

        return image_alpha

    def _render_vector_ship(self, renderer: RenderInterface, sx: int, sy: int, a: float) -> None:
        """Fallback ship rendering when sprite art is unavailable."""
        s = SHIP_SIZE

        # Ship shadow
        points_shadow = [
            (sx + math.cos(a) * s + 5, sy + math.sin(a) * s + 10),
            (sx + math.cos(a + 2.5) * s * 0.7 + 5, sy + math.sin(a + 2.5) * s * 0.7 + 10),
            (sx + math.cos(a - 2.5) * s * 0.7 + 5, sy + math.sin(a - 2.5) * s * 0.7 + 10),
        ]
        renderer.draw_polygon(points_shadow, (0, 0, 0, 150))

        # Main hull
        points = [
            (sx + math.cos(a) * s, sy + math.sin(a) * s),
            (sx + math.cos(a + 2.5) * s * 0.7, sy + math.sin(a + 2.5) * s * 0.7),
            (sx + math.cos(a - 2.5) * s * 0.7, sy + math.sin(a - 2.5) * s * 0.7),
        ]
        renderer.draw_polygon(points, SHIP_COLOR)

        # Inner hull accent
        inner_points = [
            (sx + math.cos(a) * s * 0.7, sy + math.sin(a) * s * 0.7),
            (sx + math.cos(a + 2.5) * s * 0.4, sy + math.sin(a + 2.5) * s * 0.4),
            (sx + math.cos(a - 2.5) * s * 0.4, sy + math.sin(a - 2.5) * s * 0.4),
        ]
        renderer.draw_polygon(inner_points, (220, 100, 255))

        # Cockpit glass
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
                pass  # Pause state in later session

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
            # Smoothly interpolate angle
            target_angle = math.atan2(dy, dx)
            # Find shortest rotation path
            diff = (target_angle - self.ship_angle + math.pi) % (2 * math.pi) - math.pi
            self.ship_angle += diff * min(1.0, dt * 10.0)

        move = SHIP_SPEED * dt
        if is_moving:
            self.ship_x += dx * move
            self.ship_y += dy * move
            self._distance_moved += abs(dx * move) + abs(dy * move)
            
            # Spawn trail particles
            if random.random() < 0.6:
                # Add some spread to the trail emission point behind the ship
                ex = self.ship_x - math.cos(self.ship_angle) * SHIP_SIZE * 0.8
                ey = self.ship_y - math.sin(self.ship_angle) * SHIP_SIZE * 0.8
                spread_x = random.uniform(-3, 3)
                spread_y = random.uniform(-3, 3)
                life = random.uniform(0.5, 1.2)
                self._trail.append((ex + spread_x, ey + spread_y, life, life))

        # Update trail particles
        new_trail = []
        for tx, ty, life, max_life in self._trail:
            life -= dt
            if life > 0:
                new_trail.append((tx, ty, life, max_life))
        self._trail = new_trail

        # Sync position to game state
        if self.game_state_data:
            self.game_state_data.position_x = self.ship_x
            self.game_state_data.position_y = self.ship_y
            self.game_state_data.playtime_seconds += dt

        self.camera.follow((self.ship_x, self.ship_y), dt, smoothing=8.0)
        self.hud.update(dt)

        # Periodically check for encounter triggers
        self._encounter_timer += dt
        if self._encounter_timer >= ENCOUNTER_CHECK_INTERVAL and self._distance_moved > 50:
            self._encounter_timer = 0.0
            self._distance_moved = 0.0
            self._check_encounters()

    def _check_encounters(self) -> None:
        """Evaluate encounter triggers and fire the first match."""
        if not self.encounter_engine or not self.game_state_data:
            return

        encounter = self.encounter_engine.check_triggers(self.game_state_data)
        if encounter and self._on_encounter:
            self._on_encounter(encounter)

    def _check_arc_exit(self) -> None:
        """Check if arc exit conditions are met after an encounter resolves."""
        if not self.narrative or not self.game_state_data:
            return
        if self.narrative.check_arc_exit(self.game_state_data):
            if self._on_arc_complete:
                self._on_arc_complete()

    def on_return_from_encounter(self) -> None:
        """Called when dialogue/combat finishes and we resume navigation."""
        self._encounter_timer = 0.0
        self._distance_moved = 0.0
        self._check_arc_exit()

    def render(self, renderer: RenderInterface) -> None:
        # Starfield
        self.starfield.draw(renderer, self.camera.x, self.camera.y)
        
        # Engine trail
        for tx, ty, life, max_life in self._trail:
            sx, sy = self.camera.world_to_screen((tx, ty))
            alpha = int((life / max_life) * 200)
            radius = int(2 + (life / max_life) * 4)
            # Draw glowing cyan/purple trail
            renderer.draw_circle((sx, sy), radius, (100, 180, 255, alpha))

        # Ship body
        sx, sy = self.camera.world_to_screen((self.ship_x, self.ship_y))
        a = self.ship_angle
        s = SHIP_SIZE

        if self._ship_sprite is not None and hasattr(renderer, "screen"):
            angle_degrees = math.degrees(a)
            if self._ship_sprite_points_up:
                angle_degrees += 90.0
            rotated = pygame.transform.rotozoom(self._ship_sprite, -angle_degrees, 1.0)
            ship_rect = rotated.get_rect(center=(sx, sy))
            renderer.screen.blit(rotated, ship_rect)
        else:
            self._render_vector_ship(renderer, sx, sy, a)
        
        # Engine glow
        engine_x = int(sx - math.cos(a) * s * 0.4)
        engine_y = int(sy - math.sin(a) * s * 0.4)
        
        # Pulse engine glow if moving
        pulse = 1.0
        if self.input_handler.is_action_held(Action.MOVE_UP) or \
           self.input_handler.is_action_held(Action.MOVE_DOWN) or \
           self.input_handler.is_action_held(Action.MOVE_LEFT) or \
           self.input_handler.is_action_held(Action.MOVE_RIGHT):
            pulse = 1.0 + 0.5 * math.sin(self.game_state_data.playtime_seconds * 20 if self.game_state_data else 0)
            renderer.draw_glow((engine_x, engine_y), int(15 * pulse), (100, 200, 255))
            
        renderer.draw_circle((engine_x, engine_y), int(4 * pulse), (200, 240, 255))

        # HUD
        if self.game_state_data:
            arc_title = ""
            if self.narrative:
                arc_title = self.narrative.get_arc_title(self.game_state_data.current_arc)
            self.hud.draw(renderer, self.game_state_data, arc_title)
            # Controls hint
            sw, sh = renderer.get_screen_size()
            
            # Subtle dark panel for controls
            renderer.draw_rect((sw // 2 - 280, sh - 38, 560, 38), (16, 12, 26, 160))
            renderer.draw_line((sw // 2 - 280, sh - 38), (sw // 2 + 280, sh - 38), (70, 44, 110), 1)

            renderer.draw_text(
                "WASD: MOVE   |   E: FACTIONS   |   SPACE: SHIP   |   ESC: PAUSE",
                (sw // 2 - 245, sh - 28),
                size=16,
                color=(160, 160, 170),
            )
        else:
            renderer.draw_text("WASD to move", (10, 34), size=14, color=(80, 80, 80))
