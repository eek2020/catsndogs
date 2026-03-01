"""Entry point for Whisper Crystals: python -m whisper_crystals"""

from __future__ import annotations

import os

import pygame

from whisper_crystals.core.data_loader import DataLoader
from whisper_crystals.core.event_bus import EventBus
from whisper_crystals.core.game_state import GameStateData, create_new_game_state
from whisper_crystals.core.interfaces import Action
from whisper_crystals.core.state_machine import GameStateMachine
from whisper_crystals.engine.camera import Camera
from whisper_crystals.engine.input_handler import PygameInputHandler
from whisper_crystals.engine.renderer import PygameRenderer
from whisper_crystals.entities.encounter import Encounter
from whisper_crystals.systems.combat import CombatShip, CombatState
from whisper_crystals.systems.encounter_engine import EncounterEngine
from whisper_crystals.systems.faction_system import FactionSystem
from whisper_crystals.systems.narrative import NarrativeSystem
from whisper_crystals.ui.cutscene import CutsceneState
from whisper_crystals.ui.dialogue_ui import DialogueState
from whisper_crystals.ui.faction_screen import FactionScreenState
from whisper_crystals.ui.menu import MenuState
from whisper_crystals.ui.navigation import NavigationState
from whisper_crystals.ui.ship_screen import ShipScreenState

SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
FPS = 60
SPLASH_DURATION_SECONDS = 4.0


def _resolve_project_root() -> str:
    """Find project root from src/whisper_crystals package path."""
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(os.path.dirname(here))


def _resolve_data_root() -> str:
    """Find the data/ directory relative to the project root."""
    project_root = _resolve_project_root()
    return os.path.join(project_root, "data")


def _resolve_splash_art_path() -> str:
    """Find startup splash artwork path."""
    return os.path.join(_resolve_project_root(), "design", "artwork", "wc_splash_screen.png")


def _resolve_intro_title_art_path() -> str:
    """Find intro cutscene title artwork path."""
    return os.path.join(_resolve_project_root(), "design", "artwork", "whisper_crystals_title.png")


def _resolve_aristotle_art_path() -> str:
    """Find Aristotle portrait artwork path."""
    return os.path.join(_resolve_project_root(), "design", "charcters", "aristotle.png")


def _resolve_dave_art_path() -> str:
    """Find Dave portrait artwork path."""
    return os.path.join(_resolve_project_root(), "design", "charcters", "dave.png")


def _load_splash_art() -> pygame.Surface | None:
    """Load startup splash artwork if present."""
    path = _resolve_splash_art_path()
    if not os.path.exists(path):
        return None
    try:
        return pygame.image.load(path).convert()
    except pygame.error:
        return None


def _load_art_alpha(path: str) -> pygame.Surface | None:
    """Load an RGBA artwork surface if present."""
    if not os.path.exists(path):
        return None
    try:
        return pygame.image.load(path).convert_alpha()
    except pygame.error:
        return None


def _remove_near_white_background(
    surface: pygame.Surface,
    hard_threshold: int = 232,
    soft_threshold: int = 196,
) -> pygame.Surface:
    """Make bright neutral background pixels transparent, with soft anti-halo feathering."""
    cleaned = surface.copy().convert_alpha()
    width, height = cleaned.get_size()
    for x in range(width):
        for y in range(height):
            r, g, b, a = cleaned.get_at((x, y))
            whiteness = min(r, g, b)
            if whiteness >= hard_threshold:
                cleaned.set_at((x, y), (r, g, b, 0))
            elif whiteness >= soft_threshold:
                # Fade edge pixels to avoid a bright halo around the sprite silhouette.
                span = max(1, hard_threshold - soft_threshold)
                alpha_scale = (hard_threshold - whiteness) / span
                cleaned.set_at((x, y), (r, g, b, int(a * alpha_scale)))
            else:
                cleaned.set_at((x, y), (r, g, b, a))
    return cleaned


