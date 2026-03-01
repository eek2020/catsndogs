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
**Politics:** Noble hierarchy — they were rulers before crystals existed and intend to rule after. Aristotle is an insult to their lineage.

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-046 | Faction Entity: `faction_id: lions`, `species: cat_noble`, `alignment: lawful_aristocratic`, `government: noble_hierarchy`, `realm: feline_courts`, `ideology: rule_by_birthright` | MUST HAVE | Faction loads in registry with realm and ideology |
| PRD003-REQ-047 | Faction Traits: Political power, claim of divine right over crystals, diplomatic pressure tactics; demand tribute from Aristotle. Self-declared noblest beasts of the jungle. | MUST HAVE | Traits manifest in diplomatic encounters; Lion NPCs reference birthright claim |
| PRD003-REQ-047a | Faction Unique Abilities: (1) **Diplomatic Pressure** — can force tribute demands that cost crystals if refused, worsening reputation; (2) **Noble Authority** — Lion presence in a region grants +20% political influence over neutral factions there; (3) **Royal Decree** — can temporarily close trade routes to factions they are hostile toward | MUST HAVE | Each ability produces measurable gameplay effect; modelled in `faction_abilities[]` |
| PRD003-REQ-048 | Faction Attributes: `political_influence`, `crystal_claim_status`, `tribute_demanded`, `reputation_scores{}` | MUST HAVE | Attributes track political state; tribute demand triggers Arc 2 event |

### 3.4 The Wolves (Military Elite Dogs)

**Realm of Origin:** Realm of the Canine Order (military elite branch)  
**Ideology:** Dominance through superior tactics and evolutionary right  
**Politics:** Military stratocracy — self-declared noblest beasts of the forest. They do not follow orders — they give them.

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-049 | Faction Entity: `faction_id: wolves`, `species: wolf`, `alignment: lawful_dominant`, `government: military_stratocracy`, `realm: canine_order`, `ideology: dominance_through_tactics` | MUST HAVE | Faction loads in registry with realm and ideology |
| PRD003-REQ-050 | Faction Traits: Strategic and disciplined military force; believe in breaking the crystal monopoly by force; commanders and tacticians for the dog world. The strategic mind behind Canis League military ambition. | MUST HAVE | Wolf encounters are military-focused; Wolf NPCs are tactically competent |
| PRD003-REQ-050a | Faction Unique Abilities: (1) **Tactical Superiority** — Wolf ships gain +20% firepower when initiating combat (first-strike advantage); (2) **Pack Coordination** — multiple Wolf ships in combat share targeting data, reducing player dodge chance by 15%; (3) **Evolutionary Right** — Wolf diplomatic encounters can escalate to combat with no reputation penalty to Wolves | MUST HAVE | Each ability produces measurable gameplay effect; modelled in `faction_abilities[]` |
| PRD003-REQ-051 | Faction Attributes: `military_strength`, `tactical_rating`, `crystal_seizure_intent`, `reputation_scores{}` | MUST HAVE | Attributes drive Arc 4 military events |

