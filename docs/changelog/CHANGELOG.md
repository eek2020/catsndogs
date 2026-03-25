# Changelog

All notable changes to the Whisper Crystals project are documented here.

Format: Each entry includes the date, phase/task reference, and summary of changes.

---

## 2026-03-25 — Feature: 2D World Gameplay Layer

**Feature:** Added a full 2D world layer on top of the existing UI-screen-based game systems. Includes tilemap-based world scenes, a playable CharacterBody2D player, NPC state machines with pathfinding and dialogue triggers, scene transitions with fade effects, and an example interior (tavern). The Celestial Codex star map now supports travel-to-world-scene flow.

### Phase 1: Tileset Atlas Generator

- **Created** `tools/godot-dev/tiles/tileset_generator.py` — Pillow-based script generating a 288×256 atlas PNG with 32×32px tiles
- **Created** `tools/godot-dev/tiles/requirements.txt` — Pillow dependency
- **Output** `godot/assets/tiles/world_atlas.png` — 9×8 grid atlas with 6 terrain types (Grass, Dirt, Stone, Wall, Water, Roof) in 3×3 autotile layout, plus 18 decor/furniture tiles

### Phase 2: TileSet & TileMap World Scene

- **Created** `godot/resources/world_tileset.tres` — TileSet resource with 32×32 tile size, physics layer for collision, 6 terrain sets for autotiling
- **Created** `godot/scenes/world/world.tscn` — Main world scene with Node2D root (y_sort), GroundLayer/DecorLayer/RoofLayer TileMapLayer nodes, NavigationRegion2D, and Entities container

### Phase 3: Player Controller

- **Created** `godot/scripts/world/player_controller.gd` — 8-direction movement via existing input map (WASD/arrows), `move_and_slide()` physics, animation state machine (idle/walk × 4 directions), interact action emits EventBus signal
- **Created** `godot/scenes/world/player.tscn` — CharacterBody2D with AnimatedSprite2D, RectangleShape2D collision, Camera2D with smoothing

### Phase 4: NPC System

- **Created** `godot/scripts/world/npc_controller.gd` — State machine (IDLE/PATROL/TALK), NavigationAgent2D pathfinding, Area2D interaction zone, faction-aware dialogue triggering via EventBus
- **Created** `godot/scenes/world/npc.tscn` — CharacterBody2D with AnimatedSprite2D, collision, NavigationAgent2D, CircleShape2D interact zone (radius 40)
- **Created** `godot/scripts/world/dialogue_manager.gd` — Bridges NPC interactions to existing dialogue UI; loads dialogue JSON, builds Encounter objects, supports dialogue_steps branching; faction-reputation-aware generic barks

### Phase 5: Scene Transitions & Interiors

- **Created** `godot/scripts/world/scene_transition.gd` — Area2D-based door detection, fade-out/fade-in transitions via TransitionOverlay, stores return position in GameSession
- **Created** `godot/scenes/world/tavern.tscn` — Example interior with TileMapLayers, NavigationRegion2D, Innkeeper NPC, Patron NPC, exit door with scene_transition back to world

### Phase 6: Overworld Map Enhancement

- **Modified** `godot/scripts/ui/star_map_screen.gd` — Added travel-to-world-scene flow: SPACE key requests travel, confirmation dialog with ENTER/ESC, `WORLD_SCENE_MAP` lookup, deferred scene change; updated galaxy layer control hints

### Integration

- **Modified** `godot/scripts/autoload/game_session.gd` — Added `_return_scene_path`, `_return_position`, `_return_facing` tracking variables; `store_return_position()`, `get_return_position()`, `has_return_position()`, `clear_return_position()` helper methods
- **Modified** `godot/scripts/autoload/event_bus.gd` — Added 5 world layer signals: `world_scene_entered`, `world_scene_exited`, `npc_interaction_started`, `npc_interaction_ended`, `door_transition`

---

## 2026-03-25 — Art: Aristotle spritesheet on planet screen

**Enhancement:** Replaced placeholder circle with animated spritesheets for both Aristotle and Dave in the top-down planet exploration mode. The sprite renders 8-direction walk cycles and falls back to idle frames when stationary. The correct spritesheet loads automatically based on the selected protagonist.

### Changes

- Copied `aristotle_spritesheet.png` and `dave_spritesheet.png` to `assets/sprites/`
- `planet_screen.gd` — loads spritesheet based on `protagonist_id`, tracks facing octant, cycles walk/idle animation rows, draws correct frame via `draw_texture_rect_region()`

---

## 2026-03-23 — Feature: Planetary Exploration (Top-Down Mode)

**Feature:** Top-down exploration mode for planetary surfaces with merchants, treasures, and NPC interaction.

### New System

- `Planet` entity (`scripts/entities/planet.gd`) — planet data model with biome, merchants, treasures, hostiles
- `PlanetSystem` (`scripts/systems/planet_system.gd`) — manages planet loading, landing/departure, treasure collection, state persistence
- Planet screen (`scripts/ui/planet_screen.gd`) — top-down exploration with 4-way movement, merchant trading, treasure hunting
- 3 charted planets: Fringe Haven (settlement), Goblin Market World (industrial), Moonpetal Glade (enchanted)
- 4 biome types defined in `data/planets/biomes.json`

### Integration

- Navigation screen renders planet markers with biome-coloured circles and `[L] LAND` proximity prompt
- `[L]` key or `[Enter]` lands on nearby planets, transitioning to the planet screen
- Depart button returns to navigation with collected loot merged into main inventory
- Planet state persists: cleared treasures and visit history survive save/load
- `EventBus` emits `planet_landed`, `planet_departed`, `planet_treasure_found`, `planet_merchant_interacted`
- `GameStateData` tracks `current_planet_id`, `planet_states`, `planet_inventory` (save/load compatible)

---

## 2026-03-23 — Feature: Star Bases (Dockable Space Stations)

**Feature:** Dockable space stations on the star map with services, artifacts, and three base variants.

### New System

- `StarBase` entity (`scripts/entities/star_base.gd`) — base data model with type, faction, services, artifacts
- `StarBaseSystem` (`scripts/systems/star_base_system.gd`) — manages base loading, visibility, docking, artifact purchases, proximity detection
- Station screen UI (`scripts/ui/station_screen.gd`) — overlay menu for docked services (refuel, repair, trade, salvage drop-off, artifact market)
- 6 star bases across regions: Fringe Outpost, Corsair Haven, Iron Dock, Twilight Exchange, Scrapheap Station (hidden), Wolf Citadel (stronghold)
- 5 exclusive artifacts: Aeolian Tuning Fork, Bottled Solar Flare, Chrono-Compass, Midas's Grapnel, Fairy Dust Scrubber

### Integration

- Navigation screen renders diamond-shaped base markers with proximity dock prompt
- `[E]` key docks at nearby bases (overrides faction screen when in range)
- Three base variants: Open (always dockable), Hidden (requires discovery flag), Stronghold (requires faction reputation)
- Artifact passive bonuses tracked via `get_artifact_bonuses()` for use by other systems
- `EventBus` emits `base_docked`, `base_undocked`, `artifact_acquired` signals
- `GameStateData` tracks `docked_base_id`, `discovered_bases`, `acquired_artifacts`, `base_state_overrides` (save/load compatible)

---

## 2026-03-23 — Feature: Skill Point Allocation ("Harmonic Attunement")

**Feature:** New game start skill redistribution screen and stat evaluation system.