def _draw_startup_visual(
    screen: pygame.Surface,
    splash_art: pygame.Surface | None,
    message: str,
    progress: float | None,
    pulse: float,
    show_text: bool = True,
) -> None:
    """Draw splash art plus loading/status overlay."""
    sw, sh = screen.get_size()
    screen.fill((6, 8, 16))

    if splash_art is not None:
        iw, ih = splash_art.get_size()
        scale = min(sw / iw, sh / ih)
        scaled = pygame.transform.smoothscale(splash_art, (int(iw * scale), int(ih * scale)))
        sx = (sw - scaled.get_width()) // 2
        sy = (sh - scaled.get_height()) // 2
        screen.blit(scaled, (sx, sy))

    if not show_text:
        return

    # Overlay for readability
    panel = pygame.Surface((sw, sh), pygame.SRCALPHA)
    panel.fill((8, 10, 20, 120))
    screen.blit(panel, (0, 0))

    title_font = pygame.font.Font(None, 62)
    status_font = pygame.font.Font(None, 34)
    hint_font = pygame.font.Font(None, 26)

    title = title_font.render("WHISPER CRYSTALS", True, (230, 236, 255))
    screen.blit(title, ((sw - title.get_width()) // 2, int(sh * 0.10)))

    status_text = status_font.render(message, True, (170, 210, 255))
    status_y = int(sh * 0.78)
    screen.blit(status_text, ((sw - status_text.get_width()) // 2, status_y))

    if progress is not None:
        bar_w = int(sw * 0.5)
        bar_h = 20
        bar_x = (sw - bar_w) // 2
        bar_y = status_y + 38

        pygame.draw.rect(screen, (25, 30, 52), (bar_x, bar_y, bar_w, bar_h), border_radius=8)
        fill_w = int(bar_w * max(0.0, min(progress, 1.0)))
        if fill_w > 0:
            pygame.draw.rect(
                screen,
                (95, 185, 255),
                (bar_x, bar_y, fill_w, bar_h),
                border_radius=8,
            )
        pygame.draw.rect(screen, (140, 180, 230), (bar_x, bar_y, bar_w, bar_h), width=1, border_radius=8)

        # Animated pulse dot near the current fill amount
        dot_x = bar_x + fill_w
        dot_y = bar_y + bar_h // 2
        dot_r = 4 + int(abs(pulse) * 4)
        pygame.draw.circle(screen, (200, 240, 255), (dot_x, dot_y), dot_r)

    hint = hint_font.render("Press any key to skip splash", True, (170, 170, 190))
    screen.blit(hint, ((sw - hint.get_width()) // 2, sh - 42))


def _show_startup_splash(screen: pygame.Surface, splash_art: pygame.Surface | None) -> bool:
    """Display startup splash briefly before entering menu."""
    start_tick = pygame.time.get_ticks()
    while True:
        skip_requested = False
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False
            if event.type in (pygame.KEYDOWN, pygame.MOUSEBUTTONDOWN):
                skip_requested = True

        elapsed = (pygame.time.get_ticks() - start_tick) / 1000.0
        pulse = elapsed * 3.2
        _draw_startup_visual(
            screen,
            splash_art,
            "",
            None,
            pulse,
            show_text=False,
        )
        pygame.display.flip()

        if skip_requested or elapsed >= SPLASH_DURATION_SECONDS:
            return True

        pygame.time.delay(16)


def _show_loading_frame(
    screen: pygame.Surface,
    splash_art: pygame.Surface | None,
    message: str,
    progress: float,
) -> bool:
    """Render one loading frame; returns False if user closes window."""
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            return False

    pulse = pygame.time.get_ticks() / 170.0
    _draw_startup_visual(screen, splash_art, message, progress, pulse)
    pygame.display.flip()
    return True


def main() -> None:
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("Whisper Crystals")
    clock = pygame.time.Clock()
    splash_art = _load_splash_art()
    intro_title_art = _load_art_alpha(_resolve_intro_title_art_path())
    if intro_title_art is not None:
        intro_title_art = _remove_near_white_background(intro_title_art)
    aristotle_art = _load_art_alpha(_resolve_aristotle_art_path())
    if aristotle_art is not None:
        aristotle_art = _remove_near_white_background(aristotle_art)
    dave_art = _load_art_alpha(_resolve_dave_art_path())
    if dave_art is not None:
        dave_art = _remove_near_white_background(dave_art)

    if not _show_startup_splash(screen, splash_art):
        pygame.quit()
        return

    camera = Camera(SCREEN_WIDTH, SCREEN_HEIGHT)
    renderer = PygameRenderer(screen, camera)
    input_handler = PygameInputHandler()
    state_machine = GameStateMachine()
    event_bus = EventBus()

    # Data & systems (initialised on New Game)
    data_loader = DataLoader(data_root=_resolve_data_root())
    encounter_engine = EncounterEngine(data_loader, event_bus)
    narrative = NarrativeSystem(data_loader, event_bus)
    faction_system = FactionSystem(event_bus)

    game_state: GameStateData | None = None
    nav_state: NavigationState | None = None
    running = True

    # ------------------------------------------------------------------
    # Callbacks
    # ------------------------------------------------------------------

    def on_encounter(encounter: Encounter) -> None:
        """Push a dialogue state when an encounter fires."""
        nonlocal nav_state
        dialogue = DialogueState(
            machine=state_machine,
            encounter=encounter,
            encounter_engine=encounter_engine,
            game_state=game_state,
            on_complete=on_dialogue_complete,
            on_combat=on_combat_from_encounter,
        )
        state_machine.push(dialogue)

    def on_dialogue_complete() -> None:
        """Pop dialogue and return to navigation."""
        state_machine.pop()
        if nav_state:
            nav_state.on_return_from_encounter()

    def on_combat_from_encounter(encounter: Encounter, choice_index: int) -> None:
        """Launch combat when player picks a fight option in a combat encounter."""
        if game_state is None:
            return
        # Apply the dialogue choice outcome first (faction changes etc.)
        encounter_engine.apply_choice_outcome(game_state, encounter, choice_index)

        # Build enemy ship from encounter faction
        enemy_faction = ""
        for fid, delta in encounter.choices[choice_index].outcome.faction_changes.items():
            enemy_faction = fid
            break
        enemy_faction = enemy_faction or "canis_league"
        templates = data_loader.load_ship_templates()
        faction_data = game_state.faction_registry.get(enemy_faction)
        tmpl_id = faction_data.ship_template_id if faction_data else "league_cruiser"
        tmpl = templates.get(tmpl_id, templates.get("league_cruiser", {}))
        enemy_name = f"{game_state.faction_registry[enemy_faction].name} Ship" if enemy_faction in game_state.faction_registry else "Enemy Ship"
        enemy_ship = CombatShip.from_template(tmpl, enemy_name, enemy_faction)
        player_ship = CombatShip.from_game_ship(game_state.player_ship, is_player=True)

        def on_victory():
            state_machine.pop()  # pop combat
            state_machine.pop()  # pop dialogue
            if nav_state:
                nav_state.hud.flash("Victory! Loot collected.", 3.0)
                nav_state.on_return_from_encounter()

        def on_defeat():
            # Restore hull to 25% on defeat (PoC mercy)
            if game_state:
                game_state.player_ship.current_hull = max(25, game_state.player_ship.max_hull // 4)
            state_machine.pop()  # pop combat
            state_machine.pop()  # pop dialogue
            if nav_state:
                nav_state.hud.flash("Defeated... barely survived.", 3.0)
                nav_state.on_return_from_encounter()

        def on_flee():
            state_machine.pop()  # pop combat
            state_machine.pop()  # pop dialogue
            if nav_state:
                nav_state.hud.flash("Escaped!", 2.0)
                nav_state.on_return_from_encounter()

        combat = CombatState(
            machine=state_machine,
            player_ship=player_ship,
            enemy_ship=enemy_ship,
            game_state=game_state,
            event_bus=event_bus,
            on_victory=on_victory,
            on_defeat=on_defeat,
            on_flee=on_flee,
        )
        state_machine.push(combat)

    def open_faction_screen() -> None:
        """Push faction status screen overlay."""
        if game_state:
            screen_state = FactionScreenState(state_machine, game_state, faction_system)
            state_machine.push(screen_state)

    def open_ship_screen() -> None:
        """Push ship management screen overlay."""
        if game_state:
            screen_state = ShipScreenState(state_machine, game_state)
            state_machine.push(screen_state)

    def on_arc_complete() -> None:
        """Handle arc transition with cutscene."""
        nonlocal game_state
        if game_state and narrative:
            old_arc = game_state.current_arc
            old_title = narrative.get_arc_title(old_arc)
            new_arc = narrative.advance_arc(game_state)
            if new_arc:
                new_title = narrative.get_arc_title(new_arc)
                encounter_engine.load_encounters(new_arc)

                def on_cutscene_done():
                    state_machine.pop()  # pop cutscene
                    if nav_state:
                        nav_state.hud.flash(f"Now entering: {new_title}", 4.0)

                cutscene = CutsceneState(
                    machine=state_machine,
                    title=f"Arc Complete: {old_title}",
                    subtitle="The story continues...",
                    lines=[
                        f"Aristotle's journey through '{old_title}' has come to a close.",
                        "The decisions made here will echo through the multiverse.",
                        f"Ahead lies '{new_title}' — and new challenges await.",
                    ],
                    on_complete=on_cutscene_done,
                )
                state_machine.push(cutscene)

    def _launch_navigation() -> None:
        """Create navigation state and switch to it."""
        nonlocal nav_state
        nav_state = NavigationState(
            machine=state_machine,
            camera=camera,
            input_handler=input_handler,
            game_state=game_state,
            encounter_engine=encounter_engine,
            narrative=narrative,
            on_encounter=on_encounter,
            on_arc_complete=on_arc_complete,
        )
        state_machine.switch(nav_state)

    def start_new_game() -> None:
        nonlocal game_state, nav_state, running

        if not _show_loading_frame(screen, splash_art, "Preparing game state...", 0.15):
            running = False
            return
        game_state = create_new_game_state(data_loader)

        if not _show_loading_frame(screen, splash_art, "Loading narrative data...", 0.50):
            running = False
            return
        narrative.load()

        if not _show_loading_frame(screen, splash_art, "Syncing encounters...", 0.85):
            running = False
            return
        encounter_engine.load_encounters("arc1")

        if not _show_loading_frame(screen, splash_art, "Ready for launch", 1.0):
            running = False
            return
        pygame.time.delay(140)

        # Show intro cutscene, then launch navigation
        intro = CutsceneState(
            machine=state_machine,
            title="WHISPER CRYSTALS",
            subtitle="",
            lines=[
                "In a multiverse where cats, dogs, fairies, and goblins sail between realms...",
                "Captain Aristotle — a street cat turned Corsair — discovers a crystal that hums with unearthly power.",
                "Whisper Crystals. Fuel for ships, currency for empires, and now... his burden.",
                "The Canis League wants them. The Lions demand tribute. Something ancient watches from the shadows.",
                "And so the journey begins.",
            ],
            on_complete=lambda: (state_machine.pop(), _launch_navigation()),
            title_image=intro_title_art,
            character_image=aristotle_art,
            character_image_left=dave_art,
        )
        state_machine.switch(intro)

    def quit_game() -> None:
        nonlocal running
        running = False

    # Start at menu
    menu = MenuState(
        state_machine,
        on_new_game=start_new_game,
        on_quit=quit_game,
        splash_art=splash_art,
    )
    state_machine.push(menu)

    # ------------------------------------------------------------------
    # Main loop
    # ------------------------------------------------------------------
    while running:
        dt = clock.tick(FPS) / 1000.0
        events = pygame.event.get()
        input_handler.process_events(events)

        if input_handler.should_quit():
            break

        state = state_machine.current_state
        if state is None:
            break

        actions = input_handler.poll_actions()

        # Global hotkeys from navigation state
        if state is nav_state:
            if Action.INTERACT in actions:
                open_faction_screen()
                continue
            if Action.FIRE in actions:
                open_ship_screen()
                continue

        state.handle_input(actions)
        state.update(dt)

        renderer.clear()
        state.render(renderer)
        renderer.present()

    pygame.quit()


if __name__ == "__main__":
    main()
