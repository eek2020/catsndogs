> **Status:** ARCHIVED — IMPLEMENTED with modifications. The skill allocation screen (`scripts/ui/skill_allocation.gd` + `scenes/ui/skill_allocation.tscn`) allows redistribution of starting stat points with preset archetypes. `StatEvaluator` (`scripts/systems/stat_evaluator.gd`) handles skill checks. Resonance Shards implemented as collectibles in `data/items/resonance_shards.json`. The "Harmonic Attunement" branding was not used; the system is functional without the thematic wrapper.

# Feature Request: Initial Skill Allocation

## Overview
Implement a "Harmonic Attunement" system at the start of a new game that allows players to redistribute their character’s starting Skill Points across core attributes. This ensures that whether playing as Aristotle or Dave, the player can lean into a specific playstyle (e.g., more tactical ship combat vs. higher narrative/faction influence) from the first arc.

## Conceptual Branding
**"The Whisper's Resonance"**
As the Captain bonds with their ship’s core Whisper Crystal, the player "tunes" their natural aptitude.
* **Skill Points (SP):** The fundamental measure of a Captain's proficiency.
* **Resonance Shards:** Power-up items found in the world used to increase the total SP pool mid-game.

## Functional Requirements
1.  **Variable Starting Distribution:**
    * Players begin with a fixed pool of **Initial XP**.
    * Using a slider or +/- interface, players can distribute this XP across skill categories (e.g., *Navigation, Combat, Diplomacy, Engineering*).
    * The total percentage must always equal 100% of the starting pool.
2.  **Character Archetypes:** * Provide a "Quick Start" preset for Aristotle (Cat Pirate) and Dave (Dog Soldier) that reflects their lore-accurate strengths, while still allowing for full customization.
3.  **Growth Hook:** * Create a hook for "Resonance Shard" items. When collected in-game, these trigger a "Level Up" UI where players can add new points to these same categories.
4.  **Dynamic Arc Variations (The "Butterfly Effect"):**
    * **Dialogue/Choice Locking:** Certain narrative paths in the 10 arcs should be gated or unlocked based on the player’s highest percentage type (e.g., a "Cunning" Aristotle can talk his way out of a goblin blockade that a "Combat" Aristotle must fight through).
    * **Environmental Interaction:** High "Arcane" percentage might allow players to detect Whisper Crystal echoes earlier in a mission, changing the "Discovery" phase of the arc.
5.  **Gameplay Scaling:**
    * Ship performance and character abilities must scale mathematically based on these percentages, creating a unique "feel" for each run.
6.  **Mid-Game Progression:** * "Resonance Shards" (Power-ups) found in-game allow the player to increase the total pool, potentially shifting their "dominant" type and altering the trajectory of future story arcs.

## Technical Implementation Notes (Godot)
* **Weighted Flags:** Create a `StatEvaluator` singleton that checks if a specific skill percentage exceeds a threshold (e.g., `if stats.cunning_percent > 40: unlock_bribery_option()`).
* **Arc Branching:** Use the `Resource` system to swap out `DialogueResource` files or `Encounter` scenes based on the player's primary "Attunement."
* **Visual Feedback:** The UI should clearly indicate when a player's skill allocation has triggered a specific story variation so the player feels the weight of their initial choices.

## Lore Integration
The "Whisper Crystals" don't just fuel ships; they react to the intent of the Captain. A Captain focused on war (High Combat) causes the ship's crystal to glow a jagged crimson, prompting different reactions from NPCs than a Captain focused on trade (High Diplomacy).

## UI/UX Suggestions
* **The Hex-Grid:** A spider/radar chart showing the character's balance. As players shift points from 'Combat' to 'Diplomacy', the shape of the web shifts dynamically.
* **Theme:** Use a "Crystal Pulse" aesthetic in the UI—glow effects that change color based on the dominant skill type.

## Technical Implementation Notes (Godot)
* **Data Structure:** Use a `Resource` script (`CharacterStats.gd`) to store the integer values for each skill.
* **Signal Bus:** Emit a `stats_changed` signal whenever a Resonance Shard is consumed to update ship performance or dialogue options globally.
* **Scalability:** Ensure the system can handle the addition of new skill types if the 10-arc story introduces new mechanics (e.g., Realm-specific skills).