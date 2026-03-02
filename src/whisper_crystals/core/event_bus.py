"""Pub/sub event bus for decoupled communication between systems."""

from __future__ import annotations

import logging
from typing import Any, Callable

logger = logging.getLogger(__name__)


class EventBus:
    """Simple publish/subscribe event system.

    Usage:
        bus = EventBus()
        bus.subscribe("faction_score_changed", my_handler)
        bus.publish("faction_score_changed", faction_id="canis_league", delta=-15)
    """

    def __init__(self) -> None:
        self._subscribers: dict[str, list[Callable[..., Any]]] = {}

    def subscribe(self, event_name: str, callback: Callable[..., Any]) -> None:
        """Register a callback for an event."""
        if event_name not in self._subscribers:
            self._subscribers[event_name] = []
        self._subscribers[event_name].append(callback)

    def unsubscribe(self, event_name: str, callback: Callable[..., Any]) -> None:
        """Remove a callback for an event."""
        if event_name in self._subscribers:
            self._subscribers[event_name] = [
                cb for cb in self._subscribers[event_name] if cb is not callback
            ]

    def publish(self, event_name: str, *args: Any, **kwargs: Any) -> None:
        """Fire an event, calling all subscribers with the provided args and kwargs."""
        for callback in self._subscribers.get(event_name, []):
            try:
                callback(*args, **kwargs)
            except Exception:
                logger.exception(
                    "EventBus: subscriber %r failed for event %r",
                    callback, event_name,
                )
