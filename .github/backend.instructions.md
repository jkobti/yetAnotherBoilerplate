---
applyTo: "packages/backend/**"
---

# Backend folder (Django app) instructions

1. All commands executed in this folder must use the project’s virtual environment via Poetry (e.g., `poetry run …`).
   - For example: `poetry run python manage.py migrate`, `poetry run pytest`, etc.
   - Do **not** run commands using system Python or bypass the Poetry environment.

2. Migrations must always be created using Django’s migration tooling: use `python manage.py makemigrations` (via `poetry run`) rather than writing migration files manually.
   - Hand-editing or manually crafting migrations is not allowed without a very strong reason—and if you do, document why.
   - Before merging changes that involve model/schema updates, run `poetry run python manage.py makemigrations --dry-run` (or the equivalent) to ensure the migration will be generated.

3. Whenever model/schema changes are made (fields added/renamed/deleted), ensure the migration is generated and included in the commit. If no migration is generated, revisit the change.

4. Merge/PR checklist for this folder:
   - `poetry run python manage.py makemigrations --dry-run` passes (no missing migrations).
   - `poetry run pytest` (or `poetry run python manage.py test`, whichever your test suite uses) passes with zero failures.
   - The migration(s) that appear in the `migrations/` folder contain only “auto-generated” operations unless documented otherwise.
