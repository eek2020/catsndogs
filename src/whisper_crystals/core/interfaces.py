"""Engine Abstraction Layer (EAL) — abstract interfaces for Render, Input, Audio.

Core game logic references only these ABCs. Pygame implements them in Phase 1;
Godot/Unity implements them in Phase 2.
"""

from abc import ABC, abstractmethod
from enum import Enum, auto


# ---------------------------------------------------------------------------
# Input action enum — engine-agnostic
# ---------------------------------------------------------------------------

class Action(Enum):
    MOVE_UP = auto()
    MOVE_DOWN = auto()
    MOVE_LEFT = auto()
    MOVE_RIGHT = auto()
    FIRE = auto()
    INTERACT = auto()
    PAUSE = auto()
    CONFIRM = auto()
    CANCEL = auto()
    MENU_UP = auto()
    MENU_DOWN = auto()


# ---------------------------------------------------------------------------
# Render interface
# ---------------------------------------------------------------------------

class RenderInterface(ABC):
    """Abstract rendering interface."""

    @abstractmethod
    def clear(self) -> None:
        pass

    @abstractmethod
    def draw_sprite(self, sprite_id: str, world_pos: tuple[float, float]) -> None:
        pass

    @abstractmethod
    def draw_text(
        self,
        text: str,
        pos: tuple[int, int],
        font_id: str | None = None,
        color: tuple[int, int, int] = (255, 255, 255),
        size: int = 24,
    ) -> None:
        pass

    @abstractmethod
    def draw_rect(
        self,
        rect: tuple[int, int, int, int],
        color: tuple[int, int, int],
        width: int = 0,
    ) -> None:
        pass

    @abstractmethod
    def draw_polygon(
        self,
        points: list[tuple[float, float]],
        color: tuple[int, int, int],
        width: int = 0,
    ) -> None:
        pass

    @abstractmethod
    def draw_circle(
        self,
        center: tuple[int, int],
        radius: int,
        color: tuple[int, int, int] | tuple[int, int, int, int],
        width: int = 0,
    ) -> None:
        pass

    @abstractmethod
    def draw_glow(
        self,
        center: tuple[int, int],
        radius: int,
        color: tuple[int, int, int]
    ) -> None:
        """Draws an additive-blended soft glow."""
        pass

    @abstractmethod
    def draw_nebula(
        self,
        center: tuple[int, int],
        radius: int,
        color: tuple[int, int, int],
        timer: float
    ) -> None:
        """Draws a soft-edged nebula cloud."""
        pass

    @abstractmethod
    def draw_line(
        self,
        start: tuple[int, int],
        end: tuple[int, int],
        color: tuple[int, int, int] | tuple[int, int, int, int],
        width: int = 1
    ) -> None:
        pass

    @abstractmethod
    def draw_image(
        self,
        image: object,
        pos: tuple[int, int],
        size: tuple[int, int] | None = None,
        rotation: float | None = None,
        centered: bool = False,
    ) -> None:
        """Draw an engine-specific image handle at the given position.

        Args:
            image: Opaque engine image handle.
            pos: Screen (x, y) position.
            size: Optional (w, h) to scale the image.
            rotation: Optional rotation in degrees.
            centered: If True, pos is the center; otherwise top-left.
        """
        pass

    @abstractmethod
    def get_image_size(self, image: object) -> tuple[int, int]:
        """Return (width, height) of an opaque image handle."""
        pass

    @abstractmethod
    def measure_text(self, text: str, size: int = 24) -> tuple[int, int]:
        """Return (width, height) of text rendered at the given size."""
        pass

    @abstractmethod
    def get_screen_size(self) -> tuple[int, int]:
        pass

    @abstractmethod
    def present(self) -> None:
        pass


# ---------------------------------------------------------------------------
# Input interface
# ---------------------------------------------------------------------------

class InputInterface(ABC):
    """Abstract input interface. Returns engine-agnostic Action enums."""

    @abstractmethod
    def poll_actions(self) -> list[Action]:
        """Return list of Action enums triggered this frame."""
        pass

    @abstractmethod
    def is_action_held(self, action: Action) -> bool:
        pass

    @abstractmethod
    def should_quit(self) -> bool:
        pass


# ---------------------------------------------------------------------------
# Audio interface
# ---------------------------------------------------------------------------

class AudioInterface(ABC):
    """Abstract audio interface."""

    @abstractmethod
    def play_sfx(self, sfx_id: str) -> None:
        pass

    @abstractmethod
    def play_music(self, music_id: str, loop: bool = True) -> None:
        pass

    @abstractmethod
    def stop_music(self) -> None:
        pass

    @abstractmethod
    def set_volume(self, volume: float) -> None:
        """Volume from 0.0 to 1.0."""
        pass
