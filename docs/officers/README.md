# Officer guide

Use this guide when turning the product plan into tasks for students. A student ticket should explain one small piece of work well enough that someone new to the project can start without designing the whole feature.

- [Writing student tickets](student-tickets.md): task size, language, examples and review checklist.
- [Decisions before tickets](decisions-before-tickets.md): when to discuss the design with Neal instead of assigning an unclear task.
- [Current student backlog](../backlog.md): student tasks grouped by delivery milestone.
- [GitHub issue links](../github-issues.md): the live issues and their labels.

The reference for difficulty and explanation style is last year's [SideQuest Feed and Leaderboard Features document](https://docs.google.com/document/d/1wiEmdK0Y3LPy2bUQQ7BZNhrf8yw1YhgU1M4lPjiMK1s/edit?tab=t.nozbwnwzo21g). Its early tasks ask for things such as fetching records for a user, filtering an array, sorting posts by date, and building a small subview. We use that level of scope and its input/action/output explanations. We do not copy its assignments, branch instructions, app behavior or unsupported performance claims.

## Ownership

Use one primary issue label: `viz`, `data`, `social`, or `lead`.

Student tickets use one of the three team labels. Complex work uses `lead`, without a student-team label. That prevents it from entering a student's label-based project view. Individual students are not assigned until their participation is confirmed.

The `lead` project is not needed for now. Keep lead work in GitHub Issues using the label. Do not create, edit or try to configure a lead board as part of writing student tickets. The empty projects created earlier are not task dependencies.

## Keep the records consistent

GitHub is the source of truth for status and assignment. The Markdown backlog explains scope and links to each issue. When changing a ticket, update both its GitHub body and the matching Markdown entry. Reuse an existing issue when it still represents the same piece of work. If an old feature ticket combines several jobs, leave overall integration with the lead and create smaller related tasks for students.

For project routing, `viz`, `data`, and `social` map to the existing projects with those names. An auto-add workflow may not backfill older issues, and changing a label may leave an old card behind. Check actual board membership when reorganizing issues. Remove only the project card when moving work out of a student board; do not delete or close the underlying issue.
