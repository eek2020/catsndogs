"""Purchase screen — ship repairs, upgrades, and new ship purchases."""

from __future__ import annotations

from typing import TYPE_CHECKING

from whisper_crystals.core.interfaces import Action, RenderInterface
from whisper_crystals.core.state_machine import GameState, GameStateMachine, GameStateType

if TYPE_CHECKING:
    from whisper_crystals.core.game_state import GameStateData
    from whisper_crystals.systems.economy import EconomySystem

# Colours
BG = (8, 14, 28)
PANEL = (14, 24, 44)
BORDER = (56, 132, 196)
TEXT = (236, 245, 255)
DIM = (132, 162, 190)
HIGHLIGHT = (110, 214, 255)
GREEN = (60, 200, 80)
RED = (220, 50, 40)
GOLD = (220, 180, 40)
HEALTH_GREEN = (60, 200, 80)
HEALTH_RED = (220, 60, 40)


class PurchaseScreenState(GameState):
    """Purchase screen with tabs for repairs, upgrades, and ships."""

    state_type = GameStateType.PURCHASE

    def __init__(
        self,
        machine: GameStateMachine,
        game_state: GameStateData,
        economy: EconomySystem,
        location: str,
        on_close: callable | None = None,
    ) -> None:
        super().__init__(machine)
        self.game_state = game_state
        self.economy = economy
        self.location = location
        self.on_close = on_close

        # UI state
        self._tab = 0  # 0=repairs, 1=upgrades, 2=ships
        self._selected_index = 0
        self._repair_amount = 10
        self._message = ""
        self._message_timer = 0.0

        # Load data
        self._load_data()

    def _load_data(self) -> None:
        """Load ship templates and upgrade data."""
        from whisper_crystals.core.data_loader import DataLoader
        data_loader = DataLoader()
        
        self._ship_templates_dict = data_loader.load_ship_templates()
        self._upgrades = data_loader.load_upgrades()
        
        # Convert dict to list for easier iteration
        self._ship_templates = list(self._ship_templates_dict.values())
        
        # Filter available ships based on location and faction reputation
        self._available_ships = []
        for template in self._ship_templates:
            faction_id = template["faction_id"]
            faction = self.game_state.faction_registry.get(faction_id)
            if faction and faction.reputation_with_player >= 0:
                self._available_ships.append(template)

    def enter(self) -> None:
        self._tab = 0
        self._selected_index = 0
        self._repair_amount = 10
        self._message = ""
        self._message_timer = 0.0

    def exit(self) -> None:
        pass

    def handle_input(self, actions: list[Action]) -> None:
        for action in actions:
            if action in (Action.CANCEL, Action.PAUSE):
                if self.on_close:
                    self.on_close()
                else:
                    self.machine.pop()
                return
            elif action == Action.MOVE_LEFT:
                self._tab = max(0, self._tab - 1)
                self._selected_index = 0
            elif action == Action.MOVE_RIGHT:
                self._tab = min(2, self._tab + 1)
                self._selected_index = 0
            elif action in (Action.MOVE_UP, Action.MENU_UP):
                self._handle_up()
            elif action in (Action.MOVE_DOWN, Action.MENU_DOWN):
                self._handle_down()
            elif action == Action.CONFIRM:
                self._handle_confirm()

    def update(self, dt: float) -> None:
        if self._message_timer > 0:
            self._message_timer -= dt
            if self._message_timer <= 0:
                self._message = ""

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()

        # Dark overlay
        renderer.draw_rect((0, 0, sw, sh), (8, 12, 24, 230))
        renderer.draw_glow((sw // 2, sh // 2), 400, (18, 54, 86))

        # Title
        title_y = 30
        renderer.draw_glow((sw // 2, title_y + 15), 120, (26, 84, 124))
        renderer.draw_text(
            f"SHIPYARD — {self.location.replace('_', ' ').title()}",
            (sw // 2 - 150, title_y), size=28, color=HIGHLIGHT,
        )
        renderer.draw_line(
            (sw // 2 - 200, title_y + 40),
            (sw // 2 + 200, title_y + 40),
            BORDER, 2,
        )

        # Player resources
        res_y = 80
        renderer.draw_text(
            f"Crystals: {self.game_state.crystal_inventory}",
            (60, res_y), size=18, color=HIGHLIGHT,
        )
        renderer.draw_text(
            f"Salvage: {self.game_state.salvage}",
            (300, res_y), size=18, color=GOLD,
        )
        renderer.draw_text(
            f"Ship: {self.game_state.player_ship.name}",
            (500, res_y), size=18, color=TEXT,
        )

        # Tabs
        self._render_tabs(renderer, sw)

        # Content based on selected tab
        if self._tab == 0:
            self._render_repairs_tab(renderer, sw, sh)
        elif self._tab == 1:
            self._render_upgrades_tab(renderer, sw, sh)
        else:
            self._render_ships_tab(renderer, sw, sh)

        # Flash message
        if self._message:
            msg_color = GREEN if "Success" in self._message else RED
            renderer.draw_glow((sw // 2, sh - 100), 100, (18, 54, 86))
            renderer.draw_text(
                self._message,
                (sw // 2 - 150, sh - 110), size=20, color=msg_color,
            )

        # Footer
        renderer.draw_text(
            "←/→ TABS   ↑/↓ SELECT   ENTER CONFIRM   ESC CLOSE",
            (sw // 2 - 200, sh - 30), size=14, color=DIM,
        )

    def _render_tabs(self, renderer: RenderInterface, sw: int) -> None:
        """Render the tab navigation."""
        tab_y = 120
        tab_w = 200
        tabs = ["REPAIRS", "UPGRADES", "SHIPS"]
        
        for i, label in enumerate(tabs):
            tx = sw // 2 - tab_w * 1.5 - 10 + i * (tab_w + 20)
            is_active = i == self._tab
            bg_color = (20, 48, 74, 200) if is_active else PANEL
            text_color = HIGHLIGHT if is_active else DIM
            
            renderer.draw_rect((tx, tab_y, tab_w, 40), bg_color)
            renderer.draw_rect((tx, tab_y, tab_w, 40), BORDER if is_active else PANEL, width=1)
            if is_active:
                renderer.draw_rect((tx, tab_y + 36, tab_w, 4), HIGHLIGHT)
            renderer.draw_text(label, (tx + 50, tab_y + 10), size=18, color=text_color)

    def _render_repairs_tab(self, renderer: RenderInterface, sw: int, sh: int) -> None:
        """Render the repairs tab."""
        panel_y = 180
        panel_w = sw - 120
        panel_h = sh - panel_y - 100
        
        renderer.draw_rect((60, panel_y, panel_w, panel_h), PANEL)
        renderer.draw_rect((60, panel_y, panel_w, panel_h), BORDER, width=1)

        ship = self.game_state.player_ship
        hull_pct = ship.current_hull / max(1, ship.max_hull)
        hcolor = HEALTH_GREEN if hull_pct > 0.5 else HEALTH_RED

        # Hull status
        hull_y = panel_y + 40
        renderer.draw_text("HULL INTEGRITY:", (100, hull_y), size=20, color=TEXT)
        
        bar_w = 400
        renderer.draw_rect((100, hull_y + 40, bar_w, 30), (40, 35, 55))
        renderer.draw_rect((100, hull_y + 40, int(bar_w * hull_pct), 30), hcolor)
        renderer.draw_rect((100, hull_y + 40, bar_w, 30), BORDER, width=1)
        
        renderer.draw_text(
            f"{ship.current_hull} / {ship.max_hull}",
            (100 + bar_w - 100, hull_y + 5), size=18, color=hcolor,
        )

        # Repair amount selector
        repair_y = hull_y + 100
        renderer.draw_text("Repair Amount:", (100, repair_y), size=18, color=TEXT)
        
        # Repair slider
        max_repair = ship.max_hull - ship.current_hull
        self._repair_amount = min(self._repair_amount, max_repair)
        
        renderer.draw_text(
            "↑", (280, repair_y - 20), size=16, color=HIGHLIGHT,
        )
        renderer.draw_rect((260, repair_y, 80, 30), (20, 48, 74))
        renderer.draw_rect((260, repair_y, 80, 30), HIGHLIGHT, width=1)
        renderer.draw_text(
            str(self._repair_amount),
            (280, repair_y + 5), size=18, color=TEXT,
        )
        renderer.draw_text(
            "↓", (280, repair_y + 35), size=16, color=HIGHLIGHT,
        )
        
        renderer.draw_text(
            f"(max: {max_repair})", (360, repair_y + 5), size=16, color=DIM,
        )

        # Cost calculation
        cost = self.economy.calculate_repair_cost(ship, self._repair_amount)
        cost_y = repair_y + 70
        renderer.draw_text("Repair Cost:", (100, cost_y), size=18, color=DIM)
        renderer.draw_text(
            f"{cost} salvage", (260, cost_y), size=20, color=GOLD if self.game_state.salvage >= cost else RED,
        )

        # Repair button
        if max_repair > 0:
            button_y = cost_y + 60
            can_afford = self.game_state.salvage >= cost
            button_color = (20, 48, 74) if can_afford else (40, 20, 20)
            
            renderer.draw_rect((100, button_y, 180, 40), button_color)
            renderer.draw_rect((100, button_y, 180, 40), HIGHLIGHT if can_afford else RED, width=1)
            renderer.draw_text(
                "[ENTER] REPAIR",
                (120, button_y + 10), size=18, color=HIGHLIGHT if can_afford else DIM,
            )
        else:
            renderer.draw_text(
                "Hull fully repaired!",
                (100, repair_y + 70), size=18, color=GREEN,
            )

    def _render_upgrades_tab(self, renderer: RenderInterface, sw: int, sh: int) -> None:
        """Render the upgrades tab."""
        panel_y = 180
        panel_w = sw - 120
        panel_h = sh - panel_y - 100
        
        renderer.draw_rect((60, panel_y, panel_w, panel_h), PANEL)
        renderer.draw_rect((60, panel_y, panel_w, panel_h), BORDER, width=1)

        # Filter available upgrades
        ship = self.game_state.player_ship
        available_upgrades = []
        for upgrade in self._upgrades:
            # Check if already installed
            already_installed = any(upg.upgrade_id == upgrade["upgrade_id"] for upg in ship.upgrades)
            if already_installed:
                continue
            
            # Check if can afford
            can_afford = (self.game_state.crystal_inventory >= upgrade.get("cost_crystals", 0) and
                         self.game_state.salvage >= upgrade.get("cost_salvage", 0))
            
            # Check stat caps
            current_stat = getattr(ship.base_stats, upgrade["target_stat"], 0)
            within_cap = current_stat + upgrade["modifier"] <= 15
            
            available_upgrades.append({
                **upgrade,
                "can_afford": can_afford,
                "within_cap": within_cap,
            })

        # Render upgrade list
        list_y = panel_y + 30
        for i, upgrade in enumerate(available_upgrades):
            y = list_y + i * 60
            if y + 50 > panel_y + panel_h - 20:
                break
            
            is_selected = i == self._selected_index
            bg_color = (20, 48, 74, 150) if is_selected else (14, 26, 42, 100)
            
            renderer.draw_rect((80, y - 10, panel_w - 40, 50), bg_color)
            if is_selected:
                renderer.draw_rect((80, y - 10, panel_w - 40, 50), HIGHLIGHT, width=1)
            
            # Upgrade info
            name_color = TEXT if (upgrade["can_afford"] and upgrade["within_cap"]) else DIM
            renderer.draw_text(
                upgrade["name"].upper(),
                (100, y), size=16, color=name_color,
            )
            
            effect_text = f"+{upgrade['modifier']} {upgrade['target_stat'].upper()}"
            renderer.draw_text(effect_text, (100, y + 20), size=14, color=HIGHLIGHT)
            
            # Side effects
            if "side_effect" in upgrade:
                side = upgrade["side_effect"]
                side_text = f"{side['modifier']} {side['target_stat'].upper()}"
                renderer.draw_text(side_text, (350, y + 20), size=14, color=RED)
            
            # Costs
            cost_text = f"{upgrade.get('cost_crystals', 0)} crystals  {upgrade.get('cost_salvage', 0)} salvage"
            cost_color = GREEN if upgrade["can_afford"] else RED
            renderer.draw_text(cost_text, (500, y + 10), size=14, color=cost_color)
            
            # Status indicators
            if not upgrade["within_cap"]:
                renderer.draw_text("STAT CAP", (700, y + 10), size=12, color=RED)
            elif not upgrade["can_afford"]:
                renderer.draw_text("INSUFFICIENT", (700, y + 10), size=12, color=RED)

        # Purchase prompt
        if available_upgrades and self._selected_index < len(available_upgrades):
            selected = available_upgrades[self._selected_index]
            if selected["can_afford"] and selected["within_cap"]:
                prompt_y = panel_y + panel_h - 60
                renderer.draw_rect((100, prompt_y, 200, 40), (20, 48, 74))
                renderer.draw_rect((100, prompt_y, 200, 40), HIGHLIGHT, width=1)
                renderer.draw_text(
                    "[ENTER] PURCHASE",
                    (120, prompt_y + 10), size=18, color=HIGHLIGHT,
                )

    def _render_ships_tab(self, renderer: RenderInterface, sw: int, sh: int) -> None:
        """Render the ships tab."""
        panel_y = 180
        panel_w = sw - 120
        panel_h = sh - panel_y - 100
        
        renderer.draw_rect((60, panel_y, panel_w, panel_h), PANEL)
        renderer.draw_rect((60, panel_y, panel_w, panel_h), BORDER, width=1)

        # Current ship trade-in value
        current_ship = self.game_state.player_ship
        trade_in_value = self.economy.calculate_ship_trade_in_value(current_ship)
        
        info_y = panel_y + 30
        renderer.draw_text("CURRENT SHIP TRADE-IN:", (100, info_y), size=16, color=DIM)
        renderer.draw_text(
            f"{trade_in_value} salvage",
            (350, info_y), size=18, color=GOLD,
        )

        # Render ship list
        list_y = info_y + 50
        for i, template in enumerate(self._available_ships):
            y = list_y + i * 80
            if y + 70 > panel_y + panel_h - 20:
                break
            
            is_selected = i == self._selected_index
            bg_color = (20, 48, 74, 150) if is_selected else (14, 26, 42, 100)
            
            renderer.draw_rect((80, y - 10, panel_w - 40, 70), bg_color)
            if is_selected:
                renderer.draw_rect((80, y - 10, panel_w - 40, 70), HIGHLIGHT, width=1)
            
            # Ship name and class
            renderer.draw_text(
                template["name"].upper(),
                (100, y), size=18, color=TEXT,
            )
            renderer.draw_text(
                template["faction_id"].replace('_', ' ').title(),
                (100, y + 25), size=14, color=DIM,
            )
            
            # Key stats
            stats = template["base_stats"]
            stats_text = f"SPD:{stats['speed']} ARM:{stats['armour']} FIR:{stats['firepower']} CAP:{stats['crystal_capacity']} CREW:{stats['crew_capacity']}"
            renderer.draw_text(stats_text, (400, y + 5), size=12, color=HIGHLIGHT)
            
            # Hull and cost
            hull = template["max_hull"]
            base_cost = hull * 3
            net_cost = max(0, base_cost - trade_in_value)
            
            renderer.draw_text(f"HULL: {hull}", (400, y + 25), size=12, color=TEXT)
            
            can_afford = self.game_state.salvage >= net_cost
            cost_color = GREEN if can_afford else RED
            renderer.draw_text(f"{net_cost} salvage", (600, y + 15), size=16, color=cost_color)

        # Purchase prompt
        if self._available_ships and self._selected_index < len(self._available_ships):
            selected = self._available_ships[self._selected_index]
            hull = selected["max_hull"]
            base_cost = hull * 3
            net_cost = max(0, base_cost - trade_in_value)
            
            if self.game_state.salvage >= net_cost:
                prompt_y = panel_y + panel_h - 60
                renderer.draw_rect((100, prompt_y, 200, 40), (20, 48, 74))
                renderer.draw_rect((100, prompt_y, 200, 40), HIGHLIGHT, width=1)
                renderer.draw_text(
                    "[ENTER] PURCHASE",
                    (120, prompt_y + 10), size=18, color=HIGHLIGHT,
                )

    def _handle_up(self) -> None:
        """Handle up navigation."""
        if self._tab == 0:  # Repairs
            ship = self.game_state.player_ship
            max_repair = ship.max_hull - ship.current_hull
            self._repair_amount = min(self._repair_amount + 5, max_repair)
        elif self._tab == 1:  # Upgrades
            self._selected_index = max(0, self._selected_index - 1)
        else:  # Ships
            self._selected_index = max(0, self._selected_index - 1)

    def _handle_down(self) -> None:
        """Handle down navigation."""
        if self._tab == 0:  # Repairs
            self._repair_amount = max(1, self._repair_amount - 5)
        elif self._tab == 1:  # Upgrades
            ship = self.game_state.player_ship
            available_upgrades = [u for u in self._upgrades 
                                 if not any(upg.upgrade_id == u["upgrade_id"] for upg in ship.upgrades)]
            self._selected_index = min(len(available_upgrades) - 1, self._selected_index + 1)
        else:  # Ships
            self._selected_index = min(len(self._available_ships) - 1, self._selected_index + 1)

    def _handle_confirm(self) -> None:
        """Handle confirm action."""
        if self._tab == 0:  # Repairs
            if self._repair_amount > 0:
                success = self.economy.repair_ship(self.game_state, self._repair_amount)
                if success:
                    self._flash(f"Success! Repaired {self._repair_amount} hull points.")
                    self._repair_amount = 0
                else:
                    self._flash("Repair failed — insufficient salvage.")
        elif self._tab == 1:  # Upgrades
            ship = self.game_state.player_ship
            available_upgrades = [u for u in self._upgrades 
                                 if not any(upg.upgrade_id == u["upgrade_id"] for upg in ship.upgrades)]
            
            if self._selected_index < len(available_upgrades):
                upgrade_id = available_upgrades[self._selected_index]["upgrade_id"]
                success = self.economy.purchase_upgrade(self.game_state, upgrade_id)
                if success:
                    self._flash(f"Success! Installed {available_upgrades[self._selected_index]['name']}.")
                else:
                    self._flash("Purchase failed — check requirements and resources.")
        else:  # Ships
            if self._selected_index < len(self._available_ships):
                template_id = self._available_ships[self._selected_index]["template_id"]
                success = self.economy.purchase_ship(self.game_state, template_id)
                if success:
                    self._flash(f"Success! Purchased {self._available_ships[self._selected_index]['name']}.")
                    self._load_data()  # Reload data since ship changed
                else:
                    self._flash("Purchase failed — check requirements and resources.")

    def _flash(self, message: str) -> None:
        """Show a temporary message."""
        self._message = message
        self._message_timer = 3.0
