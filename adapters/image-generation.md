# Image Generation Adapter

Image generation is optional.

## Secret Policy

- Keep real provider config in project-local `studio/image-generation.config.json`.
- Keep API keys out of shared files.
- `.gitignore` excludes `image-generation.config.json`, `*.key`, and `.env`.
- `studio/image-generation.config.example.json` must remain secret-free.

## Workflow

1. Technical Artist writes the prompt from approved visual direction.
2. The user or local adapter selects the provider.
3. Generated images are saved in an approved Unity art path.
4. Prompt metadata is saved without API keys.

## Default Stance

If provider config is absent, create art briefs and prompts instead of attempting network generation.

