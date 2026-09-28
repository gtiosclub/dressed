# Three subteams

| Label | Owns | Primary output | Collaborates with |
| --- | --- | --- | --- |
| `data` | Shared schema stewardship, Firebase rules/adapters, private persistence, capture/import pipeline and its review UI, tagging and recommendation logic | Validated owned records, media references, stable service contracts | viz on placements/avatars; social on published snapshots and retrieval |
| `viz` | Authenticated app shell, My Closet UI, reusable garment cards, outfit picker/canvas and avatar visualization | Views using mock/repository contracts; normalized outfit placements | data for persistence/session contracts; social for reusable cards |
| `social` | Profiles, OOTD publication/feed, saved posts, Discovery/Search UI and social repository behavior | Publishable snapshots and community interactions | data for rules/storage/query infrastructure and retrieval |

Each ticket has exactly one primary label. Cross-team consultation belongs in the body, not competing primary labels. `data` is not a catch-all for every method that calls Firebase: social owns Post/SavedPost/UserProfile behavior while data owns common storage/auth boundaries and the shared contract review. viz owns the Outfit/Avatar shapes; data owns their database adapter. Both review contract changes.

Do not infer individual GitHub handles or assign students from first names. Team membership is still unconfirmed. Nicole was named for similarity recommendations; that ticket belongs to data with social as its consumer.

## Handoffs

1. data publishes shared templates and protocols; viz/social use fixtures rather than duplicate types.
2. data emits reviewed ClothingItem records; viz displays them and emits Outfit placements.
3. data persists private outfits; social publishes separate immutable garment/media snapshots.
4. data returns scored similar-item candidates with provenance; social renders them without claiming exact identification.

See [backend schema map](../backend/schemas/README.md) for per-entity contract ownership. Teams do not correspond to three top-level tabs: data owns the Camera import flow; viz owns My Closet and the shell; social owns Discovery.

## Feature folders (SideQuest-inspired)

Use `Common/Models` for shared schemas and future feature `Views` / `ViewModels` pairs. viz primarily works in Closet/Outfits and the shell, data in Camera and common Firebase adapters, social in Discovery/Profile. Folder names describe features, not student rosters. Existing auth code stays in place until its shell ticket.
