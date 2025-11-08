# Feature Flags

This document describes the simple global feature flag system implemented in the backend and consumed by the Flutter web apps.

## Overview

A feature flag is a globally scoped toggle with the following fields:

- `key` (string, unique) – machine name used by clients (e.g. `demo_feature`).
- `name` (string) – human readable title.
- `description` (text) – optional longer context.
- `enabled` (boolean) – when true the flag is considered active.
- Timestamps: `created_at`, `updated_at`.

(Current implementation does not support per-user targeting, variants, or percentage rollouts – these can be added later.)

## Backend Endpoints

Admin (staff only):

| Method | Path                         | Description                                |
| ------ | ---------------------------- | ------------------------------------------ |
| GET    | `/admin/api/features`        | List all flags                             |
| POST   | `/admin/api/features`        | Create a new flag                          |
| GET    | `/admin/api/features/<uuid>` | Retrieve a flag by ID                      |
| PATCH  | `/admin/api/features/<uuid>` | Update `name`, `description`, or `enabled` |
| DELETE | `/admin/api/features/<uuid>` | Remove a flag                              |

Public:

| Method | Path             | Description                                                          |
| ------ | ---------------- | -------------------------------------------------------------------- |
| GET    | `/api/features/` | Returns `{ "flags": ["key1", "key2"], "count": N }` of enabled flags |

## Data Model

Django model `FeatureFlag` in `apps.featureflags.models`:
```python
class FeatureFlag(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    key = models.CharField(max_length=64, unique=True)
    name = models.CharField(max_length=128)
    description = models.TextField(blank=True)
    enabled = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
```

## Admin Portal UI

The Admin Dashboard displays a "Feature Flags" card:
- Shows current enabled flags.
- A "Create Flag" button opens a dialog permitting creation (pre-populated example: `demo_feature`).
- A "Toggle demo_feature" button flips its `enabled` state if it exists.
- "Refresh" reloads from the public endpoint.

All create/update/delete operations are audited via the existing `AdminAudit` model.

## Customer App Usage

The customer app loads flags at startup by watching `featureFlagsProvider` (Riverpod `AsyncNotifier`). Home page gates the "Demo Feature" card with:

```dart
final demoFeatureEnabled = ref.watch(featureFlagSelectorProvider('demo_feature'));
if (demoFeatureEnabled) { /* render card */ }
```

A "Refresh flags" button can refetch without a full app restart.

## Riverpod Implementation (Flutter)

File: `lib/core/feature_flags/feature_flags_provider.dart`
- Fetches `GET /api/features/` once.
- Exposes `featureFlagsProvider` (async set of enabled keys).
- `featureFlagSelectorProvider(key)` returns a boolean for fine-grained rebuilds.

## Adding a New Flag

1. Go to Admin portal.
2. Click "Create Flag", fill key (lowercase, underscores or hyphens), set initial `enabled` value.
3. In client code gate UI with `featureFlagSelectorProvider('<key>')`.

## Removing a Flag Safely

1. Toggle `enabled` to false.
2. Deploy code removing gated block.
3. Delete the flag via Admin UI (or leave disabled for historical record).

## Future Enhancements

| Feature            | Description                                                 |
| ------------------ | ----------------------------------------------------------- |
| Lifecycle states   | `draft`, `active`, `deprecated` for safer cleanup           |
| Percentage rollout | Add `rollout_percentage` and hash-based user bucketing      |
| Segmentation       | Per-user/org targeting via conditions JSON                  |
| Variants           | A/B test variant selection with weighted distribution       |
| Caching            | Add ETag + `Cache-Control` headers; server-side Redis cache |
| SDK alignment      | Adopt OpenFeature-style evaluation responses                |

## Example Public Response

```json
{
  "flags": ["demo_feature", "another_flag"],
  "count": 2
}
```

Missing key implies disabled – clients should code defensively.

## Error Handling

- Admin endpoints return standard DRF validation errors.
- Public endpoint always returns 200 with an empty list on internal errors (current minimal implementation). Future versions may return a 5xx with problem-details payload.

## Security

- Admin endpoints protected by `IsAdminUser` (staff flag on user model).
- Public endpoint exposes only enabled keys (no internal metadata).

## Testing Summary

- `test_featureflags.py` covers public listing and CRUD lifecycle.
- Frontend gating verified manually; future: widget tests ensuring conditional rendering when flag toggles.

## Quick Curl Examples

```bash
# List enabled flags
curl -s http://localhost:8000/api/features/ | jq

# Create a flag (admin token required)
curl -X POST http://localhost:8000/admin/api/features \
  -H "Authorization: Bearer <access>" \
  -d 'key=demo_feature' -d 'name=Demo Feature' -d 'enabled=true'

# Toggle (patch)
curl -X PATCH http://localhost:8000/admin/api/features/<uuid> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access>" \
  -d '{"enabled": false}'
```

## Frontend Refresh Pattern

If a flag is toggled while a user session is active, they can:
- Press the "Refresh flags" button inside a gated component.
- Or implement a global refresh (call `ref.read(featureFlagsProvider.notifier).refresh()`).

---

This system provides a minimal, extensible baseline. Enhance incrementally as needs grow.
