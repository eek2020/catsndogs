> **ARCHIVED — 2026-03-02 — STATUS: MOSTLY COMPLETE**
>
> **Completion Summary:**
> All MUST HAVE character and faction requirements are implemented. All 6 core factions and 2 wider factions
> are in `data/factions/faction_registry.json`. Crew system is implemented. Named crew storylines are deferred (PLAN-002).
>
> | Section | Status | Notes |
> |---------|--------|-------|
> | Aristotle entity (REQ-001–004) | ✅ Complete | Character dataclass, stats, dialogue integration, narrative progression |
> | Dave entity (REQ-010–013) | ✅ Complete | BehaviourState machine, relationship tracking, dialogue trees |
> | Death entity (REQ-020–023) | ✅ Complete | Hidden → revealed arc, `true_allegiance` revealed in Arc 3 |
> | NPC Behaviour System (REQ-030–033) | ✅ Complete | BehaviourState enum, relationship_with_player tracking; NPC memory via story flags and conditional dialogue |
> | Felid Corsairs faction (REQ-040–042) | ✅ Complete | faction_registry.json; ship templates; abilities modelled |
> | Canis League faction (REQ-043–045) | ✅ Complete | Full faction entity with abilities |
> | Lions faction (REQ-046–048) | ✅ Complete | Full faction entity with abilities |
> | Wolves faction (REQ-049–051) | ✅ Complete | Full faction entity with abilities |
> | Wider factions — Fairies, Knights, Goblins, Aliens (REQ-052–055) | ✅ Complete | All 4 in faction registry |
> | Faction Relationship System (REQ-060–065) | ✅ Complete | Reputation scores, diplomatic states, cascade rules, threshold events |
> | Faction Ships (REQ-070–073) | ✅ Complete | ship_templates.json with all faction ship templates |
> | Crew System (REQ-074–076) | ✅ Complete | CrewMember entity with mixed-universe crews; faction_trait_bonus; skill_level |
> | Crew Morale (REQ-077) | ✅ Complete | CrewMoraleSystem with faction loyalty checks, morale thresholds, mutiny events |
> | Crew Encounter Unlocks (REQ-078) | ✅ Partial | Framework in place; per-faction encounter unlock conditions available in data |
> | Named Crew with Mini-Storylines | ⬜ Deferred | PLAN-002 Tier 2 enhancement — crew have names/species but no personal backstory arcs yet |
> | Faction Conquest AI (REQ-080) | ✅ Complete | FactionConquestAI in systems/faction_conquest.py |
> | Realm Control (REQ-081) | ✅ Complete | RealmControlSystem in systems/realm_control.py |
> | Power Balance Display (REQ-082) | ✅ Complete | FactionScreenState shows relationship matrix; power rankings in FactionConquestAI |
>
> **Deviations:**
> - Named crew backstory/loyalty arcs (REQ-076 aspect) deferred to PLAN-002 (named crew mini-storylines)
> - Crew encounter unlocks (REQ-078) are data-driven but not all faction types have unique unlocked options authored yet

---

# PRD-003: Character & Faction System Requirements

**Project:** Whisper Crystals — A Space Pirates Game
**Version:** 0.1
**Date:** February 2026
**Classification:** Creative Development — Confidential

---

## Section 1: Character System Requirements

### 1.1 Aristotle — Protagonist / Player Character

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-001 | Aristotle Entity: Player character representing the Felid Corsair captain. Species: Cat. Faction: Felid Corsairs | MUST HAVE | Entity loads with correct attributes; player controls Aristotle's ship and decisions |
| PRD003-REQ-002 | Aristotle Attributes: `name`, `species`, `faction_id` (felid_corsairs), `title` (Captain), `stats` (cunning, leadership, negotiation, combat_skill), `crystal_knowledge` (refining proficiency level) | MUST HAVE | All attributes initialised on new game; stats affect encounter outcomes; crystal_knowledge gates production efficiency |
| PRD003-REQ-003 | Aristotle Dialogue Integration: Aristotle's dialogue options reflect current stats, faction standings, and story flags | MUST HAVE | Dialogue system reads Aristotle's state; high cunning unlocks bluff options; high leadership unlocks crew morale options |
| PRD003-REQ-004 | Aristotle Progression: Stats improve through encounters and story beats; no traditional XP system — growth is narrative and strategic | MUST HAVE | Stat changes are triggered by specific events; changes are logged in choice history; progression feels earned, not arbitrary |

