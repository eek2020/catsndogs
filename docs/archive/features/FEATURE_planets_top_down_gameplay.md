> **Status:** ARCHIVED — SUPERSEDED. Core concept implemented as the 2D World Gameplay Layer (2026-03-25). See `docs/plans/2d_world_gameplay_layer.md` (COMPLETE). Implemented scenes: `fringe_haven_outpost.tscn`, `planet_surface.tscn`, `tavern.tscn`. Scripts: `player_controller.gd`, `npc_controller.gd`, `dialogue_manager.gd`, `scene_transition.gd`. Some proposed elements (siege/conquest, treasure hunting tools) remain unimplemented.

# Celestial Exploration & Planetary Interaction

## 1. Feature Overview
Introduce a dedicated **Top-Down Exploration Mode** for planets within the *Whisper Crystals* multiverse. When a player lands their ship, the game transitions from 2D side-scrolling space flight to a 2D top-down perspective (Zelda-style), allowing for deep interaction with NPCs, environments, and faction-based activities.

## 2. Core Mechanics: The "Landing" Loop
* **Charted vs. Uncharted:**
    * **Charted Planets:** Known settlements with established merchants, factions (Cats/Dogs/Fairies), and persistent quest hubs.
    * **Uncharted Planets:** Procedurally generated or hand-crafted "Wilderness" zones containing hidden treasures, rare crew recruits, and hostile goblins or alien fauna.
* **Top-Down Interaction System:** * **Movement:** 4-way or 8-way directional movement.
    * **Combat/Interaction:** Melee/ranged weapon use for clearing planetary threats or sieging towns.
    * **Social:** Dialogue system for story-critical NPCs and recruitable crew members.

## 3. Key Activities & Features
| Activity | Description |
| :--- | :--- |
| **Merchant Trading** | Unique planet-specific economies. Buy Whisper Crystals low, sell high elsewhere. |
| **Crew Enlistment** | Find NPCs in taverns or wilderness. Their stats influence your ship’s performance back in the side-scrolling layer. |
| **Treasure Hunting** | Use "Whisper Resonance" tools to find buried loot, ship upgrades, or lore collectibles. |
| **Siege & Conquest** | Hostile towns can be raided. Victory provides a massive reputation boost (or penalty) and rare resources. |
| **Reputation System** | Interactions (helping a goblin vs. robbing a knight) dynamically update faction standing, influencing future story arcs. |

## 4. Visual & Technical Implementation (Godot Integration)
* **Perspective Shift:** Use a separate `Node2D` or `SubViewport` for planetary exploration. 
* **Asset Style:** Pixel art consistent with the 2D side-scrolling ship scenes, but utilizing a top-down TileMap.
* **State Persistence:** Planets should track "Cleared" status for treasures and "Aggro" status for town sieges.

## 5. Narrative Alignment
This feature serves as the primary vehicle for the **10-Arc Story**. 
* **Aristotle (Cat Pirate):** Uses planetary landings for illicit smuggling and building a pirate network.
* **Dave (Dog Soldier):** Uses planetary landings for diplomatic missions, peacekeeping, and securing fuel lines for the military.