### New System

- `StatEvaluator` (`scripts/systems/stat_evaluator.gd`) — utility for checking skill thresholds, finding highest stat, percentage calculations
- Skill allocation screen (`scripts/ui/skill_allocation.gd`) — redistribute starting points across 6 stats with +/- controls
- Presets: Default, Warrior, Diplomat, Shadow
- Resonance Shards (`data/items/resonance_shards.json`) — in-game items that expand the skill point pool

### Integration

- Character select now routes through skill allocation before cutscene
- `EncounterEngine` supports `min_<stat>`, `highest_stat`, and `karma_tier` trigger conditions
- `CombatSystem` factors `combat_skill` into damage (+2% per point) and `stealth` into dodge (+1% per point)
- `GameStateData` tracks `bonus_skill_points` and `resonance_shards_found` (save/load compatible)
- `EventBus` emits `stats_changed` and `resonance_shard_found` signals

---

## 2026-03-23 — Feature: Karma System (Global Reputation Meter)

**Feature:** Added a global karma system that tracks moral alignment on a -100 to +100 scale, separate from per-faction reputation.

### New System

- `KarmaSystem` (`scripts/systems/karma_system.gd`) — core logic for karma tracking, tier calculation, price/NPC modifiers
- Five karma tiers: Tyrant, Ruthless, Neutral, Virtuous, Paragon
- Karma-based merchant price modifiers (Tyrant: +40%, Paragon: -20%)
- NPC disposition offsets per tier
- JSON-driven configuration (`data/karma/karma_config.json`, `data/karma/karma_triggers.json`)

### Integration

- `EncounterOutcome` now supports `karma_delta` field for encounter choices
- `EncounterEngine` applies karma changes when processing choice and dialogue outcomes
- `EconomySystem` applies karma price modifier to buy prices
- `GameStateData` tracks `karma` score and `karma_history` (save/load compatible)
- `EventBus` emits `karma_changed` and `karma_tier_changed` signals
- Navigation HUD displays karma tier and score with colour coding

---

## 2026-03-21 — Major Content Expansion: Maps, Arcs, Characters

**Feature:** Massive content expansion adding 6 new maps, 6 new story arcs, 22 special characters, and a hidden map with a secret 4th ending.

### Maps (7 → 13 regions)

- **The Shattered Prides** — Dedicated Lion sovereign territory with palace ruins, political intrigue
- **The Iron Expanse** — Dedicated Wolf military frontier with fortresses and weapons testing
- **The Twilight Bazaar** — Neutral free port hub for cross-faction encounters and special characters
- **The Warp Marches** — Unstable alien frontier with reality distortions and high-risk exploration
- **The Bone Yard** — Ancient starship graveyard with massive salvage rewards and lore
- **The Cradle of Whispers** — Hidden map (10 complex unlock requirements), origin of all Whisper Crystals, secret 4th ending

### Story Arcs (4 → 10 arcs)

- Current Arc 4 "The Reckoning" repositioned as Arc 10 (finale)
- **Arc 4 "The Undercurrent"** — Crystal instability, Lion fracture, Death erratic
- **Arc 5 "The Iron Tide"** — Wolf total war campaign, Dave loyalty crisis
- **Arc 6 "The Fracture"** — Bone Yard discovery, Lion civil war, ancient signal
- **Arc 7 "The Communion"** — Warp Marches, crystal consciousness contact
- **Arc 8 "The Gathering Storm"** — Final alliances, Cradle portal
- **Arc 9 "The Cradle"** — Hidden optional arc inside Cradle of Whispers
- **Ending D "Reunite"** — Hidden 4th ending for balanced players who find the Cradle

### Special Characters (22 new)

- 12 faction-aligned: Lord Mane, Iron Fang, Glimmer, Cogsworth, Ser Galvain, Tidewalker, Lady Penumbra, Rustclaw, The Void Singer, Brother Hemlock, Snarl, Admiral Brass
- 10 independent: The Oracle, The Keeper, Jinx, The Debt Collector, Patch, Flux, Sister Meridian, Wraith, Grizzle, Echo
- Mix of significant (determines faction outcomes) and flavor (world-building richness)

### Files Changed

- `data/story/arc_definitions.json` — Expanded from 4 to 10 arcs, added ending_d_reunite threshold
- `data/maps/galaxy_layout.json` — Added 6 new region nodes
- `data/maps/region_maps.json` — Added 6 new region definitions with POIs, spawn zones, hidden locations
- `data/maps/purchasable_maps.json` — Added 5 new purchasable star charts
- `scripts/core/data_loader.gd` — Added `load_cradle_encounters()` and `load_special_character_encounters()`

### Files Added

- `data/encounters/arc4_encounters.json` through `arc9_encounters.json` — Aristotle path encounters
- `data/encounters/arc4_encounters_dave.json` through `arc9_encounters_dave.json` — Dave path encounters
- `data/encounters/arc10_encounters.json` + `arc10_encounters_dave.json` — Renamed from old arc4
- `data/encounters/special_characters.json` — 22 special character encounters
- `data/side_missions/arc4_side_missions.json` through `arc9_side_missions.json` — Aristotle side missions
- `data/side_missions/arc4_side_missions_dave.json` through `arc9_side_missions_dave.json` — Dave side missions
- `data/side_missions/arc10_side_missions.json` + `arc10_side_missions_dave.json` — Renamed from old arc4
- `data/side_missions/distress_signals.json` — Added 5 new region-specific distress signals

---

## 2026-03-21 — Celestial Codex: 3-Layer Map System

**Feature:** Replaced the single-region star map with the "Celestial Codex" — a three-layer map overlay accessible via TAB.

- **Galaxy Layer** — shows all 7 regions as connected nodes with discovery state, fog reveal progress arcs, and danger level indicators. Arrow keys navigate between nodes, ENTER drills into a region.
- **Region Layer** — the existing circular map view with fog of war, POIs, player position, and breadcrumb navigation. ESC returns to galaxy, ENTER drills to local scan.
- **Local Layer** — zoomed-in player-centered view with detailed fog, labeled POIs, vision range circle, region boundary indicators, and coordinate readout.
- **Directional boundary transitions** — flying off a region edge now picks the neighbor whose galaxy position matches the exit direction (no longer always picks the first connected region).
- **Directional entry positions** — entering a region places the player on the edge closest to where they came from.

### Files Changed

- `data/maps/galaxy_layout.json` — New: galaxy node positions and colors for all 7 regions
- `scripts/core/data_loader.gd` — Added `load_galaxy_layout()` method
- `scripts/systems/star_map_system.gd` — Added galaxy layout storage, `get_galaxy_node_pos()`, `get_galaxy_node_color()`, `get_region_fog_percentage()`, and directional `get_entry_position()`
- `scripts/autoload/game_session.gd` — Wired galaxy layout loading in `_init_star_maps()`
- `scripts/ui/star_map_screen.gd` — Major rewrite: 3-layer renderer with galaxy/region/local draw methods, layer transitions, galaxy node navigation, per-layer input handling
- `scripts/ui/navigation.gd` — Directional boundary neighbor selection using galaxy layout positions
- `scripts/autoload/event_bus.gd` — Added `codex_layer_changed` signal
- `scenes/ui/star_map_screen.tscn` — Updated title to "CELESTIAL CODEX"

---

## 2026-03-20 — Fix Arc 1 ending prematurely after "Eyes in the Dark"

