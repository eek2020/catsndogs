# Whisper Crystals — Agent Briefing Document

> **Purpose:** This document is a complete briefing for an AI agent tasked with building *Whisper Crystals*. It contains everything needed: story, lore, characters, factions, ships, gameplay mechanics, side missions, art direction, asset descriptions, and technical architecture. Read this in full before beginning any development work.
>
> **Status Note (2026-04-05):** This briefing describes the implemented 4-arc game with 3 endings. A 10-arc expansion (Arcs 5-10, 4th ending, 6 new regions) is planned in `docs/GAME_SUMMARY.md` — encounter data exists in JSON but is not integration-tested. The **Dual Protagonist System** is fully implemented: players choose Aristotle (cat) or Dave (dog) at game start, with fully separate narrative paths, encounters, dialogue, and side missions for each.

---

## 1. Project Overview

**Title:** Whisper Crystals — A Space Pirates Game
**Genre:** Narrative-driven 2D side-scrolling space pirate game
**Engine:** Godot 4.6 (GL Compatibility renderer)
**Language:** GDScript
**Resolution:** 1280×720, canvas_items stretch mode
**Platform:** Desktop (Mac M3/M4 primary, Windows compatible)
**Inspiration:** Spelljammer (D&D setting) — serious stakes with a fun, accessible cast of anthropomorphic animals

**Elevator Pitch:** You are Aristotle (or Dave), a captain who controls — or seeks to control — the multiverse's only source of starship fuel — Whisper Crystals. Every faction in every realm wants what you have. Navigate four story arcs of escalating conflict, diplomacy, betrayal, and choice. Your decisions accumulate toward one of three endings that determine the fate of the multiverse.

---

## 2. The World — The Multiverse

The game is set across a Spelljammer-style multiverse of interconnected realms, each with distinct cultures, factions, and aesthetics. Starships travel between realms using Whisper Crystals as fuel — making whoever controls the crystals the most powerful entity in existence.

### Regions

| Region | Atmosphere | Colour Temperature | Description |
| -------- | ----------- | ------------------- | ------------- |
| Starting Realm (Forgotten Realm) | Warm, discovery | Amber/gold | Where Aristotle found the first crystal deposits. Ancient, mostly unmapped. |
| Trade Hubs | Busy, cosmopolitan | Bright multi-colour | Cross-faction commerce zones. Neutral ground. |
| Canis Territory | Cold, military | Cool blue/grey | Heavily patrolled. League blockades. |
| Lion Territory | Opulent, political | Golden/ivory | Noble courts, tribute demands, political intrigue. |
| Fairy Realms | Mystical, fluid | Iridescent blue-green | Information brokers, magical traders. |
| Deep Space | Dark, mysterious | Dark, sparse | Alien contact zones. Unknown threats. |

### Whisper Crystals

The central MacGuffin and economic engine of the entire game.

- **Raw form:** Translucent blue-white mineral deposits found in certain forgotten realms
- **Refined form:** Glowing crystalline fuel rods that power starship engines
- **Visual:** Emit a soft, pulsing glow — blue-white core fading to purple at the edges. "Whisper" effect: subtle particle trails resembling sound waves. Refined crystals glow brighter than raw deposits.
- **Gameplay role:** Currency, trade commodity, ship fuel, upgrade cost, and the source of all political conflict
- **Lore:** Only the Felid Corsairs know the refining process. This knowledge is Aristotle's true power.

---

## 3. Story — The Four Arcs

### Arc 1 — The Upstart (Origin)

**Theme:** How did a street cat become the most powerful figure in the multiverse?

**Summary:** Aristotle discovers Whisper Crystals in a forgotten realm, teaches himself to refine them through sheer ingenuity, builds a crew, then a fleet. By the time the Lions notice, he is already entrenched.

**Key Story Beats:**

1. Crystal discovery in the Forgotten Realm — first raw deposit found
2. Self-taught refining — Aristotle figures out the process alone
3. First encounter with Dave — tense trade negotiation; Dave is sizing him up
4. First glimpse of Death — watching from the shadows; identity unknown

**Player Decision Point:** Choose initial strategic stance:

- **Aggressive Expansion** — raid and take; build power through force
- **Cautious Trade** — sell cautiously; grow slowly, stay under the radar
- **Isolationist Defence** — hoard the crystals; fortify and hold

**Arc Exit Conditions (story flags):** `arc1_crystal_discovered`, `arc1_dave_met`, `arc1_death_glimpsed` all true

---

### Arc 2 — The Squeeze (Rising Pressure)

**Theme:** Power attracts enemies. The monopoly is now a target for everyone.

**Summary:** Dave escalates with blockades and raids. Death begins destabilising the Corsairs from within. The Lions demand tribute. Aristotle fights on three simultaneous fronts.

**Key Story Beats:**

1. Major supply route seized — player must negotiate, fight, or reroute
2. Death's betrayal within the corsair fleet — sabotage and misdirection
3. Lion tribute demand — pay up, refuse outright, or counter-offer
4. A wider multiverse faction offers alliance — with strings attached

**Player Decision Point:** Choose primary front to address:

- **External** — Focus on Dave and the Canis League military threat
- **Internal** — Root out Death and the corsair traitors
- **Political** — Manage the Lions through diplomacy

**Arc Exit Conditions:** `arc2_route_resolved`, `arc2_death_betrayal`, `arc2_lion_response` all set

---

### Arc 3 — The Alliance (Unlikely Partners)

**Theme:** Sometimes your enemy's enemy is your only friend.

**Summary:** To survive on all fronts, Aristotle must make deals with factions he would normally raid — fairies, aliens, even dog factions opposing Dave. The multiverse is more complex than cats versus dogs.

**Key Story Beats:**

1. Alien summit — Aristotle meets a faction leader from a completely alien universe
2. Aristotle and Dave share a scene together — tense, almost respectful; structural conflict acknowledged
3. Death's true allegiance finally revealed — Lions, Wolves, or pure independent ambition

