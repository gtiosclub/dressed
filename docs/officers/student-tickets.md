# Agreed student ticket format

Assign one small backend function, one array operation, or one reusable view. The early tasks in the [SideQuest reference](https://docs.google.com/document/d/1wiEmdK0Y3LPy2bUQQ7BZNhrf8yw1YhgU1M4lPjiMK1s/edit?tab=t.nozbwnwzo21g) establish the intended difficulty. Leads handle system design and connecting the pieces.

## Function tickets

Use **Task**, **Input**, **Output**, **Example**, **Where to work**, and **Done when**. Explain the job in one or two complete sentences, give concrete input/output values, and finish with two or three observable checks. Use [the function template](../../templates/planning/function-ticket.md).

## UI tickets

Use **Task**, **Displays**, **Interactions**, **Example**, **Where to work**, and **Done when**. Explain supplied values and what interactions report to the parent. Do not include fetching, persistence or navigation unless explicitly part of the task. Add a design-reference link when one exists.

End with **PR evidence** and this sentence: “Screenshots of the component are preferred in the PR.” Use [the UI template](../../templates/planning/ui-ticket.md).

## Keep it clear

Use familiar words and complete sentences. “Saving the same ID updates the same document” is clearer than “idempotent persistence.” Include one useful example, not a generic user story. Avoid architecture boilerplate, repeated template instructions and long unrelated scope lists.

Only add dependency, setup or scope notes when needed. Keep team and priority in GitHub labels/project fields and delivery order in the milestone, rather than repeating metadata in the body. A small view need not have its own view model; one database function does not require the student to invent a repository framework.

If expected behavior or shared inputs are undecided, discuss them with Neal before assigning dependent work. See [the decision process](decisions-before-tickets.md). First delivery uses photo selection and manual clothing details; AI extraction is not required to start.