**Bug Fix:** Completing the "Eyes in the Dark" encounter immediately triggered the arc 1 exit, skipping "The Captain's Doctrine" stance choice. Added `arc1_stance` to arc 1 exit conditions so the player must make their doctrine decision before advancing to arc 2.

### Files Changed

- `data/story/arc_definitions.json` — Added `arc1_stance: true` to arc 1 exit conditions and arc 2 entry conditions

---

## 2026-03-20 — Fix dialogue title shifting outside parchment with 3+ choices

**Bug Fix:** When encounters displayed more than 2 choice options, the title label shifted outside the parchment background. The panel and dialogue background had a fixed 280px height that couldn't accommodate the extra buttons. The panel now dynamically resizes upward to fit its content when choices are added, and resets when choices are cleared between dialogue steps.

### Files Changed

- `scripts/ui/dialogue_ui.gd` — Added `_resize_panel_to_fit()` to grow panel/background height based on content; called after building choices in both legacy and dialogue-step paths; reset height on choice clear

---

## 2026-03-20 — Dialogue Background for All Interactions + Soft Fog Edges

**Enhancement:** The dialogue background texture is now shown for all encounter types, not just multi-step dialogue encounters. Legacy single-choice encounters now also display the parchment background with matching text styling.

**Enhancement:** Fog of war edges in both the navigation view and star map screen are now rendered with soft, cloud-like edges instead of sharp rectangles. Boundary cells use overlapping circles with alpha gradients based on proximity to revealed areas, creating a natural nebula/cloud aesthetic.

### Files Changed

- `scripts/ui/dialogue_ui.gd` — Always show dialogue background and parchment styling for all encounter types
- `scripts/ui/navigation.gd` — Soft circle-based fog rendering at revealed/hidden boundaries
- `scripts/ui/star_map_screen.gd` — Per-cell soft circle fog with neighbor-based alpha at boundaries

---

## 2026-03-20 — Star Map Fog, Cartographer Balance, and Distress Signal Fix

**Enhancement:** Replaced solid black fog of war on the star map with a translucent nebula-style fog. Unrevealed cells now render with subtle colour variation and partial transparency, while boundary cells between revealed and hidden areas get a softer fade for a more atmospheric look.

**Balance:** The fairy cartographer encounter now requires completing the Crystal Discovery encounter first (`arc1_crystal_discovered` flag) and is placed at a fixed location in the far corner of The Fringe (5400, 5600), making Pip much harder to find early on.

**Enhancement:** Rescuing the cartographer now reveals fog only around the hidden locations Pip has charted (radius 400 around each hidden location across all regions), rather than making everything visible. Players must still explore or purchase maps to uncover the rest.

**Bug Fix:** Removed the fairy cartographer reference from the repeatable `distress_escape_pod` encounter. The rescue outcome now features a retired merchant navigator instead, eliminating the conflict with the dedicated one-time cartographer encounter.

### Files Changed
- `scripts/ui/star_map_screen.gd` — Fog of war rendering: nebula colours, edge-cell blending, translucent density
- `scripts/systems/star_map_system.gd` — `on_cartographer_rescued()` reveals fog around hidden locations only
- `data/encounters/fairy_cartographer.json` — Added `arc1_crystal_discovered` trigger condition
- `data/maps/region_maps.json` — Added fixed story location for cartographer in starting_realm
- `data/side_missions/distress_signals.json` — Changed escape pod rescue outcome from fairy cartographer to merchant navigator

---

## 2026-03-20 — Fix POIs Spawning Outside Region Bounds + Boundary Edge Effect

**Bug Fix:** Story encounters, distress signals, combat spawns, and other POIs could spawn outside the navigable region boundary, making them unreachable. All POI spawn points (random encounters, distress signals, and star map spawn zones) are now clamped to stay within region bounds with a 150-unit padding.

**Enhancement:** Added a fuzzy gradient edge effect at region boundaries. As the player approaches the edge of the map, a smooth quadratic dark gradient fades in, with a solid dark overlay beyond the boundary. This clearly communicates inaccessible areas. The existing pulsing blue glow for region transitions is preserved on top.

### Files Changed
- `scripts/ui/navigation.gd` — Added `_clamp_to_bounds()` helper, clamped POI positions in `_spawn_poi()` and `_update_distress()`, replaced thin boundary line with multi-strip gradient fade effect
- `scripts/systems/star_map_system.gd` — Clamped random spawn zone POI positions to region bounds

---

## 2026-03-20 — Dialogue Overlay Visibility

**Enhancement:** Added a semi-transparent dark backdrop behind dialogue encounters so the dialogue panel clearly stands out from the gameplay scene underneath. The backdrop fades in smoothly when the dialogue opens.

---

## 2026-03-19 — Arc Transition: Stats Summary + Hyperspace Jump

**Feature:** When a story arc completes, a full-screen stats summary and hyperspace jump animation play before entering the next sector.

1. **Arc Summary Screen** — Overlay showing completed arc title, next arc title + theme teaser, and 8 animated count-up stats: encounters completed, combat victories, crew recruited, missions completed, crystals, salvage, hull status, and playtime.

2. **Hyperspace Jump Shader** — Custom canvas_item shader with radial star streaks, blue-white tunnel intensification, flash-to-white, and fade-to-black. Driven by a single `progress` uniform (0→1) over ~2.5 seconds.

3. **Combat Victory Counter** — Added `combat_victories` field to `GameStateData` with full save/load persistence, incremented on each `combat_victory` signal.

4. **Flow:** Arc exit conditions met → `arc_advanced` signal → navigation pushes `arc_summary` overlay → player reads stats → presses "JUMP TO NEXT SECTOR" → stats fade out → hyperspace shader plays → `arc_transition_complete` signal → POIs refresh for new arc.

### New Files

- `scripts/ui/arc_summary.gd` — Stats screen + hyperspace jump controller
- `scenes/ui/arc_summary.tscn` — Scene layout with panel, stats container, continue button, hyperspace ColorRect
- `shaders/hyperspace_jump.gdshader` — Radial streak warp shader with 3-phase animation

### Modified Files

- `scripts/core/game_state_data.gd` — Added `combat_victories` field + persistence in `to_dict()`/`from_dict()`
- `scripts/autoload/game_session.gd` — Connected `combat_victory` signal, added `_on_combat_victory()` handler
- `scripts/autoload/event_bus.gd` — Added `arc_transition_complete(new_arc)` signal
- `scripts/ui/main.gd` — Registered `arc_summary` in SCENES dictionary
- `scripts/ui/navigation.gd` — Replaced flash message with `push_overlay("arc_summary")`, added `_on_arc_transition_complete()` to refresh POIs after jump

---

## 2026-03-19 — Crew recruitment encounters converted to dialogue_steps

**Feature:** All 8 crew member recruitment encounters now use two-sided branching dialogue.

1. **Cat crew encounters** - Nine Lives, No Tail, Silky, and Blood Paw recruitment conversations converted to dialogue_steps with Aristotle. Each crew member has distinct personality: Nine Lives (cocky), No Tail (gruff), Silky (enigmatic), Blood Paw (dedicated healer).

2. **Dog crew encounters** - Charlie, Bombardier, Luna, and Thistle recruitment conversations converted to dialogue_steps with Dave. Each crew member has distinct personality: Charlie (enthusiastic), Bombardier (sarcastic), Luna (calculating), Thistle (principled).

3. **Arc 1-2 story encounters** — Key Dave/Aristotle confrontations converted: arc1 face-to-face meeting and arc2 route seizure standoff.