### 3.5 Wider Multiverse Factions

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-052 | Fairies Faction: `faction_id: fairies`, `realm: fairy_realms`, `ideology: knowledge_is_currency`. Magical traders and information brokers; offer intel and rare trades; know more than they reveal. Politics: fluid mercantile allegiances. | SHOULD HAVE | Faction loads; fairy encounters provide unique trade and intel options |
| PRD003-REQ-052a | Fairy Unique Abilities: (1) **Magical Espionage** — reveal hidden story flags or NPC true states for a crystal fee; (2) **Enchanted Goods** — fairy trade items grant temporary stat buffs lasting 3 encounters; (3) **Intelligence Networks** — purchasing fairy intel reveals encounter tables for the current region | SHOULD HAVE | Each ability produces measurable gameplay effect; modelled in `faction_abilities[]` |
| PRD003-REQ-053 | Knights Faction: `faction_id: knights`, `realm: knight_kingdoms`, `ideology: order_through_law`. Chivalric orders imposing universal law; see multiverse conflict as chaos requiring correction. Politics: feudal hierarchy. | SHOULD HAVE | Faction loads; knight encounters offer military support with political strings attached |
| PRD003-REQ-053a | Knight Unique Abilities: (1) **Heavy Armour** — Knight crew members grant +10% armour to any ship they serve on; (2) **Disciplined Formations** — Knight-allied fleet combat reduces incoming damage by 10%; (3) **Siege Engineering** — can breach blockaded routes at reduced cost | SHOULD HAVE | Each ability produces measurable gameplay effect; modelled in `faction_abilities[]` |
| PRD003-REQ-054 | Goblins Faction: `faction_id: goblins`, `realm: goblin_warrens`, `ideology: profit_above_all`. Scavengers and engineers; black-market dealers in crystals and ship parts. Politics: anarchic guild cartels. | SHOULD HAVE | Faction loads; goblin encounters provide ship upgrades and black-market crystal trades |
| PRD003-REQ-054a | Goblin Unique Abilities: (1) **Rapid Ship Modification** — goblin engineers can apply upgrades mid-encounter (emergency repairs); (2) **Black-Market Crystal Trade** — buy/sell crystals outside normal trade channels at volatile prices; (3) **Sabotage Services** — hire goblins to reduce a target faction's military_strength or internal_stability | SHOULD HAVE | Each ability produces measurable gameplay effect; modelled in `faction_abilities[]` |
| PRD003-REQ-055 | Aliens Faction: `faction_id: aliens`, `realm: deep_space`, `ideology: varies`. Advanced civilisations with their own agendas and technologies; wild-card allies or enemies. Politics: varies wildly by race. | SHOULD HAVE | Faction loads; alien encounters introduce multiverse scale and unique technology |
| PRD003-REQ-055a | Alien Unique Abilities: (1) **Superior Technology** — alien weapons ignore 25% of target armour; (2) **Unknown Weapons** — alien combat encounters have unpredictable damage variance (±50%); (3) **Deeply Unpredictable Behaviour** — alien diplomatic outcomes have a random modifier that can swing results ±20% | SHOULD HAVE | Each ability produces measurable gameplay effect; modelled in `faction_abilities[]` |

---

## Section 4: Faction Relationship System Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-060 | Faction Reputation Scores: Each faction maintains a reputation score for the player ranging from -100 (hostile) to +100 (allied) | MUST HAVE | Scores initialise per faction defaults; scores update on player actions; scores persist in save data |
| PRD003-REQ-061 | Diplomatic States: Each faction has a diplomatic state derived from reputation score — `hostile` (-100 to -51), `wary` (-50 to -1), `neutral` (0 to 25), `friendly` (26 to 75), `allied` (76 to 100) | MUST HAVE | State labels display correctly in faction status screen; state thresholds are configurable in data files |
| PRD003-REQ-062 | Trade Permissions: Trade access is gated by diplomatic state — `hostile` factions refuse trade; `wary` factions trade at premium; `neutral` at standard; `friendly` at discount; `allied` offer exclusive goods | MUST HAVE | Trade UI reflects pricing modifications; trade refusal triggers appropriate dialogue |
| PRD003-REQ-063 | Mission Availability: Faction-specific missions unlock at `friendly` or higher standing; alliance missions require `allied` standing | SHOULD HAVE | Mission board filters by faction standing; locked missions show requirement |
| PRD003-REQ-064 | Relationship Matrix: Cross-faction relationships exist (e.g., Lions and Corsairs have inherent tension); player actions with one faction can cascade to others | MUST HAVE | Matrix is stored as data; cascading effects are calculated on faction score changes; cascade rules are configurable |
| PRD003-REQ-065 | Faction Relationship Events: Crossing a diplomatic state threshold triggers a narrative event (e.g., becoming hostile with Canis League triggers Dave warning) | SHOULD HAVE | Threshold crossing events are defined in data; events fire once per threshold crossing per session |

---

