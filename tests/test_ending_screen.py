"""Tests for ending screen summary builder and state logic."""

from unittest.mock import MagicMock

from whisper_crystals.core.game_state import GameStateData, PlayerDecision
from whisper_crystals.core.state_machine import GameStateMachine, GameStateType
from whisper_crystals.core.interfaces import Action
from whisper_crystals.entities.faction import Faction
from whisper_crystals.entities.side_mission import SideMission
from whisper_crystals.ui.ending_screen import EndingState, _wrap_text


def _make_faction(faction_id: str, name: str, rep: int = 0, **kw) -> Faction:
    """Create a Faction with minimal required fields for testing."""
    return Faction(
        faction_id=faction_id, name=name,
        species="cat", alignment="neutral", government="council",
        reputation_with_player=rep, **kw,
    )


def _make_game_state(**overrides) -> GameStateData:
    """Create a minimal GameStateData for testing."""
    gs = GameStateData()
    gs.playtime_seconds = overrides.get("playtime_seconds", 1800.0)
    gs.crystal_inventory = overrides.get("crystal_inventory", 42)
    gs.salvage = overrides.get("salvage", 100)
    gs.completed_encounters = overrides.get("completed_encounters", ["e1", "e2", "e3"])
    gs.story_flags = overrides.get("story_flags", {})
    gs.player_decisions = overrides.get("player_decisions", [])
    gs.side_missions = overrides.get("side_missions", {})
    gs.faction_registry = overrides.get("faction_registry", {})
    return gs


def _make_machine() -> GameStateMachine:
    return GameStateMachine()


class TestEndingCalculation:
    """Test ending title/colour logic."""

    def test_destroy_ending(self):
        gs = _make_game_state(story_flags={"final_choice": "destroy"})
        state = EndingState(_make_machine(), gs, lambda: None)
        assert state._ending_title == "THE CRYSTALS SHATTERED"
        assert state._ending_color == (220, 60, 40)

    def test_share_ending_via_flag(self):
        gs = _make_game_state(story_flags={"final_choice": "share"})
        state = EndingState(_make_machine(), gs, lambda: None)
        assert state._ending_title == "A SHARED MULTIVERSE"
        assert state._ending_color == (60, 200, 80)

    def test_share_ending_via_reputation(self):
        factions = {
            "canis_league": _make_faction("canis_league", "Canis League", rep=60),
            "felid_corsairs": _make_faction("felid_corsairs", "Felid Corsairs", rep=60),
        }
        gs = _make_game_state(faction_registry=factions)
        state = EndingState(_make_machine(), gs, lambda: None)
        assert state._ending_title == "A SHARED MULTIVERSE"

    def test_hold_ending_default(self):
        gs = _make_game_state()
        state = EndingState(_make_machine(), gs, lambda: None)
        assert state._ending_title == "POWER CONSOLIDATED"
        assert state._ending_color == (180, 50, 220)


