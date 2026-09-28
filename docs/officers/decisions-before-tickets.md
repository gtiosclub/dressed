# Discuss decisions before assigning work

When the design is unclear, work through it with Neal before turning it into a student ticket. Do not choose a major product behavior silently and put the consequences in a student's acceptance checklist.

Questions that need a discussion include:

- What does an imported item contain, and which fields are required?
- What should happen to a public post when its original closet item is deleted?
- Does the user own an item, or are they saving it to a wishlist?
- Should a shared link import an image, product details, or both?
- What does “similar” mean, and what data can the app search?
- Is the avatar a simple composition tool or an attempt to predict fit?

## Small decision process

1. Describe the user-facing choice in a short paragraph.
2. Offer two or three practical options and explain their consequences in ordinary language.
3. Recommend one when there is enough evidence, while making assumptions explicit.
4. Ask Neal for the decision. Continue unrelated tasks while waiting; do not publish dependent student work as ready.
5. Record the answer below or in the relevant architecture section.
6. Create student tasks only for the now-defined pieces. Keep integration and unresolved work labeled `lead`.

## Current decisions and boundaries

| Topic | Current position | Student impact |
| --- | --- | --- |
| Student task size | One function or small view; use the SideQuest early-week examples | No full-feature delivery responsibility |
| Ticket writing | Plain-language explanation plus input, action, output and example | No shorthand-only requirements |
| First milestone | Photo selection and manual name/category entry; extraction later | No AI dependency for the first closet flow |
| Ticket format | Concise function/UI sections; screenshots preferred for UI PRs | Follow the agreed templates |
| Starter code | Shared schema templates and optional copyable starters | Students fill in the small assigned behavior |
| Complex work | `lead` label and [lead board](https://github.com/orgs/gtiosclub/projects/82) | Student projects stay focused |
| Product navigation | My Closet, Discovery, Camera remains the planning direction | Students build isolated components; leads wire navigation |
| First clothing item | Agreed: id, ownerId, name, category, imagePath, createdAt; private owner record | Save/fetch tickets use this six-field example |
| Other backend records | Draft templates; leads still approve those examples and access rules | Real database checks wait for lead setup |
| Extraction, recommendations, share extension, avatars | Lead planning/integration, not beginner work | Do not assign algorithm or architecture choices to students |

The current starter tickets deliberately use supplied images, sample arrays and caller-provided records. This allows useful work without deciding the advanced features first. A database ticket can be written against the existing schema template, but its real Firebase check depends on lead-provided examples and access (#49 and #51).
