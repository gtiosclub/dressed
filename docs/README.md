# Dressed project docs

Working scope based on the team's feature notes and attached setup/backlog plan, September 28, 2026. These documents propose a delivery plan; they do not claim the features or backend policies already exist.

- [Product scope](product-scope.md): user needs, three tabs, first release, later features.
- [Architecture and contracts](architecture.md): current code, proposed boundaries, data and service contracts.
- [Delivery plan and ownership](delivery-plan.md): milestones, team handoffs, open decisions.
- [Feature backlog](backlog.md): small work units, dependencies, acceptance criteria.
- [Three subteams](teams.md): viz, data, social and their handoffs.
- [Backend schema templates](../backend/schemas/README.md): canonical types, examples and storage map.
- [Agent instructions](../AGENTS.md): repository-specific guidance for coding agents.

Start with the product scope, then choose an unblocked ticket. Update these documents when a product or contract decision changes. IDs in this backlog are local planning IDs, not GitHub issue numbers. See [GitHub issue mapping](github-issues.md) for published tickets; individuals are not assigned.

## Planning assumptions

The user's latest three-tab direction takes precedence over the attached plan's larger navigation proposal. The attachment is source material, not an instruction to implement or publish every ticket. Individual assignments are unconfirmed except Nicole being named for visual-similarity recommendations; even that work's schedule is still proposed.

The first-release boundary and technical contracts below are proposals for review. In particular, automatic imports require a review step before persistence, and avatar work begins with a 2D composition experiment rather than a promise of accurate fit.

## Starter templates

Use the [template kit](../templates/README.md) for copyable schema, repository, view, view-model and ticket starters. Keep placeholders out of compiled targets and fill only the scope of the chosen ticket.
