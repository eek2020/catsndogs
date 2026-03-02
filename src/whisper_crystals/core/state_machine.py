"""Stack-based game state machine with push/pop/switch operations."""

from __future__ import annotations

from abc import ABC, abstractmethod
from enum import Enum, auto
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from whisper_crystals.core.interfaces import Action, RenderInterface


class GameStateType(Enum):
    MENU = auto()
    NAVIGATION = auto()
    COMBAT = auto()
    TRADE = auto()
    DIALOGUE = auto()
    CUTSCENE = auto()
    PAUSE = auto()
    END = auto()
    FACTION_SCREEN = auto()
    SHIP_SCREEN = auto()
    SETTINGS = auto()
    PURCHASE = auto()


class GameState(ABC):
    """Base class for all game states."""

    state_type: GameStateType

    def __init__(self, machine: GameStateMachine) -> None:
        self.machine = machine

    @abstractmethod
    def enter(self) -> None:
        """Called when this state becomes active."""

    @abstractmethod
    def exit(self) -> None:
        """Called when this state is deactivated."""

    @abstractmethod
    def handle_input(self, actions: list[Action]) -> None:
        """Process player input actions."""

    @abstractmethod
    def update(self, dt: float) -> None:
        """Update game logic for this frame."""

    @abstractmethod
    def render(self, renderer: RenderInterface) -> None:
        """Draw this state's visuals."""


class GameStateMachine:
    """Stack-based state machine supporting push, pop, and switch."""

    def __init__(self) -> None:
        self._stack: list[GameState] = []

    @property
    def current_state(self) -> GameState | None:
        return self._stack[-1] if self._stack else None

    @property
    def is_empty(self) -> bool:
        return len(self._stack) == 0

    def push(self, state: GameState) -> None:
        """Push a new state on top (e.g., pause overlay)."""
        if self._stack:
            self._stack[-1].exit()
        self._stack.append(state)
        state.enter()

    def pop(self) -> None:
        """Remove the top state and resume the one below."""
        if self._stack:
            self._stack[-1].exit()
            self._stack.pop()
        if self._stack:
            self._stack[-1].enter()

    def switch(self, state: GameState) -> None:
        """Replace the top state (e.g., menu → navigation)."""
        if self._stack:
            self._stack[-1].exit()
            self._stack.pop()
        self._stack.append(state)
        state.enter()

    def clear(self) -> None:
        """Remove all states from the stack.

        Only the top state receives an exit() call; intermediate states
        are discarded without enter/exit churn.
        """
        if self._stack:
            self._stack[-1].exit()
            self._stack.clear()