**Player Decision Point:** Build an alliance portfolio — choose which factions to ally with and which to oppose. Every alliance has a cost.

**Arc Exit Conditions:** `arc3_alien_contact`, `arc3_dave_parley`, `arc3_death_allegiance` all set

---

### Arc 4 — The Reckoning (Final Conflict)

**Theme:** What is Aristotle willing to become to keep what he built?

**Summary:** All fronts converge simultaneously. Dave launches full military assault on crystal production. Death makes a final power grab. Lions and Wolves declare ultimate intent. Aristotle must make a final choice that determines the fate of the multiverse.

**Key Story Beats:**

1. Dave's full-scale military assault on crystal production sites
2. Death's final bid to seize production
3. Lions and Wolves declare ultimate intent — conquest or co-existence

**The Three Endings (determined by cumulative choice history across all four arcs):**

| Ending | Name | Description |
| -------- | ------ | ------------- |
| A | Hold | Aristotle keeps the monopoly. Wins, but rules alone. Power without peace. |
| B | Share | Aristotle distributes crystal knowledge. Power spreads. Peace through redistribution. |
| C | Destroy | Aristotle destroys production sites. No one wins. The multiverse must find another way. |

---

## 4. Characters

### Aristotle — Player Protagonist

- **Species:** Cat — Felid Corsair captain
- **Faction:** Felid Corsairs
- **Role:** Player character, discoverer and controller of Whisper Crystal production
- **Visual:** Confident smirk, captain's coat (deep purple with gold trim), crystal pendant at chest, amber eyes, upright ears. Head-and-shoulders portrait style.
- **Personality:** Street cat made good. Thinks he is the smartest creature in any room — and usually is. Still operates like a scrappy alley cat even while commanding a fleet. Philosophical, cunning, allergic to being told what to do.
- **Philosophy:** Understand everything, control what you can, survive the rest.
- **Backstory:** Born with nothing. Stumbled upon Whisper Crystals, figured out refining through sheer ingenuity alone. Built an empire before the Lions even noticed.
- **Core Tension:** Balancing being a pirate (free, chaotic, self-serving) with being the most powerful supplier in the multiverse (responsibility, enemies everywhere).
- **Name Meaning:** The philosopher who believed in understanding the world through observation and reason — a cat who built his empire on knowing things others didn't.
- **Dialogue Tone:** Pragmatic, witty, strategic. Never formal. Never subservient. Think pirate captain who reads philosophy.

**Starting Stats:**

| Stat | Value | Notes |
| ------ | ------- | ------- |
| Cunning | 8 | Primary — affects bluff and intel options |
| Leadership | 7 | Crew morale and fleet command |
| Negotiation | 6 | Trade pricing and diplomatic success |
| Combat Skill | 6 | Direct combat effectiveness |
| Intimidation | 4 | Low — leads by respect, not fear |
| Stealth | 3 | Low — a known figure, not a shadow |

---

### Dave — Primary Antagonist

- **Species:** Dog — Canis League commander
- **Faction:** Canis League
- **Role:** Primary external antagonist, leading the dog faction's campaign to break the crystal monopoly
- **Visual:** Calm intensity, military collar (navy blue), steady unwavering gaze, short fur, square jaw. Portrait conveys quiet threat.
- **Personality:** The most dangerous kind of antagonist — completely ordinary name, completely extraordinary determination. Methodical, loyal, utterly relentless. Does not hate Aristotle. Simply needs what Aristotle has and will not stop.
- **Motivation:** Break the cats' stranglehold on Whisper Crystals. Energy independence for dogs — by trade, force, or finding an alternative.
- **Relationship with Aristotle:** Respect mixed with deep frustration. The conflict is structural, not personal.
- **Dialogue Tone:** Quiet, direct, almost polite. His scariest lines are his simplest. Contrast with Aristotle's wit.

**Behaviour State Progression:**

- Arc 1: `OBSERVING` — Trade negotiation, sizing Aristotle up
- Arc 2: `HOSTILE` — Blockades, raids, diplomatic pressure
- Arc 3: `TRADING` — Brief parley, almost respectful
- Arc 4: `OPEN_CONFLICT` — Full military assault

---

### Death — Secondary Antagonist

- **Species:** Cat — rival Felid Corsair captain
- **Faction:** Felid Corsairs (rival subfaction)
- **Role:** Internal antagonist, creating a two-front war
- **Visual:** Hooded, glowing eyes visible in shadow, dark robes over corsair armour, older and more worn than Aristotle. Presence feels ancient and theatrical.
- **Personality:** Old world. Theatrical where Dave is quiet. Ancient, patient, completely certain of their own superiority. Sees Aristotle as an upstart who got lucky and intends to correct that mistake.
- **Motivation:** Take Aristotle's empire. Sees himself as the rightful controller of crystal production.
- **True Allegiance:** Hidden until Arc 3 — determined by player's investigation choices in Arc 2:
  - **Lions:** Death is a Lion agent, working to return crystal control to the nobility
  - **Wolves:** Death allied with Wolves, planning a military coup
  - **Independent:** Death serves only themselves — pure ambition
- **Dialogue Tone:** Dark, theatrical, grandiose. Speaks like someone who has been waiting centuries for this moment.

**Behaviour State Progression:**

- Arc 1: `HIDDEN` — First glimpse only, watching from shadows
- Arc 2: `COVERT_ACTION` — Betrayal, sabotage within corsair fleet
- Arc 3: `REVEALED` — True allegiance exposed
- Arc 4: `OPEN_CONFLICT` — Final power grab attempt

---

## 5. Factions

### Core Factions

#### Felid Corsairs (Player Faction)