4. **Arc 3 story encounters** — Dave/Aristotle parley (both perspectives), Death reveal on Aristotle's bridge, Death's offer to Dave in the Forgotten Realm.

5. **Arc 4 story encounters** — Dave's assault on crystal fields (Dave/Aristotle comms exchange before combat), Death's Vault bid (Aristotle/Death confrontation), Death's mid-battle betrayal (Dave/Death), and the climactic Dave/Aristotle showdown with three branching endings (surrender terms, shared governance, destruction).

6. **Portrait support** — Added 8 crew member portraits to CHARACTER_PORTRAITS registry including Nine Lives portrait.

### Changes

- `scripts/ui/dialogue_ui.gd` — Added crew member portrait paths
- `data/encounters/crew_nine_lives.json` — Converted to dialogue_steps
- `data/encounters/crew_no_tail.json` — Converted to dialogue_steps
- `data/encounters/crew_silky.json` — Converted to dialogue_steps
- `data/encounters/crew_blood_paw.json` — Converted to dialogue_steps
- `data/encounters/crew_charlie.json` — Converted to dialogue_steps
- `data/encounters/crew_bombardier.json` — Converted to dialogue_steps
- `data/encounters/crew_luna.json` — Converted to dialogue_steps
- `data/encounters/crew_thistle.json` — Converted to dialogue_steps
- `data/encounters/arc1_encounters_dave.json` — Dave/Aristotle meeting converted
- `data/encounters/arc2_encounters.json` — Route seizure confrontation converted
- `data/encounters/arc3_encounters.json` — Dave parley + Death reveal converted
- `data/encounters/arc3_encounters_dave.json` — Aristotle parley + Death offer converted
- `data/encounters/arc4_encounters.json` — Dave assault + Death bid converted
- `data/encounters/arc4_encounters_dave.json` — Death betrayal + Aristotle showdown converted

---

## 2026-03-19 — Two-sided branching dialogue system

**Feature:** Encounters can now have multi-step, two-sided conversations with branching outcomes.

1. **Dialogue steps format** — Encounters support an optional `dialogue_steps` array in JSON. Each step has a `speaker`, `text`, and optional `choices` with `next_step` branching. Steps can end peacefully (`"end": true`) or escalate to combat (`"start_combat": true`).

2. **Two-portrait UI** — Dialogue screen now shows Aristotle on the left and the NPC on the right. The active speaker's portrait is highlighted at full opacity while the other dims to 0.4 alpha.

3. **Step state machine** — The dialogue UI walks through steps sequentially, pausing for player choices and auto-advancing non-choice lines. Choices apply mid-dialogue outcomes (flags, resources, factions) and jump to branch targets via `step_id`.

4. **Backwards compatible** — Encounters without `dialogue_steps` use the original single-step flow unchanged.

5. **Proof-of-concept** — `enc_arc1_dave_trade` converted to a branching two-sided conversation with three paths: friendly trade, negotiation, and hostile escalation to combat.

### Changes

- `scripts/entities/encounter.gd` — added `DialogueStep`, `DialogueStepChoice` inner classes, `dialogue_steps` field
- `scripts/systems/encounter_engine.gd` — added `apply_dialogue_step_outcome()`, `complete_encounter()`
- `scripts/autoload/event_bus.gd` — added `dialogue_step_advanced` signal
- `scenes/ui/dialogue_ui.tscn` — restructured to left/right portrait layout
- `scripts/ui/dialogue_ui.gd` — added step state machine, two-portrait handling, speaker highlighting, branching flow
- `data/encounters/arc1_encounters.json` — converted Dave trade encounter to branching dialogue

---

## 2026-03-19 — Add ship purchasing and Pirate Destroyer to shipyard

**Feature:** Players can now buy new ships in the shipyard alongside repairs and upgrades.

1. **Pirate Destroyer template** — Added to `ship_templates.json` with `purchasable: true`, costing 80 crystals + 60 salvage. Stats: Spd 4, Arm 8, Fp 9, Hull 160, Cargo 5, Crew 8. Uses `ship_destroyer_r_side.png` sprite.

2. **Ship purchase logic** — Added `purchase_ship()` to `economy_system.gd`. Validates affordability, prevents re-buying current ship class, transfers crew and cargo to the new vessel, emits `EventBus.ship_purchased`.

3. **Data loader** — Added `load_purchasable_ships()` to `data_loader.gd` filtering templates with `purchasable == true`.

4. **Shipyard UI** — Left panel now shows current ship sprite preview and ship name/class. Right panel split into "Ships For Sale" (with thumbnails, stat summary, cost, buy button) and "Ship Upgrades". Buying a ship swaps your vessel and refreshes the entire UI.

### Changes

- `data/ships/ship_templates.json` — added Pirate Destroyer template with purchase cost fields
- `scripts/core/data_loader.gd` — added `load_purchasable_ships()`
- `scripts/systems/economy_system.gd` — added `purchase_ship()`
- `scripts/ui/purchase_screen.gd` — added ship preview, ship purchasing UI, ship list builder
- `scenes/ui/purchase_screen.tscn` — added ShipPreview, ShipNameLabel, ShipList nodes; restructured right panel

---

## 2026-03-19 — Implement ship upgrade shop in the shipyard screen

**Problem:** The shipyard (R key) only offered hull repair. Ship upgrades were fully defined in data (7 upgrades in `ship_templates.json`) and the `Ship.ShipUpgrade` entity class existed, but there was no way to browse, buy, or apply upgrades during gameplay. This made combat increasingly unwinnable as enemies scaled up.

**Solution:** Built the full upgrade purchase pipeline:

1. **Economy logic** — Added `purchase_upgrade()` and `_apply_stat_modifier()` to `economy_system.gd`. Handles cost deduction (crystals + salvage), stat application (including side effects like Siege Cannons: +2 firepower / -1 speed), duplicate prevention, and emits `EventBus.upgrade_purchased`.

2. **Shipyard UI overhaul** — Rebuilt `purchase_screen.gd` to show current ship stats, repair with dynamic cost display, and a scrollable list of all 7 upgrades. Each row shows the upgrade name, stat effect, cost (crystals + salvage), affordability colour coding, and a Buy button. Installed upgrades show as green "INSTALLED" labels.

3. **Scene layout** — Expanded `purchase_screen.tscn` panel to fit ship stats line, repair button, upgrades header, scrollable upgrade list, and close button.

### Changes

- `scripts/systems/economy_system.gd` — added `purchase_upgrade()` and `_apply_stat_modifier()` functions
- `scripts/ui/purchase_screen.gd` — full rewrite with upgrade list UI, dynamic repair cost, ship stats display
- `scenes/ui/purchase_screen.tscn` — expanded layout with `ShipStatsLabel`, `ScrollContainer`/`UpgradeList`, `UpgradesHeader`

---

## 2026-03-19 — Fix story arc progression, add repair access and arc progress HUD

**Problem:** Story arcs never advanced because `NarrativeSystem.check_arc_exit()` and `advance_arc()` were defined but never called after encounters. This meant the game stayed stuck in Arc 1 forever, making battles increasingly pointless. Additionally, the repair/purchase screen existed but had no keybind to access it, so players couldn't repair their ship during gameplay.

**Solution:** Three changes to make gameplay progression work:

1. **Wired arc progression** — After each encounter outcome is applied in `encounter_engine.gd`, the game now checks if the current arc's exit conditions are satisfied and automatically advances to the next arc. This loads new encounters, side missions, and updates music.

