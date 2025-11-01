# Pre-commit: minimal run steps

We ship a ready-to-use pre-commit setup for formatting and hygiene.

What's included:
- Python (packages/backend): Ruff formatter + lint (auto-fix)
- Markdown/JSON/YAML: Prettier (auto-fix)
- Generic checks: trailing whitespace, EOF fixer, merge conflicts, JSON/TOML/YAML validity

Where:
- Config: `.pre-commit-config.yaml` (repo root)
- Python config: `packages/backend/pyproject.toml` (see `[tool.ruff]`)
- Prettier ignore: `.prettierignore`

Run it (macOS, zsh):

```bash
brew install pre-commit   # or: pipx install pre-commit

# One-time setup
pre-commit install

# Optional: run on everything once
pre-commit run --all-files
```

That’s it. Commit as usual—hooks will auto-fix and block on remaining issues.