- **ID:** `felid_corsairs`
- **Species:** Cat (anthropomorphic, pirate culture)
- **Ideology:** Freedom through power
- **Alignment:** Chaotic Independent
- **Government:** Decentralised Captains — meritocracy, leadership earned not inherited
- **Culture:** Crew loyalty earned through loot and leadership. Fiercely self-determined. Pirate flags everywhere.
- **Ships:** Fast, low armour, asymmetric, jury-rigged, devastatingly effective
- **Colour Palette:** Deep purple, crimson red — accented with gold, amber. Pirate flags, royal rebellion.
- **Special Ability:** Sole producers of Whisper Crystals. This is their power and their target.
- **Faction Abilities:**
  - **Crystal Refining** — only faction that can refine raw crystals
  - **Shadow Running** — evade detection in hostile territory (-30% ambush rate)
  - **Cunning Diplomacy** — unlocks bluff/misdirect dialogue options
- **Base Ship Stats:** Speed 8 | Armour 3 | Firepower 5 | Crystal Capacity 6 | Crew 4

#### Canis League (Dogs)

- **ID:** `canis_league`
- **Species:** Dog (military culture)
- **Ideology:** Order through loyalty
- **Alignment:** Lawful Hierarchical
- **Government:** Military Command — pack loyalty structure
- **Culture:** Honour, hierarchy, they follow orders. Naval power structure. Organised and disciplined.
- **Ships:** Bulkier, stronger armour, more guns, organised fleet formations
- **Colour Palette:** Navy blue, steel grey — accented with white, brass. Military uniforms, battleship hulls.
- **Special:** Completely crystal-dependent — this drives all their aggression
- **Faction Abilities:**
  - **Organised Warfare** — fleet formations grant +15% armour when 2+ ships present
  - **Siege Tactics** — can blockade supply routes (-50% crystal throughput)
  - **Superior Logistics** — resupply/repair at League ports costs 20% less
- **Base Ship Stats:** Speed 4 | Armour 8 | Firepower 7 | Crystal Capacity 5 | Crew 8

#### The Lions (Noble Cat Hierarchy)

- **ID:** `lions`
- **Species:** Cat (Noble — lions, aristocratic lineage)
- **Ideology:** Rule by divine birthright
- **Alignment:** Lawful Aristocratic
- **Government:** Noble Hierarchy — divine right, claim to rulership predating crystals
- **Culture:** Arrogant, political, self-declared noblest beasts. Resent owing anything to a street cat.
- **Ships:** Ornate, balanced, politically modified with gold filigree and stained glass
- **Colour Palette:** Gold, royal purple — accented with white marble, ivory. Cathedrals, divine right.
- **Faction Abilities:**
  - **Diplomatic Pressure** — force tribute demands costing crystals if refused
  - **Noble Authority** — +20% political influence over neutral factions in their regions
  - **Royal Decree** — can temporarily close trade routes to hostile factions
- **Base Ship Stats:** Speed 5 | Armour 6 | Firepower 5 | Crystal Capacity 7 | Crew 6

#### The Wolves (Military Elite)

- **ID:** `wolves`
- **Species:** Wolf (military stratocracy — evolved beyond dogs)
- **Ideology:** Dominance through superior tactics and evolutionary right
- **Alignment:** Lawful Dominant
- **Government:** Military Stratocracy — they do not follow orders, they give them
- **Culture:** Strategic, disciplined, utterly convinced of superiority. Dominance and calculated power.
- **Ships:** Tactical, dark, optimised for combat. Toughest opponents in space.
- **Colour Palette:** Charcoal, dark green — accented with silver, ice blue. Tactical gear, winter campaigns, cold efficiency.
- **Faction Abilities:**
  - **Tactical Superiority** — +20% firepower when initiating combat (first-strike)
  - **Pack Coordination** — multiple Wolf ships share targeting data (-15% player dodge)
  - **Evolutionary Right** — diplomatic encounters can escalate to combat with no reputation penalty
- **Base Ship Stats:** Speed 6 | Armour 7 | Firepower 8 | Crystal Capacity 4 | Crew 7

---

### Wider Multiverse Factions

#### Fairies

- **ID:** `fairies`
- **Species:** Fairy — small, winged, ancient magical beings
- **Ideology:** Knowledge is currency
- **Politics:** Fluid mercantile allegiances
- **Personality:** Know more than they let on. Mystical, enigmatic, transactional. Never give information for free.
- **Colour Palette:** Iridescent blue-green, soft pink — accented with starlight white, crystal shimmer
- **Gameplay Role:** Intel brokers, rare traders, unique crystal-related knowledge. High-value but unpredictable allies.
- **Abilities:** Magical espionage, enchanted goods, intelligence networks

#### Knights

- **ID:** `knights`
- **Species:** Human (chivalric orders from medieval realms)
- **Ideology:** Order through law
- **Politics:** Feudal hierarchy imposing universal order
- **Personality:** Honourable, rigid. Believe in imposing structure on chaos. Will not bend rules even when inconvenient.
- **Colour Palette:** Silver, red, heraldic blue — accented with gold trim, banner colours
- **Gameplay Role:** Military alliance at cost of autonomy. Strong combat support but political strings attached.
- **Abilities:** Heavy armour, disciplined formations, siege engineering

#### Goblins

- **ID:** `goblins`
- **Species:** Goblin — small, resourceful, amoral engineers
- **Ideology:** Profit above all
- **Politics:** Anarchic guild cartels
- **Personality:** Resourceful, amoral, profit-driven. Will deal with anyone. No loyalties except to payment.
- **Colour Palette:** Rust orange, sickly green — accented with brass, salvage metal. Jury-rigged everything.
- **Gameplay Role:** Ship upgrades, black-market crystal trades, illicit goods. Useful but unreliable.
- **Abilities:** Rapid ship modification, black-market crystal trade, sabotage services

#### Aliens & Space Races

- **ID:** `aliens`
- **Species:** Various — advanced civilisations from deep space
- **Ideology:** Varies wildly by race
- **Personality:** Wild cards. Could be allies, enemies, or something entirely unexpected. Technology beyond anything in the known multiverse.
- **Colour Palette:** Neon cyan, deep black — accented with bioluminescent greens and purples
- **Gameplay Role:** Introduce multiverse scale. Unique technology. Deeply unpredictable faction dynamics.
- **Abilities:** Superior technology, unknown weapons, deeply unpredictable behaviour