### 1.2 Dave — Primary Antagonist (NPC)

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-010 | Dave Entity: NPC antagonist representing the Canis League commander. Species: Dog. Faction: Canis League | MUST HAVE | Entity loads with correct attributes; Dave appears in encounters per story arc requirements |
| PRD003-REQ-011 | Dave Attributes: `name`, `species`, `faction_id` (canis_league), `rank` (Commander), `stats` (loyalty, strategy, persistence, military_strength), `relationship_with_player` (score) | MUST HAVE | All attributes initialised; relationship score starts at neutral; behaviour adjusts based on relationship |
| PRD003-REQ-012 | Dave Behaviour AI: Dave's actions escalate across arcs — Arc 1 (observation/trade), Arc 2 (blockades/raids), Arc 3 (parley), Arc 4 (full assault) | MUST HAVE | Behaviour state machine has 4 states matching arcs; transitions triggered by arc progression; AI selects appropriate encounter types per state |
| PRD003-REQ-013 | Dave Dialogue: Dave's dialogue reflects respect mixed with frustration; tone shifts based on player's prior choices toward the Canis League | MUST HAVE | Dialogue trees for Dave have conditional branches based on `canis_league` faction score and `relationship_with_player` |

### 1.3 Death — Secondary Antagonist (NPC)

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-020 | Death Entity: NPC antagonist representing a rival Felid Corsair captain. Species: Cat. Faction: Felid Corsairs (rival) | MUST HAVE | Entity loads with correct attributes; Death appears in encounters per story arc requirements |
| PRD003-REQ-021 | Death Attributes: `name`, `species`, `faction_id` (felid_corsairs), `subfaction` (rival), `stats` (intimidation, stealth, ancient_knowledge, combat_skill), `true_allegiance` (determined by Arc 3 revelation) | MUST HAVE | All attributes initialised; `true_allegiance` is null until Arc 3; revelation sets value to `lions` / `wolves` / `independent` |
| PRD003-REQ-022 | Death Behaviour AI: Death operates covertly in Arcs 1–2, is revealed in Arc 3, and acts openly in Arc 4 | MUST HAVE | Behaviour state machine: `hidden` → `covert_action` → `revealed` → `open_conflict`; transitions match arc progression |
| PRD003-REQ-023 | Death Dialogue: Death's tone is dark, theatrical, and ancient; dialogue contrasts with Aristotle's pragmatic style | MUST HAVE | Dialogue trees reflect personality; conditional branches based on player's investigation actions and story flags |

---

## Section 2: NPC Behaviour Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-030 | NPC State Machine: All major NPCs (Dave, Death, faction leaders) operate via a behaviour state machine with defined states and transition conditions | MUST HAVE | Each NPC has a `behaviour_state` attribute; state transitions are triggered by story flags and arc progression; state determines available encounter types and dialogue |
| PRD003-REQ-031 | NPC Relationship Tracking: Each NPC tracks a `relationship_with_player` score that modifies their behaviour, dialogue tone, and encounter difficulty | MUST HAVE | Score updates on every relevant player action; score range is -100 to +100; thresholds define hostile / wary / neutral / friendly / allied bands |
| PRD003-REQ-032 | NPC Encounter Selection: NPCs select encounter types (combat / trade / diplomacy) based on their current behaviour state and relationship score | SHOULD HAVE | High hostility NPCs prefer combat; neutral NPCs prefer trade; allied NPCs offer support missions |
| PRD003-REQ-033 | NPC Memory: NPCs reference prior player actions in dialogue (e.g., Dave mentions a past betrayal or a kept promise) | SHOULD HAVE | Dialogue conditions check specific story flags; NPC dialogue adapts to player history |

