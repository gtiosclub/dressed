---
name: design-proposal
description: Research and write a concise technical design proposal when choosing an architecture, vendor, library, or build-versus-buy approach. Compare viable open-source, paid, and in-house options with engineering time and money, then recommend a path and implementation. Use for a decision proposal, not a feature ticket or implementation request.
---

# Design proposal

Produce a decision-ready page that a project lead can read in about five minutes. Lead with the key architecture points and recommendation; put supporting detail below. The proposal is a recommendation for review, not approval to implement, purchase, deploy, publish, or assign work.

## Ground the decision

- Identify the exact decision, desired outcome, scale, deadline, and constraints. Read the relevant project code, docs, and issue before describing the current system. Distinguish observed behavior from planned contracts; never present a prototype as a deployed service.
- Research a small set of genuinely viable approaches: an in-house build or extension of the current stack, relevant open-source solutions, and paid/managed solutions. If a category has no credible fit, explain why in one sentence. Avoid a long vendor catalog.
- Verify capabilities, licenses, pricing, limits, and maintenance status against current primary sources. Link claims at the point of use and mark the research date. Where evidence is missing, say so; do not manufacture quotes, performance results, or a Dressed-specific bill.
- Compare options against the same requirements and workload. Cover integration and migration effort, data ownership/privacy, operating burden, reliability, lock-in/exit, and the most consequential failure mode. Include the current baseline when it is a realistic option.

## Make costs comparable

For **every** shortlisted option, including in-house and open source, show:

1. **Time to first useful slice:** engineering person-days or weeks, with the main work items and uncertainty range.
2. **Money to launch:** licenses, setup, hosting, and any one-time fees. If engineer time is monetized, state the hourly rate and keep it separate from cash spend.
3. **Ongoing cost:** a monthly estimate or a transparent pricing formula for infrastructure, usage, support, and maintenance labor.
4. **One shared horizon:** preferably 12-month total cost under stated low/base/high usage assumptions when inputs permit it. Show the arithmetic or link a compact calculation. Use a range or “unknown pending quote/measurement” where precision is unsupported.

Separate verified prices from assumptions and estimates. Use the same currency, date, workload, staffing rate, and horizon across rows. Free license does not mean free operation; paid service does not mean zero engineering. Call out material usage thresholds or minimum charges that could change the ranking.

## Page structure

Aim for roughly 600–900 words of main text. Use a short title that names the decision, then these sections in order:

1. **Key architecture points** — 3–5 bullets giving the system boundary, data flow, trust/security boundary, and the highest-impact constraint. State what exists versus what is proposed.
2. **Recommendation** — one or two sentences naming the preferred option, why it wins for the stated stage, and the condition that would change the choice.
3. **Decision context** — the problem, success measure, assumptions, and non-goals in a few sentences.
4. **Options and total cost** — one compact comparison table. Include in-house, OSS, and paid rows; show time, launch cash, monthly cash plus maintenance time, 12-month cost or formula, and the decisive tradeoff. Link sources in cells or nearby prose.
5. **Technical implementation** — a concise sequence for the recommended path: components and interfaces, data movement and ownership, migration/integration, failure and rollback behavior, and validation. Name concrete files/services only after checking the repo. Keep this at architecture level unless the user requests code.
6. **Decision gates** — up to three unresolved facts or measurable checks, each with a threshold or owner if known. End with the specific decision requested.

Use plain language. A table should carry the comparison; prose should explain the recommendation and important exceptions, not repeat every cell. Move only necessary calculations or evidence into a short appendix or linked source. Do not bury the recommendation under background or add a generic conclusion.

## Deliver the page

Create a real page when the user requests a proposal: use their named destination; otherwise prefer the established project Notion location when connected. If Notion is unavailable, make a reviewable Markdown page in the requested project location and state where it is. Respect existing page conventions and avoid duplicating a page on the same decision. Share the page link or file path and a one-sentence decision summary.

For Dressed, follow the repository `AGENTS.md` and current request boundary. Proposals do not create GitHub tickets, assign students, or change service contracts on their own. Mark unresolved product or ownership choices as TBD.