2. **Added repair screen access (R key)** — Added a `repair` input action bound to R and wired it in `navigation.gd` so players can open the purchase/repair screen at any time. Updated the controls bar hint text.

3. **Added arc progress feedback** — The HUD arc label now shows progress as "ARC TITLE (2/3)" indicating how many exit conditions have been met. When an arc advances, a 6-second flash notification announces the new arc.

### Changes

- `scripts/systems/encounter_engine.gd` — added `check_arc_exit()` + `advance_arc()` call after `apply_choice_outcome()`
- `scripts/ui/navigation.gd` — connected `arc_advanced` signal, added `_on_arc_advanced()` flash + POI refresh, added R key handler for purchase overlay, updated HUD to show arc progress count, updated controls bar hint
- `project.godot` — added `repair` input action mapped to R key

---

## 2026-03-19 — Improved ship orientation during navigation

**Problem:** The player ship used a single side-view sprite rotated 360 degrees, which looked unnatural at vertical angles.

**Solution:** Replaced free rotation with a banking + smooth flip + directional sprite blending system:
- 3-sprite flip transition: cross-fades through a 3/4 angle turning sprite (`ship_rotate.png`) during horizontal direction changes, blending from rotate sprite to side sprite with overlapping alpha curves
- Ease-out-quad curve on flip progress so the rotate midpoint transitions quickly
- Slight banking tilt (up to ~17 degrees) when moving vertically for momentum feel
- Cross-fades between side-view sprite (`ship_r_side.png`) and top-down sprite (`ship_up_side.png`) based on vertical movement dominance
- Engine glow and trail particles adapt to the new orientation system

### Changes
- `scripts/ui/navigation.gd` — replaced `_ship_angle` rotation system with `_facing_right` flip, `_bank_angle` tilt, `_vertical_blend` dual-sprite blending, and `_heading_angle` for trail/minimap; added `_draw_ship_perspective()` helper that renders the ship as a UV-mapped trapezoid for pseudo-3D turning; loaded and processed `ship_up_side.png` as second directional sprite; updated engine glow to blend between side-rear and heading-based offsets

---

## 2026-03-19 — Fix ESC-to-skip cutscene, navigation & combat music

**Bug 1:** ESC key did not skip the intro cutscene. The `skip` input action was mapped to keycode `4194306` (Tab) instead of `4194305` (Escape).

**Bug 2:** Navigation music never played. `on_state_change("navigation")` always resolved to the arc-specific theme (`"theme_arc1"`) which doesn't exist, instead of falling back to `"theme_navigation"`. Additionally, `_play_theme()` set `_current_theme` even when no file was found, poisoning subsequent calls.

**Bug 3:** Combat music never played. Combat starts via `replace_overlay()` which was missing the `MusicManager.on_state_change()` call that `push_overlay()` and `switch_scene()` both have.

### Changes
- `project.godot` — fixed `skip` input action keycode from `4194306` (Tab) to `4194305` (Escape)
- `scripts/autoload/music_manager.gd` — added `_theme_file_exists()` helper; `on_state_change()` and `on_arc_change()` now fall back to default themes when arc-specific files don't exist; `_play_theme()` now resolves the new stream before stopping the current track — if no file exists, current music keeps playing instead of going silent; lowered default music volume from -10 dB to -20 dB
- `scripts/ui/main.gd` — `replace_overlay()` now calls `MusicManager.on_state_change(scene_key)` and sets overlay meta key

---

## 2026-03-19 — Music volume control & playback continuity

**Features:**
- Volume control: settings slider now controls music volume (0–100% linear scale, mapped to dB)
- Music continuity: when switching themes (e.g., navigation → combat → navigation), tracks resume where they left off instead of restarting from the beginning
- Navigation music support: place `theme_navigation.ogg/.mp3` in `assets/audio/music/` and it plays during flight

### Changes
- `scripts/autoload/music_manager.gd` — added `set_music_volume()`, `set_sfx_volume()`, playback position save/restore in `_play_theme()`, default volume at -10 dB, wired `EventBus.volume_changed`
- `scripts/ui/settings_screen.gd` — slider initializes from current volume, toggles reflect current state, calls `MusicManager.set_music_volume()` directly

---

## 2026-03-19 — Fix overlay music (combat, trade, etc.)

**Bug:** `push_overlay()` in `main.gd` did not call `MusicManager.on_state_change()`, so combat music (and any other overlay-based screen music) never played.

### Changes
- `scripts/ui/main.gd` — `push_overlay()` now triggers `MusicManager.on_state_change(scene_key)` and saves the prior scene key; `pop_overlay()` restores the previous music when all overlays are cleared.

---

## 2026-03-18 — Crew Missions Feature

**Task:** Add crew recruitment missions — 4 named crew members per protagonist with story-driven recruitment and trait bonuses

### New Files

- `data/characters/crew_members.json` — 8 crew member definitions (4 per protagonist) with roles, traits, backstories
- `data/side_missions/crew_missions_aristotle.json` — 4 crew recruitment missions for Aristotle
- `data/side_missions/crew_missions_dave.json` — 4 crew recruitment missions for Dave
- `data/encounters/crew_nine_lives.json` — Nine Lives recruitment encounters (2 encounters)
- `data/encounters/crew_no_tail.json` — No Tail recruitment encounters (3 encounters)
- `data/encounters/crew_silky.json` — Silky recruitment encounters (2 encounters)
- `data/encounters/crew_blood_paw.json` — Blood Paw recruitment encounters (3 encounters)
- `data/encounters/crew_charlie.json` — Charlie recruitment encounters (2 encounters)
- `data/encounters/crew_bombardier.json` — Bombardier recruitment encounters (3 encounters)
- `data/encounters/crew_luna.json` — Luna recruitment encounters (2 encounters)
- `data/encounters/crew_thistle.json` — Thistle recruitment encounters (3 encounters)
- `scripts/systems/crew_trait_system.gd` — CrewTraitSystem: loads crew definitions, calculates active trait bonuses per ship
- `assets/characters/crew/.gdkeep` — Placeholder directory for crew portrait art

### Modified Files

- `scripts/entities/ship.gd` — Extended `CrewMember` with `trait_id`, `portrait`, `backstory`, `recruitment_status` fields + serialization
- `scripts/entities/side_mission.gd` — Added `crew_member_id` field + serialization
- `scripts/entities/encounter.gd` — Added `mission_type`, `crew_member_id` fields + deserialization
- `scripts/core/data_loader.gd` — Added `load_crew_members()`, `load_crew_missions()`, `load_crew_encounters()`
- `scripts/systems/side_mission_system.gd` — Added `load_crew_missions()` to append crew missions to templates
- `scripts/systems/combat_system.gd` — Applied `firepower_bonus` and `critical_hit_chance` crew trait bonuses to damage calculation
- `scripts/systems/crew_morale_system.gd` — Applied `morale_recovery` crew trait bonus to positive morale changes
- `scripts/systems/economy_system.gd` — Applied `hull_repair_rate` crew trait bonus to reduce repair costs
- `scripts/systems/encounter_engine.gd` — Applied `exploration_discovery_rate` and `ambush_detection` bonuses to encounter priority sorting
- `scripts/autoload/event_bus.gd` — Added `crew_member_recruited(crew_id, protagonist_id)` signal
- `scripts/autoload/game_session.gd` — Added `CrewTraitSystem` initialization, crew mission/encounter loading, recruitment listener, `recruit_crew_member()` helper
- `scripts/ui/dialogue_ui.gd` — Added crew recruitment detection (`_check_crew_recruitment`) and confirmation display (`_show_crew_recruitment_confirmation`)
- `scripts/ui/ship_screen.gd` — Enhanced crew roster with role labels, trait descriptions, morale colours, and empty role slots
- `scripts/ui/mission_log.gd` — Added "CREW MISSIONS" group header with crew/main/side sorting
- `scripts/ui/navigation.gd` — Added crew count indicator to HUD (`Crew: X/Y`)

