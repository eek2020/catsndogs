"""Regression tests for navigation camera deadzone and sprite background cleanup."""

from __future__ import annotations

from dataclasses import dataclass

from whisper_crystals.core.game_state import GameStateData
from whisper_crystals.core.interfaces import Action
from whisper_crystals.core.state_machine import GameStateMachine
from whisper_crystals.engine.image_utils import remove_background_by_corners
from whisper_crystals.ui.navigation import CAMERA_DEADZONE, NavigationState


class _FakeInput:
    def __init__(self) -> None:
        self.held: set[Action] = set()

    def poll_actions(self) -> list[Action]:
        return []

    def is_action_held(self, action: Action) -> bool:
        return action in self.held

    def should_quit(self) -> bool:
        return False


class _FakeCamera:
    def __init__(self, width: int = 1000, height: int = 600, x: float = -500.0, y: float = -300.0) -> None:
        self.width = width
        self.height = height
        self.x = x
        self.y = y
        self.follow_calls: list[tuple[tuple[float, float], float, float]] = []

    def follow(self, target_pos: tuple[float, float], dt: float, smoothing: float = 5.0) -> None:
        self.follow_calls.append((target_pos, dt, smoothing))

    def world_to_screen(self, world_pos: tuple[float, float]) -> tuple[int, int]:
        return (int(world_pos[0] - self.x), int(world_pos[1] - self.y))


@dataclass
class _Pixel:
    r: int
    g: int
    b: int
    a: int


class _FakeSurface:
    def __init__(self, rows: list[list[tuple[int, int, int, int]]]) -> None:
        self._grid = [[_Pixel(*px) for px in row] for row in rows]

    def convert_alpha(self) -> _FakeSurface:
        return self

    def get_size(self) -> tuple[int, int]:
        return (len(self._grid[0]), len(self._grid))

    def get_at(self, pos: tuple[int, int]) -> _Pixel:
        x, y = pos
        return self._grid[y][x]

    def set_at(self, pos: tuple[int, int], rgba: tuple[int, int, int, int]) -> None:
        x, y = pos
        self._grid[y][x] = _Pixel(*rgba)


class TestNavigationCameraDeadzone:
    def test_camera_target_uses_deadzone_offset_when_ship_moves_right(self) -> None:
        game_state = GameStateData(position_x=0.0, position_y=0.0)
        camera = _FakeCamera()
        input_handler = _FakeInput()
        input_handler.held.add(Action.MOVE_RIGHT)

        state = NavigationState(
            machine=GameStateMachine(),
            camera=camera,
            input_handler=input_handler,
            game_state=game_state,
        )

        state.update(1.0)

        assert camera.follow_calls, "Expected camera.follow() to be called"
        (target_x, target_y), dt, smoothing = camera.follow_calls[-1]
        assert dt == 1.0
        assert smoothing == 8.0
        assert target_x == state.ship_x - CAMERA_DEADZONE
        assert target_y == 0.0


class TestRemoveBackgroundByCorners:
    def test_ignores_noisy_corner_when_choosing_background_colour(self) -> None:
        # Three corners are grey background; one corner is noisy black artifact.
        surface = _FakeSurface(
            [
                [(120, 120, 120, 255), (120, 120, 120, 255), (0, 0, 0, 255)],
                [(120, 120, 120, 255), (130, 130, 130, 255), (120, 120, 120, 255)],
                [(120, 120, 120, 255), (120, 120, 120, 255), (120, 120, 120, 255)],
            ]
        )

        cleaned = remove_background_by_corners(surface)

        # Background-like center pixel should become transparent.
        assert cleaned.get_at((1, 1)).a == 0

    def test_feathers_alpha_for_near_background_pixels(self) -> None:
        surface = _FakeSurface(
            [
                [(120, 120, 120, 255), (120, 120, 120, 255), (120, 120, 120, 255)],
                [(120, 120, 120, 255), (160, 160, 160, 255), (120, 120, 120, 255)],
                [(120, 120, 120, 255), (120, 120, 120, 255), (120, 120, 120, 255)],
            ]
        )

        cleaned = remove_background_by_corners(surface)

        # Pixel is slightly outside hard tolerance, so it should become partially transparent.
        alpha = cleaned.get_at((1, 1)).a
        assert 120 <= alpha <= 135
