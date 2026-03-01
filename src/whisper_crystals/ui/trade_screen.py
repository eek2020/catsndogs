"""Trade screen — buy and sell crystals with factions."""

from __future__ import annotations

import math

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


class TradeScreenState(GameState):
    """Overlay screen for buying/selling crystals with a faction."""

    state_type = GameStateType.TRADE

    def __init__(
        self,
        machine: GameStateMachine,
        game_state: GameStateData,
        economy: EconomySystem,
        faction_id: str,
        on_close: callable | None = None,
    ) -> None:
        super().__init__(machine)
        self.game_state = game_state
        self.economy = economy
        self.faction_id = faction_id
        self.on_close = on_close

        # UI state
        self._mode = 0  # 0=buy, 1=sell
        self._quantity = 1
        self._message = ""
        self._message_timer = 0.0

    def enter(self) -> None:
        self._mode = 0
        self._quantity = 1
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
                self._mode = 0  # buy
                self._quantity = 1
            elif action == Action.MOVE_RIGHT:
                self._mode = 1  # sell
                self._quantity = 1
            elif action in (Action.MOVE_UP, Action.MENU_UP):
                self._quantity = min(self._quantity + 1, self._max_quantity())
            elif action in (Action.MOVE_DOWN, Action.MENU_DOWN):
                self._quantity = max(1, self._quantity - 1)
            elif action == Action.CONFIRM:
                self._execute_trade()

    def update(self, dt: float) -> None:
        if self._message_timer > 0:
            self._message_timer -= dt
            if self._message_timer <= 0:
                self._message = ""

    def render(self, renderer: RenderInterface) -> None:
        sw, sh = renderer.get_screen_size()

        # Dark overlay
        renderer.draw_rect((0, 0, sw, sh), (8, 12, 24, 230))
        renderer.draw_glow((sw // 2, sh // 2), 350, (18, 54, 86))

        # Title
        faction = self.game_state.faction_registry.get(self.faction_id)
        faction_name = faction.name if faction else self.faction_id
        title_y = 30
        renderer.draw_glow((sw // 2, title_y + 15), 100, (26, 84, 124))
        renderer.draw_text(
            f"CRYSTAL TRADE — {faction_name.upper()}",
            (sw // 2 - 200, title_y), size=28, color=HIGHLIGHT,
        )
        renderer.draw_line(
            (sw // 2 - 250, title_y + 40),
            (sw // 2 + 250, title_y + 40),
            BORDER, 2,
        )

        # Player resources bar
        res_y = 90
        current, capacity = self.economy.get_cargo_capacity(self.game_state)
        renderer.draw_text(
            f"Crystals: {current}/{capacity}",
            (60, res_y), size=18, color=TEXT,
        )
        renderer.draw_text(
            f"Salvage: {self.game_state.salvage}",
            (300, res_y), size=18, color=GOLD,
        )
        if faction:
            renderer.draw_text(
                f"Faction Reserves: {faction.crystal_reserves}",
                (500, res_y), size=18, color=DIM,
            )

        # Mode tabs
        tab_y = 130
        tab_w = 200
        for i, label in enumerate(["BUY CRYSTALS", "SELL CRYSTALS"]):
            tx = sw // 2 - tab_w - 10 + i * (tab_w + 20)
            is_active = i == self._mode
            bg_color = (20, 48, 74, 200) if is_active else PANEL
            text_color = HIGHLIGHT if is_active else DIM
            renderer.draw_rect((tx, tab_y, tab_w, 40), bg_color)
            renderer.draw_rect((tx, tab_y, tab_w, 40), BORDER if is_active else PANEL, width=1)
            if is_active:
                renderer.draw_rect((tx, tab_y + 36, tab_w, 4), HIGHLIGHT)
            renderer.draw_text(label, (tx + 30, tab_y + 10), size=18, color=text_color)

        # Trade panel
        panel_y = 190
        panel_w = sw - 120
        panel_h = sh - panel_y - 80
        renderer.draw_rect((60, panel_y, panel_w, panel_h), PANEL)
        renderer.draw_rect((60, panel_y, panel_w, panel_h), BORDER, width=1)

        # Quantity selector
        qty_y = panel_y + 40
        renderer.draw_text("Quantity:", (100, qty_y), size=20, color=TEXT)

        # Quantity display with arrows
        qty_x = 260
        renderer.draw_text(
            "↑", (qty_x + 20, qty_y - 20), size=16, color=HIGHLIGHT,
        )
        renderer.draw_rect((qty_x, qty_y, 80, 30), (20, 48, 74))
        renderer.draw_rect((qty_x, qty_y, 80, 30), HIGHLIGHT, width=1)
        renderer.draw_text(
            str(self._quantity),
            (qty_x + 30, qty_y + 5), size=20, color=TEXT,
        )
        renderer.draw_text(
            "↓", (qty_x + 20, qty_y + 35), size=16, color=HIGHLIGHT,
        )

        max_q = self._max_quantity()
        renderer.draw_text(
            f"(max: {max_q})", (qty_x + 100, qty_y + 5), size=16, color=DIM,
        )

        # Price display
        price_y = qty_y + 70
        if self._mode == 0:
            total = self.economy.get_buy_price(
                self.game_state, self.faction_id, self._quantity,
            )
            unit = total // self._quantity if self._quantity > 0 else 0
            renderer.draw_text("Unit Price:", (100, price_y), size=18, color=DIM)
            renderer.draw_text(
                f"{unit} salvage", (260, price_y), size=18, color=TEXT,
            )
            renderer.draw_text("Total Cost:", (100, price_y + 30), size=18, color=DIM)
            renderer.draw_text(
                f"{total} salvage", (260, price_y + 30), size=20, color=RED,
            )
        else:
            total = self.economy.get_sell_price(
                self.game_state, self.faction_id, self._quantity,
            )
            unit = total // self._quantity if self._quantity > 0 else 0
            renderer.draw_text("Unit Value:", (100, price_y), size=18, color=DIM)
            renderer.draw_text(
                f"{unit} salvage", (260, price_y), size=18, color=TEXT,
            )
            renderer.draw_text("Total Revenue:", (100, price_y + 30), size=18, color=DIM)
            renderer.draw_text(
                f"{total} salvage", (260, price_y + 30), size=20, color=GREEN,
            )

        # Confirm prompt
        action_y = price_y + 80
        action_label = "BUY" if self._mode == 0 else "SELL"
        renderer.draw_rect((100, action_y, 180, 40), (20, 48, 74))
        renderer.draw_rect((100, action_y, 180, 40), HIGHLIGHT, width=1)
        renderer.draw_text(
            f"[ENTER] {action_label}",
            (120, action_y + 10), size=18, color=HIGHLIGHT,
        )

        # Flash message
        if self._message:
            msg_color = GREEN if "Success" in self._message else RED
            renderer.draw_glow((sw // 2, action_y + 60), 80, (18, 54, 86))
            renderer.draw_text(
                self._message,
                (100, action_y + 50), size=18, color=msg_color,
            )

        # Trade summary
        summary = self.economy.get_trade_summary(self.game_state)
        sum_y = sh - 110
        renderer.draw_line((80, sum_y - 10), (sw - 80, sum_y - 10), BORDER, 1)
        renderer.draw_text("TRADE LOG:", (100, sum_y), size=16, color=HIGHLIGHT)
        renderer.draw_text(
            f"Bought: {summary['total_bought']}  "
            f"Sold: {summary['total_sold']}  "
            f"Net: {summary['net_profit']:+d} salvage",
            (100, sum_y + 25), size=14, color=DIM,
        )

        # Footer
        renderer.draw_text(
            "←/→ MODE   ↑/↓ QTY   ENTER CONFIRM   ESC CLOSE",
            (sw // 2 - 210, sh - 30), size=14, color=DIM,
        )

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _max_quantity(self) -> int:
        """Calculate maximum trade quantity based on mode."""
        if self._mode == 0:  # buy
            faction = self.game_state.faction_registry.get(self.faction_id)
            if not faction:
                return 0
            # Limited by faction reserves, cargo capacity, and salvage
            _, capacity = self.economy.get_cargo_capacity(self.game_state)
            cargo_room = capacity - self.game_state.crystal_inventory
            unit_price = self.economy.get_buy_price(self.game_state, self.faction_id, 1)
            affordable = self.game_state.salvage // max(1, unit_price)
            return max(0, min(faction.crystal_reserves, cargo_room, affordable))
        else:  # sell
            return max(0, self.game_state.crystal_inventory)

    def _execute_trade(self) -> None:
        """Execute the current buy/sell operation."""
        if self._quantity <= 0:
            self._flash("Nothing to trade.")
            return

        if self._mode == 0:
            ok = self.economy.buy_crystals(
                self.game_state, self.faction_id, self._quantity,
            )
            if ok:
                self._flash(f"Success! Bought {self._quantity} crystals.")
            else:
                self._flash("Trade failed — check resources.")
        else:
            ok = self.economy.sell_crystals(
                self.game_state, self.faction_id, self._quantity,
            )
            if ok:
                self._flash(f"Success! Sold {self._quantity} crystals.")
            else:
                self._flash("Trade failed — not enough crystals.")

        self._quantity = min(self._quantity, max(1, self._max_quantity()))

    def _flash(self, message: str) -> None:
        """Show a temporary message."""
        self._message = message
        self._message_timer = 3.0