### Updated Documentation

- `docs/plans/MASTER_PLAN.md` — Marked Crew Missions Feature as COMPLETE (2026-03-18) with full implementation summary

---

## 2026-03-17 — Character Selection Feature (ISSUE-001)

**Task:** Add dual-protagonist support — choose Aristotle or Dave at game start
**Model:** Opus 4.6

### Changes

- **GameStateData:** Added `protagonist_id` field with backward-compatible save/load
- **DataLoader:** Added `load_protagonists()`, suffix parameter on `load_encounters()` and `load_side_missions()` with fallback to shared files
- **GameSession:** Refactored `start_new_game(protagonist_id)` and `create_new_game_state()` to be data-driven from `protagonists.json` config
- **Character Select UI:** New scene (`character_select.tscn`) and controller (`character_select.gd`) with two-panel layout, portraits, stats, and select buttons
- **Menu:** "New Game" now routes to character selection screen
- **Cutscene:** Intro text loaded from protagonist config instead of hardcoded Aristotle lines
- **Faction systems:** Replaced hardcoded `"felid_corsairs"` references with dynamic `player_character.faction_id` in `faction_system.gd` and `faction_conquest_system.gd`
- **EventBus:** Added `protagonist_selected` signal
- **Ending screen:** Added protagonist-specific flavor text for Dave
- **Data files:** Created `protagonists.json`, Dave arc 1-4 encounters, Dave dialogue files, Dave side missions

---

## 2026-03-17 — Godogen Asset & Workflow Integration

**Task:** Integrate godogen Godot 4 development resources into Whisper Crystals
**Model:** Opus 4.6

### Phase 1: Documentation Structure

- Created `docs/godot-reference/` with 7 core reference documents:
  - `gdscript-reference.md` — Complete GDScript syntax, types, operators, patterns
  - `quirks-and-gotchas.md` — 18 known engine issues and runtime pitfalls
  - `best-practices.md` — Coding standards for Godot development
  - `scene-generation-patterns.md` — Scene builder patterns and ownership chains
  - `script-generation-patterns.md` — Runtime script templates
  - `scene-script-coordination.md` — Rules for scene/script interaction
  - `test-harness-patterns.md` — Testing approaches for Godot scenes
  - `screenshot-capture.md` — Screenshot and video capture workflow
- Copied 862 Godot API reference files to `docs/godot-reference/api/`
- Created workflow templates: `PLAN.md`, `ASSETS.md`, `MEMORY.md` at project root

### Phase 2: Local Tools

- Set up `tools/godot-dev/` with 4 tool categories:
  - `sprites/` — spritesheet_template.py, spritesheet_slice.py
  - `assets/` — rembg_matting.py (background removal with alpha matting)
  - `docs/` — godot_api_converter.py, class_list.py, ensure_doc_api.sh
  - `capture/` — gpu_detect.sh, screenshot.sh (with macOS support)

### Phase 3: Development Methodology

- Created `docs/development-methodology/` with 3 guides:
  - `task-decomposition.md` — Feature classification and task planning
  - `architecture-planning.md` — Scene hierarchy and script design
  - `iteration-strategy.md` — Progress-based stopping criteria
- Created `docs/qa/visual-qa-checklist.md` — Manual QA checklists from VQA prompts

### Phase 4: Testing Infrastructure

- Created `examples/godot-patterns/test-harness-example/` with working test template

### Phase 5: Project-Specific Adaptations

- Created `docs/GODOT_DEV_GUIDE.md` — Central reference linking all godogen assets
- Created quick reference cards in `docs/godot-reference/quick-refs/`:
  - `gdscript-cheat-sheet.md` — Type inference rules, common patterns
  - `common-nodes.md` — Node types by category with use cases
- Created working examples in `examples/godot-patterns/`:
  - `scene-builder-example/` — 2D scene builder with ownership chain
  - `runtime-script-example/` — Player controller with proper type annotations
  - `test-harness-example/` — Test with simulated input and assertions

### Excluded (API-Dependent)

- asset_gen.py (Gemini API), tripo3d.py (Tripo3D API), visual_qa.py (Gemini Vision)
- All SKILL.md files (Claude Code skill invocation system)

---

## 2026-03-03 — PLAN-003 (3.2, 3.4) Ship Sprite Integration

**Tasks:** Register new ship art, faction ship sprites in navigation, combat ship sprites
**Model:** Opus 4.6

### New Art Assets

- `design/ships/wolf_ship.png` — Wolf Clans strike craft
- `design/ships/fairy_ship.png` — Fairy Court vessel
- `design/ships/knight_ship.png` — Knight Order warship
- `design/ships/goblin_scrapper.png` — Goblin Syndicate scrapship

### Modified Files

- `engine/sprite_manager.py` — Registered 4 new ship sprites (wolf, fairy, knight, goblin) in
  SHIP_SPRITES registry. Only `alien_craft` remains as a placeholder.
- `__main__.py` — Creates SpriteManager and passes to GameSession.
- `core/session.py` — Accepts `sprite_manager` parameter, stores it, passes to CombatState.
- `ui/navigation.py` — Faction ship sprites rendered at combat POIs (with bobbing animation and
  cutlass sub-icon). Faction inferred from encounter data via `_infer_faction()`. Player ship
  loading refactored to use SpriteManager. Location-to-faction and faction-to-template mappings.
- `ui/combat_ui.py` — Ship sprites replace vector shapes when available. Player sprite (facing
  right) and enemy sprite (flipped left). Vector fallback preserved. Lazy-loaded via
  `_ensure_sprites_loaded()`.
- `systems/combat.py` — Added `ship_template_id` field to `CombatShip` dataclass. Populated
  in both `from_game_ship()` and `from_template()` factory methods.
- `tests/test_sprite_manager.py` — Updated tests: new assets have paths, only `alien_craft`
  is empty. Test count: 26.

### Test Results

- 281 tests, 100% pass rate
- EAL compliance verified (zero pygame imports in core/systems/entities)

---

## 2026-03-03 — Phase 4 (4.1, 4.1b, 4.3) + PLAN-003 (3.1)

**Tasks:** Music System, SFX System, Ending Summary Screen, Sprite Asset Manager
**Model:** Opus 4.6

### New Files

- `core/music_manager.py` — MusicManager with per-state theme mapping, arc-specific navigation
  themes, SFX event registry, enable/disable controls. Engine-agnostic (uses AudioInterface ABC).
- `engine/sprite_manager.py` — SpriteManager with centralised sprite loading, caching, scaling,
  faction-keyed ship/portrait/character registries, faction colour palettes. Lazy-load with
  graceful fallback to None (callers use vector shapes).
- `tests/test_music_manager.py` — 18 tests covering theme registry, state transitions, arc themes,
  overlay behaviour, SFX triggers, enable/disable, no-audio fallback.
