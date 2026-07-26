# Command: brainstorm

## Purpose

Expand a sparse game seed into a differentiated product concept, researched references, a pitch, pillars, and the first content-architecture draft. MVP is a validation subset, not the implied size of the finished game.

This replaces the older `references` and `concept` split for normal use. Reference analysis is still allowed when the user provides references, but the command should keep moving toward a playable Unity concept.

## Lead

Creative Director

## Supporting Agents

- Producer for scope and next action
- Game Designer for loop and MVP feasibility
- Technical Artist when visual direction matters
- Unity Architect when the idea has obvious technical risk

## Read

- resolved project `.mlgs/state.json` or legacy `.mlgs/state.yaml`
- project `.mlgs/project.md`
- existing `design/references.md`
- existing `design/reference-analysis.md`
- existing `design/concept-package.md`
- existing `design/art/visual-target.json`
- user-provided references, links, files, or idea text

## Write

- project `design/references.md` when references exist
- project `design/reference-analysis.md` when references need synthesis
- project `design/concept-package.md`
- project `design/content-architecture.json`
- project `design/art/visual-target.json` and at least one target image under `design/art/targets/`
- project `.mlgs/state.json`

## Flow

1. Resolve active project. If none exists and the user gave an idea seed, create or propose the smallest internal project workspace and continue drafting. If none exists and there is no seed at all, route to internal `start`.
2. Read owner participation.
3. If the owner gives no idea, present A/B/C/D ideation options:
   - A) genre-first
   - B) fantasy-first
   - C) mechanic-first
   - D) reference-first
4. If the owner gives a rough or clear idea, preserve its promise but do not treat its named mechanics as the complete design.
5. Classify the intended experience as `hyper-casual`, `light`, `standard`, or `deep`. Low participation delegates decisions; it never implies hyper-casual scope. Infer at least `standard` when the owner rejects light play, asks for a reference-led product, or promises 10+ hours; infer `deep` for a 30+ hour promise unless the owner deliberately narrows it.
6. For `standard`/`deep`, a named reference, or a sparse low-participation seed, research the current web before converging:
   - use 3-7 games across direct competitors, adjacent inspirations, and contrast/anti-references
   - prefer sources that expose real systems and progression: official/store pages, developer material, manuals, maintained wikis, and substantive analyses
   - record URLs, access date, observed facts, inferences, what to adapt, and what to reject
   - never invent search results or copy protected expression, names, narrative, layouts, or art
   - if internet access is unavailable, record the blocker; do not pretend research happened
7. Run a divergent expansion pass before selecting one direction. Produce at least three meaningfully different product shapes by varying progression, economy, world/content structure, player decisions, social/collection pressure, and endgame. Reject candidates that only add more items, larger numbers, or prettier presentation.
8. Synthesize the strongest direction into a compact concept package:
   - one-sentence pitch
   - core fantasy
   - target player
   - 3-5 pillars
   - anti-goals
   - moment, session, medium-term, and long-term loops
   - prototype subset versus full-product promise
   - target session and lifetime playtime
   - selected expansion direction and rejected alternatives
   - visual direction
   - Unity feasibility notes
   - risks and assumptions
9. Draft `design/content-architecture.json` with the experience target, research synthesis, four loop horizons, interacting system portfolio, content families, progression arcs, variety/repetition controls, differentiation, and an estimated content-hour budget. Planning will finalize its release-scope mappings.
10. Creative Director and Technical Artist convert the visual direction into at least one representative final-gameplay target image. Record the image, source, target resolution, non-negotiable visual rules, forbidden prototype treatments, and owner approval in `design/art/visual-target.json`. A mood board or HTML prototype alone is not a visual target.
11. Under low participation, autonomously choose and write the strongest coherent direction, record assumptions, and ask only for the concept phase approval.
12. Under medium participation, write the draft and ask for approve/revise.
13. Under high participation, show 2-4 direction options before finalizing major creative choices.
14. Set next action to planning only after the concept, research synthesis, content-architecture draft, and visual target are ready for approval.
15. Record trace.

## Completion

The concept package and researched expansion draft exist, or the owner has one clear next ideation question. A sparse mechanic list renamed as an MVP is not completion.