---

### Faction Relationship Matrix (Starting Values)

| Faction | Corsairs | Canis | Lions | Wolves | Fairies | Knights | Goblins | Aliens |
| --------- | ---------- | ------- | ------- | -------- | --------- | --------- | --------- | -------- |
| **Corsairs** | — | -20 | -10 | -30 | +15 | 0 | +10 | +5 |
| **Canis** | -20 | — | -15 | +40 | 0 | +20 | -10 | 0 |
| **Lions** | -10 | -15 | — | -20 | +10 | +15 | -5 | +5 |
| **Wolves** | -30 | +40 | -20 | — | -10 | +10 | -15 | -5 |
| **Fairies** | +15 | 0 | +10 | -10 | — | +5 | +20 | +15 |
| **Knights** | 0 | +20 | +15 | +10 | +5 | — | -20 | 0 |
| **Goblins** | +10 | -10 | -5 | -15 | +20 | -20 | — | +10 |
| **Aliens** | +5 | 0 | +5 | -5 | +15 | 0 | +10 | — |

**Diplomatic States (by score):** Hostile (< -40) | Wary (-40 to -10) | Neutral (-10 to +10) | Friendly (+10 to +40) | Allied (> +40)

**Important Lore:** Every faction is actively competing for total multiverse conquest. Aristotle sits at the centre because whoever controls the crystals controls who can participate in that race. Mixed-universe crews are normal — a cat captain can have goblin engineers, fairy scouts, and a knight navigator.

---

## 6. Ships

### Ship Stat System (1–10 scale)

| Stat | Description | Gameplay Effect |
| --------- | ------------- | ----------------- |
| Speed | Velocity and acceleration | Movement in navigation; dodge chance in combat |
| Armour | Hull durability | Damage reduction per hit |
| Firepower | Weapon strength | Damage dealt per hit |
| Crystal Capacity | Fuel/cargo storage | Max crystals; trade volume and travel range |
| Crew Capacity | Max crew slots | Crew role bonuses; boarding actions |

### Damage Formula

`damage = attacker_firepower - defender_armour` (minimum 1)

- 50% hull: visual damage effects (smoke, sparks)
- 25% hull: critical warning, -1 penalty to all stats
- 0% hull: ship destroyed

---

### Felid Corsair Ships

**Visual Design Language:** Asymmetric silhouettes — no two look identical. Jury-rigged appearance with mismatched panels and improvised additions. Sleek and fast — long, narrow profiles. Visible crystal fuel chambers glowing in the hull. Pirate flags and pennants trailing behind. Colour: deep purple and crimson with gold accents.

**Corsair Raider — Player Starting Ship ("The Whisper"):**

- Speed 8 | Armour 3 | Firepower 5 | Crystal Capacity 6 | Crew 4
- Visual: Sleek, asymmetric, jury-rigged panels, visible crystal fuel chamber glowing blue-white in the hull
- Strengths: Fastest ship in the game, excellent dodge rating
- Weaknesses: Low armour — a few hits can be devastating

**Corsair Smuggler** (upgrade path — trade focus)

- Speed 7 | Armour 3 | Firepower 4 | Crystal Capacity 9 | Crew 3
- Visual: Wider hull with hidden cargo bays, extra crystal storage pods bolted on externally

**Corsair Interceptor** (upgrade path — combat focus)

- Speed 9 | Armour 2 | Firepower 7 | Crystal Capacity 4 | Crew 3
- Visual: Narrow, blade-like, twin oversized engines, minimal crew quarters

---

### Canis League Ships

**Visual Design Language:** Symmetrical, imposing silhouettes. Heavy plating with visible gun turrets and military markings. Broader, more armoured hulls designed for fleet formation. Military insignia and rank markings. Colour: navy blue and steel grey with white/brass accents.

**League Cruiser — Dave's Fleet Standard:**

- Speed 4 | Armour 8 | Firepower 7 | Crystal Capacity 5 | Crew 8
- Visual: Broad, symmetrical hull, heavy plating, multiple gun turrets, military rank markings
- Strengths: High survivability, strong firepower, large crew for boarding
- Weaknesses: Slow, fuel-hungry

**League Destroyer** (elite combat / boss-level threat)

- Speed 3 | Armour 9 | Firepower 9 | Crystal Capacity 4 | Crew 10
- Visual: Massive, bristling with forward-mounted weapon arrays

---

### Lion Ships

**Visual Design Language:** Ornate and decorative — gold filigree, carved prow, cathedral-ship aesthetic. Stained glass viewports. Balanced but slightly ostentatious. Colour: gold and royal purple with white marble and ivory.

**Royal Galleon:**

- Speed 5 | Armour 6 | Firepower 5 | Crystal Capacity 7 | Crew 6
- Visual: Ornate gold filigree, stained glass viewports, carved lion-head prow

---

### Wolf Ships

**Visual Design Language:** Streamlined predator shapes. Tactical and minimal decoration. Dark paint, low-visibility profiles. Built for strike missions. Colour: charcoal and dark green with silver/ice blue accents.

**Wolf Strike Craft:**

- Speed 6 | Armour 7 | Firepower 8 | Crystal Capacity 4 | Crew 7
- Visual: Dark, streamlined predator silhouette, minimal decoration, angular attack profile

---

### Upgrade System

Each ship has **3 upgrade slots**. Upgrades purchased from friendly ports or looted from encounters.

| Upgrade | Effect | Crystal Cost | Salvage Cost |
| --------- | -------- | ------------- | ------------- |
| Reinforced Hull | Armour +1 | 20 | 10 |
| Turbocharger | Speed +1 | 25 | 15 |
| Heavy Guns | Firepower +1 | 30 | 20 |
| Crystal Compressor | Crystal Capacity +1 | 15 | 5 |
| Expanded Quarters | Crew Capacity +1 | 10 | 15 |
| Stealth Plating | Speed +1, Armour -1 | 35 | 25 |
| Siege Cannons | Firepower +2, Speed -1 | 40 | 30 |

---

