# Unity Code Rules

- Prefer `[SerializeField] private` fields over public mutable fields.
- Avoid `Find`, `FindObjectOfType`, and `SendMessage` in production paths.
- Cache components instead of repeated `GetComponent` in hot paths.
- Avoid allocations in `Update`, physics callbacks, and tight loops.
- Keep gameplay rules data-driven where practical.
- Use ScriptableObjects for content/config when content is authored or generated.
- Keep UI code separate from core gameplay rules.
- Record test or smoke evidence for production tasks.

