# Studio Policy: Verification And Builds

- Work packages default to task-boundary verification. Aggregate small edits and run focused inner-loop checks only for acceptance-critical or risk-triggered changes.
- Reuse passing evidence until a relevant input changes. Shared contracts, scene/prefab wiring, persistence/configuration, a prior failure, phase gates, or an owner request trigger broader regression.
- Regression breadth never grants packaging authority.
- A new project may run one initial target-platform package validation after platform confirmation and record it in `.mlgs/build-policy.json`.
- After that passes, ordinary development through Beta uses compile, editor, PlayMode, data, and platform-preflight evidence only.
- A later development package requires an explicit request in the owner’s current message. Automatic packages resume only for Release Candidate and Release.
