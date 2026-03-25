# Feature: Star Base Interactivity & Hub System

## Overview
Star Bases are the primary celestial hubs in *Whisper Crystals*. They serve as neutral or faction-aligned sanctuaries where Captains (Aristotle or Dave) can manage their crew, repair their vessels, and progress through narrative arcs. These bases act as the mechanical "save points" and economic engines of the multiverse.

## Gameplay Mechanics

### 1. Docking & Services
* **Refuel & Resupply:** The primary locations to replenish Whisper Crystals and ship vitals (food, ammo, oxygen).
* **Distress Salvage:** A dedicated "Drop-off Zone" for rescued passengers found during exploration, providing rewards (Gold/Reputation) upon successful delivery.
* **The Artifact Market:** Exclusive shops that sell gameplay-altering items required for specific story arcs (e.g., a "Void Compass" for Arc 4).

### 2. Base Variants & Visibility
* **Open Ports:** Naturally occurring bases visible on the HUD/Mini-map, accessible to all.
* **Hidden Outposts:** Bases obscured within "Storm Clouds" or nebulae. Players must use scanners or follow specific navigation cues to locate these pirate coves or secret military installations.
* **Protected Strongholds:** Faction-locked bases (Dog Soldier or Cat Pirate aligned) that require a specific reputation level or "Letter of Marque" to dock safely without being fired upon.

### 3. Narrative Integration
* **Branching Hubs:** Certain bases will change their layout, available NPCs, or hostility based on the player’s choices across the 10 story arcs.
* **Crew Recruitment:** The primary location to meet and hire new crew members from the various races (Goblins, Fairies, Knights, etc.).

## Technical Requirements (Godot 2D)
* **Docking State:** Implementation of a `docked` state for the player ship, disabling combat physics and enabling the UI-based station menu.
* **Parallax Layers:** Integration of Star Base assets into the background/mid-ground layers of the 2D side-scrolling environment.
* **Proximity Triggers:** Area2D nodes to handle docking requests and "Hidden" status logic within storm cloud tiles.

## Success Criteria
* Player can successfully dock and transition from ship flight to the Station UI.
* "Passenger" count resets to zero upon docking, awarding the player the appropriate currency.
* Hidden bases remain invisible on the map until the player enters a specific radius within a storm cloud.

## A quick suggestion for the Godot implementation

Since this is a 2D side-scroller, you might want to consider making the docking process a "transition" into a zoomed-in interior view or a stylized UI overlay. This keeps the scale feeling massive without requiring you to build 1:1 scale interiors for every base.

# Artifact Catalog: Star Base Exclusives

### 1. The Aeolian Tuning Fork
* **Arc Utility:** Essential for navigating the "Shattered Soundscape" arc.
* **Gameplay Effect:** When equipped, it emits a visual pulse in 2D space that reveals hidden paths within Storm Clouds. 
* **Lore:** A silver tool used by ancient Goblins to "play" the wind currents of the multiverse.

### 2. Bottled Solar Flare
* **Arc Utility:** Required to survive the "Deep Dark" or Frozen Realm arcs.
* **Gameplay Effect:** Acts as a temporary light radius and heat source. In combat, it can be "shattered" to create a massive flash-blind effect, allowing for a quick escape from Dog Soldier patrols.
* **Lore:** Literally a piece of a dying sun corked inside a Whisper Crystal vial.

### 3. Chrono-Compass (The "Wait-a-Minute" Dial)
* **Arc Utility:** Facilitates branching narrative choices by allowing a "vision" of a choice's outcome.
* **Gameplay Effect:** Allows the player to "rewind" the last 5 seconds of ship movement or combat once per docking cycle. Perfect for undoing a disastrous collision with an asteroid.
* **Lore:** A finicky device favored by Aristotle for those "purr-fect" escapes.

### 4. Midas’s Grapnel
* **Arc Utility:** Used in mid-game arcs to scavenge derelict knight-ships.
* **Gameplay Effect:** Replaces the standard harpoon. It can latch onto larger debris or enemy ships to pull the player toward them (or vice versa), adding a physics-based "grapple" mechanic to the side-scrolling combat.
* **Lore:** An enchanted golden claw that never loses its grip on "treasure," whether that treasure wants to be caught or not.

### 5. Fairy Dust Scrubber
* **Arc Utility:** Necessary for the "Diplomatic" arcs involving the Fae Courts.
* **Gameplay Effect:** Passive ship upgrade. Reduces the "detection radius" of hostile factions by 30% and allows the ship to pass through magical barriers that would otherwise repel metal hulls.
* **Lore:** A series of bellows and brushes that constantly coats the ship in a thin, shimmering layer of invisibility.