### Crew Roles and Faction Bonuses

| Role | Stat Affected | Bonus |
| --------- | --------------- | ------- |
| Pilot | Speed | +2% per skill level |
| Gunner | Firepower | +2% per skill level |
| Engineer | Armour (repair rate) | +2% per skill level |
| Diplomat | Trade pricing | +2% per skill level |

| Crew Origin | Faction Bonus |
| --------- | --------------- |
| Felid Corsairs | +5% Speed (manoeuvrability) |
| Canis League | +5% Armour (discipline) |
| Goblins | +10% Salvage from encounters |
| Fairies | +5% Trade pricing (intel advantage) |
| Knights | +5% Firepower (martial training) |

---

## 7. Gameplay Systems

### Core Game Loop

```text
Navigation (side-scrolling space) 
  → Encounter Trigger (proximity to POI)
    → Combat | Trade | Dialogue | Exploration
  → Outcome → Loot / Story flags / Faction reputation changes
  → Arc progression check
  → Repeat
```

### Navigation State

The player controls their ship scrolling through 2D space. Points of interest (POIs) appear on a minimap. Traveling into a POI triggers an encounter. The camera follows the player ship with smooth lerp.

**POI Types:**

- Combat encounter (faction ship in red)
- Trade port (faction colours)
- Dialogue trigger (story beat)
- Exploration site (discovery event)
- Distress signal (side mission hook)

---

### Combat System

Turn-based combat with ship-vs-ship resolution.

**Resolution formula:** `damage = attacker_firepower - defender_armour` (min 1)

**Combat Options:**

- **Attack** — deal damage based on firepower vs armour
- **Flee** — chance based on speed differential; success = escape, failure = take a hit
- **Special** — faction-specific abilities (Crystal Surge, Formation Shield, etc.)

**Outcomes:**

- Victory → loot (salvage, crystals, intel tokens) + faction rep change
- Defeat → rescue/reload prompt
- Flee → escape with possible retaliation hit

**Visual:** Player ship on left, enemy ship on right (mirrored/flipped). Health bars for both. At 50% hull: smoke and spark particle effects. At 25%: critical warning overlay.

---

### Trade System

Split-screen inventory trade interface with faction-aware pricing.

**Pricing modifiers by diplomatic state:**

- Allied: -20% (discount)
- Friendly: -10%
- Neutral: base price
- Wary: +15% premium
- Hostile: trade unavailable

**Trade Commodities:** Crystals (primary), Salvage, Credits, Ship Parts, Intel Tokens, Rare Alloys

**Player Actions:** Counter-Offer | Accept | Reject

---

### Dialogue System

Character portrait + typewriter text + numbered response options.

**Mechanics:**

- Typewriter effect: 30 characters/second default (player can CONFIRM to instant-fill)
- Conditional branches: dialogue options unlock/lock based on story flags and faction scores
- Outcomes: faction reputation changes, story flag sets, can chain to combat or trade

**Aristotle's default dialogue filters:** His player-character context informs all dialogue tone — pragmatic, witty, strategic. Never formal. Never subservient.

---

### Economy System

**Crystal Extraction:** Raw deposits in regions generate crystals over time. Felid Corsairs refine them — no other faction can.

**Supply Routes:** Defined trade paths between regions. Can be blockaded (Canis Siege Tactics), rerouted, or fought over.

**Market Pricing:** Supply/demand affected by faction conquest events. Prices shift dynamically.

---

### Faction Reputation System

All 8 factions tracked with a score (-100 to +100). Actions in encounters change scores. Cascade rules apply — harming a faction may improve their rivals' scores.

**Diplomatic States:**

- Hostile (< -40): No trade, will attack on sight
- Wary (-40 to -10): Trade at premium
- Neutral (-10 to +10): Normal trade
- Friendly (+10 to +40): Trade discount, intel sharing
- Allied (> +40): Active support, special missions

---

### Exploration System

- **Region Discovery:** Traveling to new areas reveals map data
- **POI Scanning:** Scan nearby points of interest before committing to encounter
- **Exploration Events:** Random discoveries — derelict ships, crystal caches, ancient ruins, faction intelligence

---

### Crew Morale System

Crew morale tracked as a score with thresholds affecting performance:

- High morale: bonus to all stats
- Low morale: penalties; risk of desertion
- Morale affected by: victories, defeats, pay (crystals), faction composition conflicts, story events

---

### Faction Conquest AI (Background Simulation)

Factions actively compete for realm control in the background, independent of player actions. This creates:

- Dynamic "live world news" — faction territory shifts
- Changing encounter tables as factions move
- Power rankings that affect diplomatic options

---

### Save System

3 save slots. Atomic writes (write-temp, rename). All game state serialisable via `to_dict()` / `from_dict()`.

---

## 8. Side Missions

Side missions provide optional gameplay texture between arc beats. Triggered by story flags and region proximity.

### Mission Types

| Type | Description |
| ------ | ------------- |
| Bounty | Hunt and defeat a target enemy |
| Retrieval | Locate and return a specific cargo or person |
| Escort | Protect a ship through hostile territory |
| Salvage | Board and loot a derelict vessel |

### Arc 1 Side Missions

**"Clean Up Aisle Seven"** (Bounty)

- Region: Asteroid Belt
- Trigger: Arc 1 active + crystal discovered
- Summary: Goblin Scrapper raiders are ambushing merchant convoys. The Felid Corsairs want them permanently removed.
- Objective: Defeat the Goblin Scrapper patrol
- Rewards: 40 salvage, 5 crystals
- Faction impact: Corsairs +8, Goblins -5

**"Lost in Transit"** (Retrieval)

- Region: Forgotten Realm
- Trigger: Arc 1 active + Dave met
- Summary: A shipment of rare alloys vanished between realms. The cargo manifest tells a different story than the Canis League suspects.
- Objectives: Locate missing cargo → return to contact
- Rewards: 60 salvage, 8 crystals
- Faction impact: Canis League +5

**"Wings of Diplomacy"** (Escort)

