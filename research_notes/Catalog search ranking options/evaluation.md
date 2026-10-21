# Evaluation design and in-house catalog ranking

## What does issue #178 require, and what exists now?

### Takeaway
The deliverable is a reproducible ranking proposal, not production search or exact visual identification. The existing SQLite prototype makes a valid baseline but cannot test meaningful relevance using its three-product fixture.

### Cited Findings
- [Issue #178](https://github.com/gtiosclub/dressed/issues/178) asks for a sample corpus and queries with expected relevant products, category/text baseline versus one richer ranker, top-result usefulness, stale-result leakage, latency, source-link correctness, an example response, and an embedding recommendation.
- The prototype's [`CatalogDatabase.search`](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/catalog.py) filters `status='active'`, applies a substring `LIKE` to title or brand, optionally filters category, sorts by title then ID, and returns `total` and `nextOffset`; it does not calculate relevance scores. It accepts `limit` from 1 to 100 and a nonnegative offset.
- The [synthetic demo feed](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/fixtures/demo-feed.json) contains three products. The [catalog README](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/README.md) states that `.example` links are intentionally unusable.
- The [catalog specification](https://github.com/gtiosclub/dressed/blob/main/docs/catalog-and-recognition-spec.md) calls for public retailer offers separate from private `ClothingItem`, source provenance, a currentness policy, and image embeddings only after a text/attribute baseline. It reserves “exact” for verified product identity rather than visual similarity.

### Inferences
- Use the current `search` implementation unchanged as baseline A so the comparison reflects the real starting behavior. Report the zero-result rate: multiword queries such as `blue denim jacket` require that exact contiguous substring under this baseline.
- Treat the current URL check as *allowlisted-host and syntax validation*, not live retailer-link verification. A `.example` link must fail a reachability check by design; fixture results should exercise the verification logic with test evidence rather than be called valid retailer links.

### Gaps
- The product team has not chosen approved retailer source(s), geography/currency, refresh interval, or variant grouping. These decisions affect freshness and link checks and should remain explicit configuration decisions.

## How should the corpus, labels, and comparison be constructed?

### Takeaway
Freeze a small permissioned or synthetic snapshot, query set, relevance judgments, and evaluation timestamp. Compare both rankers against the same data and run hardware so the result can be repeated.

### Cited Findings
- The issue itself gives `blue denim jacket` as the motivating query and says a different-brand visual lookalike must only be shown as similar with a verified retailer link. — [Issue #178](https://github.com/gtiosclub/dressed/issues/178)
- The local importer creates stable IDs from `(sourceId, externalId)`, records `lastCheckedAt`, and marks a missing product `stale` after one complete scan and `unavailable` after two. Partial snapshots do not age out missing products. — [Catalog implementation](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/catalog.py); [catalog README](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/README.md)
- SQLite FTS5 supports tokenization, prefixes, column weights, and `bm25()` ranking, so a lexical candidate can be implemented within the existing SQLite prototype. External-content indexes require deliberate synchronization, including a rebuild of preexisting rows. — [SQLite FTS5 documentation](https://www.sqlite.org/fts5.html)
- NDCG weights highly relevant items more when they occur near the top and supports a top-`k` cutoff. — [scikit-learn metric documentation](https://scikit-learn.org/stable/modules/generated/sklearn.metrics.ndcg_score.html)

### Inferences
- Proposed files: `backend/catalog/evaluation/products.json` (30–50 synthetic or approved-source products); `queries.json` (8–12 stable query IDs, text, optional category, intent, expected no-result flag); `qrels.json` (query ID, product ID, grade 0–3, short rationale); `run.py` (builds identical fresh DB snapshots, runs A/B, emits CSV/Markdown and environment metadata). Product identifiers must be fixed across runs. These counts are proposed pilot sizes, not established requirements.
- Include categories (tops, pants, dresses, shoes, outerwear), colors/materials/brands only when source-backed, duplicates/variants, one stale and one unavailable product, a product with `availability='outOfStock'`, and intentionally bad/missing source URL cases in a separate negative fixture. Keep relevance judgments independent of each algorithm's output; judge the whole bounded corpus if possible.
- Query strata: exact title; `blue denim jacket` attribute query; synonyms (`jeans`/`denim pants`); brand plus type; broad category (`jacket`); misspelling; mixed attributes (`black leather boots`); no-result; category-conflict; and repeated near-duplicate/variant. Label `3` ideal, `2` good substitute, `1` weakly related, `0` irrelevant. For the jacket query, a blue denim jacket of the named brand could be 3; other-brand blue denim jacket 2; blue non-denim outerwear 1; unrelated shirt 0. These are proposed judgments, to be recorded before running the candidates.
- Baseline A: current `status='active'` plus optional category, title/brand substring, alphabetical tie break. Alternative B: normalize query tokens and reviewed synonyms; retrieve via FTS5 title/brand/sourceCategory (or a simple token scan while the corpus stays tiny), then rerank with explicit category agreement, title token coverage, source-backed color/material/brand matches, and an exact title phrase bonus. Avoid inferred visual attributes in the text ranker. Sort equal scores by stable product ID. Freeze weights before holdout evaluation, or use separate tuning and holdout query subsets.
- Per query: record P@5 (grade ≥2), NDCG@5, zero-result cases, and top-five IDs with explanations. Aggregate macro averages across queries; report each query as well, since 8–12 queries yield volatile averages. Safety checks: stale/unavailable leakage count must be zero on normal search; out-of-stock policy must be explicitly decided and tested; source URL check pass rate requires approved host plus redirect/final-target review on approved live sources. Measure warm and cold server-side p50/p95 latency over repeated calls with the same process and hardware, alongside corpus size and index build time. Never present tiny-fixture latency as production capacity evidence.
- Keep an immutable `evaluatedAt` and input-file hashes in the report. A stale-by-age policy should compare `lastCheckedAt` against a documented threshold; current `status='active'` alone means “present in latest complete scan,” not necessarily recently checked. For normal results, exclude stale/unavailable. Decide separately whether old-but-active or out-of-stock offers are hidden, flagged, or returned only with a warning.

### Gaps
- No real evaluation results exist yet; P@5, NDCG@5, latency, URL pass rate, and which ranker wins must be measured after the corpus and qrels are built.
- No retailer-approved live URL set is documented, so only synthetic URL-validation behavior can be tested now; real link correctness requires an approved source and bounded live checks.

## What technical implementation and result contract should be recommended?

### Takeaway
Build the evaluation harness around the existing backend before changing app search. A scored lexical/attribute ranker is the next in-house candidate; vector search becomes a separate experiment only if held-out text queries or photo matching show a concrete gap.

### Cited Findings
- The current public DTO already includes product ID, source ID/name, product URL, status, availability, and `lastCheckedAt`; `/products` returns `total` and `nextOffset`. — [Catalog implementation](https://github.com/gtiosclub/dressed/blob/main/backend/catalog/catalog.py)
- The [iOS catalog client](https://github.com/gtiosclub/dressed/blob/main/dressed/Discovery/ViewModels/CatalogService.swift) requests up to 100 results in one call, so UI pagination is not yet exercised.
- The [product scope](https://github.com/gtiosclub/dressed/blob/main/docs/product-scope.md) says visual resemblance alone is “similar,” and a real purchase link requires a product source.
- SQLite FTS5 `bm25()` accepts per-column weights; FTS5 query strings have their own syntax, including operators, so raw user text should not be treated as an operator expression. — [SQLite FTS5 documentation](https://www.sqlite.org/fts5.html)

### Inferences
- Suggested sequence: (1) freeze fixtures/qrels and add a reproducible baseline runner; (2) collect A metrics and failure examples; (3) implement B as a standalone evaluator using FTS5 or token scan, with parameterized SQL and escaped/tokenized query terms; (4) compare on held-out queries; (5) only if B wins and service integration is in scope, add a versioned `rankingMode`/`matchExplanation` to the API and deterministic page behavior; (6) test iOS paging and result copy in a separate implementation ticket. This preserves #178's proposal scope.
- Example response proposal: `{ "id": "...", "source": {"id":"fixture-retailer","name":"Demo Retailer"}, "lastCheckedAt":"2026-10-15T00:00:00Z", "match": {"kind":"text", "label":"similar", "explanation":"Matches blue, denim, and outerwear"}, "verifiedProductURL": null }`. Keep `verifiedProductURL` null for synthetic or unchecked links. Return a URL only after source validation; a valid URL does not by itself prove that a photo depicts that product.
- Pagination: choose page size (e.g. 20) and deterministic ordering by score then product ID. Offset is adequate for a frozen snapshot evaluation. A production index that changes between page requests needs a snapshot token or cursor containing the last score/ID and index version to prevent duplicates or skipped results; decide that in the service proposal, not by pretending current offset is snapshot-stable.
- Exact-versus-similar: for text search, `exact` may describe an exact catalog identifier/title query match only if the meaning is clear to the UI; for photo-to-product identity, require a verified retailer product identifier, SKU/GTIN, or verified source URL that is independently tied to the photographed item. A high score, same color, or source URL attached only to a visually similar candidate is insufficient. Favor the simpler UI labels “Catalog results” and “Similar items” until identity evidence exists.
- Image embeddings should be deferred for the first bounded text catalog unless held-out query failures show semantic retrieval is material. Photo-based similar-item ranking can later compare image embeddings against a labeled photo/query set, but it still cannot produce an exact identity label without independent proof. This is a recommendation to evaluate, not a measured conclusion.

### Gaps
- URL redirects, retailer licensing, refresh age threshold, variant grouping, exact-label UI terminology, and acceptable latency targets need product/source decisions. The current repo does not establish those values.