- `tests/test_sprite_manager.py` — 25 tests covering registry completeness, lookup/caching,
  flip/scale, faction colour lookup, preload, cache clearing.
- `tests/test_ending_screen.py` — 18 tests covering ending calculation, summary builder
  (stats, factions, decisions, missions), input handling (scroll, confirm), text wrapping.
- `assets/audio/music/.gitkeep` — Directory for BGM track files
- `assets/audio/sfx/.gitkeep` — Directory for SFX files

### Modified Files

- `core/session.py` — Replaced raw audio event subscriptions with MusicManager. Added
  `music.on_state_change()` at all key transitions (menu, cutscene, navigation, dialogue,
  combat, trade, ending). Wired SFX events through music manager. Arc advancement updates
  navigation theme via `music.on_arc_change()`.
- `ui/ending_screen.py` — Full rewrite: scrollable decision summary with voyage statistics
  (duration, crystals, salvage, encounters, decisions, ship status), faction standings with
  reputation tags (Allied/Friendly/Neutral/Hostile/At War), side mission summary, decision
  history grouped by arc with positive/negative indicators. Arrow key scrolling. Fixed
  `.reputation` → `.reputation_with_player` bug.

### Bug Fixes

- Fixed `EndingState._calculate_ending()` using non-existent `.reputation` attribute on
  Faction entities (should be `.reputation_with_player`). Same fix in `_build_summary()`.

### Test Results

