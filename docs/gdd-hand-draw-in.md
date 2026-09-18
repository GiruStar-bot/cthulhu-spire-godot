# Mechanic: Hand Draw-In

**Game**: Abyss of R'lyeh (`cthulhu-spire-godot`)  
**Area**: Combat hand (`scenes/combat/Combat.gd`)  
**Version**: 2026-09-18 redesign (player-experience first; not a blind React port)

## Purpose
Animate only cards that newly enter the hand from the draw pile into their fan slot, so the player feels a brief ritual of "summoning" a card without refreshing or replaying motion on existing hand cards.

## Player Fantasy
A card is drawn from the abyss (draw pile) and settles into its seat in the fan. Orbit and timing carry the mood more than VFX.

## Design Pillars (must not violate)
1. Unsettling ritual tone
2. Weight of each card
3. Space for reading / decision

## Input
Hand set diff: appearance of a new card `uid` (turn draw, effect draw, etc.).

## Output
- **New uids**: interpolate from draw-pile anchor → fan landing pose (position, rotation, scale, opacity)
- **Existing uids**: layout update only; **never** replay draw-in

## Success Condition
- Each new uid plays draw-in exactly once
- After landing, fan angle / overlap / hit targets match normal hand
- Card identity stays readable during flight (cost/type not fully hidden)

## Failure State (treat as broken)
- Full hand recreate every refresh → every card flies again
- Layout overwrite mid-tween → landing snap/jitter and misclicks
- Multi-draw stacks so cards are uncountable

## Edge Cases
- Multi-draw: stagger; beyond stagger cap, remaining cards use shortened/zero extra delay
- Play/discard mid-tween: kill tween, continue normal remove flow
- Overflow discard while tweening: rules discard wins; tween may abort
- Failed draw (empty pile): do not start tween
- Drag during tween: allow drag only after land (preferred)

## Tuning Levers `[PLACEHOLDER]`
| Variable | Base | Min | Max | Notes |
|----------|------|-----|-----|-------|
| duration | 0.35s | 0.2 | 0.55 | Ritual vs tempo |
| stagger | 40ms | 20 | 80 | Multi-draw readability |
| stagger_cap | 8 | 4 | 10 | Cap wait time |
| start_scale | 0.42 | 0.3 | 0.6 | Draw-pile size feel |
| start_rot_offset | -16° | -30 | 0 | Twist on summon |
| start | draw-pile node anchor | — | — | Do **not** hardcode vw/vh; follow real pile position |
| ease | ease-out | — | — | Settle into slot |

## Out of Scope (v1)
- Mandatory particles every draw
- Re-fan animation tied to every draw for old cards
- SAN-based random trajectory (optional later: distort only at low SAN)

## Implementation contract (for engineers)
1. Reuse `CombatCard` nodes by `uid`; spawn only for new uids
2. Start draw-in once per new uid
3. Start = draw-pile anchor; end = fan layout pose for that index
4. Honor kill/conflict rules above
5. Tween vs AnimationPlayer is an implementation choice

## Playtest gates
**Pass**: ≥80% observers say it came from the pile; multi-draw countable; veterans don't feel combat became a waiting game (~duration ≤ 0.4s candidate).  
**Fail / revert**: refresh flies all cards; post-land fan glitch causes misclicks; tempo feels wait-heavy.
