"""Tests for skip functionality in dialogue and cutscene states."""

from __future__ import annotations

from unittest.mock import MagicMock

from whisper_crystals.core.event_bus import EventBus
from whisper_crystals.core.game_state import GameStateData
from whisper_crystals.core.interfaces import Action
from whisper_crystals.core.state_machine import GameStateMachine
from whisper_crystals.entities.encounter import Encounter, EncounterChoice, EncounterOutcome
from whisper_crystals.systems.encounter_engine import EncounterEngine
from whisper_crystals.ui.cutscene import CutsceneState
from whisper_crystals.ui.dialogue_ui import DialogueState


# ---- Helpers ----

def _make_encounter() -> Encounter:
    """Create a minimal encounter for testing."""
    return Encounter(
        encounter_id="test_enc",
        encounter_type="diplomatic",
        title="Test Encounter",
        description="This is a long description that takes time to type out.",
        arc_id="arc_1",
        location="sector_1",
        trigger_conditions={},
        npc_ids=["aristotle"],
        choices=[
            EncounterChoice(
                choice_id="greet",
                text="Hello there",
                outcome=EncounterOutcome(),
            ),
            EncounterChoice(
                choice_id="leave",
                text="Goodbye",
                outcome=EncounterOutcome(),
            ),
        ],
        priority=1,
        repeatable=False,
        spawn_weight=1.0,
    )


def _make_dialogue_state(
    encounter: Encounter | None = None,
) -> tuple[DialogueState, MagicMock]:
    """Create a DialogueState with mocked dependencies. Returns (state, on_complete_mock)."""
    machine = GameStateMachine()
    enc = encounter or _make_encounter()
    event_bus = EventBus()
    game_state = GameStateData()
    engine = EncounterEngine(MagicMock(), event_bus)
    on_complete = MagicMock()

    state = DialogueState(
        machine=machine,
        encounter=enc,
        encounter_engine=engine,
        game_state=game_state,
        event_bus=event_bus,
        on_complete=on_complete,
    )
    state.enter()
    return state, on_complete


def _make_cutscene_state() -> tuple[CutsceneState, MagicMock]:
    """Create a CutsceneState with mocked dependencies. Returns (state, on_complete_mock)."""
    machine = GameStateMachine()
    on_complete = MagicMock()

    state = CutsceneState(
        machine=machine,
        title="Test Cutscene",
        lines=["Line one of the cutscene.", "Line two.", "Final line."],
        on_complete=on_complete,
    )
    state.enter()
    return state, on_complete


# ---- DialogueState Skip Tests ----

class TestDialogueSkip:
    """Test SKIP action in DialogueState."""

    def test_skip_during_typewriter_reveals_description(self) -> None:
        """SKIP during typewriter effect instantly reveals full description."""
        state, _ = _make_dialogue_state()

        # Description should not be done yet
        assert not state._description_done

        state.handle_input([Action.SKIP])

        assert state._description_done
        assert state._description_chars == float(len(state.encounter.description))

    def test_skip_during_typewriter_lands_on_choices(self) -> None:
        """After SKIP, state is in choosing phase with description done (choices visible)."""
        state, _ = _make_dialogue_state()

        state.handle_input([Action.SKIP])

        assert state._phase == "choosing"
        assert state._description_done

    def test_skip_during_outcome_triggers_complete(self) -> None:
        """SKIP during outcome phase acts like CONFIRM — calls on_complete."""
        state, on_complete = _make_dialogue_state()

        # Fast-forward to outcome phase
        state._description_done = True
        state._description_chars = float(len(state.encounter.description))
        state._phase = "outcome"

        state.handle_input([Action.SKIP])

        on_complete.assert_called_once()

    def test_skip_does_not_auto_select_choice(self) -> None:
        """SKIP during choosing phase (description done) does NOT auto-pick a choice."""
        state, on_complete = _make_dialogue_state()

        # Skip through description first
        state.handle_input([Action.SKIP])
        assert state._description_done

        # Now SKIP again — should NOT resolve a choice
        state.handle_input([Action.SKIP])

        assert state._phase == "choosing"
        on_complete.assert_not_called()


# ---- CutsceneState Skip Tests ----

class TestCutsceneSkip:
    """Test SKIP action in CutsceneState."""

    def test_skip_jumps_to_all_done(self) -> None:
        """SKIP during line display sets all_done to True."""
        state, _ = _make_cutscene_state()

        assert not state._all_done

        state.handle_input([Action.SKIP])

        assert state._all_done

    def test_skip_does_not_call_on_complete(self) -> None:
        """SKIP lands on 'press enter to continue' — does NOT auto-complete."""
        state, on_complete = _make_cutscene_state()

        state.handle_input([Action.SKIP])

        assert state._all_done
        on_complete.assert_not_called()

    def test_skip_then_confirm_completes(self) -> None:
        """After SKIP, pressing CONFIRM triggers on_complete."""
        state, on_complete = _make_cutscene_state()

        state.handle_input([Action.SKIP])
        state.handle_input([Action.CONFIRM])

        on_complete.assert_called_once()

    def test_skip_when_already_done_is_noop(self) -> None:
        """SKIP when already all_done does nothing (no error)."""
        state, on_complete = _make_cutscene_state()

        # Skip to done
        state.handle_input([Action.SKIP])
        assert state._all_done

        # Skip again — should not error or call complete
        state.handle_input([Action.SKIP])
        on_complete.assert_not_called()

    def test_skip_midway_through_lines(self) -> None:
        """SKIP partway through cutscene lines jumps to all_done."""
        state, _ = _make_cutscene_state()

        # Advance through first line manually
        state.handle_input([Action.CONFIRM])  # reveals full first line
        state.handle_input([Action.CONFIRM])  # advance to second line

        assert state._current_line == 1
        assert not state._all_done

        state.handle_input([Action.SKIP])

        assert state._all_done
