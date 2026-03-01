"""Core game loop — tick-based orchestrator.

Owns the main while-loop. Delegates input, update, and render to the
active game state via the state machine. Engine-agnostic except for
the clock (injected).
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Protocol

if TYPE_CHECKING:
    from whisper_crystals.core.interfaces import InputInterface, RenderInterface


class Clock(Protocol):
    """Minimal clock protocol — Pygame clock satisfies this."""

    def tick(self, fps: int) -> int: ...


class GameLoop:
    """Main game loop. Call run() to start."""

    def __init__(
        self,
        renderer: RenderInterface,
        input_handler: InputInterface,
        clock: Clock,
        fps: int = 60,
    ) -> None:
        self.renderer = renderer
        self.input_handler = input_handler
        self.clock = clock
        self.fps = fps
        self.running = True

        # Will be set externally once the state machine exists (Session 2).
        # For Session 1, we use a simple callback pair.
        self._update_fn: callable | None = None
        self._render_fn: callable | None = None

    def set_callbacks(
        self,
        update_fn: callable,
        render_fn: callable,
    ) -> None:
        """Temporary hook for Session 1 before state machine exists."""
        self._update_fn = update_fn
        self._render_fn = render_fn

    def run(self) -> None:
        """Run the main loop until quit."""
        while self.running:
            dt = self.clock.tick(self.fps) / 1000.0

            # Input
            if self.input_handler.should_quit():
                self.running = False
                break

            actions = self.input_handler.poll_actions()

            # Update
            if self._update_fn:
                self._update_fn(dt, actions)

            # Render
            self.renderer.clear()
            if self._render_fn:
                self._render_fn(self.renderer)
            self.renderer.present()
