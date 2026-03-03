"""Combat UI state — turn-based ship combat rendering and interaction."""

from __future__ import annotations

import math
import random
import logging
from dataclasses import dataclass
from typing import TYPE_CHECKING
from whisper_crystals.core.interfaces import Action, RenderInterface

from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType
from whisper_crystals.systems.combat import CombatLog, CombatShip, calculate_damage, dodge_chance

if TYPE_CHECKING:
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Lightweight rect helper (engine-agnostic — no pygame dependency)
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class _Rect:
    """Minimal axis-aligned rectangle with pygame.Rect-style accessors."""

    x: int
    y: int
    w: int
    h: int

    @property
    def center(self) -> tuple[int, int]:
        return (self.x + self.w // 2, self.y + self.h // 2)

    @property
    def centerx(self) -> int:
        return self.x + self.w // 2

    @property
    def centery(self) -> int:
        return self.y + self.h // 2

    @property
    def top(self) -> int:
        return self.y

    @property
    def bottom(self) -> int:
        return self.y + self.h

    @property
    def left(self) -> int:
        return self.x

    @property
    def right(self) -> int:
        return self.x + self.w

    @property
    def midtop(self) -> tuple[int, int]:
        return (self.centerx, self.y)

    @property
    def midbottom(self) -> tuple[int, int]:
        return (self.centerx, self.y + self.h)

    @classmethod
    def from_center(cls, cx: int, cy: int, w: int, h: int) -> _Rect:
        """Create a rect centered on (cx, cy) with the given dimensions."""
        return cls(cx - w // 2, cy - h // 2, w, h)


# ---------------------------------------------------------------------------
# Absolute anchor coordinates (design resolution: 1024 × 576)
# ---------------------------------------------------------------------------
# These are pixel-mapped from combat_background.png.  At runtime they are
# scaled linearly to the actual screen size so everything stays aligned.

_DESIGN_W, _DESIGN_H = 1024, 576

# Porthole glass centres — radial-edge circle fit from combat_background.png
_PORTHOLE_LEFT_CX, _PORTHOLE_LEFT_CY = 253, 176
_PORTHOLE_RIGHT_CX, _PORTHOLE_RIGHT_CY = 773, 176

# Health-bar slot centres — CX matches porthole; CY on brass shelf below
_HEALTHBAR_LEFT_CX, _HEALTHBAR_LEFT_CY = 253, 252
_HEALTHBAR_RIGHT_CX, _HEALTHBAR_RIGHT_CY = 773, 252

# Ship titles: render with midbottom at this Y (above portholes)
_TITLE_MIDBOTTOM_Y = 105

# Hull text: render with midtop at this Y
_HULL_TEXT_MIDTOP_Y = 268

# Health-bar slot size (pixels in the design resolution) - matched to bronze frame
_BAR_W, _BAR_H = 180, 20

# Parchment combat-log region — bounds measured from combat_background.png
# Parchment strip spans design Y ≈ 290–352; inset for text padding.
_LOG_TOP_Y = 298
_LOG_BOT_Y = 343
_LOG_MARGIN_X = 75

_TITLE_FONT_SIZE = 36
_LOG_FONT_SIZE = 18

# Action / compass area
_DESIGN_ACTION_Y = 470


def _scale(dx: int, dy: int, sw: int, sh: int) -> tuple[int, int]:
    """Scale a design-resolution coordinate to actual screen pixels."""
    return int(dx * sw / _DESIGN_W), int(dy * sh / _DESIGN_H)


def _scale_x(dx: int, sw: int) -> int:
    """Scale a single x-coordinate."""
    return int(dx * sw / _DESIGN_W)


def _scale_y(dy: int, sh: int) -> int:
    """Scale a single y-coordinate."""
    return int(dy * sh / _DESIGN_H)


# ---------------------------------------------------------------------------
# Steampunk colour palette
# ---------------------------------------------------------------------------
# Text on parchment / brass UI
TEXT = (42, 30, 18)
TEXT_LIGHT = (70, 52, 34)
DIM = (180, 160, 130)
HIGHLIGHT = (210, 175, 95)
HIGHLIGHT_BRIGHT = (240, 210, 130)
PLAYER_COLOR = (120, 210, 255)
ENEMY_COLOR = (255, 100, 80)
HEALTH_GREEN = (60, 180, 70)
HEALTH_RED = (190, 50, 35)
HEALTH_BG = (40, 35, 30, 200)
HEALTH_FRAME = (140, 115, 75)
MISS_COLOR = (100, 90, 70)
LOG_TEXT = (42, 30, 18)
LOG_HIGHLIGHT = (160, 30, 20)
LOG_DODGE = (30, 70, 120)
RESULT_VICTORY = (60, 160, 60)
RESULT_DEFEAT = (190, 50, 35)
RESULT_FLED = (120, 100, 78)
PARCHMENT_TEXT = (42, 30, 18)

# Laser effect colours
LASER_PLAYER = (100, 200, 255)
LASER_ENEMY = (255, 80, 50)
LASER_GLOW = (200, 230, 255)

COMBAT_SHIP_SIZE = (100, 80)


class CombatState(GameState):
    """Turn-based combat encounter."""

    state_type = GameStateType.COMBAT

    def __init__(
        self,
        machine: GameStateMachine,
        player_ship: CombatShip,
        enemy_ship: CombatShip,
        game_state: GameStateData,
        event_bus: EventBus,
        on_victory: callable,
        on_defeat: callable,
        on_flee: callable,
        sprite_manager: object | None = None,
        background: object | None = None,
    ) -> None:
        super().__init__(machine)
        self.player = player_ship
        self.enemy = enemy_ship
        self.game_state = game_state
        self.event_bus = event_bus
        self._on_victory = on_victory
        self._on_defeat = on_defeat
        self._on_flee = on_flee

        self._options = ["Fire!", "Flee"]
        self._selected = 0
        self._phase = "player_turn"  # player_turn, animating, enemy_turn, result
        self._result = ""  # "victory", "defeat", "fled"
        self._log = CombatLog()
        self._anim_timer = 0.0
        self._flee_attempts = 0

        # Visual animation state
        self._player_shake = 0.0
        self._enemy_shake = 0.0
        self._projectiles: list[dict] = []
        self._lasers: list[dict] = []  # active laser beams

        # Ship sprites (loaded lazily from SpriteManager)
        self._sprite_manager = sprite_manager
        self._player_sprite: object | None = None
        self._enemy_sprite: object | None = None
        self._sprites_loaded = False

        # Background image
        self._background = background


    def _ensure_sprites_loaded(self) -> None:
        """Lazily load ship sprites for combat display."""
        if self._sprites_loaded:
            return
        self._sprites_loaded = True
        sm = self._sprite_manager
        if sm is None:
            return
        # Player ship (facing right)
        player_tmpl = getattr(self.player, "ship_template_id", "corsair_raider")
        self._player_sprite = sm.get_ship(
            player_tmpl or "corsair_raider", size=COMBAT_SHIP_SIZE,
        )
        # Enemy ship (facing left = flipped)
        enemy_tmpl = getattr(self.enemy, "ship_template_id", "")
        if enemy_tmpl:
            self._enemy_sprite = sm.get_ship(
                enemy_tmpl, size=COMBAT_SHIP_SIZE, flip_x=True,
            )

    # ------------------------------------------------------------------
    # State lifecycle
    # ------------------------------------------------------------------

    def enter(self) -> None:
        logger.info("Combat started! %s vs %s", self.player.name, self.enemy.name)
        self._log.add(f"Combat! {self.player.name} vs {self.enemy.name}")
        self._log.add("Choose your action.")
        self._phase = "player_turn"
        self._selected = 0

    def exit(self) -> None:
        pass

    # ------------------------------------------------------------------
    # Input
    # ------------------------------------------------------------------

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if self._phase == "player_turn":
                if action in (Action.MOVE_UP, Action.MENU_UP):
                    self._selected = (self._selected - 1) % len(self._options)
                elif action in (Action.MOVE_DOWN, Action.MENU_DOWN):
                    self._selected = (self._selected + 1) % len(self._options)
                elif action == Action.CONFIRM:
                    if self._selected == 0:
                        self._player_attack()
                    elif self._selected == 1:
                        self._attempt_flee()
            elif self._phase == "result":
                if action == Action.CONFIRM:
                    self._finish()

    # ------------------------------------------------------------------
    # Combat logic (unchanged)
    # ------------------------------------------------------------------

    def _player_attack(self) -> None:
        """Player fires on enemy."""
        hit = random.random() >= dodge_chance(self.enemy.speed)
        if not hit:
            self._log.add(f"{self.enemy.name} dodges!")
            self.event_bus.publish("play_sfx", "laser_miss")
        else:
            dmg = calculate_damage(self.player.firepower, self.enemy.armour)
            self.enemy.current_hull = max(0, self.enemy.current_hull - dmg)
            self._log.add(f"You deal {dmg} damage to {self.enemy.name}!")
            self._enemy_shake = 0.3
            self.event_bus.publish("play_sfx", "laser_hit")

        self.event_bus.publish("play_sfx", "laser_fire")
        # Spawn laser beam from player to enemy
        self._lasers.append({
            "from": "player", "progress": 0.0, "hit": hit,
            "duration": 0.3, "elapsed": 0.0,
        })

        if self.enemy.current_hull <= 0:
            self._log.add(f"{self.enemy.name} destroyed!")
            self._phase = "result"
            self._result = "victory"
        else:
            self._phase = "animating"
            self._anim_timer = 0.5

    def _enemy_attack(self) -> None:
        """Enemy fires on player."""
        hit = random.random() >= dodge_chance(self.player.speed)
        if not hit:
            self._log.add(f"{self.player.name} dodges!")
            self.event_bus.publish("play_sfx", "laser_miss")
        else:
            dmg = calculate_damage(self.enemy.firepower, self.player.armour)
            self.player.current_hull = max(0, self.player.current_hull - dmg)
            self._log.add(f"{self.enemy.name} deals {dmg} damage!")
            self._player_shake = 0.3
            self.event_bus.publish("play_sfx", "laser_hit")

        self.event_bus.publish("play_sfx", "laser_fire")
        # Spawn laser beam from enemy to player
        self._lasers.append({
            "from": "enemy", "progress": 0.0, "hit": hit,
            "duration": 0.3, "elapsed": 0.0,
        })

        if self.player.current_hull <= 0:
            self._log.add("Your ship is destroyed!")
            self._phase = "result"
            self._result = "defeat"
        else:
            self._phase = "player_turn"
            self._log.add("Your turn. Choose an action.")

    def _attempt_flee(self) -> None:
        """Try to flee — success based on relative speed, improving with each attempt."""
        base_chance = self.player.speed / max(1, self.player.speed + self.enemy.speed)
        flee_chance = min(0.95, base_chance + self._flee_attempts * 0.15)
        self._flee_attempts += 1
        if random.random() < flee_chance:
            self._log.add("You escaped!")
            self._phase = "result"
            self._result = "fled"
        else:
            self._log.add("Failed to flee!")
            self._phase = "animating"
            self._anim_timer = 0.5

    def _finish(self) -> None:
        """Apply combat results to game state and call the appropriate callback."""
        self.game_state.player_ship.current_hull = self.player.current_hull
        logger.info(
            "Combat finished. Result: %s. Player hull remaining: %d",
            self._result, self.player.current_hull,
        )

        if self._result == "victory":
            crystal_loot = random.randint(3, 10)
            salvage_loot = random.randint(5, 15)
            self.game_state.crystal_inventory += crystal_loot
            self.game_state.salvage += salvage_loot
            self.event_bus.publish("play_sfx", "victory_fanfare")
            self.event_bus.publish(
                "combat_victory",
                enemy_faction=self.enemy.faction_id,
                crystals=crystal_loot,
                salvage=salvage_loot,
            )
            self._on_victory()
        elif self._result == "defeat":
            self.event_bus.publish("play_sfx", "explosion_large")
            self._on_defeat()
        elif self._result == "fled":
            self.event_bus.publish("play_sfx", "engine_boost")
            self._on_flee()

    def update(self, dt: float) -> None:
        self._player_shake = max(0.0, self._player_shake - dt)
        self._enemy_shake = max(0.0, self._enemy_shake - dt)

        # Tick laser animations
        for laser in self._lasers:
            laser["elapsed"] += dt
            laser["progress"] = min(1.0, laser["elapsed"] / laser["duration"])
        self._lasers = [l for l in self._lasers if l["progress"] < 1.0]

        if self._phase == "animating":
            self._anim_timer -= dt
            if self._anim_timer <= 0:
                self._phase = "enemy_turn"
                self._enemy_attack()

    # ------------------------------------------------------------------
    # Rendering
    # ------------------------------------------------------------------

    def render(self, renderer: RenderInterface) -> None:
        self._ensure_sprites_loaded()
        sw, sh = renderer.get_screen_size()

        self._render_with_background(renderer, sw, sh)

    def _render_with_background(
        self, renderer: RenderInterface, sw: int, sh: int,
    ) -> None:
        """Render the steampunk combat UI using the background image."""
        # Draw background scaled to cover
        iw, ih = renderer.get_image_size(self._background)
        bg_scale = max(sw / iw, sh / ih)
        bg_w = int(iw * bg_scale)
        bg_h = int(ih * bg_scale)
        bg_left = (sw - bg_w) // 2
        bg_top = (sh - bg_h) // 2
        renderer.draw_image(
            self._background,
            (sw // 2, sh // 2),
            size=(bg_w, bg_h),
            centered=True,
        )

        def map_to_bg(dx: int, dy: int) -> tuple[int, int]:
            return (
                bg_left + int(dx * bg_w / _DESIGN_W),
                bg_top + int(dy * bg_h / _DESIGN_H),
            )

        def map_x_to_bg(dx: int) -> int:
            return int(dx * bg_w / _DESIGN_W)

        def map_y_to_bg(dy: int) -> int:
            return bg_top + int(dy * bg_h / _DESIGN_H)

        # -- Compute absolute screen positions from design anchors ------
        lp_cx, lp_cy = map_to_bg(_PORTHOLE_LEFT_CX, _PORTHOLE_LEFT_CY)
        rp_cx, rp_cy = map_to_bg(_PORTHOLE_RIGHT_CX, _PORTHOLE_RIGHT_CY)
        bar_w = map_x_to_bg(_BAR_W)
        bar_h = max(12, int(_BAR_H * bg_h / _DESIGN_H))

        # Porthole rects (ship_rect.center = porthole center)
        porthole_left = _Rect.from_center(lp_cx, lp_cy, *COMBAT_SHIP_SIZE)
        porthole_right = _Rect.from_center(rp_cx, rp_cy, *COMBAT_SHIP_SIZE)

        # Health-bar slot rects
        hb_lx, hb_ly = map_to_bg(_HEALTHBAR_LEFT_CX, _HEALTHBAR_LEFT_CY)
        hb_rx, hb_ry = map_to_bg(_HEALTHBAR_RIGHT_CX, _HEALTHBAR_RIGHT_CY)
        healthbar_left = _Rect.from_center(hb_lx, hb_ly, bar_w, bar_h)
        healthbar_right = _Rect.from_center(hb_rx, hb_ry, bar_w, bar_h)

        # Title: render with midbottom at this Y
        title_y = map_y_to_bg(_TITLE_MIDBOTTOM_Y)

        # Hull text: render with midtop at this Y
        hull_y = map_y_to_bg(_HULL_TEXT_MIDTOP_Y)

        # Log and action areas
        log_top = map_y_to_bg(_LOG_TOP_Y)
        log_bot = map_y_to_bg(_LOG_BOT_Y)
        action_y = map_y_to_bg(_DESIGN_ACTION_Y)

        # -- Ship sprites: center = porthole glass center ----------------
        px, py = porthole_left.center
        ex, ey = porthole_right.center

        # Shake offsets the draw position, not the anchor
        if self._player_shake > 0:
            px += int(math.sin(self._player_shake * 40) * 8)
            py += int(math.cos(self._player_shake * 30) * 4)
        if self._enemy_shake > 0:
            ex += int(math.sin(self._enemy_shake * 40) * 8)
            ey += int(math.cos(self._enemy_shake * 30) * 4)

        # -- Ship sprites inside portholes ---------------------------------
        self._draw_ship(
            renderer, px, py, PLAYER_COLOR, self.player,
            facing_right=True, sprite=self._player_sprite,
        )
        self._draw_ship(
            renderer, ex, ey, ENEMY_COLOR, self.enemy,
            facing_right=False, sprite=self._enemy_sprite,
        )

        # -- Ship name labels: drawn above portholes (on top of sprites) --
        pw, ph = renderer.measure_text(self.player.name, size=_TITLE_FONT_SIZE)
        renderer.draw_text(
            self.player.name,
            (lp_cx - pw // 2, title_y - ph),
            size=_TITLE_FONT_SIZE, color=HIGHLIGHT_BRIGHT,
        )
        ew, eh = renderer.measure_text(self.enemy.name, size=_TITLE_FONT_SIZE)
        renderer.draw_text(
            self.enemy.name,
            (rp_cx - ew // 2, title_y - eh),
            size=_TITLE_FONT_SIZE, color=HIGHLIGHT_BRIGHT,
        )

        # -- Laser beams between ships ----------------------------------
        self._draw_lasers(renderer, px, py, ex, ey)

        # -- Health bars: centered in brass slot rects ------------------
        self._draw_health_bar_styled(renderer, healthbar_left, self.player)
        self._draw_health_bar_styled(renderer, healthbar_right, self.enemy)

        # -- Hull text: midtop at hull_y --------------------------------
        self._draw_hull_text(renderer, lp_cx, hull_y, self.player)
        self._draw_hull_text(renderer, rp_cx, hull_y, self.enemy)

        # -- Combat log text drawn LAST (on top of parchment graphic) ---
        log_margin_x = map_to_bg(_LOG_MARGIN_X, 0)[0]
        self._draw_combat_log_bg(renderer, sw, sh, log_top, log_bot, log_margin_x)

        # -- Actions / result (also on top of parchment) ----------------
        if self._phase == "player_turn":
            self._draw_actions(renderer, sw, sh, action_y)
        elif self._phase == "result":
            self._draw_result(renderer, sw, sh, action_y)


    # ------------------------------------------------------------------
    # Styled sub-elements (steampunk theme)
    # ------------------------------------------------------------------

    def _draw_health_bar_styled(
        self, renderer: RenderInterface, slot: _Rect, ship: CombatShip,
    ) -> None:
        """Draw a brass-framed health bar centered inside *slot*."""
        x, y, bar_w, bar_h = slot.x, slot.y, slot.w, slot.h
        pct = ship.current_hull / max(1, ship.max_hull)
        fill_color = HEALTH_GREEN if pct > 0.5 else HEALTH_RED

        # Background
        renderer.draw_rect((x - 2, y - 2, bar_w + 4, bar_h + 4), HEALTH_FRAME)
        renderer.draw_rect((x, y, bar_w, bar_h), (30, 25, 20))

        # Fill
        fill_w = max(0, int(bar_w * pct))
        if fill_w > 0:
            renderer.draw_rect((x, y, fill_w, bar_h), fill_color)

        # Segment lines
        seg_step = max(20, bar_w // 8)
        for sx in range(x + seg_step, x + bar_w, seg_step):
            renderer.draw_line((sx, y), (sx, y + bar_h), (20, 18, 14), 1)

        # Frame outline
        renderer.draw_rect((x - 2, y - 2, bar_w + 4, bar_h + 4), HEALTH_FRAME, width=2)

    def _draw_hull_text(
        self, renderer: RenderInterface, center_x: int, top_y: int,
        ship: CombatShip,
    ) -> None:
        """Draw 'HULL: xx/xx' with its top edge at *top_y*, centred on *center_x*."""
        label = f"HULL: {ship.current_hull}/{ship.max_hull}"
        lw, _ = renderer.measure_text(label, size=15)
        renderer.draw_text(
            label, (center_x - lw // 2, top_y), size=15, color=HIGHLIGHT_BRIGHT,
        )

    def _draw_combat_log_bg(
        self, renderer: RenderInterface, sw: int, sh: int,
        log_top: int, log_bot: int,
        margin_x: int | None = None,
    ) -> None:
        """Overlay combat log text onto the parchment strip (drawn last).

        Shows the most recent entries that fit within the parchment bounds.
        *margin_x* should be background-relative; falls back to screen-scaled.
        """
        if margin_x is None:
            margin_x = _scale_x(_LOG_MARGIN_X, sw)
        available_h = log_bot - log_top
        line_h = _LOG_FONT_SIZE + 4
        max_lines = max(1, available_h // line_h)

        # Show most recent entries that fit
        visible = self._log.entries[-max_lines:]

        for i, entry in enumerate(visible):
            y = log_top + i * line_h
            if y + line_h > log_bot:
                break
            color = LOG_TEXT
            if "destroyed" in entry.lower() or "defeat" in entry.lower():
                color = LOG_HIGHLIGHT
            elif "dodges" in entry.lower() or "escaped" in entry.lower():
                color = LOG_DODGE
            renderer.draw_text(f"> {entry}", (margin_x, y), size=_LOG_FONT_SIZE, color=color, shadow=False)

    def _draw_lasers(
        self, renderer: RenderInterface,
        px: int, py: int, ex: int, ey: int,
    ) -> None:
        """Draw active laser beam effects between ships."""
        for laser in self._lasers:
            t = laser["progress"]
            if laser["from"] == "player":
                sx, sy = px + 40, py
                tx, ty = ex - 40, ey
                beam_color = LASER_PLAYER
            else:
                sx, sy = ex - 40, ey
                tx, ty = px + 40, py
                beam_color = LASER_ENEMY

            # Laser bolt tip position (travels from source to target)
            tip_x = int(sx + (tx - sx) * t)
            tip_y = int(sy + (ty - sy) * t)
            # Tail trails behind the tip
            tail_t = max(0.0, t - 0.3)
            tail_x = int(sx + (tx - sx) * tail_t)
            tail_y = int(sy + (ty - sy) * tail_t)

            # Main beam line (thick)
            renderer.draw_line((tail_x, tail_y), (tip_x, tip_y), beam_color, 3)
            # Bright core
            renderer.draw_line((tail_x, tail_y), (tip_x, tip_y), LASER_GLOW, 1)
            # Glow at tip
            renderer.draw_glow((tip_x, tip_y), 12, beam_color)

            # Impact flash when beam reaches target
            if t > 0.85 and laser["hit"]:
                flash_x, flash_y = tx, ty
                renderer.draw_glow((flash_x, flash_y), 30, (255, 200, 100))

    def _draw_actions(
        self, renderer: RenderInterface, sw: int, sh: int,
        action_y: int | None = None,
    ) -> None:
        """Draw action options in the compass dial area."""
        if action_y is None:
            action_y = int(sh * ACTION_Y)
        cx = sw // 2

        for i, opt in enumerate(self._options):
            y = action_y + i * 38
            tw, _ = renderer.measure_text(opt, size=22)
            text_x = cx - tw // 2

            if i == self._selected:
                # Animated selection indicator
                time_mod = (self.game_state.playtime_seconds * 4) % 1.0
                offset = int(time_mod * 4)
                indicator_x = text_x - 22 + offset
                renderer.draw_polygon(
                    [
                        (indicator_x, y + 6),
                        (indicator_x + 12, y + 12),
                        (indicator_x, y + 18),
                    ],
                    HIGHLIGHT_BRIGHT,
                )
                renderer.draw_text(opt, (text_x, y), size=22, color=HIGHLIGHT_BRIGHT)
                # Underline
                renderer.draw_line(
                    (text_x, y + 28), (text_x + tw, y + 28), HIGHLIGHT, 1,
                )
            else:
                # Non-selected options clearly visible
                renderer.draw_text(opt, (text_x, y), size=22, color=HIGHLIGHT)

    def _draw_result(
        self, renderer: RenderInterface, sw: int, sh: int,
        action_y: int | None = None,
    ) -> None:
        """Draw victory/defeat/fled result on the parchment area."""
        result_text = {
            "victory": "VICTORY!",
            "defeat": "DEFEATED",
            "fled": "ESCAPED",
        }.get(self._result, "")

        result_color = {
            "victory": RESULT_VICTORY,
            "defeat": RESULT_DEFEAT,
            "fled": RESULT_FLED,
        }.get(self._result, DIM)

        # Draw result text in the action area
        if action_y is None:
            action_y = int(sh * ACTION_Y)
        tw, _ = renderer.measure_text(result_text, size=32)
        renderer.draw_text(
            result_text, (sw // 2 - tw // 2, action_y - 10), size=32, color=result_color,
        )

        # Pulsing continue prompt
        alpha = int(127 + 127 * math.sin(self.game_state.playtime_seconds * 5))
        prompt = ">> PRESS ENTER TO CONTINUE <<"
        pw, _ = renderer.measure_text(prompt, size=14)
        renderer.draw_text(
            prompt, (sw // 2 - pw // 2, action_y + 40), size=14, color=(*DIM[:2], alpha),
        )

        # Hull damage warning
        if self.player.current_hull < self.player.max_hull:
            damage_percent = 1.0 - (self.player.current_hull / self.player.max_hull)
            if damage_percent > 0.1:
                warn_y = action_y + 65
                w1, _ = renderer.measure_text("HULL DAMAGE DETECTED", size=13)
                renderer.draw_text(
                    "HULL DAMAGE DETECTED",
                    (sw // 2 - w1 // 2, warn_y),
                    size=13, color=HEALTH_RED,
                )


    # ------------------------------------------------------------------
    # Ship drawing (shared by both renderers)
    # ------------------------------------------------------------------

    def _draw_ship(
        self,
        renderer: RenderInterface,
        cx: int,
        cy: int,
        color: tuple[int, int, int],
        ship: CombatShip,
        facing_right: bool,
        sprite: object | None = None,
    ) -> None:
        """Draw a ship — sprite if available, vector fallback otherwise."""
        s = 40

        # Glow behind the ship so it stands out from dark porthole background
        renderer.draw_glow((cx, cy), 55, color)

        if sprite is not None:
            renderer.draw_image(
                sprite, (cx, cy), size=COMBAT_SHIP_SIZE, centered=True,
            )
            return

        # Vector fallback — bright colours to stand out against dark portholes
        direction = 1 if facing_right else -1

        # Hull body
        points = [
            (cx + direction * s, cy),
            (cx - direction * s * 0.6, cy - s * 0.4),
            (cx - direction * s * 0.8, cy),
            (cx - direction * s * 0.6, cy + s * 0.4),
        ]
        renderer.draw_polygon(points, color)
        # Bright edge outline
        renderer.draw_polygon(points, (255, 255, 255), width=2)

        # Cockpit window
        cockpit = [
            (cx + direction * int(s * 0.2), cy),
            (cx - direction * int(s * 0.2), cy - int(s * 0.2)),
            (cx - direction * int(s * 0.3), cy),
        ]
        renderer.draw_polygon(cockpit, (220, 240, 255))

        # Engine glow at rear
        engine_x = cx - direction * int(s * 0.8)
        renderer.draw_glow((engine_x, cy), 15, (200, 220, 255))

