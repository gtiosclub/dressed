# Start from a template

These files are intentionally incomplete and live outside the app target. Copy only the pieces your ticket needs, replace every `__PLACEHOLDER__`, and implement the ticket's acceptance criteria. `.swift.template` files are not compiled. No template is a working feature or permission to deploy a backend.

| Team | Start here | Fill in |
| --- | --- | --- |
| data | [Schema](swift/Record.swift.template), [repository contract](swift/Repository.swift.template) | Field meanings, validation, ownership, persistence/error contracts |
| viz | [view](swift/FeatureView.swift.template), [view model](swift/FeatureViewModel.swift.template) | Inputs/actions, layout, loading/empty/error states, mock-driven behavior |
| social | [view](swift/FeatureView.swift.template), [repository contract](swift/Repository.swift.template) | Public snapshot boundaries, pagination, saves, profile/feed states |
| all | [ticket worksheet](planning/ticket.md) | One primary team, inputs/outputs, blockers and observable acceptance |

## How to use

1. Read the linked GitHub ticket and identify its primary team.
2. Check `dressed/Common/Models` before copying Record: reuse an existing schema whenever possible.
3. Copy needed Swift templates into `Common` or the feature's `Views` / `ViewModels` folder. Use the SideQuest-inspired layout in [architecture](../docs/architecture.md).
4. Replace tokens and annotate unresolved decisions with an owner and issue ID. Keep unresolved code out of the app target until it compiles.
5. Add synthetic fixtures, then implement the behavior required by the ticket. A mock is only a preview/test dependency, never a silent production substitute.
6. Run the relevant checks and record which acceptance criteria are demonstrated.

## What remains for students

The schema files are starter contracts. Teams still own schema review, service protocols, validation, migrations, Firebase adapters/rules, extraction, UI and integration. TODO comments name these responsibilities without supplying a finished implementation. Existing enum values and examples are proposals to review, not a database already deployed.

Do not fill a repository method with a fake success, an empty array, or `fatalError` just to make a screen appear functional. Keep service templates protocol-only until the implementation ticket is picked up.

## Keep student work small

Read [officer guidance](../docs/officers/README.md) before assigning work. Use one component or basic function per student ticket, with a plain-language example. These templates are optional aids: a student writing one Firebase function does not need to create a repository framework. Complex choices and integration work use the `lead` label.