- Region: Starting Realm
- Trigger: Arc 1 active + crystal discovered
- Summary: A Fairy Collective envoy needs safe passage through contested space — straight through Lion patrol routes.
- Objective: Escort the Fairy envoy through Lion territory
- Rewards: 30 salvage, 12 crystals
- Faction impact: Fairies +10, Lions -3

**"Ghost Ship"** (Salvage/Retrieval)

- Region: Forgotten Realm
- Trigger: Arc 1 active (any time)
- Summary: Sensors detect a derelict drifting in the outer reaches. No life signs. No distress beacon. Just a hull full of salvage — and probably a reason nobody claimed it.
- Objective: Board and search the derelict vessel
- Rewards: 80 salvage
- Note: Available without a discovery encounter — player can stumble on it

### Distress Signals

Random encounters spawned as POIs during navigation. Five encounter templates, each with 3 choice options. Player can investigate or ignore. Outcomes vary — some are genuine, some are traps.

### Mission Log UI

Accessible via M key during navigation. Two-panel layout:

- Left: Active mission list with status indicators
- Right: Selected mission detail with objectives, rewards, faction impacts
- HUD indicator: active mission count shown at all times

---

## 9. Art Direction

### Overall Aesthetic

- **Tone:** Spelljammer-inspired — serious stakes with a fun, accessible anthropomorphic cast
- **Style:** 2D — clean sprite art. Pixel art OR vector sprites (prototype uses placeholder geometry; Phase 2 adds full sprites)
- **Palette:** Deep space blacks and blues contrasted with warm ship interiors and crystal glow effects
- **Mood:** Adventurous, slightly chaotic, with moments of grandeur and menace
- **Key Distinguisher:** Every faction is immediately identifiable by silhouette and colour alone

---

### Faction Colour Palettes (authoritative)

| Faction | Primary | Accent | Feel |
| --------- | --------- | -------- | ------ |
| Felid Corsairs | Deep purple, crimson red | Gold, amber | Pirate flags, royal rebellion, independence |
| Canis League | Navy blue, steel grey | White, brass | Military uniforms, battleship hulls, discipline |
| The Lions | Gold, royal purple | White marble, ivory | Nobility, cathedrals, divine right |
| The Wolves | Charcoal, dark green | Silver, ice blue | Tactical gear, winter campaigns, cold efficiency |
| Fairies | Iridescent blue-green, soft pink | Starlight white, crystal shimmer | Mystical, mercurial, magical |
| Goblins | Rust orange, sickly green | Brass, salvage metal | Scavenged, industrial, amoral |
| Knights | Silver, red, heraldic blue | Gold trim, banner colours | Medieval order, honour codes, heraldry |
| Aliens | Neon cyan, deep black | Bioluminescent green, purple | Unknown, advanced, otherworldly |

---

### Character Portrait Style

- **Frame:** Head-and-shoulders crop
- **Expression:** Highly expressive — emotions readable at small sizes (128×128 minimum)
- **Silhouette:** Every character identifiable by outline alone, without colour
- **Clothing:** Faction colours integrated into armour and clothing
- **Specific Designs:**
  - **Aristotle:** Confident smirk, captain's coat (deep purple/gold), crystal pendant, amber eyes
  - **Dave:** Calm intensity, military collar (navy blue), steady unwavering gaze
  - **Death:** Hooded, glowing eyes visible in shadow, old and worn, theatrical dark presence

---

### Ship Visual Design (detailed)

**Cat Ships (Felid Corsairs):**

- Asymmetric — no two identical; mismatched panels suggest assembly from salvage
- Sleek and fast — elongated narrow profiles, rear-heavy engine mounts
- Glowing crystal fuel chambers visible through translucent hull sections (blue-white pulsing glow)
- Pirate pennants and flags trailing from hull protrusions
- Colours: deep purple hulls with crimson and gold trim

**Dog Ships (Canis League):**

- Symmetrical, imposing — clearly military
- Heavy external armour plating with visible bolt lines and stress marks
- Multiple gun turrets in fixed positions; forward-facing main cannons
- Military rank insignia painted or riveted on hull
- Fleet formation markings showing unit affiliation
- Colours: navy blue/steel grey with white numbers and brass fittings

**Lion Ships:**

- Cathedral-ship aesthetic — ornate and decorative
- Gold filigree engraved on hull panels
- Stained glass viewports that glow from interior lighting
- Carved lion-head prow as figurehead
- Colours: gold and royal purple, white marble texture sections

**Wolf Ships:**

- Predator-shaped — low profile, swept angles suggesting attack direction
- Dark paint, almost invisible against deep space
- Minimal external decoration — pure function
- Angular attack profile, no wasted surface area
- Colours: charcoal dark green with silver trim only on weapon mounts

**Fairy Vessels:**

- Organic, flowing shapes — look grown rather than built
- Iridescent hull material that catches light differently at different angles
- Trailing particle wisps as propulsion exhaust
- Crystalline observation domes

**Goblin Scrapships:**

- Visibly assembled from salvaged parts of other ships
- Multiple mismatched engine exhausts
- External cargo containers bolted at odd angles
- Rust patches and repair welds visible as texture detail

**Knight Warships:**

- Medieval castle aesthetic translated to space
- Battlements and turrets from castle architecture
- Heraldic banners attached to external poles
- Heavy and angular, like a fortress that can fly

---

### Whisper Crystal Visual Effects

- **Core colour:** Blue-white at centre
- **Edge falloff:** Purple at outer edges
- **Animation:** Soft pulsing glow (0.5–1.5 second cycle)
- **"Whisper" particle effect:** Subtle trails that resemble sound waves or ripples in air — particles drift outward and fade
- **Raw deposits:** Dimmer, uneven glow — rough crystal formations embedded in rock
- **Refined crystals:** Brighter, cleaner, more regular pulsing
- **Ship crystal chambers:** Pulse in rhythm with engine thrust — glow intensifies during acceleration

---

### Space Background System

Layered parallax system (back to front):

