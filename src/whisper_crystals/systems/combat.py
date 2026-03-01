"""Combat system — turn-based ship combat with damage model."""

from __future__ import annotations

import math
import random
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType

if TYPE_CHECKING:
    from whisper_crystals.core.event_bus import EventBus
    from whisper_crystals.core.game_state import GameStateData
    from whisper_crystals.entities.ship import ShipStats


# Colours
BG = (8, 14, 28)
PANEL = (14, 24, 44)
BORDER = (56, 132, 196)
TEXT = (236, 245, 255)
DIM = (132, 162, 190)
PLAYER_COLOR = (110, 214, 255)
ENEMY_COLOR = (220, 60, 40)
HEALTH_GREEN = (60, 200, 80)
HEALTH_RED = (220, 60, 40)
HIGHLIGHT = (110, 214, 255)
MISS_COLOR = (100, 100, 100)


@dataclass
class CombatShip:
    """Simplified ship representation for combat."""
    name: str
    faction_id: str
    speed: int
    armour: int
    firepower: int
    current_hull: int
    max_hull: int
    is_player: bool = False

    @classmethod
    def from_game_ship(cls, ship, is_player: bool = False) -> CombatShip:
        return cls(
            name=ship.name,
            faction_id=ship.faction_id,
            speed=ship.base_stats.speed,
            armour=ship.base_stats.armour,
            firepower=ship.base_stats.firepower,
            current_hull=ship.current_hull,
            max_hull=ship.max_hull,
            is_player=is_player,
        )

    @classmethod
    def from_template(cls, template: dict, name: str, faction_id: str) -> CombatShip:
        stats = template.get("base_stats", {})
        return cls(
            name=name,
            faction_id=faction_id,
            speed=stats.get("speed", 5),
            armour=stats.get("armour", 5),
            firepower=stats.get("firepower", 5),
            current_hull=template.get("max_hull", 100),
            max_hull=template.get("max_hull", 100),
        )


@dataclass
class CombatLog:
    entries: list[str] = field(default_factory=list)

    def add(self, text: str) -> None:
        self.entries.append(text)
        if len(self.entries) > 8:
            self.entries.pop(0)


def calculate_damage(attacker_fp: int, defender_armour: int) -> int:
    """Damage = attacker_firepower - defender_armour, min 1, with ±20% variance."""
    base = max(1, attacker_fp - defender_armour)
    variance = random.uniform(0.8, 1.2)
    return max(1, int(base * variance))


