# Command: brainstorm

## Purpose

Explore a game idea, references, pitch, pillars, and MVP concept package.

This replaces the older `references` and `concept` split for normal use. Reference analysis is still allowed when the user provides references, but the command should keep moving toward a playable Unity concept.

## Lead

Creative Director

## Supporting Agents

- Producer for scope and next action
- Game Designer for loop and MVP feasibility
- Technical Artist when visual direction matters
- Unity Architect when the idea has obvious technical risk

## Read

- resolved project `.mlgs/state.yaml`
- project `.mlgs/project.md`
- existing `design/references.md`
- existing `design/reference-analysis.md`
- existing `design/concept-package.md`
- user-provided references, links, files, or idea text

## Write

- project `design/references.md` when references exist
- project `design/reference-analysis.md` when references need synthesis
- project `design/concept-package.md`
- project `.mlgs/state.yaml`

## Flow

1. Resolve active project. If none exists and the user gave an idea seed, create or propose the smallest internal project workspace and continue drafting. If none exists and there is no seed at all, route to internal `start`.
2. Read owner participation.
3. If the owner gives no idea, present A/B/C/D ideation options:
   - A) genre-first
   - B) fantasy-first
   - C) mechanic-first
   - D) reference-first
4. If the owner gives a rough or clear idea, use it directly.
5. Create or update a compact concept package:
   - one-sentence pitch
   - core fantasy
   - target player
   - 3-5 pillars
   - anti-goals
   - core loop
   - MVP scope
   - visual direction
   - Unity feasibility notes
   - risks and assumptions
6. Under low participation, write a reasonable draft and mark approval pending.
7. Under medium participation, write the draft and ask for approve/revise.
8. Under high participation, show 2-4 direction options before finalizing major creative choices.
9. Set next action to `/mlgs 把当前概念拆成开发计划` when the concept is ready enough.
10. Record trace.

## Completion

The concept package exists or the owner has one clear next ideation question.