1. **Deep background:** Static starfield (tiny white dots, various brightness)
2. **Nebula layer:** Soft colour wash — colour temperature varies by region
3. **Mid layer:** Dust clouds, larger stars with subtle glow halos
4. **Near layer:** Asteroids, debris fields, moving slowly (parallax rate ~0.3x player speed)
5. **POI layer:** Stations, derelicts, encounter markers

**Region colour temperatures:**

- Starting Realm / Forgotten Realm: Warm amber/gold — discovery feel
- Trade Hubs: Bright, multi-coloured — commerce and activity
- Canis Territory: Cool blue/grey — military cold efficiency
- Lion Territory: Golden/ivory — noble warmth and opulence
- Deep Space: Dark, sparse, almost black — unknown and vast

---

### UI Visual Style

- **Panels:** Semi-transparent dark backgrounds with faction-appropriate border colours
- **Dialogue boxes:** Dark background, character portrait left, text right, name plate above text
- **HUD:** Minimal, docked to screen edges, no more than 15% screen occlusion
- **Trade UI:** Split-screen with clean inventory grids
- **Faction colours:** UI elements adopt relevant faction's palette when viewing faction-specific content
- **Reputation bars:** Colour-coded red (hostile) → orange (wary) → grey (neutral) → green (friendly) → blue (allied)
- **Transitions:** 0.3-second fade between major state changes
- **Font minimum:** 14px for accessibility; high contrast mode option

---

### Existing Art Assets (Ready for Integration)

| Asset | File | Purpose |
| ------- | ------ | --------- |
| Aristotle portrait | `design/charcters/aristotle_head.png` | Dialogue portraits |
| Dave portrait | `design/charcters/dave_head.png` | Dialogue portraits |
| Death portrait | `design/charcters/death_head.png` | Dialogue portraits |
| Player ship (side) | `design/ships/ship_r_side.png` | Navigation + combat |
| Player ship (top) | `design/ships/ship_up_side.png` | Alternative view |
| League Cruiser | `design/ships/league_cruiser.png` | Enemy ship |
| League Destroyer | `design/ships/league_destroyer.jpg` | Boss ship |
| Royal Galleon | `design/ships/royal_galleon.jpg` | Lion ship |
| Wolf Strike Craft | `design/ships/wolf_ship.png` | Wolf enemy |
| Fairy Vessel | `design/ships/fairy_ship.png` | Fairy ally/enemy |
| Knight Warship | `design/ships/knight_ship.png` | Knight faction |
| Goblin Scrapship | `design/ships/goblin_scrapper.png` | Goblin faction |
| Combat icon | `design/ui_ux/fight_cutlass.png` | Combat POI markers |
| Splash screen | `design/artwork/wc_splash_screen.png` | Game startup |
| Title graphic | `design/artwork/whisper_crystals_title.png` | Main menu |

**Assets still needed (to generate or commission):**

- Alien vessel sprite (neon cyan/bioluminescent)
- Crystal deposit sprite with glow animation
- Faction-specific UI frame textures

---

## 10. UI/UX Specification

### Screen Flow

```text
Title Screen → Main Menu
  ├── New Game → Intro Cutscene → Navigation
  ├── Continue → Load Slot Select → Navigation
  ├── Settings → Settings Panel
  └── Quit

Navigation (core loop)
  ├── Encounter → Combat | Trade | Dialogue | Exploration
  ├── Story Beat → Cutscene
  ├── ESC → Pause Menu (overlay)
  │    ├── Resume | Save | Load | Settings | Quit to Menu
  ├── S key → Ship Management (overlay)
  ├── F key → Faction Status (overlay)
  └── M key → Mission Log (overlay)

Combat → Victory/Defeat/Flee → Loot Summary → Navigation
Trade → Complete/Cancel → Navigation
Dialogue → Complete → Navigation | Combat | Trade
Final Decision → Ending Cutscene → Ending Summary → Credits → Main Menu
```

### HUD Layout (Navigation)

```text
┌─────────────────────────────────────────────────────┐
│ [Ship Health Bar]              [Crystal Count: 150]  │
│ [Shield Bar]                   [Salvage: 45]         │
│                                                      │
│              GAMEPLAY AREA (side-scrolling)          │
│                                                      │
│ [Minimap]                      [Current Mission]     │
│ [Arc: The Squeeze]             [Faction Alert Icon]  │
└─────────────────────────────────────────────────────┘
```

### Key Controls

| Key | Action |
| ----- | -------- |
| WASD / Arrow Keys | Ship movement |
| E | Interact |
| SPACE | Fire |
| ESC | Pause |
| RETURN | Confirm |
| S | Ship screen |
| F | Faction screen |
| M | Mission log |
| 1–3 | Dialogue options |

---

## 11. Technical Architecture

### Engine & Stack

- **Engine:** Godot 4.6 (GL Compatibility renderer)
- **Language:** GDScript
- **Resolution:** 1280×720, canvas_items stretch
- **Rendering:** Layer order: Background → Environment → Entities → Effects → UI → Overlay

### Architecture Principles

1. **Autoload Singletons:** `EventBus`, `GameSession`, `MusicManager` — global services
2. **Data-driven content:** All encounters, dialogue, factions, ships in JSON under `data/`
3. **Event Bus:** Pub/sub system for decoupled communication — systems publish events, never call each other directly
4. **Scene-based UI:** UI screens are individual scenes managed via the scene tree
5. **Stack state machine:** All game states managed via push/pop/switch. No ad-hoc boolean flags.
6. **Entity serialisation:** All entities implement `to_dict()` / `from_dict()` for save/load

### Project Structure

