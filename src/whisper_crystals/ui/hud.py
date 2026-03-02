"""HUD overlay — crystal count, health bar, arc label, salvage."""

from __future__ import annotations

import math
from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import RenderInterface

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData


class HUD:
    """Renders player stats, current arc, and temporary messages."""

    def __init__(self) -> None:
        self._message: str = ""
        self._message_timer: float = 0.0

    def flash(self, message: str, duration: float = 2.0) -> None:
        """Display a temporary message on screen."""
        self._message = message
        self._message_timer = duration

    def update(self, dt: float) -> None:
        if self._message_timer > 0:
            self._message_timer -= dt

    def draw(self, renderer: RenderInterface, state: GameStateData, arc_title: str, active_pois: list[dict] | None = None) -> None:
        sw, sh = renderer.get_screen_size()

        # Top bar styling - beautiful angled high-tech panel
        # We'll use a semi-transparent dark background with glowing bottom edge
        renderer.draw_rect((0, 0, sw, 45), (15, 12, 25, 200))
        renderer.draw_line((0, 45), (sw, 45), (180, 50, 220), 2)  # Glowing purple edge
        
        # Angled decorative accent on the right side
        renderer.draw_polygon([
            (sw - 300, 45),
            (sw - 280, 55),
            (sw - 20, 55),
            (sw, 45)
        ], (30, 25, 45, 180))
        renderer.draw_line((sw - 280, 55), (sw - 20, 55), (80, 50, 130), 1)

        # Left side: Crystals & Salvage
        y = 10
        # Crystal Icon
        renderer.draw_polygon([(15, y+10), (21, y+1), (27, y+10), (21, y+19)], (100, 180, 255))
        renderer.draw_text(f"Crystals: {state.crystal_inventory}", (38, y+1), size=20, color=(220, 220, 230))

        # Salvage Icon
        renderer.draw_rect((178, y+5, 11, 11), (180, 150, 100))
        renderer.draw_line((183, y+1), (183, y+19), (120, 100, 80), 2)
        renderer.draw_text(f"Salvage: {state.salvage}", (198, y+1), size=20, color=(220, 220, 230))

        # Center: Current Arc
        if arc_title:
            arc_text = f"ARC {state.current_arc.split('_')[1]}: {arc_title.upper()}"
            renderer.draw_text(arc_text, (sw // 2 - len(arc_text) * 5, y+1), size=20, color=(180, 50, 220))

        # Right side: Ship Hull
        hull_pct = state.player_ship.current_hull / max(1, state.player_ship.max_hull)
        hcolor = (60, 200, 80) if hull_pct > 0.5 else (220, 60, 40)

        hull_text = f"Hull: {state.player_ship.current_hull}/{state.player_ship.max_hull}"
        renderer.draw_text(hull_text, (sw - 230, y+1), size=20, color=hcolor)

        # Angled health bar next to text
        bar_x = sw - 120
        renderer.draw_polygon([
            (bar_x, y+5), (bar_x + 100, y+5),
            (bar_x + 95, y+17), (bar_x - 5, y+17)
        ], (40, 35, 55, 200))

        if pct_width := int(100 * hull_pct):
            renderer.draw_polygon([
                (bar_x, y+5), (bar_x + pct_width, y+5),
                (bar_x + pct_width - 5, y+17), (bar_x - 5, y+17)
            ], hcolor)

        # Flashing central message with cinematic drop shadow & glow
        if self._message_timer > 0:
            msg_y = sh // 4
            
            # Pulse opacity based on time
            alpha = min(255, int(self._message_timer * 400))
            if self._message_timer > 1.0:
                alpha = int(200 + 55 * math.sin(state.playtime_seconds * 10))
                
            renderer.draw_glow((sw // 2, msg_y + 15), 100, (50, 20, 80))
            
            text_x = sw // 2 - len(self._message) * 6
            # Drop shadow
            renderer.draw_text(
                self._message,
                (text_x + 2, msg_y + 2),
                size=28,
                color=(10, 5, 15, alpha),
            )
            # Main text
            renderer.draw_text(
                self._message,
                (text_x, msg_y),
                size=28,
                color=(255, 200, 50, alpha),
            )

        self._draw_minimap(renderer, state, active_pois)

    def _draw_minimap(self, renderer: RenderInterface, state: GameStateData, active_pois: list[dict] | None = None) -> None:
        """Draws a 150x150 minimap in the bottom right corner showing the player."""
        sw, sh = renderer.get_screen_size()
        
        map_size = 150
        map_x = sw - map_size - 20
        map_y = sh - map_size - 20
        
        # Background
        renderer.draw_rect((map_x, map_y, map_size, map_size), (12, 18, 28, 200))
        renderer.draw_rect((map_x, map_y, map_size, map_size), (50, 100, 180, 255), width=2)
        
        # Grid lines for flavour
        for i in range(1, 4):
            renderer.draw_line((map_x + i * (map_size // 4), map_y), 
                               (map_x + i * (map_size // 4), map_y + map_size), 
                               (30, 50, 80, 150), 1)
            renderer.draw_line((map_x, map_y + i * (map_size // 4)), 
                               (map_x + map_size, map_y + i * (map_size // 4)), 
                               (30, 50, 80, 150), 1)

        # Player Blip
        # Assuming world coordinates roughly map linearly for visual purposes
        # Let's say the minimap covers a 10000x10000 area centered on (0,0)
        world_scale = 10000.0
        
        # Clamp player position for minimap
        px = max(-world_scale/2, min(world_scale/2, state.position_x))
        py = max(-world_scale/2, min(world_scale/2, state.position_y))
        
        normalized_x = (px + world_scale/2) / world_scale
        normalized_y = (py + world_scale/2) / world_scale
        
        blip_x = map_x + int(normalized_x * map_size)
        blip_y = map_y + int(normalized_y * map_size)
        
        # Draw POIs
        if active_pois:
            for poi in active_pois:
                poi_x = max(-world_scale/2, min(world_scale/2, poi["x"]))
                poi_y = max(-world_scale/2, min(world_scale/2, poi["y"]))
                
                poi_nx = (poi_x + world_scale/2) / world_scale
                poi_ny = (poi_y + world_scale/2) / world_scale
                
                poi_map_x = map_x + int(poi_nx * map_size)
                poi_map_y = map_y + int(poi_ny * map_size)
                
                renderer.draw_circle((poi_map_x, poi_map_y), 3, poi["color"])
        
        # Player Blip on top
        renderer.draw_circle((blip_x, blip_y), 3, (110, 214, 255))
        renderer.draw_circle((blip_x, blip_y), 6, (110, 214, 255, 100), width=1)
        
        renderer.draw_text("SECTOR MAP", (map_x + 5, map_y + 5), size=12, color=(100, 180, 220))
