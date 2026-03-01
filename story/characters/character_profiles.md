# Whisper Crystals — Character Profiles

---

## Aristotle — Protagonist

- **Species:** Cat — Felid Corsair captain
- **Faction:** Felid Corsairs
- **Role:** Player character. Leader of the Corsairs. Discoverer and controller of Whisper Crystal production.
- **Personality:** Street cat made good. Self-made before the lions even noticed the crystals existed. Thinks he is the smartest creature in any room — and usually is. Still thinks like a scrappy alley cat even while commanding a fleet. Philosophical, cunning, allergic to being told what to do.
- **Philosophy:** Understand everything, control what you can, survive the rest.
- **Backstory:** Born with nothing. Stumbled upon Whisper Crystals, figured out refining through sheer ingenuity. Built an empire before the Lions even noticed.
- **Core Tension:** Balancing being a pirate (free, chaotic, self-serving) with being the most powerful supplier in the multiverse (responsibility, enemies everywhere).
- **Name Meaning:** The philosopher who believed in understanding the world through observation and reason — a cat who built his empire on knowing things others didn't.
- **Dialogue Tone:** Aristotle's player character context must inform default dialogue tone throughout the game — pragmatic, witty, strategic. Never formal. Never subservient.

### Starting Stats
| Stat | Value | Notes |
|------|-------|-------|
| Cunning | 8 | Primary stat — affects bluff and intel options |
| Leadership | 7 | Crew morale and fleet command |
| Negotiation | 6 | Trade pricing and diplomatic success |
| Combat Skill | 6 | Direct combat effectiveness |
| Intimidation | 4 | Low — Aristotle leads by respect, not fear |
| Stealth | 3 | Low — he's a known figure, not a shadow |

### Arc Progression
- **Arc 1:** Establishing power, proving himself
- **Arc 2:** Defending on three fronts, testing resolve
- **Arc 3:** Political navigation, alliance building
- **Arc 4:** Ultimate choice — what kind of leader will he be?

---

## Dave — Primary Antagonist

- **Species:** Dog — Canis League commander
- **Faction:** Canis League
- **Role:** Primary antagonist. Leading the dog faction's campaign to break the crystal monopoly.
- **Personality:** The most dangerous kind of antagonist — completely ordinary name, completely extraordinary determination. Methodical, loyal to his faction, utterly relentless. He does not hate Aristotle. He simply needs what Aristotle has and will not stop until he gets it. The banality of Dave is intentional. He is not theatrical. He just wins.
- **Motivation:** Break the cats' stranglehold on Whisper Crystals. Achieve energy independence for dogs. Through trade, force, or discovering an alternative.
- **Relationship with Aristotle:** Respect mixed with deep frustration. Does not hate Aristotle — just needs what he has. Their conflict is structural, not personal.
- **Dialogue Tone:** Quiet, direct, almost polite. Contrast with Aristotle's wit and Death's theatricality. Dave's scariest lines should be the simplest.

### Stats
| Stat | Value | Notes |
|------|-------|-------|
| Cunning | 5 | Average — Dave is methodical, not tricky |
| Leadership | 8 | Commands deep loyalty |
| Negotiation | 5 | Prefers action to words |
| Combat Skill | 7 | Strong military commander |
| Intimidation | 7 | Quietly threatening |
| Stealth | 3 | Operates openly |

### Behaviour State Progression
- **Arc 1:** `OBSERVING` — Introduces himself through trade, sizing up Aristotle
- **Arc 2:** `HOSTILE` — Escalates to blockades, raids, diplomatic pressure
- **Arc 3:** `TRADING` — Brief parley, almost respectful moment
- **Arc 4:** `OPEN_CONFLICT` — Full military assault

---

## Death — Secondary Antagonist

- **Species:** Cat — rival Felid Corsair captain
- **Faction:** Felid Corsairs (rival subfaction)
- **Role:** Internal antagonist. Wants Whisper Crystal production for themselves.
- **Personality:** Old world. Theatrical where Dave is quiet. Possibly connected to the Lion hierarchy, possibly a pure rogue — this ambiguity is intentional and must be preserved until Arc 3 reveals it. Sees Aristotle as an upstart who got lucky with the crystals and intends to correct that. Ancient, patient, and completely certain of their own superiority.
- **Motivation:** Take Aristotle's empire. An internal power grab within cat hierarchy. Sees himself as the rightful controller of crystal production.
- **Story Role:** Creates a two-front war — Dave externally, Death internally. Forces alliance choices.
- **Dialogue Tone:** Dark, theatrical, grandiose. Contrast with Aristotle's pragmatism and Dave's banality. Death speaks like someone who has been waiting centuries for this moment.
- **Implementation Note:** Death's true allegiance must be implemented as a hidden story flag (`true_allegiance`) that is `null` until the Arc 3 revelation event sets it.

### Stats
| Stat | Value | Notes |
|------|-------|-------|
| Cunning | 7 | Skilled manipulator |
| Leadership | 5 | Leads through fear, not loyalty |
| Negotiation | 4 | Prefers manipulation to negotiation |
| Combat Skill | 6 | Capable but not primary approach |
| Intimidation | 9 | Primary tool — theatrical menace |
| Stealth | 8 | Operates in shadows until revealed |

### Behaviour State Progression
- **Arc 1:** `HIDDEN` — First glimpse only, watching from shadows
- **Arc 2:** `COVERT_ACTION` — Betrayal, sabotage within corsair fleet
- **Arc 3:** `REVEALED` — True allegiance exposed (Lions / Wolves / Independent)
- **Arc 4:** `OPEN_CONFLICT` — Final power grab attempt

### True Allegiance (Arc 3 Revelation)
Determined by player's investigation choices in Arc 2:
- **Lions:** Death is a Lion agent, working to return crystal control to the nobility
- **Wolves:** Death allied with Wolves, planning a military coup
- **Independent:** Death serves only themselves — pure ambition