```text
godot/
├── project.godot
├── scenes/
│   ├── main.tscn                 # Entry point
│   └── ui/                       # UI scenes
├── scripts/
│   ├── autoload/                 # EventBus, GameSession, MusicManager
│   ├── core/                     # Core game logic
│   ├── entities/                 # Data models (Ship, Character, Faction, Encounter, SideMission)
│   ├── systems/                  # Game systems (combat, economy, crew, faction, side_mission)
│   └── ui/                       # UI controllers
├── data/
│   ├── encounters/               # Arc 1–4 encounter definitions (JSON)
│   ├── dialogue/                 # Dialogue trees (JSON)
│   ├── factions/                 # Faction registry (JSON)
│   ├── ships/                    # Ship templates (JSON)
│   ├── economy/                  # Crystal deposits, supply routes, regions (JSON)
│   ├── story/                    # Arc definitions and story flags (JSON)
│   └── side_missions/            # Side mission data (JSON)
├── assets/
│   ├── sprites/                  # Ship, character, UI sprites
│   └── audio/                    # Music and SFX
└── shaders/                      # Custom shaders (crystal glow, parallax)
```

### Game State Machine

States: `MENU | NAVIGATION | COMBAT | TRADE | DIALOGUE | CUTSCENE | PAUSE | SHIP_SCREEN | FACTION_SCREEN | MISSION_LOG | ENDING`

Stack operations:

- `switch` — replace top state (menu → navigation)
- `push` — overlay on top (navigation → pause)
- `pop` — return to previous (pause → navigation)

### Key Systems to Implement

| System | File | Responsibility |
| -------- | ------ | --------------- |
| EventBus | `autoload/event_bus.gd` | Pub/sub global signal bus |
| GameSession | `autoload/game_session.gd` | All game state; save/load |
| MusicManager | `autoload/music_manager.gd` | BGM tracks, SFX triggers |
| CombatSystem | `systems/combat_system.gd` | Combat resolution |
| EconomySystem | `systems/economy_system.gd` | Crystal extraction, trade pricing |
| FactionSystem | `systems/faction_system.gd` | Reputation, diplomatic states |
| FactionConquestAI | `systems/faction_conquest.gd` | Background faction warfare |
| CrewMoraleSystem | `systems/crew_morale.gd` | Morale tracking and effects |
| SideMissionSystem | `systems/side_mission_system.gd` | Mission lifecycle, objectives |
| EncounterEngine | `systems/encounter_engine.gd` | Trigger evaluation, dispatch |
| SaveManager | `core/save_manager.gd` | 3 slots, atomic writes |

### Data Files (JSON)

Each encounter record includes:

- `encounter_id`, `encounter_type`, `arc`, `conditions`, `priority`
- `dialogue` tree with `speaker`, `text`, `choices[]`, `outcomes[]`
- `faction_changes`, `story_flags`, `rewards`

---

## 12. Audio Direction

### Music System

Per-state background music tracks with smooth transitions:

- **Main Menu:** Atmospheric, slow — space ambience with light melodic theme
- **Navigation:** Adventurous, medium tempo — pirate/space hybrid. Shifts by region.
- **Combat:** Intense, percussion-driven — tempo increases with danger
- **Dialogue — Tense:** Sparse, low strings — unresolved tension
- **Dialogue — Friendly:** Warmer tones, lighter
- **Trade:** Ambient, slightly whimsical — marketplace feel
- **Endings:** Each ending has its own theme (Hold: triumphant but lonely; Share: hopeful; Destroy: mournful)

### Sound Effects

Triggered via EventBus events:

- Ship engine hum (continuous, navigation)
- Weapons fire (per combat hit)
- Crystal activation/glow (crystal pickup, chamber pulse)
- Dialogue advance (typewriter click or soft chime)
- UI navigation clicks
- Victory fanfare / defeat sting

---

## 13. Current Development State

As of the latest review, the game is fully implemented as a **Python/Pygame prototype** with:

- All 4 story arcs with encounter data, dialogue, and arc transition logic
- All 3 endings reachable based on cumulative choice history
- 8 factions with full relationship matrix and conquest AI
- Complete combat, trade, exploration, crew morale, and economy systems
- Side missions and distress signals (Arc 1: 4 missions, 5 distress encounters)
- Save/load system (3 slots)
- Music and SFX systems
- Sprite asset manager with faction ship sprites
- 280 tests, 100% pass rate

**The task for the agent is to migrate this to a full Godot 4.6 GDScript implementation**, or continue development on the existing Godot port already in progress at `godot/`.

### What Exists in Godot Already (check `godot/` before rebuilding)

- `godot/project.godot` — project file
- `godot/scripts/` — partial GDScript port
- `godot/data/` — JSON data files including side missions
- `godot/scenes/` — scene files

### What Needs Building / Completing

Per `docs/MASTER_PLAN.md` Section 6 — outstanding tasks:

1. Character portraits in all dialogue encounters (task 3.3)
2. Faction-themed UI panels (task 3.5)
3. Region-specific space backgrounds (task 3.6)
4. Crystal visual effects — pulsing glow on HUD, deposit POIs, ship engine chambers (task 3.7)
5. Difficulty balance pass on combat and economy

---

## 14. Agent Instructions

When building this project, follow these rules:

1. **Read the JSON data files first** — all story content, dialogue, factions, ships, and encounters are data-driven. Do not hardcode narrative content in scripts.

2. **Use the EventBus for all cross-system communication** — no direct system-to-system calls. Systems emit signals; other systems subscribe.

3. **Autoload singletons provide global services** — `EventBus`, `GameSession`, `MusicManager`. All other scripts reference these.

4. **Stack state machine for all UI transitions** — push overlays, pop to return, switch to replace. Never manage state with boolean flags.

5. **Faction colours are canonical** — see Section 9. Apply them consistently to all ship sprites, UI panels, and portraits for that faction.

6. **Aristotle's voice is always pragmatic and witty** — any default dialogue or UI copy that references the player character must reflect this.

7. **Crystal effects are always blue-white core / purple edges with a pulsing animation** — do not deviate from this.

8. **Every entity must implement serialisation** — `to_dict()` / `from_dict()` for save/load compatibility.

9. **Existing art assets are at `design/`** — check the asset table in Section 9 before generating new art. Sprites already exist for all major ships and main characters.

10. **Three endings are determined by accumulated choices** — the ending system must read cumulative story flags, not just the final decision.
