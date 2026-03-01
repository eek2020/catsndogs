"""Ship management screen — read-only stats, crew, upgrades view."""

from __future__ import annotations

from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData

# Colours
BG = (8, 14, 28)
PANEL = (14, 24, 44)
BORDER = (56, 132, 196)
TEXT = (236, 245, 255)
DIM = (132, 162, 190)
HIGHLIGHT = (110, 214, 255)
STAT_COLOR = (100, 180, 255)
HEALTH_GREEN = (60, 200, 80)
HEALTH_RED = (220, 60, 40)


class ShipScreenState(GameState):
    """Overlay showing player ship stats, crew, and upgrades (read-only for PoC)."""

    state_type = GameStateType.PAUSE

    def __init__(self, machine: GameStateMachine, game_state: GameStateData) -> None:
        super().__init__(machine)
        self.game_state = game_state

    def enter(self) -> None:
        pass

    def exit(self) -> None:
        pass

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if action in (Action.CANCEL, Action.PAUSE):
                self.machine.pop()

    def update(self, dt: float) -> None:
        pass

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()
        ship = self.game_state.player_ship

        # Deep space gradient background overlay
        renderer.draw_rect((0, 0, sw, sh), (8, 12, 24, 230))
        renderer.draw_glow((sw // 2, sh // 2), 500, (18, 54, 86))

        # Stylized Header
        renderer.draw_rect((0, 0, sw, 80), (12, 22, 36, 200))
        renderer.draw_line((0, 80), (sw, 80), HIGHLIGHT, 2)
        
        # Ship Title Background Glow
        renderer.draw_glow((sw // 2, 40), 150, (26, 84, 124))
        
        # Title
        renderer.draw_text(f"VESSEL: {ship.name.upper()}", (sw // 2 - 160, 20), size=36, color=TEXT)
        renderer.draw_text(f"CLASS: {ship.ship_class.replace('_', ' ').title()}", (sw // 2 - 80, 65), size=16, color=DIM)

        # -- Left Panel: Ship Stats --
        stat_x, stat_y = 60, 120
        stat_w = 400
        
        renderer.draw_rect((stat_x - 20, stat_y - 20, stat_w + 40, sh - stat_y - 40), PANEL)
        renderer.draw_rect((stat_x - 20, stat_y - 20, stat_w + 40, sh - stat_y - 40), BORDER, width=1)
        # Decorative accents
        renderer.draw_line((stat_x - 20, stat_y - 20), (stat_x, stat_y - 20), HIGHLIGHT, 2)
        renderer.draw_line((stat_x - 20, stat_y - 20), (stat_x - 20, stat_y), HIGHLIGHT, 2)

        renderer.draw_text("SYSTEMS & CAPACITIES", (stat_x, stat_y), size=20, color=HIGHLIGHT)
        renderer.draw_line((stat_x, stat_y + 30), (stat_x + stat_w, stat_y + 30), BORDER, 1)

        stats = ship.base_stats
        stat_names = [
            ("Speed", stats.speed, (100, 200, 255)),
            ("Armour", stats.armour, (150, 150, 150)),
            ("Firepower", stats.firepower, (255, 100, 100)),
            ("Crystal Cap.", stats.crystal_capacity, (110, 214, 255)),
            ("Crew Cap.", stats.crew_capacity, (200, 180, 100)),
        ]
        
        for i, (name, val, color) in enumerate(stat_names):
            y = stat_y + 50 + i * 40
            renderer.draw_text(name.upper(), (stat_x, y), size=16, color=DIM)
            
            # Stylized stat bar
            bar_x = stat_x + 160
            bar_w = 150
            fill = min(bar_w, int(bar_w * val / 15)) # Assuming 15 is roughly max standard stat
            
            # Empty slots
            for j in range(15):
                slot_x = bar_x + j * (bar_w // 15)
                renderer.draw_rect((slot_x, y + 2, (bar_w // 15) - 2, 14), (40, 35, 55))
                
            # Filled slots
            for j in range(val):
                slot_x = bar_x + j * (bar_w // 15)
                renderer.draw_rect((slot_x, y + 2, (bar_w // 15) - 2, 14), color)
                
            renderer.draw_text(str(val), (bar_x + bar_w + 15, y), size=18, color=color)

        # Hull bar (Larger, more prominent)
        hull_y = stat_y + 280
        hull_pct = ship.current_hull / max(1, ship.max_hull)
        hcolor = HEALTH_GREEN if hull_pct > 0.5 else HEALTH_RED
        
        renderer.draw_text("HULL INTEGRITY:", (stat_x, hull_y), size=18, color=TEXT)
        
        bar_w = stat_w
        renderer.draw_rect((stat_x, hull_y + 30, bar_w, 20), (40, 35, 55))
        renderer.draw_rect((stat_x, hull_y + 30, int(bar_w * hull_pct), 20), hcolor)
        renderer.draw_rect((stat_x, hull_y + 30, bar_w, 20), BORDER, width=1)
        
        # Grid overlay on hull bar
        for sx in range(stat_x + 20, stat_x + bar_w, 20):
            renderer.draw_line((sx, hull_y + 30), (sx, hull_y + 50), (20, 20, 20), 1)
            
        renderer.draw_text(f"{ship.current_hull} / {ship.max_hull}", (stat_x + bar_w - 80, hull_y + 5), size=16, color=hcolor)

        # Cargo
        cargo_y = hull_y + 80
        renderer.draw_text("CARGO BAY", (stat_x, cargo_y), size=18, color=HIGHLIGHT)
        
        # Crystal hex representations
        for i in range(stats.crystal_capacity):
            cx = stat_x + 20 + (i % 10) * 30
            cy = cargo_y + 40 + (i // 10) * 35
            
            if i < ship.crystal_cargo:
                # Filled crystal slot
                renderer.draw_glow((cx, cy), 20, (100, 180, 255))
                renderer.draw_polygon([
                    (cx, cy - 10), (cx + 8, cy - 5), (cx + 8, cy + 5), 
                    (cx, cy + 10), (cx - 8, cy + 5), (cx - 8, cy - 5)
                ], (180, 220, 255))
            else:
                # Empty crystal slot
                renderer.draw_polygon([
                    (cx, cy - 10), (cx + 8, cy - 5), (cx + 8, cy + 5), 
                    (cx, cy + 10), (cx - 8, cy + 5), (cx - 8, cy - 5)
                ], (40, 35, 55))
                renderer.draw_polygon([
                    (cx, cy - 10), (cx + 8, cy - 5), (cx + 8, cy + 5), 
                    (cx, cy + 10), (cx - 8, cy + 5), (cx - 8, cy - 5)
                ], BORDER, width=1)

        # -- Right Panel: Crew and Upgrades --
        crew_x = 540
        crew_y = 120
        crew_w = sw - crew_x - 40
        
        renderer.draw_rect((crew_x - 20, crew_y - 20, crew_w + 40, sh - crew_y - 40), (12, 20, 36, 220))
        renderer.draw_rect((crew_x - 20, crew_y - 20, crew_w + 40, sh - crew_y - 40), BORDER, width=1)

        renderer.draw_text(f"CREW MANIFEST ({len(ship.crew)}/{stats.crew_capacity})", (crew_x, crew_y), size=20, color=HIGHLIGHT)
        renderer.draw_line((crew_x, crew_y + 30), (crew_x + crew_w, crew_y + 30), BORDER, 1)
        
        if ship.crew:
            for i, member in enumerate(ship.crew):
                y = crew_y + 50 + i * 60
                
                # Crew card styling
                renderer.draw_rect((crew_x, y - 10, crew_w, 50), (14, 26, 42, 150))
                renderer.draw_rect((crew_x, y - 10, 4, 50), (100, 200, 255))
                
                # Simple portrait placeholder based on role
                px, py = crew_x + 25, y + 15
                renderer.draw_circle((px, py), 15, (40, 35, 55))
                renderer.draw_circle((px, py), 15, (100, 200, 255), width=1)
                
                role_text = f"{member.name.upper()}  //  {member.role.upper()}  //  SKILL: {member.skill_level}"
                renderer.draw_text(role_text, (crew_x + 60, y - 5), size=16, color=TEXT)
                
                if member.faction_origin:
                    renderer.draw_text(
                        f"ORIGIN: {member.faction_origin.upper()}",
                        (crew_x + 60, y + 15),
                        size=12,
                        color=DIM,
                    )
        else:
            renderer.draw_text("No crew currently assigned to this vessel.", (crew_x, crew_y + 50), size=14, color=DIM)

        # Upgrades
        upgrade_y = crew_y + 300
        renderer.draw_text("INSTALLED UPGRADES", (crew_x, upgrade_y), size=20, color=HIGHLIGHT)
        renderer.draw_line((crew_x, upgrade_y + 30), (crew_x + crew_w, upgrade_y + 30), BORDER, 1)
        
        if ship.upgrades:
            for i, upg in enumerate(ship.upgrades):
                y = upgrade_y + 50 + i * 40
                renderer.draw_polygon([
                    (crew_x, y+6), (crew_x + 10, y), (crew_x + 20, y+6), (crew_x + 10, y+12)
                ], (180, 220, 100))
                
                upg_text = f"{upg.name.upper()}  [ +{upg.modifier} {upg.target_stat.upper()} ]"
                renderer.draw_text(upg_text, (crew_x + 35, y), size=16, color=TEXT)
        else:
            renderer.draw_text("No structural upgrades installed.", (crew_x, upgrade_y + 50), size=14, color=DIM)

        # Footer
        renderer.draw_text("ESC TO CLOSE", (sw // 2 - 50, sh - 30), size=14, color=DIM)
