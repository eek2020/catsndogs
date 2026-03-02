"""GameSession — orchestrates game systems, state transitions, and callbacks.

This module is engine-agnostic: ZERO pygame imports.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

from whisper_crystals.core.data_loader import DataLoader
from whisper_crystals.core.event_bus import EventBus
from whisper_crystals.core.game_state import GameStateData, create_new_game_state
from whisper_crystals.core.interfaces import Action
from whisper_crystals.core.save_manager import SaveManager
from whisper_crystals.core.state_machine import GameStateMachine

logger = logging.getLogger(__name__)

# We import AudioInterface to keep core engine agnostic, but we inject PygameAudio in __main__
from whisper_crystals.core.interfaces import AudioInterface
from whisper_crystals.entities.encounter import Encounter
from whisper_crystals.systems.combat import CombatShip
from whisper_crystals.systems.encounter_engine import EncounterEngine
from whisper_crystals.systems.crew_morale import CrewMoraleSystem
from whisper_crystals.systems.economy import EconomySystem
from whisper_crystals.systems.exploration import ExplorationSystem
from whisper_crystals.systems.faction_conquest import FactionConquestAI
from whisper_crystals.systems.faction_system import FactionSystem
from whisper_crystals.systems.narrative import NarrativeSystem
from whisper_crystals.systems.realm_control import RealmControlSystem
from whisper_crystals.ui.combat_ui import CombatState
from whisper_crystals.ui.cutscene import CutsceneState
from whisper_crystals.ui.dialogue_ui import DialogueState
from whisper_crystals.ui.ending_screen import EndingState
from whisper_crystals.ui.faction_screen import FactionScreenState
from whisper_crystals.ui.menu import MenuState
from whisper_crystals.ui.navigation import NavigationState
from whisper_crystals.ui.pause_menu import PauseMenuState
from whisper_crystals.ui.purchase_screen import PurchaseScreenState
from whisper_crystals.ui.settings_screen import SettingsScreenState, load_settings
from whisper_crystals.ui.ship_screen import ShipScreenState
from whisper_crystals.ui.trade_screen import TradeScreenState

if TYPE_CHECKING:
    from whisper_crystals.core.interfaces import InputInterface, RenderInterface
    from whisper_crystals.engine.camera import Camera


class GameSession:
    """Manages all game systems, state machine, and inter-state callbacks.

    Constructed with engine-provided dependencies (camera, input_handler, renderer).
    All pygame interaction stays in __main__.py; this class is fully portable.
    """

    def __init__(
        self,
        data_root: str,
        camera: Camera,
        input_handler: InputInterface,
        state_machine: GameStateMachine,
        audio_subsystem: AudioInterface | None = None,
    ) -> None:
        self.camera = camera
        self.input_handler = input_handler
        self.state_machine = state_machine
        self.audio = audio_subsystem
        self.event_bus = EventBus()

        # Data & systems
        self.data_loader = DataLoader(data_root=data_root)
        self.encounter_engine = EncounterEngine(self.data_loader, self.event_bus)
        self.narrative = NarrativeSystem(self.data_loader, self.event_bus)
        self.faction_system = FactionSystem(self.event_bus)
        self.economy_system = EconomySystem(self.event_bus, data_loader=self.data_loader)
        self.crew_morale = CrewMoraleSystem(self.event_bus)
        self.exploration = ExplorationSystem(self.event_bus)
        self.faction_conquest = FactionConquestAI(self.event_bus)
        self.realm_control = RealmControlSystem(self.event_bus)
        self.save_manager = SaveManager()
        self.settings = load_settings()
        
        # Apply initial settings to audio
        if self.audio:
            # Assuming settings dict has 'audio_volume' or similar
            vol = self.settings.get('volume', 1.0) if hasattr(self.settings, 'get') else 1.0
            self.audio.set_volume(vol)
            
            # Setup basic audio events
            self.event_bus.subscribe("play_sfx", lambda sfx_id, **kw: self.audio.play_sfx(sfx_id))
            self.event_bus.subscribe("play_music", lambda music_id, **kw: self.audio.play_music(music_id))
            self.event_bus.subscribe("stop_music", lambda *args, **kw: self.audio.stop_music())
            self.event_bus.subscribe("arc_advanced", lambda old_arc, new_arc, **kw: self.audio.play_music(new_arc))
            self.event_bus.subscribe("volume_changed", lambda vol, **kw: self.audio.set_volume(vol))

        self.event_bus.subscribe("game_ending_reached", lambda *args, **kw: self._on_game_ending_reached())

        # Runtime state
        self.game_state: GameStateData | None = None
        self.nav_state: NavigationState | None = None
        self.running = True

    # ------------------------------------------------------------------
    # Public: called by the engine main loop
    # ------------------------------------------------------------------

    def push_menu(
        self,
        splash_art: object | None = None,
    ) -> None:
        """Push the initial menu state onto the state machine."""
        menu = MenuState(
            self.state_machine,
            on_new_game=lambda: self.start_new_game(),
            on_load_game=self._open_load_from_menu,
            on_quit=self._quit,
            event_bus=self.event_bus,
            splash_art=splash_art,
            save_manager=self.save_manager,
        )
        self.state_machine.push(menu)

    def tick(self, dt: float) -> bool:
        """Run one frame of game logic. Returns False when the game should exit."""
        if not self.running:
            return False

        state = self.state_machine.current_state
        if state is None:
            return False

        actions = self.input_handler.poll_actions()

        # Global hotkeys from navigation state
        if state is self.nav_state:
            if Action.PAUSE in actions:
                self._open_pause_menu()
                return True
            if Action.INTERACT in actions:
                self._open_faction_screen()
                return True
            if Action.FIRE in actions:
                self._open_ship_screen()
                return True
            if Action.MENU_SELECT in actions:
                self.nav_state._open_purchase_screen()
                return True

        state.handle_input(actions)
        state.update(dt)
        return True

    def render(self, renderer: RenderInterface) -> None:
        """Render the current state."""
        state = self.state_machine.current_state
        if state:
            renderer.clear()
            state.render(renderer)
            renderer.present()

    # ------------------------------------------------------------------
    # New game flow
    # ------------------------------------------------------------------

    def start_new_game(
        self,
        on_loading_frame: callable | None = None,
        intro_title_art: object | None = None,
        aristotle_art: object | None = None,
        dave_art: object | None = None,
    ) -> None:
        """Initialise game state, load data, and transition to intro cutscene.

        on_loading_frame: optional callback(message, progress) -> bool for
            showing loading progress. Returns False if user closed window.
        """
        if on_loading_frame:
            if not on_loading_frame("Preparing game state...", 0.15):
                self.running = False
                return

        self.game_state = create_new_game_state(self.data_loader)
        logger.info("Starting new game state: %s", self.game_state)

        if on_loading_frame:
            if not on_loading_frame("Loading narrative data...", 0.50):
                self.running = False
                return

        self.narrative.load()

        if on_loading_frame:
            if not on_loading_frame("Syncing encounters...", 0.85):
                self.running = False
                return

        self.encounter_engine.load_encounters("arc1")

        if on_loading_frame:
            if not on_loading_frame("Ready for launch", 1.0):
                self.running = False
                return

        # Show intro cutscene, then launch navigation
        intro = CutsceneState(
            machine=self.state_machine,
            title="WHISPER CRYSTALS",
            subtitle="",
            lines=[
                "In a multiverse where cats, dogs, fairies, and goblins sail between realms...",
                "Captain Aristotle — a street cat turned Corsair — discovers a crystal "
                "that hums with unearthly power.",
                "Whisper Crystals. Fuel for ships, currency for empires, and now... his burden.",
                "The Canis League wants them. The Lions demand tribute. "
                "Something ancient watches from the shadows.",
                "And so the journey begins.",
            ],
            on_complete=lambda: (self.state_machine.pop(), self._launch_navigation()),
            title_image=intro_title_art,
            character_image=aristotle_art,
            character_image_left=dave_art,
        )
        self.state_machine.switch(intro)

    # ------------------------------------------------------------------
    # Callbacks (encounter, dialogue, combat, arc transitions)
    # ------------------------------------------------------------------

    def _on_encounter(self, encounter: Encounter) -> None:
        """Push a dialogue state when an encounter fires."""
        logger.info("Triggered encounter: %s", encounter.encounter_id)
        dialogue = DialogueState(
            machine=self.state_machine,
            encounter=encounter,
            encounter_engine=self.encounter_engine,
            game_state=self.game_state,
            event_bus=self.event_bus,
            on_complete=self._on_dialogue_complete,
            on_combat=self._on_combat_from_encounter,
        )
        self.state_machine.push(dialogue)

    def _on_dialogue_complete(self) -> None:
        """Pop dialogue and return to navigation."""
        self.state_machine.pop()
        if self.nav_state:
            self.nav_state.on_return_from_encounter()

    def _on_combat_from_encounter(self, encounter: Encounter, choice_index: int) -> None:
        """Launch combat when the player picks a fight option."""
        if self.game_state is None:
            return

        self.encounter_engine.apply_choice_outcome(self.game_state, encounter, choice_index)

        # Build enemy ship from encounter faction
        enemy_faction = ""
        for fid in encounter.choices[choice_index].outcome.faction_changes:
            enemy_faction = fid
            break
        enemy_faction = enemy_faction or "canis_league"

        templates = self.data_loader.load_ship_templates()
        faction_data = self.game_state.faction_registry.get(enemy_faction)
        tmpl_id = faction_data.ship_template_id if faction_data else "league_cruiser"
        tmpl = templates.get(tmpl_id, templates.get("league_cruiser", {}))
        enemy_name = (
            f"{self.game_state.faction_registry[enemy_faction].name} Ship"
            if enemy_faction in self.game_state.faction_registry
            else "Enemy Ship"
        )
        enemy_ship = CombatShip.from_template(tmpl, enemy_name, enemy_faction)
        player_ship = CombatShip.from_game_ship(self.game_state.player_ship, is_player=True)

        def on_victory() -> None:
            self.state_machine.pop()  # pop combat
            self.state_machine.pop()  # pop dialogue
            if self.nav_state:
                self.nav_state.hud.flash("Victory! Loot collected.", 3.0)
                self.nav_state.on_return_from_encounter()

        def on_defeat() -> None:
            if self.game_state:
                self.game_state.player_ship.current_hull = max(
                    25, self.game_state.player_ship.max_hull // 4
                )
            self.state_machine.pop()
            self.state_machine.pop()
            if self.nav_state:
                self.nav_state.hud.flash("Defeated... barely survived.", 3.0)
                self.nav_state.on_return_from_encounter()

        def on_flee() -> None:
            self.state_machine.pop()
            self.state_machine.pop()
            if self.nav_state:
                self.nav_state.hud.flash("Escaped!", 2.0)
                self.nav_state.on_return_from_encounter()

        combat = CombatState(
            machine=self.state_machine,
            player_ship=player_ship,
            enemy_ship=enemy_ship,
            game_state=self.game_state,
            event_bus=self.event_bus,
            on_victory=on_victory,
            on_defeat=on_defeat,
            on_flee=on_flee,
        )
        self.state_machine.push(combat)

    def _on_arc_complete(self) -> None:
        """Handle arc transition with cutscene."""
        if not self.game_state or not self.narrative:
            return

        old_arc = self.game_state.current_arc
        old_title = self.narrative.get_arc_title(old_arc)
        new_arc = self.narrative.advance_arc(self.game_state)
        logger.info("Arc completed: %s. Advanced to new arc: %s", old_arc, new_arc)

        if new_arc:
            new_title = self.narrative.get_arc_title(new_arc)
            self.encounter_engine.load_encounters(new_arc)

            def on_cutscene_done() -> None:
                self.state_machine.pop()
                if self.nav_state:
                    self.nav_state.hud.flash(f"Now entering: {new_title}", 4.0)

            cutscene = CutsceneState(
                machine=self.state_machine,
                title=f"Arc Complete: {old_title}",
                subtitle="The story continues...",
                lines=[
                    f"Aristotle's journey through '{old_title}' has come to a close.",
                    "The decisions made here will echo through the multiverse.",
                    f"Ahead lies '{new_title}' — and new challenges await.",
                ],
                on_complete=on_cutscene_done,
            )
            self.state_machine.push(cutscene)

    def _on_game_ending_reached(self) -> None:
        """Push ending screen when the narrative concludes."""
        if not self.game_state:
            return
            
        ending = EndingState(
            machine=self.state_machine,
            game_state=self.game_state,
            on_return_to_menu=self._quit_to_menu,
        )
        self.state_machine.switch(ending)

    # ------------------------------------------------------------------
    # Screen overlays
    # ------------------------------------------------------------------

    def _open_faction_screen(self) -> None:
        """Push faction status screen overlay."""
        if self.game_state:
            screen_state = FactionScreenState(
                self.state_machine, self.game_state, self.faction_system
            )
            self.state_machine.push(screen_state)

    def _open_ship_screen(self) -> None:
        """Push ship management screen overlay."""
        if self.game_state:
            screen_state = ShipScreenState(self.state_machine, self.game_state)
            self.state_machine.push(screen_state)

    def open_trade_screen(self, faction_id: str) -> None:
        """Push trade screen overlay for a specific faction."""
        if self.game_state:
            trade = TradeScreenState(
                machine=self.state_machine,
                game_state=self.game_state,
                economy=self.economy_system,
                faction_id=faction_id,
                on_close=lambda: self.state_machine.pop(),
            )
            self.state_machine.push(trade)

    def open_purchase_screen(self, location: str) -> None:
        """Push purchase screen overlay for ship repairs, upgrades, and new ships."""
        if self.game_state:
            purchase = PurchaseScreenState(
                machine=self.state_machine,
                game_state=self.game_state,
                economy=self.economy_system,
                location=location,
                on_close=lambda: self.state_machine.pop(),
            )
            self.state_machine.push(purchase)

    # ------------------------------------------------------------------
    # Navigation
    # ------------------------------------------------------------------

    def _launch_navigation(self) -> None:
        """Create navigation state and switch to it."""
        self.nav_state = NavigationState(
            machine=self.state_machine,
            camera=self.camera,
            input_handler=self.input_handler,
            game_state=self.game_state,
            encounter_engine=self.encounter_engine,
            narrative=self.narrative,
            on_encounter=self._on_encounter,
            on_arc_complete=self._on_arc_complete,
            session=self,
        )
        self.state_machine.switch(self.nav_state)

    # ------------------------------------------------------------------
    # Pause menu and settings
    # ------------------------------------------------------------------

    def _open_pause_menu(self) -> None:
        """Push pause menu overlay on top of navigation."""
        if not self.game_state:
            return
        pause = PauseMenuState(
            machine=self.state_machine,
            game_state=self.game_state,
            save_manager=self.save_manager,
            on_resume=lambda: self.state_machine.pop(),
            on_load_game=self._open_load_from_pause,
            on_settings=self._open_settings,
            on_quit=self._quit_to_menu,
        )
        self.state_machine.push(pause)

    def _open_settings(self) -> None:
        """Push settings screen overlay."""
        settings_state = SettingsScreenState(
            machine=self.state_machine,
            settings=self.settings,
            event_bus=self.event_bus,
        )
        self.state_machine.push(settings_state)

    def _open_load_from_menu(self, slot: int) -> None:
        """Load a saved game from the main menu."""
        loaded = self.save_manager.load_game(slot)
        if loaded:
            self.game_state = loaded
            self.narrative.load()
            self.encounter_engine.load_encounters(loaded.current_arc)
            self._launch_navigation()

    def _open_load_from_pause(self) -> None:
        """Pop pause, then show load slots on menu.

        For now, quick-load from slot 0.
        """
        loaded = self.save_manager.load_game(0)
        if loaded:
            self.game_state = loaded
            self.narrative.load()
            self.encounter_engine.load_encounters(loaded.current_arc)
            # Pop pause menu, then switch to new navigation
            self.state_machine.pop()
            self._launch_navigation()

    def _quit_to_menu(self) -> None:
        """Pop back to main menu from pause."""
        self.state_machine.clear()
        self.game_state = None
        self.nav_state = None
        self.push_menu()

    def _quit(self) -> None:
        self.running = False
