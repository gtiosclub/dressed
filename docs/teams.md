# Student teams and lead responsibilities

Students work on one small function or view at a time. Leads provide the shared decisions and connect the pieces into working features.

| Label | Student focus | Examples |
| --- | --- | --- |
| `data` | Basic backend functions and small import controls | Save one item, fetch clothing, upload supplied image bytes, source buttons |
| `viz` | Small closet/outfit views and simple array logic | Clothing card, category buttons, grid, category filter, selected-item row |
| `social` | Small social views and basic post functions | Post card, profile header, search field, save one post, fetch recent posts |

`lead` is a separate issue label for complex work, including shared schemas, Firebase rules, authentication/navigation, connecting the import and publication flows, AI choices, share extensions and avatar planning. Track these issues on the [lead board](https://github.com/orgs/gtiosclub/projects/82).

The split follows the feature boundary, not a rule that one team owns every frontend or backend file. `data` owns the small closet/outfit data functions and import controls. `viz` owns small closet/outfit presentation pieces. `social` owns small feed/profile pieces and basic post functions. Leads own shared field decisions, security, app-wide state, photo and post publication, and the code that connects student pieces into working screens. See the [ticket feasibility check](officers/ticket-feasibility.md) for current handoffs and blockers.

A task receives exactly one primary ownership label from `viz`, `data`, `social`, or `lead`, plus `frontend`, `backend`, or both for the kind of work. Views and client-side filtering are frontend; Firebase functions and shared data contracts are backend; integration across both gets both. Leads can help any student team without adding a student label to a complex task. Do not infer individual assignments from first names or old team notes.

## What leads provide

Before asking a student to use Firebase, provide an approved example record and development access (#49 and #51). Before asking for a view, provide its input values and what its buttons should report to the parent view. If the product behavior is undecided, discuss it with Neal before assigning the dependent student work.

The code layout stays SideQuest-inspired: shared records in `Common/Models`, with `Views` and `ViewModels` under feature folders. A simple view does not require its own view model. Basic backend functions can live under `Common/Firebase`; students do not need to invent a service framework.

See [the student backlog](backlog.md) and [officer ticket guidance](officers/README.md).
