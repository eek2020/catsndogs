
# Sheet specs

1172×4192px · 32×32px sprites at 4× export scale (128×128px per frame) · dark background with labelled rows
29 animation rows across 5 categories:

Movement (8 directions) — Walk cycles for all 8 compass directions (down, up, left, right, + all four diagonals DL/DR/UL/UR), plus run cycles and idles. The diagonals use a 3/4 perspective that blends the front and side views with appropriate hat, coat, and face orientation.
Combat — Attack slashes in 5 directions (down, left, right, DL, DR), plus hurt/flinch
Interaction — Talk, laugh, coin flip, drink (tankard)
Special — Victory flourish, sneak crouch (left/right), sleep slump with Z's

Engine integration notes:

Each row maps to a single animation ID — index by (animName, frame)
Frame counts: most are 4 frames; hurt is 3, sleep is 2
The diagonal walk/run rows are drop-in compatible with any 8-direction movement controller
Transparent background on all sprites — paste directly over your tilemap

Death — wide-brim musketeer hat with purple crystal decoration, ornate lion-pommel sword, crystal cluster held in raised hand, shield emblem on chest armour
Blood Paw — massive fluffy mane/ruff, blood-stained claws, anchor-rope hat badge, charm-adorned belt, snarling expression baked into every frame
Nine Lives — tricolour calico patching on coat and face, red headband, teal hat with gold "9" badge, charm necklace with lucky charms
No Tail — dark chocolate Burmese colouring, teal navigator hat with "N" monogram, rapier instead of cutlass (navigator = precision), no tail stub drawn
Silky — silver-white longhair with fluffy chest ruff and face frame, crimson hat with "S" anchor emblem, blue gem + compass charms
Fairy Cartographer — the only humanoid, pointed elf ears, braided updo with leaf pins and blonde streaks, leather pauldron armour, mechanical bee on shoulder, quill and ink bottle, writes in idle/talk states

NPCs:

Tavern Landlord — fat jovial cat, white apron with pocket, tankard in hand (disappears mid-walk), jowls and thinning hair
Merchant — narrow snout, purple fancy waistcoat, gold pocket watch chain, round spectacles, top hat, balance scales in hand, coin bag on belt
Sailor — striped shirt, red bandana with tails, rope coil on arm
Town Guard — dog breed, red tabard over chainmail, plumed helmet, tall spear
Bard — motley split-colour coat (purple/blue), feathered cap, lute with animated strum frames
Street Urchin — child-scale (slightly shorter), oversized eyes, patched ragged shirt, leather satchel

Every sheet uses the same 27-row animation layout as Aristotle and Dave, so they all drop straight into the same Godot SpriteFrames setup.
