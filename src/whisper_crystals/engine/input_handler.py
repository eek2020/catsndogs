"""Pygame input handler — implements InputInterface."""

import pygame

from whisper_crystals.core.interfaces import Action, InputInterface

# Default key mapping (configurable)
DEFAULT_KEY_MAP: dict[int, Action] = {
    pygame.K_w: Action.MOVE_UP,
    pygame.K_s: Action.MOVE_DOWN,
    pygame.K_a: Action.MOVE_LEFT,
    pygame.K_d: Action.MOVE_RIGHT,
    pygame.K_UP: Action.MOVE_UP,
    pygame.K_DOWN: Action.MOVE_DOWN,
    pygame.K_LEFT: Action.MOVE_LEFT,
    pygame.K_RIGHT: Action.MOVE_RIGHT,
    pygame.K_SPACE: Action.FIRE,
    pygame.K_e: Action.INTERACT,
    pygame.K_ESCAPE: Action.PAUSE,
    pygame.K_RETURN: Action.CONFIRM,
    pygame.K_BACKSPACE: Action.CANCEL,
    pygame.K_r: Action.MENU_SELECT,
    pygame.K_m: Action.MISSION_LOG,
    pygame.K_TAB: Action.SKIP,
}


class PygameInputHandler(InputInterface):
    """Translates Pygame key events into engine-agnostic Actions."""

    def __init__(self, key_map: dict[int, Action] | None = None) -> None:
        self.key_map = key_map or DEFAULT_KEY_MAP
        self._held: set[Action] = set()
        self._quit_requested = False
        self._triggered: list[Action] = []

    def process_events(self, events: list[pygame.event.Event]) -> None:
        """Call once per frame with the raw Pygame event list."""
        self._triggered.clear()
        self._quit_requested = False
        for event in events:
            if event.type == pygame.QUIT:
                self._quit_requested = True
            elif event.type == pygame.KEYDOWN:
                action = self.key_map.get(event.key)
                if action:
                    self._triggered.append(action)
                    self._held.add(action)
            elif event.type == pygame.KEYUP:
                action = self.key_map.get(event.key)
                if action:
                    self._held.discard(action)

    # -- InputInterface implementation --

    def poll_actions(self) -> list[Action]:
        return list(self._triggered)

    def is_action_held(self, action: Action) -> bool:
        return action in self._held

    def should_quit(self) -> bool:
        return self._quit_requested
