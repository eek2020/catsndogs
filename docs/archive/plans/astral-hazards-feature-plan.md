# Astral Hazards & Celestial Phenomena — Implementation Plan — COMPLETE (2026-04-05)

**Status:** COMPLETE
**Completed:** 2026-04-05

**What was delivered:** `AstralHazardSystem` (`scripts/systems/astral_hazard_system.gd`), static and dynamic hazard types, crew trait mitigation, hull damage, status effects (crystal_drain, hull_weakness), 5 EventBus signals, full serialization. Data files: `data/hazards/astral_hazards.json`, `data/hazards/static_hazards.json`. Navigation UI integration with hazard collision detection and visual indicators.

**Known issues (from CODE_REVIEW_2026-04-05):** `apply_damage()` does not emit game-over when hull reaches 0 (must-fix).

## Source

`docs/archive/features/FEATURE_astral_hazards.md`

## Overview

Dynamic environmental hazards during space flight that challenge crew composition and navigation skills. Two categories: **static** (pre-placed, fog-hidden) and **dynamic** (entropy-timer spawned). Crew traits determine mitigation; failure deals hull damage and/or temporary status effects.

---

## Phase 1: Data Layer

### 1A. `data/hazards/astral_hazards.json`

Hazard type definitions. Each entry contains:

- **hazard_id** — unique key (`solar_flare`, `asteroid_field`, `mana_void`, `singularity`)
- **display_name** — human-readable name
- **description** — flavour text
- **category** — `dynamic` or `static`
- **visual_type** — rendering hint (`light_burst`, `debris`, `nebula`, `distortion`)
- **visual_color** — hex color for draw calls
- **zone_radius** — world-unit radius of the hazard area
- **damage_min_pct / damage_max_pct** — % of `max_hull` (0.0–0.20)
- **mitigation_trait** — crew trait bonus key that mitigates (e.g. `hazard_shielding`, `hazard_piloting`, `hazard_magic`, `hazard_veteran`)
- **mitigation_threshold** — minimum trait bonus to fully negate (e.g. 0.10)
- **status_effect** — optional dict `{effect_id, duration_seconds, description}` (e.g. `fog_blind` jams fog for 60s)
- **dialogue_barks** — dict keyed by protagonist_id with short crew reaction strings
- **entropy_weight** — spawn weighting for the dynamic spawner (higher = more common)

### 1B. `data/hazards/static_hazards.json`

Per-region static hazard placements:

```json
{
  "region_id": [
    {"hazard_id": "singularity", "x": 1200, "y": 3400, "zone_radius": 250}
  ]
}
```

These are hidden behind fog of war — revealed when the player explores nearby.

### 1C. Crew trait additions (`data/characters/crew_members.json`)

Add hazard-mitigation trait bonuses to relevant crew members:

| Crew Member | New Bonus Key | Value | Rationale |
|---|---|---|---|
| Nine Lives (Aristotle) | `hazard_piloting` | 0.12 | Evasion skills |
| Silky (Aristotle) | `hazard_magic` | 0.10 | Fairy-realm navigator |
| Blood Paw (Aristotle) | `hazard_veteran` | 0.08 | Experienced field surgeon |
| No Tail (Aristotle) | `hazard_shielding` | 0.08 | Battle-hardened defender |
| Charlie (Dave) | `hazard_veteran` | 0.10 | Academy training |
| Luna (Dave) | `hazard_piloting` | 0.12 | Star-reading navigator |
| Bombardier (Dave) | `hazard_shielding` | 0.10 | Demolitions knowledge |
| Thistle (Dave) | `hazard_magic` | 0.08 | Knight herbalism/arcane |

---

## Phase 2: System Layer

### 2A. `scripts/systems/astral_hazard_system.gd`

New `AstralHazardSystem` class (`RefCounted`):

**State:**

- `hazard_definitions: Dictionary` — loaded from JSON
- `static_hazards: Dictionary` — region_id → Array of placed hazard dicts
- `active_dynamic_hazards: Dictionary` — region_id → Array of spawned hazard dicts (with `{hazard_id, x, y, zone_radius, age}`)
- `entropy_timer: float` — countdown until next dynamic spawn (900–1200s = 15–20min)
- `status_effects: Array` — active effects `[{effect_id, remaining_seconds, hazard_id}]`
- `hazard_cooldown: float` — time since last hazard hit (prevents rapid re-triggering)

**Methods:**

- `load_definitions(data: Dictionary)` — parse astral_hazards.json
- `load_static_hazards(data: Dictionary)` — parse static_hazards.json
- `update(region_id, dt, game_state)` — tick entropy timer, age dynamic hazards, tick status effects
- `spawn_dynamic_hazard(region_id)` — weighted random pick, random position in region, add to active list
- `get_visible_hazards(region_id) → Array` — return static + dynamic hazards in revealed fog
- `check_ship_collision(region_id, ship_x, ship_y) → Dictionary or null` — returns hazard dict if ship is inside a zone
- `resolve_hazard(hazard_def, ship, game_state) → Dictionary` — crew check → damage/status calc → return `{mitigated, damage, status_effect, bark}`
- `apply_damage(game_state, damage)` — reduce `player_ship.current_hull`
- `apply_status_effect(effect)` — push onto active effects, emit signal
- `tick_status_effects(dt)` — decrement timers, remove expired, emit signal
- `has_active_effect(effect_id) → bool` — query (e.g. navigation checks `fog_blind`)
- `remove_dynamic_hazard(region_id, index)` — after player passes through
- `to_dict() / load_from_dict()` — serialization