- All 280 tests pass (210 previous + 70 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-02 — PLAN-002: Side Missions & Distress Signals

**Task:** Entertainment Enhancements — Side Missions + Distress Signals (13 tasks)
**Model:** Opus 4.6

### New Files

- `systems/side_mission.py` — SideMissionSystem with mission lifecycle, objective tracking, reward
  application, and distress signal spawning (timer-based, weighted random)
- `data/side_missions/arc1_side_missions.json` — 4 side missions for Arc 1 (bounty, retrieval, escort, salvage)
- `data/side_missions/distress_signals.json` — 5 distress signal encounters with 3 choices each
  (help/exploit/ignore), repeatable, weighted spawn
- `ui/mission_log.py` — MissionLogState overlay (two-panel: mission list + detail with objectives/rewards)
- `tests/test_side_missions.py` — 24 tests covering entity serialization, data loading, system lifecycle,
  rewards, events, and GameStateData round-trip

### Modified Files

- `core/interfaces.py` — Added `MISSION_LOG` to `Action` enum
- `core/state_machine.py` — Added `MISSION_LOG` to `GameStateType` enum
- `core/data_loader.py` — Added `load_side_missions(arc_id)`, `load_distress_signals()`
- `core/game_state.py` — Added `side_missions: dict[str, SideMission]` field + to_dict/from_dict
- `core/session.py` — Wired SideMissionSystem, M key hotkey, `_open_mission_log()`,
  load on new game/load/arc transition
- `entities/encounter.py` — Added `spawn_weight: float` field
- `engine/input_handler.py` — Mapped `pygame.K_m` to `Action.MISSION_LOG`
- `ui/navigation.py` — Distress POI spawning, mission objective checking, distress_signal colour
- `ui/hud.py` — Active mission count indicator (amber text in top bar)

### Updated Documentation

- `docs/MASTER_PLAN.md` — Marked PLAN-002 complete, added PLAN-003 (Sprite Character & Visual Identity),
  updated metrics (210 tests, 10 systems, 14 UI states, 20 data files)

### Test Results

- All 210 tests pass (186 previous + 24 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-02 — Documentation Audit & Restructure

**Task:** Documentation consolidation and master plan creation
**Scope:** Full /docs reorganisation — no source code changes

### Documentation Structure

- Created `docs/MASTER_PLAN.md` — unified single source of truth for all planning and status
- Created `docs/architecture/` — moved all TRDs (TRD-001, TRD-002, TRD-003) here from `docs/trd/`
- Created `docs/architecture/decisions/` — moved ADR_TEMPLATE and ADR-001 here from `docs/decisions/`
- Created `docs/process/` — moved `CONTRIBUTING.md` here; updated all plan references to `MASTER_PLAN.md`
- Created `docs/archive/prds/` — archived PRD-001, PRD-002, PRD-003 with completion summaries
- Created `docs/archive/plans/` — archived PLAN-001 (superseded) and PLAN-002 (absorbed into MASTER_PLAN.md)
- Created `docs/archive/briefs/` — moved `suggestions.md` here

### Reviews

- Moved `CODE_REVIEW_2026-03-02.md` → `docs/reviews/REVIEW-002_code_review_2026-03-02.md`
- Moved `IMPLEMENTATION_PLAN_2026-03-02.md` → `docs/reviews/REVIEW-002_remediation_plan_2026-03-02.md`
- Updated `docs/reviews/REVIEW_LOG.md` with REVIEW-002 entry

### Removed

- `docs/trd/` — empty after TRD migration to `docs/architecture/`
- `docs/prd/` — empty after PRD archival
- `docs/decisions/` — empty after ADR migration to `docs/architecture/decisions/`
- `docs/plans/` — superseded by `docs/MASTER_PLAN.md`
- `docs/suggestions.md` — moved to `docs/archive/briefs/`

### Updated

- `README.md` — updated project structure, docs links point to new locations, added game status
- `docs/process/CONTRIBUTING.md` — updated all plan references to `MASTER_PLAN.md` and new path structure
- `docs/reviews/REVIEW_LOG.md` — added REVIEW-002 entry

---

## 2026-03-01 — Phase 2: Game Systems

**Tasks:** 2.1, 2.2, 2.3, 2.4, 2.5, 2.6 (PLAN-001)
**Model:** Opus 4.6

### Task 2.1 — Economy System

- Created `systems/economy.py` — crystal extraction, supply routes, market pricing, buy/sell trade
- Added `to_dict()` / `from_dict()` to `CrystalDeposit`, `SupplyRoute`, `CrystalMarket` entities
- Added economy fields to `GameStateData` (crystal_deposits, supply_routes, crystal_market, trade_ledger)
- Updated `GameStateData` serialization for full economy round-trip
- Created `data/economy/economy_data.json` — 6 crystal deposits, 5 supply routes, market config, trade goods
- Added `load_crystal_deposits()`, `load_supply_routes()`, `load_crystal_market()` to `DataLoader`
- Wired `EconomySystem` into `GameSession`
- Created `tests/test_economy.py` — 38 tests covering extraction, discovery, routes, trade, faction economics, serialization

### Task 2.2 — Trade UI

- Created `ui/trade_screen.py` — `TradeScreenState` overlay with buy/sell modes, quantity selection, price display
- Faction-aware pricing with reputation modifiers and trade margin (75% sell/buy ratio)
- Cargo capacity checks, faction reserve limits, trade ledger summary
- Added `open_trade_screen()` to `GameSession` for encounter/dialogue integration

### Task 2.3 — Exploration System

- Created `systems/exploration.py` — `ExplorationSystem` with `Region` and `PointOfInterest` dataclasses
- Region discovery, accessibility, and travel with connected-region validation
- POI discovery via scanning (probability-based), visitation with reward application
- Procedural exploration events with weighted random selection based on region danger
- Full serialization via `get_state_dict()` / `load_state_dict()`
- Created `data/economy/regions.json` — 7 regions with connections, 5 POIs with rewards
- Added `load_regions()`, `load_points_of_interest()` to `DataLoader`
- Created `tests/test_exploration.py` — 16 tests covering regions, travel, POIs, events, serialization

### Task 2.4 — Crew Morale System

- Created `systems/crew_morale.py` — `CrewMoraleSystem` tracking individual and average crew morale
- Morale thresholds: MUTINY (≤20), DISGRUNTLED (≤40), STEADY (≤60), CONTENT (≤80), INSPIRED (>80)
- Combat modifier (0.7x–1.2x) and trade modifier (0.9x–1.1x) based on morale
- Event-driven morale effects: combat victory/defeat, trade outcomes, idle decay
- Faction loyalty checks: crew from hostile factions suffer morale penalties
- Mutiny risk events published when morale drops below threshold
- Created `tests/test_crew_morale.py` — 16 tests covering queries, changes, combat modifiers, loyalty

### Task 2.5 — Faction Conquest AI

- Created `systems/faction_conquest.py` — `FactionConquestAI` with AI-driven faction-vs-faction warfare
- `ConquestAction` dataclass for attack, blockade, diplomacy, and fortify actions
- AI target selection weighted by negative relationships; action type by personality traits
- Resolution: attacks compare military + tactical vs military + stability; blockades reduce reserves
- Diplomacy improves inter-faction relations; fortify boosts military and stability
- Power rankings, threat queries, conflict history tracking
- Created `tests/test_faction_conquest.py` — 8 tests covering planning, all action types, rankings, serialization

### Task 2.6 — Realm Control

- Created `systems/realm_control.py` — `RealmControlSystem` with `RealmState` tracking per-region influence
- Influence-based control: faction with highest influence controls region
- Contested detection when second-place faction has >70% of leader's influence
- Natural drift: home realm influence grows, foreign influence decays
- Conflict result application: winner gains influence, loser loses
- Danger modifiers for contested regions
- Full serialization via `get_state_dict()` / `load_state_dict()`
- Created tests in `test_faction_conquest.py` — 9 tests covering initialization, influence, control changes, territories

### Test Results

- All 151 tests pass (99 previous + 52 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-01 — Phase 1: Core Infrastructure

**Tasks:** 1.1, 1.2, 1.3, 1.4 (PLAN-001)
**Model:** Opus 4.6

### Task 1.1 — Save/Load Manager

- Created `core/save_manager.py` — engine-agnostic save/load system with JSON persistence
- Supports 3 save slots with metadata (character name, arc, playtime, timestamp)
- Atomic writes via temp file + `os.replace()` to prevent corruption
- Created `tests/test_save_manager.py` — 12 tests covering round-trip, corruption, slots, deletion

### Task 1.2 — Wire Save/Load into UI

- Updated `core/session.py` — integrated SaveManager, settings, pause menu, and quit-to-menu flow
- Updated `ui/menu.py` — dynamic "Load Game" options based on available save slots
- Pause menu intercepts `Action.PAUSE` from navigation in `GameSession.tick()`
- Load game from menu or pause restores state and relaunches navigation

### Task 1.3 — Pause Menu

- Created `ui/pause_menu.py` — overlay state with Resume / Save / Load / Settings / Quit to Menu
- Quick save to current slot with visual feedback flash
- Follows overlay pattern (semi-transparent background, `machine.pop()` to resume)

### Task 1.4 — Settings Screen

- Created `ui/settings_screen.py` — overlay with music/SFX volume sliders and difficulty toggle
- Settings persisted to `~/.whisper_crystals/settings.json`
- `load_settings()` / `save_settings()` helpers with defaults merging
- Created `tests/test_settings.py` — 5 tests covering round-trip, defaults, corruption, directory creation

### Test Results

- All 61 tests pass (44 previous + 17 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-01 — Phase 0: Structural Refactor

**Tasks:** 0.1, 0.2, 0.3, 0.4, 0.5 (PLAN-001)
**Model:** Opus 4.6

### Task 0.1 — Extract GameSession from `__main__.py`

- Created `core/session.py` — engine-agnostic `GameSession` class with all callbacks, state transitions, and system orchestration
- Created `core/config.py` — game constants (screen size, FPS, splash duration)
- Created `engine/startup.py` — pygame-specific splash screen and loading frame rendering
- Created `engine/image_utils.py` — centralised pygame image loading and transformation
- Reduced `__main__.py` from 488 lines to 87 lines (pygame init, engine setup, thin main loop)

### Task 0.2 — Separate CombatState UI from combat logic

- Created `ui/combat_ui.py` — CombatState (GameState subclass) with all rendering and interaction
- Stripped `systems/combat.py` to pure logic only: CombatShip, CombatLog, calculate_damage, dodge_chance
- `systems/combat.py` now has zero imports from `core.interfaces` or `core.state_machine`

### Task 0.3 — Fix Engine Abstraction Layer violations

- Added `draw_image()`, `get_image_size()`, `measure_text()` to `RenderInterface` in `core/interfaces.py`
- Implemented all three in `engine/renderer.py` (PygameRenderer)
- Removed `import pygame` from `ui/menu.py`, `ui/navigation.py`, `ui/dialogue_ui.py`, `ui/cutscene.py`
- All UI files now use `RenderInterface` methods exclusively (draw_image, get_image_size, measure_text)
- **Verification:** zero pygame imports in `core/`, `systems/`, `entities/`, `ui/`

### Task 0.4 — Add missing GameStateTypes, remove dead code

- Added `FACTION_SCREEN`, `SHIP_SCREEN`, `SETTINGS` to `GameStateType` enum
- Updated `ui/faction_screen.py` to use `GameStateType.FACTION_SCREEN`
- Updated `ui/ship_screen.py` to use `GameStateType.SHIP_SCREEN`
- Deleted unused `core/game_loop.py`

### Task 0.5 — GameStateData serialization

- Added `to_dict()` / `from_dict()` to `PlayerDecision` and `GameStateData`
- Fixed `Faction.from_dict()` to accept both `reputation_with_player` and `starting_reputation` keys
- Created `tests/test_game_state_serialization.py` — 5 tests covering fresh/modified round-trip, JSON serialization, faction and NPC registry persistence

### Test Results

- All 44 tests pass (27 original + 17 new/modified)
- All tests run headless without pygame display context

---

## 2026-03-01 — Step 1: Project Management Structure

**Task:** Step 1 (PLAN-001)
**Model:** Opus 4.6 (planning), Haiku (execution)

### Added

- `CLAUDE.md` — Project-level AI agent instructions with architecture rules and conventions
- `docs/CONTRIBUTING.md` — Task workflow guide for AI agents and developers
- `docs/plans/PLAN-001_Implementation_Master_Plan.md` — Full implementation plan (31 tasks across 6 phases)
- `docs/plans/PLAN-001_Task_Tracker.md` — Checkbox-based progress tracker for all tasks
- `docs/reviews/REVIEW_TEMPLATE.md` — Code review template with EAL compliance checklist
- `docs/reviews/REVIEW_LOG.md` — Master review log
- `docs/issues/ISSUE_TEMPLATE.md` — Issue reporting template
- `docs/issues/ISSUE_LOG.md` — Master issue index
- `docs/decisions/ADR_TEMPLATE.md` — Architecture Decision Record template
- `docs/decisions/ADR-001_Project_Structure_Refactor.md` — First ADR documenting the refactor rationale
- `docs/changelog/CHANGELOG.md` — This file

### Directory Structure

- Created archive directories for: plans, reviews, issues, decisions, PRDs, TRDs, design, story
- Created issue tracking directories: open, in-progress, closed
