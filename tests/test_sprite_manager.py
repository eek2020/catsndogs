"""Tests for the sprite asset manager registry and lookup logic."""

from unittest.mock import MagicMock, patch

from whisper_crystals.engine.sprite_manager import (
    CHARACTER_PORTRAITS,
    CHARACTER_SPRITES,
    FACTION_COLOURS,
    SHIP_SPRITES,
    UI_SPRITES,
    SpriteManager,
)


class TestSpriteRegistry:
    """Verify that all registries have correct entries."""

    def test_ship_sprites_has_all_factions(self):
        expected = {
            "corsair_raider",
            "league_cruiser",
            "league_destroyer",
            "royal_galleon",
            "wolf_strike_craft",
            "fairy_vessel",
            "knight_warship",
            "goblin_scrapship",
            "alien_craft",
        }
        assert set(SHIP_SPRITES.keys()) == expected

    def test_ship_sprites_existing_assets_have_paths(self):
        assert SHIP_SPRITES["corsair_raider"] != ""
        assert SHIP_SPRITES["league_cruiser"] != ""
        assert SHIP_SPRITES["royal_galleon"] != ""

    def test_ship_sprites_new_assets_have_paths(self):
        assert SHIP_SPRITES["wolf_strike_craft"] != ""
        assert SHIP_SPRITES["fairy_vessel"] != ""
        assert SHIP_SPRITES["knight_warship"] != ""
        assert SHIP_SPRITES["goblin_scrapship"] != ""

    def test_ship_sprites_alien_craft_wired(self):
        assert SHIP_SPRITES["alien_craft"] == "design/ships/alien_vessel.png"

    def test_character_portraits_has_main_cast(self):
        assert "aristotle" in CHARACTER_PORTRAITS
        assert "dave" in CHARACTER_PORTRAITS
        assert "death" in CHARACTER_PORTRAITS

    def test_character_sprites_has_main_cast(self):
        assert "aristotle" in CHARACTER_SPRITES
        assert "dave" in CHARACTER_SPRITES
        assert "death" in CHARACTER_SPRITES

    def test_ui_sprites_has_key_assets(self):
        assert "fight_cutlass" in UI_SPRITES
        assert "splash_screen" in UI_SPRITES
        assert "title" in UI_SPRITES

    def test_faction_colours_has_all_factions(self):
        expected = {
            "felid_corsairs",
            "canis_league",
            "lion_sovereignty",
            "wolf_clans",
            "fairy_court",
            "knight_order",
            "goblin_syndicate",
            "ancient_ones",
        }
        assert set(FACTION_COLOURS.keys()) == expected

    def test_faction_colours_are_rgb_tuples(self):
        for faction_id, colour in FACTION_COLOURS.items():
            assert len(colour) == 3, f"{faction_id} colour must be RGB"
            assert all(0 <= c <= 255 for c in colour), f"{faction_id} colour out of range"