class TestSummaryBuilder:
    """Test the decision summary content."""

    def test_summary_has_voyage_stats(self):
        gs = _make_game_state(
            playtime_seconds=3600.0,
            crystal_inventory=99,
            salvage=250,
        )
        state = EndingState(_make_machine(), gs, lambda: None)
        texts = [line[0] for line in state._summary_lines]
        assert any("Voyage Duration" in t for t in texts)
        assert any("99" in t for t in texts)
        assert any("250" in t for t in texts)

    def test_summary_hours_format(self):
        gs = _make_game_state(playtime_seconds=7200.0)
        state = EndingState(_make_machine(), gs, lambda: None)
        texts = [line[0] for line in state._summary_lines]
        assert any("2h 0m" in t for t in texts)

    def test_summary_includes_faction_standings(self):
        factions = {
            "canis_league": _make_faction("canis_league", "Canis League", rep=60),
            "felid_corsairs": _make_faction("felid_corsairs", "Felid Corsairs", rep=-30),
        }
        gs = _make_game_state(faction_registry=factions)
        state = EndingState(_make_machine(), gs, lambda: None)
        texts = [line[0] for line in state._summary_lines]
        assert any("FACTION STANDINGS" in t for t in texts)
        assert any("Canis League" in t and "Allied" in t for t in texts)
        assert any("Felid Corsairs" in t and "Hostile" in t for t in texts)

    def test_summary_includes_decisions(self):
        decisions = [
            PlayerDecision(
                decision_id="d1", encounter_id="e1", choice_id="help_dave",
                arc_id="arc_1", timestamp=0, outcome_weight=1.0,
            ),
            PlayerDecision(
                decision_id="d2", encounter_id="e2", choice_id="betray_league",
                arc_id="arc_2", timestamp=100, outcome_weight=-1.0,
            ),
        ]
        gs = _make_game_state(player_decisions=decisions)
        state = EndingState(_make_machine(), gs, lambda: None)
        texts = [line[0] for line in state._summary_lines]
        assert any("DECISION HISTORY" in t for t in texts)
        assert any("Help Dave" in t for t in texts)
        assert any("Betray League" in t for t in texts)
        assert any("Arc I" in t for t in texts)
        assert any("Arc II" in t for t in texts)

    def test_summary_includes_side_missions(self):
        missions = {
            "m1": SideMission(
                mission_id="m1", mission_type="bounty",
                title="Hunt the Pirate", description="",
                status="completed",
            ),
            "m2": SideMission(
                mission_id="m2", mission_type="escort",
                title="Escort the Merchant", description="",
                status="failed",
            ),
        }
        gs = _make_game_state(side_missions=missions)
        state = EndingState(_make_machine(), gs, lambda: None)
        texts = [line[0] for line in state._summary_lines]
        assert any("SIDE MISSIONS" in t for t in texts)
        assert any("Hunt the Pirate" in t for t in texts)
        assert any("Escort the Merchant" in t for t in texts)

    def test_summary_no_missions_section_when_empty(self):
        gs = _make_game_state()
        state = EndingState(_make_machine(), gs, lambda: None)
        texts = [line[0] for line in state._summary_lines]
        assert not any("SIDE MISSIONS" in t for t in texts)

    def test_summary_ends_with_end_of_voyage(self):
        gs = _make_game_state()
        state = EndingState(_make_machine(), gs, lambda: None)
        assert state._summary_lines[-1][0] == "--- END OF VOYAGE ---"


class TestEndingInput:
    """Test input handling (scroll and confirm)."""

    def test_confirm_before_delay_does_nothing(self):
        called = []
        gs = _make_game_state()
        state = EndingState(_make_machine(), gs, lambda: called.append(1))
        state.enter()
        state.update(1.0)  # only 1 second, need > 2
        state.handle_input([Action.CONFIRM])
        assert len(called) == 0

    def test_confirm_after_delay_calls_return(self):
        called = []
        gs = _make_game_state()
        state = EndingState(_make_machine(), gs, lambda: called.append(1))
        state.enter()
        state.update(3.0)
        state.handle_input([Action.CONFIRM])
        assert len(called) == 1

    def test_scroll_down(self):
        gs = _make_game_state()
        state = EndingState(_make_machine(), gs, lambda: None)
        state.enter()
        assert state._scroll_offset == 0
        state.handle_input([Action.MENU_DOWN])
        assert state._scroll_offset == 1

    def test_scroll_up_clamps_at_zero(self):
        gs = _make_game_state()
        state = EndingState(_make_machine(), gs, lambda: None)
        state.enter()
        state.handle_input([Action.MENU_UP])
        assert state._scroll_offset == 0


class TestWrapText:
    """Test the _wrap_text utility."""

    def test_short_text_single_line(self):
        assert _wrap_text("Hello world", 40) == ["Hello world"]

    def test_long_text_wraps(self):
        text = "The quick brown fox jumps over the lazy dog and keeps going"
        lines = _wrap_text(text, 20)
        assert len(lines) > 1
        assert all(len(line) <= 25 for line in lines)  # some slack for word boundary

    def test_empty_text(self):
        assert _wrap_text("", 40) == []