## Section 5: Faction-Specific Ship & Crew Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-070 | Felid Corsair Ships: Fast, low armour, high manoeuvrability; asymmetric designs; Speed 8, Armour 3, Firepower 5, Crystal Capacity 6, Crew 4 (base template) | MUST HAVE | Ship template loads from data; visual style matches faction; stats affect gameplay |
| PRD003-REQ-071 | Canis League Ships: Bulky, heavy armour, high firepower; naval structure; Speed 4, Armour 8, Firepower 7, Crystal Capacity 5, Crew 8 (base template) | MUST HAVE | Ship template loads; visual and mechanical distinction from cat ships |
| PRD003-REQ-072 | Lion Ships: Ornate, balanced stats with political modifications; Speed 5, Armour 6, Firepower 5, Crystal Capacity 7, Crew 6 (base template) | SHOULD HAVE | Ship template loads; lion ships appear in diplomatic and Arc 4 combat encounters |
| PRD003-REQ-073 | Wolf Ships: Tactical, optimised for combat; Speed 6, Armour 7, Firepower 8, Crystal Capacity 4, Crew 7 (base template) | SHOULD HAVE | Ship template loads; wolf ships are the toughest combat opponents |
| PRD003-REQ-074 | Crew System: Each ship has a crew roster with roles (pilot, gunner, engineer, diplomat); crew quality affects ship performance | MUST HAVE | Crew roles are assigned per ship; role quality modifies associated stat by ±20%; crew data persists |
| PRD003-REQ-075 | Faction Crew Traits: Crew recruited from different factions have faction-specific bonuses (e.g., cat crew: +manoeuvrability; dog crew: +armour) | MUST HAVE | Crew faction trait applies as stat modifier; visible in ship management screen |
| PRD003-REQ-076 | Mixed-Universe Crew Composition: Ship crews are NOT faction-pure. Any captain's crew can contain members drawn from across the multiverse — a cat captain can have goblin engineers, fairy scouts, and a knight navigator aboard the same ship. Crew composition affects ship capabilities, encounter options, and morale dynamics. | MUST HAVE | Crew members are individual entities with `species`, `faction_origin`, `skills[]`, and `morale_modifier` attributes; mixed crews unlock faction-specific encounter options (e.g., fairy crew member enables fairy intel purchases); crew morale is calculated from faction diversity and current faction standings |
| PRD003-REQ-077 | Crew Morale System: Crew morale is affected by faction composition relative to current faction standings — crew from hostile factions have reduced morale; crew from allied factions have boosted morale; extreme morale penalties can cause crew to desert or sabotage | SHOULD HAVE | Morale score per crew member is calculated each arc transition; low morale triggers warning events; zero morale triggers desertion event |
| PRD003-REQ-078 | Crew Encounter Unlocks: Having crew members from specific factions unlocks unique encounter options (e.g., goblin engineer enables emergency mid-combat repairs; fairy scout reveals hidden encounters; knight navigator improves travel speed in knight-controlled regions) | SHOULD HAVE | Encounter choice conditions can reference crew composition; at least 1 unique option per faction crew type |

---

---

## Section 6: Faction Conquest & Competition Requirements

Every faction is actively competing to become the dominant power across all realms. The goal for every faction is conquest and total control of the multiverse. Aristotle sits at the centre because whoever controls the crystals controls who can participate in that race.

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD003-REQ-080 | Faction Conquest Drive: Each faction has a `conquest_intent` attribute that drives their strategic behaviour — all factions are actively competing for multiverse dominance, not merely coexisting | MUST HAVE | Faction AI selects actions (trade, diplomacy, combat) based on conquest_intent and current power level; factions compete with each other, not just with the player |
| PRD003-REQ-081 | Realm Control: Each realm can be influenced or controlled by factions; faction control of a realm affects encounter types, trade access, and travel safety in that region | SHOULD HAVE | Realm control scores are tracked per faction; control affects gameplay when player enters that realm |
| PRD003-REQ-082 | Power Balance Display: Faction status screen shows relative power standings across the multiverse, updated as faction attributes change | SHOULD HAVE | Power ranking is visible; player can see which factions are rising/falling |

---

*Cross-references: See PRD-001 for ship and encounter system requirements. See PRD-002 for story arc and dialogue requirements. See TRD-003 for entity data models.*

*PRD-003 v0.2 | Whisper Crystals | Creative Development Confidential*
