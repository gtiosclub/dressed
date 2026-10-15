# Dressed project docs

Working scope based on the team's feature notes and attached setup/backlog plan, September 28, 2026. These documents propose a delivery plan; they do not claim the features or backend policies already exist.

- [Product scope](product-scope.md): user needs, three tabs, first release, later features.
- [Architecture and contracts](architecture.md): current code, proposed boundaries, data and service contracts.
- [Delivery plan and ownership](delivery-plan.md): milestones, team handoffs, open decisions.
- [Data roadmap and feature spec](data-roadmap.md): My Closet pieces and outfits, plus Share to Dressed recognition, review, and save flows.
- [Retail catalog and recognition spec](catalog-and-recognition-spec.md): proposed source connectors, product freshness, garment detection, provider evaluation, and catalog matching.
- [Viz roadmap and feature spec](viz-roadmap.md): Closet cards, details, outfit views, and import-result presentation.
- [Social roadmap and feature spec](social-roadmap.md): Discovery feed, post breakdown, saved posts, search, and publication handoffs.
- [Feature backlog](backlog.md): small work units, dependencies, acceptance criteria.
- [Three subteams](teams.md): viz, data, social and their handoffs.
- [Ticket feasibility check](officers/ticket-feasibility.md): unblocked student work and the live-service gates.
- [Firebase testing for students](officers/firebase-testing.md): current project, safe emulator checks, and live setup limits.
- [Backend schema templates](../backend/schemas/README.md): canonical types, examples and storage map.
- [Local catalog prototype](../backend/catalog/README.md): fixture ingestion, SQLite state, read-only demo API, and test commands.
- [Recognition experiment](../backend/recognition/README.md): fixture-backed Google Product Search response adapter and bounded live developer call.
- [SwiftLint guide](linting.md): local lint command, CI behavior, and fix workflow.
- [Agent instructions](../AGENTS.md): repository-specific guidance for coding agents.

Start with the product scope, then choose an unblocked ticket. Update these documents when a product or contract decision changes. IDs in this backlog are local planning IDs, not GitHub issue numbers. See [GitHub issue mapping](github-issues.md) for published tickets; individuals are not assigned.

## Local import prototype

The current `main` working tree has a device-only Share to Dressed and Camera prototype. To try external sharing on a signed device, enable the `group.gtiosclub.dressed` App Group for both the app and Share Extension identifiers in the Apple Developer account, sign both targets, open Dressed and sign in once, then share a saved image to Dressed from another app. Open Dressed to review and confirm. Data is saved only on that device; it is not a Firebase closet sync or the multi-garment extraction described in the [data roadmap](data-roadmap.md). See [architecture](architecture.md) for verified prototype behavior and remaining limits.

## Planning assumptions

The user's latest three-tab direction takes precedence over the attached plan's larger navigation proposal. The attachment is source material, not an instruction to implement or publish every ticket. Individual assignments are unconfirmed except Nicole being named for visual-similarity recommendations; even that work's schedule is still proposed.

The first-release boundary and technical contracts below are proposals for review. In particular, automatic imports require a review step before persistence, and avatar work begins with a 2D composition experiment rather than a promise of accurate fit.

## Starter templates

Use the [template kit](../templates/README.md) for copyable schema, repository, view, view-model and ticket starters. The first Camera, Closet and Firebase ticket files also have source-level outlines at their assigned paths. Those outlines compile but do not implement the tasks; fill only the scope of the chosen ticket.

## Student task size

The student backlog has 40 published small tasks grouped by the agreed roadmap milestones, including 15 independent follow-on tickets added October 8, 2026 and four sprint follow-ups added October 10. Earlier phase-sized assignments have been replaced. Read [docs/officers](officers/README.md) for plain-language ticket writing, examples, ownership and decisions to discuss before assigning work. Complex issues use the `lead` label and the [lead board](https://github.com/orgs/gtiosclub/projects/82).
