# Writing student tickets

## Choose one small result

A good starting task is one basic backend function, one function that filters or sorts existing data, or one small reusable SwiftUI view. A student should be able to explain the result in a sentence and demonstrate it using a few examples.

Examples that fit:

- Given an owner ID, fetch that person's clothing items and return an array.
- Given a clothing array and a category, return the matching items.
- Given an image, name and category, display one clothing card.
- Given text and a binding, build a search field with a clear button.

Examples that belong to leads:

- Design the database and access rules.
- Build the complete import or outfit-publishing flow.
- Decide how ranking, AI extraction, share extensions or avatars should work.
- Connect app-wide authentication and navigation.

Keep the starter files template-heavy. Explain where the student should fill in code, but do not prebuild the whole assignment. Reuse the shared schemas. A small view does not automatically need a view model, and a single Firebase function does not require the student to invent a repository framework.

## Use complete, plain-language explanations

Start by saying why this piece is needed. Then name what the student will build, what data it receives, what it should do, and what it returns or displays. Add one concrete example. Explain unfamiliar Swift words where needed instead of making the student infer them.

For example, replace “Implement idempotent persistence with ownership-scoped paths” with:

“Write a function that saves one clothing item. The caller gives you an item that already has an ID and an owner ID. Save it in that owner's items collection using the supplied item ID. If the function is called again with the same item ID, update the same document rather than making a second copy.”

Do not use a short technical phrase as a substitute for explaining the job. Conversely, do not bury a simple task under architecture notes that the student is not responsible for.

## What each ticket includes

1. **Why we need this:** a short paragraph connecting the task to the app.
2. **What to build:** one named function or component.
3. **Inputs and outputs:** the supplied values and the expected result, including types where helpful.
4. **Example:** sample data and what should happen.
5. **Where to work:** a suggested file and existing types/components to reuse. Clearly say when a file does not exist yet.
6. **How we know it is done:** two or three things a reviewer can observe.
7. **You do not need to build:** related work the lead will handle.
8. **Getting started:** local preview/sample calls, or the development environment the lead will provide.
9. **Metadata:** one primary label, priority, a stage, related/blocking issues, and an assignee only when confirmed. Do not invent estimates.

Use [the copyable ticket template](../../templates/planning/ticket.md).

## Review before posting

- Could a new member understand the task without knowing the app's entire design?
- Is there one main result rather than a page, service layer or end-to-end feature?
- Are the needed inputs already defined, or explicitly supplied by a lead?
- Does the example make the expected behavior clear?
- Can the student demonstrate it without setting up unrelated features?
- Have we told them what they do not need to implement?
- Is any uncertainty actually a lead decision disguised as a student task?

UI students should use local sample data and show the component in a native simulator or preview. Backend students should use lead-provided development data and return failures to the caller. They should not change production services or access rules to make a function work. Security and integration still matter; the lead owns those tasks separately.