**Entropy timer logic:**

- Starts at `randf_range(900.0, 1200.0)` (15–20 min)
- On expiry: spawn one dynamic hazard in current region, reset timer
- After hazard collision: cooldown of 120s before another can trigger

### 2B. Status effects

| Effect ID | Duration | Gameplay Impact |
|---|---|---|
| `fog_blind` | 60s | Re-covers nearby fog cells, halves vision radius |
| `crystal_drain` | 30s | Drains 1 crystal per 10s |
| `off_course` | 15s | Random directional drift added to movement |
| `hull_weakness` | 45s | Next hazard damage +50% |

---

## Phase 3: Integration Layer

### 3A. EventBus signals

```gdscript
# --- Astral hazard events ---
signal hazard_entered(hazard_id: String, hazard_type: String)
signal hazard_mitigated(hazard_id: String, crew_id: String)
signal hazard_damage(hazard_id: String, damage: int)
signal hazard_status_applied(effect_id: String, duration: float)
signal hazard_status_expired(effect_id: String)
```

### 3B. GameStateData additions

```gdscript
@export var active_status_effects: Array = []   # Array of {effect_id, remaining, hazard_id}
@export var astral_hazard_data: Dictionary = {}  # serialized AstralHazardSystem state
```

Plus `to_dict` / `from_dict` round-trip.

### 3C. DataLoader additions

```gdscript
func load_astral_hazards() -> Dictionary
func load_static_hazards() -> Dictionary
```

### 3D. GameSession integration

- `_ready()` — create `AstralHazardSystem`, load definitions
- `start_new_game()` — `astral_hazard_system.load_static_hazards(...)`, init entropy timer
- `load_game()` — restore from `game_state.astral_hazard_data`
- `save_game()` — persist `game_state.astral_hazard_data = astral_hazard_system.to_dict()`; persist `game_state.active_status_effects`

---

## Phase 4: UI / Navigation Layer

### 4A. navigation.gd changes

**New state:**

- `_visible_hazards: Array` — cached from `astral_hazard_system.get_visible_hazards()`
- `_hazard_collision_cooldown: float` — prevent rapid re-entry

**In `_process(dt)`:**

- Call `astral_hazard_system.update(region_id, dt, game_state)` (alongside existing `_update_star_map_spawns`)
- Refresh `_visible_hazards`
- Check ship-hazard collisions → resolve → flash message + damage + status
- If `fog_blind` active: temporarily increase fog opacity / reduce vision radius

**Drawing:**

- `_draw_hazards(center, gs)` — per hazard type:
  - **Solar Flare**: pulsing yellow/white glow, radiating lines
  - **Asteroid Field**: scattered small circles (grey/brown), jittering
  - **Mana Void**: shimmering purple nebula cloud (overlapping circles with alpha)
  - **Singularity**: dark core with swirling distortion rings
- Hazard zone ring (warning) at `zone_radius`
- On minimap: hazard blips in red/orange

**HUD:**

- Status effect indicators below hull bar (icon + timer countdown)
- Flash messages: `"SOLAR FLARE! Silky's magic shields the crew!"` or `"ASTEROID FIELD! Hull damage: -12"`

### 4B. Fog blind effect

When `fog_blind` is active:
- `star_map_system.reveal_around()` uses `VISION_RADIUS * 0.5`
- Fog drawing alpha increases temporarily

---

## Phase 5: Narrative Integration

Dialogue barks are data-driven from `astral_hazards.json`:

- **Mitigated**: `"Silky channels the fairy wards — the solar storm parts around the hull."`
- **Failed**: `"The flare slams into the hull. Aristotle curses at the repair costs."`
- Each hazard has `dialogue_barks.aristotle.mitigated`, `dialogue_barks.aristotle.failed`, same for `dave`

---

## Files Changed Summary

### New Files

| File | Description |
|---|---|
| `data/hazards/astral_hazards.json` | Hazard type definitions |
| `data/hazards/static_hazards.json` | Per-region static hazard placements |
| `scripts/systems/astral_hazard_system.gd` | Core hazard system |
| `docs/plans/astral-hazards-feature-plan.md` | This plan |

### Modified Files

| File | Changes |
|---|---|
| `scripts/autoload/event_bus.gd` | 5 new hazard signals |
| `scripts/core/game_state_data.gd` | `active_status_effects`, `astral_hazard_data` fields + serialization |
| `scripts/core/data_loader.gd` | `load_astral_hazards()`, `load_static_hazards()` |
| `scripts/autoload/game_session.gd` | AstralHazardSystem lifecycle (init, new game, load, save) |
| `scripts/ui/navigation.gd` | Hazard drawing, collision, status HUD, fog_blind effect |
| `data/characters/crew_members.json` | Hazard mitigation trait bonuses on all 8 crew |

---

## Implementation Order

1. Data files (hazards JSON + crew trait updates)
2. `AstralHazardSystem` class
3. EventBus + GameStateData + DataLoader
4. GameSession wiring
5. navigation.gd visuals + collision + status HUD
6. Testing & tuning