class TestSpriteManagerLookup:
    """Test SpriteManager get_* methods with mocked pygame surfaces."""

    def _make_manager(self) -> SpriteManager:
        return SpriteManager("/fake/root")

    @patch("whisper_crystals.engine.sprite_manager.load_image_alpha")
    @patch("whisper_crystals.engine.sprite_manager.remove_background_by_corners")
    def test_get_ship_returns_surface(self, mock_remove_bg, mock_load):
        mock_surf = MagicMock()
        mock_surf.get_size.return_value = (128, 64)
        mock_load.return_value = mock_surf
        mock_remove_bg.return_value = mock_surf

        mgr = self._make_manager()
        result = mgr.get_ship("league_cruiser")
        assert result is mock_surf
        mock_load.assert_called_once()

    @patch("whisper_crystals.engine.sprite_manager.load_image_alpha")
    def test_get_ship_missing_asset_returns_none(self, mock_load):
        mock_load.return_value = None
        mgr = self._make_manager()
        result = mgr.get_ship("league_cruiser")
        assert result is None

    def test_get_ship_unknown_id_returns_none(self):
        mgr = self._make_manager()
        result = mgr.get_ship("nonexistent_ship")
        assert result is None

    def test_get_ship_empty_path_returns_none(self):
        mgr = self._make_manager()
        result = mgr.get_ship("alien_craft")
        assert result is None

    @patch("whisper_crystals.engine.sprite_manager.load_image_alpha")
    @patch("whisper_crystals.engine.sprite_manager.remove_background_by_corners")
    def test_get_ship_caches_result(self, mock_remove_bg, mock_load):
        mock_surf = MagicMock()
        mock_load.return_value = mock_surf
        mock_remove_bg.return_value = mock_surf

        mgr = self._make_manager()
        first = mgr.get_ship("league_cruiser")
        second = mgr.get_ship("league_cruiser")
        assert first is second
        # Should only load once
        assert mock_load.call_count == 1

    @patch("whisper_crystals.engine.sprite_manager.load_image_alpha")
    @patch("whisper_crystals.engine.sprite_manager.remove_background_by_corners")
    @patch("pygame.transform.flip")
    def test_get_ship_flip_x(self, mock_flip, mock_remove_bg, mock_load):
        mock_surf = MagicMock()
        flipped_surf = MagicMock()
        mock_load.return_value = mock_surf
        mock_remove_bg.return_value = mock_surf
        mock_flip.return_value = flipped_surf

        mgr = self._make_manager()
        result = mgr.get_ship("league_cruiser", flip_x=True)
        mock_flip.assert_called_once_with(mock_surf, True, False)
        assert result is flipped_surf

    @patch("whisper_crystals.engine.sprite_manager.load_image_alpha")
    @patch("whisper_crystals.engine.sprite_manager.remove_background_by_corners")
    @patch("pygame.transform.smoothscale")
    def test_get_ship_with_size(self, mock_scale, mock_remove_bg, mock_load):
        mock_surf = MagicMock()
        scaled_surf = MagicMock()
        mock_load.return_value = mock_surf
        mock_remove_bg.return_value = mock_surf
        mock_scale.return_value = scaled_surf

        mgr = self._make_manager()
        result = mgr.get_ship("league_cruiser", size=(64, 32))
        mock_scale.assert_called_once_with(mock_surf, (64, 32))
        assert result is scaled_surf

    @patch("whisper_crystals.engine.sprite_manager.load_image_alpha")
    @patch("whisper_crystals.engine.sprite_manager.remove_background_by_corners")
    def test_get_portrait_returns_surface(self, mock_remove_bg, mock_load):
        mock_surf = MagicMock()
        mock_load.return_value = mock_surf
        mock_remove_bg.return_value = mock_surf

        mgr = self._make_manager()
        result = mgr.get_portrait("aristotle")
        assert result is mock_surf

    def test_get_portrait_unknown_returns_none(self):
        mgr = self._make_manager()
        assert mgr.get_portrait("unknown_npc") is None

    @patch("whisper_crystals.engine.sprite_manager.load_image_alpha")
    @patch("whisper_crystals.engine.sprite_manager.remove_background_by_corners")
    def test_get_character_returns_surface(self, mock_remove_bg, mock_load):
        mock_surf = MagicMock()
        mock_load.return_value = mock_surf
        mock_remove_bg.return_value = mock_surf

        mgr = self._make_manager()
        result = mgr.get_character("dave")
        assert result is mock_surf

    @patch("whisper_crystals.engine.sprite_manager.load_image_alpha")
    def test_get_ui_returns_surface(self, mock_load):
        mock_surf = MagicMock()
        mock_load.return_value = mock_surf

        mgr = self._make_manager()
        result = mgr.get_ui("fight_cutlass")
        assert result is mock_surf

    def test_get_faction_colour_known(self):
        mgr = self._make_manager()
        assert mgr.get_faction_colour("canis_league") == (40, 120, 200)

    def test_get_faction_colour_unknown_defaults_white(self):
        mgr = self._make_manager()
        assert mgr.get_faction_colour("unknown_faction") == (255, 255, 255)

    @patch("whisper_crystals.engine.sprite_manager.load_image_alpha")
    @patch("whisper_crystals.engine.sprite_manager.remove_background_by_corners")
    def test_get_ship_for_faction(self, mock_remove_bg, mock_load):
        mock_surf = MagicMock()
        mock_load.return_value = mock_surf
        mock_remove_bg.return_value = mock_surf

        faction = MagicMock()
        faction.ship_template_id = "league_cruiser"
        registry = {"canis_league": faction}

        mgr = self._make_manager()
        result = mgr.get_ship_for_faction("canis_league", registry)
        assert result is mock_surf

    def test_get_ship_for_faction_unknown(self):
        mgr = self._make_manager()
        result = mgr.get_ship_for_faction("unknown", {})
        assert result is None

    @patch("whisper_crystals.engine.sprite_manager.load_image_alpha")
    @patch("whisper_crystals.engine.sprite_manager.remove_background_by_corners")
    def test_clear_cache(self, mock_remove_bg, mock_load):
        mock_surf = MagicMock()
        mock_load.return_value = mock_surf
        mock_remove_bg.return_value = mock_surf

        mgr = self._make_manager()
        mgr.get_ship("league_cruiser")
        assert len(mgr._cache) > 0

        mgr.clear_cache()
        assert len(mgr._cache) == 0
        assert len(mgr._scaled_cache) == 0

    @patch("whisper_crystals.engine.sprite_manager.load_image_alpha")
    @patch("whisper_crystals.engine.sprite_manager.remove_background_by_corners")
    def test_preload_all_counts(self, mock_remove_bg, mock_load):
        mock_surf = MagicMock()
        mock_load.return_value = mock_surf
        mock_remove_bg.return_value = mock_surf

        mgr = self._make_manager()
        count = mgr.preload_all()
        # Should load all sprites that have non-empty paths
        non_empty = (
            sum(1 for p in SHIP_SPRITES.values() if p)
            + sum(1 for p in CHARACTER_PORTRAITS.values() if p)
            + sum(1 for p in CHARACTER_SPRITES.values() if p)
            + sum(1 for p in UI_SPRITES.values() if p)
        )
        assert count == non_empty