def dodge_chance(defender_speed: int) -> float:
    """Dodge probability based on speed: speed 10 → 30%, speed 1 → 3%."""
    return min(0.35, defender_speed * 0.03)


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

        # Visual animation state
        self._player_shake = 0.0
        self._enemy_shake = 0.0
        self._projectiles: list[dict] = []

    def enter(self) -> None:
        self._log.add(f"Combat! {self.player.name} vs {self.enemy.name}")
        self._log.add("Choose your action.")
        self._phase = "player_turn"
        self._selected = 0

    def exit(self) -> None:
        pass

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

    def _player_attack(self) -> None:
        """Player fires on enemy."""
        if random.random() < dodge_chance(self.enemy.speed):
            self._log.add(f"{self.enemy.name} dodges!")
        else:
            dmg = calculate_damage(self.player.firepower, self.enemy.armour)
            self.enemy.current_hull = max(0, self.enemy.current_hull - dmg)
            self._log.add(f"You deal {dmg} damage to {self.enemy.name}!")
            self._enemy_shake = 0.3

        if self.enemy.current_hull <= 0:
            self._log.add(f"{self.enemy.name} destroyed!")
            self._phase = "result"
            self._result = "victory"
        else:
            self._phase = "animating"
            self._anim_timer = 0.5

    def _enemy_attack(self) -> None:
        """Enemy fires on player."""
        if random.random() < dodge_chance(self.player.speed):
            self._log.add(f"{self.player.name} dodges!")
        else:
            dmg = calculate_damage(self.enemy.firepower, self.player.armour)
            self.player.current_hull = max(0, self.player.current_hull - dmg)
            self._log.add(f"{self.enemy.name} deals {dmg} damage!")
            self._player_shake = 0.3

        if self.player.current_hull <= 0:
            self._log.add("Your ship is destroyed!")
            self._phase = "result"
            self._result = "defeat"
        else:
            self._phase = "player_turn"
            self._log.add("Your turn. Choose an action.")

    def _attempt_flee(self) -> None:
        """Try to flee — success based on relative speed."""
        flee_chance = min(0.8, self.player.speed / max(1, self.player.speed + self.enemy.speed))
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
        # Sync player hull back
        self.game_state.player_ship.current_hull = self.player.current_hull

        if self._result == "victory":
            # Loot
            crystal_loot = random.randint(3, 10)
            salvage_loot = random.randint(5, 15)
            self.game_state.crystal_inventory += crystal_loot
            self.game_state.salvage += salvage_loot
            self.event_bus.publish(
                "combat_victory",
                enemy_faction=self.enemy.faction_id,
                crystals=crystal_loot,
                salvage=salvage_loot,
            )
            self._on_victory()
        elif self._result == "defeat":
            self._on_defeat()
        elif self._result == "fled":
            self._on_flee()

    def update(self, dt: float) -> None:
        self._player_shake = max(0.0, self._player_shake - dt)
        self._enemy_shake = max(0.0, self._enemy_shake - dt)

        if self._phase == "animating":
            self._anim_timer -= dt
            if self._anim_timer <= 0:
                self._phase = "enemy_turn"
                self._enemy_attack()

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()
        
        # Deep space combat background with navy tone
        renderer.draw_rect((0, 0, sw, sh), (8, 12, 20))

        # Title
        renderer.draw_glow((sw // 2, 30), 80, (26, 84, 124))
        renderer.draw_text("COMBAT PROTOCOL", (sw // 2 - 100, 15), size=28, color=HIGHLIGHT)
        
        # Scanner grid background
        for y in range(0, sh // 2, 40):
            renderer.draw_line((0, y), (sw, y), (12, 28, 42), 1)
        for x in range(0, sw, 40):
            renderer.draw_line((x, 0), (x, sh // 2), (12, 28, 42), 1)

        # --- Player ship (left) ---
        px, py = sw // 4, sh // 3
        if self._player_shake > 0:
            px += int(math.sin(self._player_shake * 40) * 10)
            py += int(math.cos(self._player_shake * 30) * 5)
            renderer.draw_glow((px, py), 60, (200, 50, 50)) # Hit flash
        self._draw_ship(renderer, px, py, PLAYER_COLOR, self.player, facing_right=True)

        # --- Enemy ship (right) ---
        ex, ey = 3 * sw // 4, sh // 3
        if self._enemy_shake > 0:
            ex += int(math.sin(self._enemy_shake * 40) * 10)
            ey += int(math.cos(self._enemy_shake * 30) * 5)
            renderer.draw_glow((ex, ey), 60, (200, 50, 50)) # Hit flash
        self._draw_ship(renderer, ex, ey, ENEMY_COLOR, self.enemy, facing_right=False)

        # Health bars
        self._draw_health_bar(renderer, sw // 4 - 70, sh // 3 + 80, self.player)
        self._draw_health_bar(renderer, 3 * sw // 4 - 70, sh // 3 + 80, self.enemy)

        # Combat log
        log_y = sh // 2 + 20
        # Beautiful translucent panel
        renderer.draw_rect((40, log_y - 5, sw - 80, len(self._log.entries) * 25 + 15), (14, 24, 38, 200))
        renderer.draw_rect((40, log_y - 5, sw - 80, len(self._log.entries) * 25 + 15), BORDER, width=1)
        for i, entry in enumerate(self._log.entries):
            color = TEXT
            if "destroyed" in entry.lower() or "defeat" in entry.lower():
                color = HEALTH_RED
            elif "dodges" in entry.lower() or "escaped" in entry.lower():
                color = (150, 200, 255)
            renderer.draw_text(f"> {entry}", (55, log_y + i * 25), size=16, color=color)

        # Actions
        if self._phase == "player_turn":
            action_y = sh - 120
            
            # Action panel background
            renderer.draw_glow((sw // 2, action_y + 30), 100, (26, 84, 124))
            
            for i, opt in enumerate(self._options):
                y = action_y + i * 45
                if i == self._selected:
                    # Pulsing selector
                    time_mod = (self.game_state.playtime_seconds * 5) % 1.0
                    offset = int(time_mod * 5)
                    renderer.draw_polygon(
                        [(sw // 2 - 80 + offset, y + 12), (sw // 2 - 65 + offset, y + 12), (sw // 2 - 70 + offset, y + 18)],
                        HIGHLIGHT,
                    )
                    color = (255, 255, 255)
                    renderer.draw_line((sw // 2 - 50, y + 30), (sw // 2 + 50, y + 30), HIGHLIGHT, 1)
                else:
                    color = DIM
                renderer.draw_text(opt, (sw // 2 - 50, y), size=24, color=color)
                
        elif self._phase == "result":
            result_text = {
                "victory": "VICTORY!",
                "defeat": "DEFEATED",
                "fled": "ESCAPED",
            }.get(self._result, "")
            
            result_color = HEALTH_GREEN if self._result == "victory" else HEALTH_RED if self._result == "defeat" else DIM
            
            # Big celebration glow
            renderer.draw_glow((sw // 2, sh - 90), 150, (*result_color[:2], min(255, result_color[2] + 50)))
            renderer.draw_text(result_text, (sw // 2 - len(result_text) * 10, sh - 110), size=36, color=result_color)
            
            # Pulsing continue prompt
            alpha = int(127 + 127 * math.sin(self.game_state.playtime_seconds * 5))
            renderer.draw_text(">> PRESS ENTER TO CONTINUE <<", (sw // 2 - 130, sh - 45), size=16, color=(*DIM[:2], alpha))

    def _draw_ship(
        self,
        renderer: RenderInterface,
        cx: int,
        cy: int,
        color: tuple[int, int, int],
        ship: CombatShip,
        facing_right: bool,
    ) -> None:
        """Draw a stylised ship vector."""
        s = 40
        direction = 1 if facing_right else -1
        
        # Engine glow
        renderer.draw_glow((cx - direction * int(s * 0.8), cy), 30, (100, 200, 255))
        
        # Main hull
        points = [
            (cx + direction * s, cy),
            (cx - direction * s * 0.6, cy - s * 0.4),
            (cx - direction * s * 0.8, cy),
            (cx - direction * s * 0.6, cy + s * 0.4),
        ]
        
        # Drop shadow for depth
        shadow_points = [(x + 5, y + 10) for x, y in points]
        renderer.draw_polygon(shadow_points, (0, 0, 0, 150))
        
        # Fill and border
        renderer.draw_polygon(points, color)
        renderer.draw_polygon(points, (255, 255, 255, 100), width=2)
        
        # Cockpit
        cockpit = [
            (cx + direction * int(s * 0.2), cy),
            (cx - direction * int(s * 0.2), cy - int(s * 0.2)),
            (cx - direction * int(s * 0.3), cy),
        ]
        renderer.draw_polygon(cockpit, (200, 230, 255))
        
        # Label
        renderer.draw_text(ship.name, (cx - len(ship.name) * 4, cy - s - 30), size=16, color=color)

    def _draw_health_bar(
        self,
        renderer: RenderInterface,
        x: int,
        y: int,
        ship: CombatShip,
    ) -> None:
        """Draw a health bar under a ship."""
        bar_w, bar_h = 160, 14
        pct = ship.current_hull / max(1, ship.max_hull)
        color = HEALTH_GREEN if pct > 0.5 else HEALTH_RED
        
        # Angled health bar styling
        renderer.draw_rect((x, y, bar_w, bar_h), (40, 35, 55, 200))
        renderer.draw_rect((x, y, int(bar_w * pct), bar_h), color)
        renderer.draw_rect((x, y, bar_w, bar_h), (100, 100, 100), width=1)
        
        # Segments overlay
        for sx in range(x + 20, x + bar_w, 20):
            renderer.draw_line((sx, y), (sx, y + bar_h), (20, 20, 20), 1)
            
        renderer.draw_text(f"HULL: {ship.current_hull}/{ship.max_hull}", (x, y - 20), size=14, color=color)