---

## Section 3: Faction Registry Requirements

### 3.1 Felid Corsairs (Cats — Player Faction)

**Realm of Origin:** Realm of the Feline Courts
**Ideology:** Freedom through power
**Politics:** Meritocracy — leadership earned, not inherited

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-040 | Faction Entity: `faction_id: felid_corsairs`, `species: cat`, `alignment: chaotic_independent`, `government: decentralised_captains`, `realm: feline_courts`, `ideology: freedom_through_power` | MUST HAVE | Faction loads in registry with all attributes including realm and ideology |
| PRD003-REQ-041 | Faction Traits: Fast ships, low armour, high manoeuvrability; crew loyalty earned through loot and leadership; crystal producers | MUST HAVE | Faction traits modify ship templates and encounter behaviour for all corsair NPCs |
| PRD003-REQ-041a | Faction Unique Abilities: (1) **Crystal Refining** — only faction that can refine raw crystals, increasing quality grade; (2) **Shadow Running** — ships can evade detection when entering hostile territory, reducing ambush encounter rate by 30%; (3) **Cunning Diplomacy** — unlocks additional bluff/misdirect dialogue options in diplomatic encounters | MUST HAVE | Each ability produces a measurable gameplay effect; abilities are modelled as `faction_abilities[]` in data; abilities affect encounter outcomes, not just aesthetics |
| PRD003-REQ-042 | Faction Attributes: `crystal_production_rate`, `fleet_strength`, `internal_stability` (affected by Death's actions), `reputation_scores{}` (per other faction) | MUST HAVE | Attributes update in response to game events; displayed in faction status screen |

### 3.2 Canis League (Dogs)

**Realm of Origin:** Realm of the Canine Order
**Ideology:** Order through loyalty
**Politics:** Military hierarchy and pack loyalty

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-043 | Faction Entity: `faction_id: canis_league`, `species: dog`, `alignment: lawful_hierarchical`, `government: military_command`, `realm: canine_order`, `ideology: order_through_loyalty` | MUST HAVE | Faction loads in registry with realm and ideology |
| PRD003-REQ-044 | Faction Traits: Bulkier ships, stronger armour, more firepower; loyalty and honour culture; hierarchical command structure; crystal-dependent | MUST HAVE | Traits modify ship templates and NPC behaviour |
| PRD003-REQ-044a | Faction Unique Abilities: (1) **Organised Warfare** — fleet formations grant +15% armour to all ships in combat when 2+ League ships present; (2) **Siege Tactics** — can blockade supply routes, reducing crystal throughput by 50%; (3) **Superior Logistics** — resupply and repair at League ports costs 20% less | MUST HAVE | Each ability produces measurable gameplay effect; modelled in `faction_abilities[]` |
| PRD003-REQ-045 | Faction Attributes: `military_strength`, `crystal_reserves`, `aggression_level` (escalates across arcs), `reputation_scores{}` | MUST HAVE | Attributes update; aggression level drives Dave's behaviour state |

### 3.3 The Lions (Noble Cat Hierarchy)

**Realm of Origin:** Realm of the Feline Courts (noble branch)
**Ideology:** Rule by divine birthright
**Politics:** Noble hierarchy — they were rulers before crystals existed and intend to rule after.

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-046 | Faction Entity: `faction_id: lions`, `species: cat_noble`, `alignment: lawful_aristocratic`, `government: noble_hierarchy`, `realm: feline_courts`, `ideology: rule_by_birthright` | MUST HAVE | Faction loads in registry with realm and ideology |
| PRD003-REQ-047 | Faction Traits: Political power, claim of divine right over crystals, diplomatic pressure tactics; demand tribute from Aristotle. | MUST HAVE | Traits manifest in diplomatic encounters; Lion NPCs reference birthright claim |
| PRD003-REQ-047a | Faction Unique Abilities: (1) **Diplomatic Pressure** — can force tribute demands; (2) **Noble Authority** — Lion presence grants +20% political influence over neutral factions; (3) **Royal Decree** — can temporarily close trade routes to hostile factions | MUST HAVE | Each ability produces measurable gameplay effect; modelled in `faction_abilities[]` |
| PRD003-REQ-048 | Faction Attributes: `political_influence`, `crystal_claim_status`, `tribute_demanded`, `reputation_scores{}` | MUST HAVE | Attributes track political state; tribute demand triggers Arc 2 event |

### 3.4 The Wolves (Military Elite Dogs)

**Realm of Origin:** Realm of the Canine Order (military elite branch)
**Ideology:** Dominance through superior tactics and evolutionary right
**Politics:** Military stratocracy

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-049 | Faction Entity: `faction_id: wolves`, `species: wolf`, `alignment: lawful_dominant`, `government: military_stratocracy`, `realm: canine_order`, `ideology: dominance_through_tactics` | MUST HAVE | Faction loads in registry with realm and ideology |
| PRD003-REQ-050 | Faction Traits: Strategic and disciplined military force; believe in breaking the crystal monopoly by force | MUST HAVE | Wolf encounters are military-focused; Wolf NPCs are tactically competent |
| PRD003-REQ-050a | Faction Unique Abilities: (1) **Tactical Superiority** — +20% firepower on first strike; (2) **Pack Coordination** — reduces player dodge chance; (3) **Evolutionary Right** — escalation to combat with no reputation penalty | MUST HAVE | Each ability produces measurable gameplay effect; modelled in `faction_abilities[]` |
| PRD003-REQ-051 | Faction Attributes: `military_strength`, `tactical_rating`, `crystal_seizure_intent`, `reputation_scores{}` | MUST HAVE | Attributes drive Arc 4 military events |

### 3.5 Wider Multiverse Factions

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-052 | Fairies Faction: `faction_id: fairies`, `realm: fairy_realms`, `ideology: knowledge_is_currency`. Magical traders and information brokers. | SHOULD HAVE | Faction loads; fairy encounters provide unique trade and intel options |
| PRD003-REQ-052a | Fairy Unique Abilities: (1) **Magical Espionage**; (2) **Enchanted Goods**; (3) **Intelligence Networks** | SHOULD HAVE | Each ability modelled in `faction_abilities[]` |
| PRD003-REQ-053 | Knights Faction: `faction_id: knights`, `realm: knight_kingdoms`, `ideology: order_through_law`. Chivalric orders. | SHOULD HAVE | Faction loads; knight encounters offer military support with political strings |
| PRD003-REQ-053a | Knight Unique Abilities: (1) **Heavy Armour**; (2) **Disciplined Formations**; (3) **Siege Engineering** | SHOULD HAVE | Each ability modelled in `faction_abilities[]` |
| PRD003-REQ-054 | Goblins Faction: `faction_id: goblins`, `realm: goblin_warrens`, `ideology: profit_above_all`. Scavengers and engineers. | SHOULD HAVE | Faction loads; goblin encounters provide ship upgrades and black-market trades |
| PRD003-REQ-054a | Goblin Unique Abilities: (1) **Rapid Ship Modification**; (2) **Black-Market Crystal Trade**; (3) **Sabotage Services** | SHOULD HAVE | Each ability modelled in `faction_abilities[]` |
| PRD003-REQ-055 | Aliens Faction: `faction_id: aliens`, `realm: deep_space`, `ideology: varies`. Advanced wild-card civilisations. | SHOULD HAVE | Faction loads; alien encounters introduce multiverse scale and unique technology |
| PRD003-REQ-055a | Alien Unique Abilities: (1) **Superior Technology**; (2) **Unknown Weapons**; (3) **Deeply Unpredictable Behaviour** | SHOULD HAVE | Each ability modelled in `faction_abilities[]` |

---

## Section 4: Faction Relationship System Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-060 | Faction Reputation Scores: Each faction maintains a reputation score for the player ranging from -100 (hostile) to +100 (allied) | MUST HAVE | Scores initialise per faction defaults; scores update on player actions; scores persist in save data |
| PRD003-REQ-061 | Diplomatic States: Each faction has a diplomatic state derived from reputation score — `hostile` (-100 to -51), `wary` (-50 to -1), `neutral` (0 to 25), `friendly` (26 to 75), `allied` (76 to 100) | MUST HAVE | State labels display correctly in faction status screen; state thresholds are configurable in data files |
| PRD003-REQ-062 | Trade Permissions: Trade access is gated by diplomatic state | MUST HAVE | Trade UI reflects pricing modifications; trade refusal triggers appropriate dialogue |
| PRD003-REQ-063 | Mission Availability: Faction-specific missions unlock at `friendly` or higher standing | SHOULD HAVE | Mission board filters by faction standing; locked missions show requirement |
| PRD003-REQ-064 | Relationship Matrix: Cross-faction relationships with cascade rules | MUST HAVE | Matrix is stored as data; cascading effects calculated on faction score changes |
| PRD003-REQ-065 | Faction Relationship Events: Crossing a diplomatic state threshold triggers a narrative event | SHOULD HAVE | Threshold crossing events defined in data; fire once per threshold crossing |

---

## Section 5: Faction-Specific Ship & Crew Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-070 | Felid Corsair Ships: Speed 8, Armour 3, Firepower 5, Crystal Capacity 6, Crew 4 (base template) | MUST HAVE | Ship template loads from data; visual style matches faction |
| PRD003-REQ-071 | Canis League Ships: Speed 4, Armour 8, Firepower 7, Crystal Capacity 5, Crew 8 (base template) | MUST HAVE | Ship template loads; visual and mechanical distinction |
| PRD003-REQ-072 | Lion Ships: Speed 5, Armour 6, Firepower 5, Crystal Capacity 7, Crew 6 (base template) | SHOULD HAVE | Ship template loads |
| PRD003-REQ-073 | Wolf Ships: Speed 6, Armour 7, Firepower 8, Crystal Capacity 4, Crew 7 (base template) | SHOULD HAVE | Ship template loads; toughest combat opponents |
| PRD003-REQ-074 | Crew System: Each ship has a crew roster with roles (pilot, gunner, engineer, diplomat) | MUST HAVE | Crew roles assigned per ship; quality modifies associated stat by ±20%; crew data persists |
| PRD003-REQ-075 | Faction Crew Traits: Crew recruited from different factions have faction-specific bonuses | MUST HAVE | Crew faction trait applies as stat modifier; visible in ship management screen |
| PRD003-REQ-076 | Mixed-Universe Crew Composition: Crews are NOT faction-pure; mixed crews unlock encounter options | MUST HAVE | Crew members have `species`, `faction_origin`, `skills[]`, and `morale_modifier`; mixed crews unlock faction-specific options |
| PRD003-REQ-077 | Crew Morale System: Morale affected by faction composition vs current standings; extreme penalties cause desertion | SHOULD HAVE | Morale score per crew calculated per arc transition; low morale triggers warning events; zero morale triggers desertion |
| PRD003-REQ-078 | Crew Encounter Unlocks: Having crew from specific factions unlocks unique encounter options | SHOULD HAVE | Encounter choice conditions can reference crew composition |

---

## Section 6: Faction Conquest & Competition Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-080 | Faction Conquest Drive: Each faction has `conquest_intent` driving strategic behaviour; factions compete with each other | MUST HAVE | Faction AI selects actions based on conquest_intent and current power level |
| PRD003-REQ-081 | Realm Control: Each realm can be influenced by factions; control affects encounter types, trade access, travel safety | SHOULD HAVE | Realm control scores tracked per faction; control affects gameplay when player enters realm |
| PRD003-REQ-082 | Power Balance Display: Faction status screen shows relative power standings | SHOULD HAVE | Power ranking is visible; player can see which factions are rising/falling |

---

*Cross-references: See PRD-001 for ship and encounter system requirements. See PRD-002 for story arc and dialogue requirements. See TRD-003 for entity data models.*

*PRD-003 v0.2 | Whisper Crystals | Creative Development Confidential*
