# Delivery plan

## Start with small pieces

The current student work is the [18-ticket starter backlog](backlog.md), with six tasks per team. It replaces the earlier large phase-based student tickets. Students build one view or basic function using provided data. Leads decide the shared behavior and connect the pieces later.

Start view work using local sample images and values. VIZ-03, VIZ-05 and SOCIAL-05 reuse the clothing card from #56. Those students can plan their layout while the card is being built. The other student tickets have no dependency on another student's implementation.

Basic Firebase functions can be drafted against the supplied model templates. Their live checks wait for approved examples (#49) and development setup (#51). Do not make a student design rules, handle a multi-step import failure or choose the app's database structure to complete a small function.

## Leads connect the pieces

| Outcome | Lead issue |
| --- | --- |
| Approved models and usable sample data | #49 |
| Sign-in and the three-tab shell | #50 |
| Development Firebase access and security | #51 |
| Garment extraction and a manual fallback | #53 |
| A complete reviewed clothing import | #55 |
| Outfit editing connected to saving | #58 |
| Publishing an outfit safely | #59 |

Share extensions, product links, recommendation choices, AI tags, avatars and preference tracking stay in the later lead backlog. Before splitting these into student tasks, discuss the unresolved product and architecture choices with Neal. A long-term feature in the product scope is not an assignment to build that whole feature now.

## Definition of a finished student task

The student can show the requested result using the examples in the issue. A small view has been shown in a native preview/simulator; a plain function returns the expected result for a few inputs; a Firebase function has been tried in the lead-provided development environment. The appropriate checks pass and the lead reviews how the component will be connected. There is no requirement to deliver an unrelated full screen or feature.

Use [docs/officers](officers/README.md) when preparing the next batch. GitHub records live status and assignments. No fixed schedule, point estimates or individual roster has been agreed.
