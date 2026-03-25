# Feature Request: Astral Hazards & Celestial Phenomena

## 1. Overview
Introduce **Astral Events**—dynamic, environmental hazards that populate the multiverse. These events act as "terrain" or "encounters" during space flight, challenging the player’s crew composition and navigation skills. They bridge the gap between static exploration and active survival.

## 2. Feature Mechanics

### A. Discovery & Spawning
* **Static Hazards:** Pre-placed objects (Black Holes, Supernovae) hidden within the **Fog of War**. Players can detect these via ship sensors or scouting, allowing for tactical rerouting.
* **Dynamic Hazards:** Randomly spawned events (Solar Flares, Asteroid Showers) that appear based on a weighted "Entropy" timer to ensure they do not occur too frequently.
* **Frequency:** To prevent gameplay fatigue, dynamic spawns should follow a cooldown period (e.g., once every 15–20 minutes of flight time).

### B. The Crew Interaction (The "Save" Mechanic)
The impact of an event is determined by the player's current crew. 
* **Avoidance:** Specific crew archetypes (e.g., a Goblin Navigator for Asteroids or a Fairy Arcanist for Solar Storms) can trigger an "Evasion" or "Shielding" event.
* **Mitigation:** If the correct crew member is present, damage is nullified or significantly reduced. If absent, the ship takes a hit.

### C. Damage & Penalties
* **Variable Scaling:** Damage is RNG-weighted between **0% and 20%** of total hull integrity.
* **Status Effects:** Beyond hull damage, certain events could cause temporary debuffs (e.g., a Solar Flare jamming the radar/Fog of War for 60 seconds).

## 3. Astral Event Types (Examples)
| Event | Visual Element | Required Crew/Trait | Result of Failure |
| :--- | :--- | :--- | :--- |
| **Solar Flare** | High-intensity light burst | Knight/Paladin (Shielding) | Hull Damage + Blindness |
| **Asteroid Field**| Physics-based debris | Cat/Goblin (Piloting) | Chip damage (1-5% per hit) |
| **Mana Void** | Shimmering purple nebula | Fairy/Mage (Magic) | Drains Whisper Crystal Fuel |
| **Singularity** | Gravitational distortion | Any "Veteran" Specialist | Pulls ship off-course / 20% Damage |

## 4. Technical Implementation Notes (Godot)
* **Node Structure:** Use a `HazardArea` (Area2D) for static hazards and a `HazardSpawner` (Timer/Randomizer) for dynamic events.
* **Signal Bus:** When a ship enters a hazard zone, emit a signal `_on_hazard_entered(type)`. The `CrewManager` checks for the required IDs and returns a `success` or `fail` boolean to the `HealthComponent`.
* **Visuals:** Utilize Godot's `GPUParticles2D` for solar storms and `CanvasModulate` to simulate the darkening effect of a Black Hole or Fog of War.

## 5. Narrative Integration
Astral events should feel like the "Whispers" of the multiverse. Aristotle might see a Solar Storm as a nuisance to his profit margins, while Dave might view it as a tactical hurdle to overcome for the mission. Short dialogue barks from crew members when an event is avoided will reinforce the narrative-driven nature of the game.