# Studio Policy: Adaptive Code

- Classify Unity code work as `new-project/lightweight`, `small-existing/standard`, or `large-framework/deep`; an owner or architect may override with a recorded reason.
- New projects establish the smallest useful foundation. Small existing projects inspect neighboring modules and representative examples. Large frameworks require dependency-graph evidence through CodeGraph, Roslyn, or documented structural review.
- Existing code is evidence rather than an absolute constraint. Valid strategies are extend, adapt, replace, create a new foundation, or isolate a new module when the approved tradeoff supports it.
- Production code requires approved framework adoption, presentation architecture, codebase profile, module map, task context pack, change plan, and planned-vs-actual conformance at the intensity appropriate to the project.
- In non-pure-UI 2D games, authoritative gameplay uses scene renderers; UGUI/UI Toolkit owns HUD, menus, overlays, and narrow approved exceptions.
- Avoid scene searches, `SendMessage`, repeated hot-path `GetComponent`, and hot-path allocations.
