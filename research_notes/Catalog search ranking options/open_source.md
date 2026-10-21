# Open-source and self-hosted catalog search options

## What can improve text retrieval with the smallest implementation change?

### Takeaway
For the bounded Dressed catalog, evaluate a transparent, source-backed token/attribute ranker first, then SQLite FTS5 as the first indexed text alternative. Both preserve the existing catalog ingestion and API shape. This is a recommendation to test, not a measured winner.

### Cited Findings
- The repository's current `CatalogDatabase.search` filters `status='active'`, matches a whole query as a case-insensitive `LIKE` substring against title or brand, sorts by title and ID, and returns `total`/`nextOffset` with `limit` 1–100. [Dressed source](/Users/nealkotval/Documents/GitHub/dressed/backend/catalog/catalog.py#L233)
- SQLite FTS5 supports tokenized queries, prefix indexes, BM25 ranking with per-column weights, and external-content tables. Its external-content documentation cautions that the FTS index must be updated consistently with the source table on update/delete. [SQLite FTS5](https://www.sqlite.org/fts5.html)
- PostgreSQL full-text search supports `websearch_to_tsquery`, weighted `tsvector` fields and `ts_rank`/`ts_rank_cd`; PostgreSQL identifies GIN as the preferred index type for frequent full-text search. [PostgreSQL text search controls](https://www.postgresql.org/docs/current/textsearch-controls.html); [PostgreSQL text search indexes](https://www.postgresql.org/docs/current/textsearch-indexes.html)

### Inferences
- A good first experiment is to tokenize the normalized query and title/brand/category, score exact title and category matches above partial/brand matches, then tie-break by immutable product ID. Keep the `active` predicate before ranking. This establishes an explainable baseline on the same fixture and judgment set before changing storage.
- An FTS5 implementation can create an external-content virtual table for title, brand and category, add insert/update/delete triggers in the same SQLite transaction as ingestion, query `MATCH`, and order by `bm25(...)` plus product ID. Escape/construct FTS queries deliberately; user text should not be spliced into `MATCH` syntax. Keep `products` as the source of truth and join back to it for status, source provenance and the public DTO.
- PostgreSQL is attractive if the public catalog is already moving to Postgres; migrating the current SQLite prototype only to get text search adds a database service and migration work. An indexed `tsvector` with `setweight` can give title/category more influence than brand, while `status` and freshness remain structured predicates.

### Gaps
- No benchmark establishes the catalog size or request rate at which SQLite FTS5 becomes insufficient.
- The relevance of FTS stemming/tokenization for clothing-specific terms, brand names, sizes and identifiers needs query judgments; no engine feature alone proves relevance.

## What dedicated open-source engines offer, and what do they cost operationally?

### Takeaway
Meilisearch and Typesense add ready-made typo tolerance, filters and ranking controls; OpenSearch has the broadest configurable hybrid-search pipeline. All require a separately operated index and a reliable projection from the canonical catalog.

### Cited Findings
- Meilisearch Community Edition is MIT licensed, self-hostable and supports hybrid search. Its own documentation describes configurable typo tolerance and ranking rules; self-hosting avoids metered Cloud charges but does not remove infrastructure or operations. [Meilisearch open source](https://www.meilisearch.com/open-source); [Meilisearch pricing](https://www.meilisearch.com/pricing); [Meilisearch typo tolerance](https://www.meilisearch.com/blog/typo-tolerance)
- Meilisearch supports user-provided embeddings and hybrid search, so external image/text vectors can be stored with catalog documents. [Meilisearch multimodal guide](https://www.meilisearch.com/blog/multimodal-rag); [Meilisearch hybrid search](https://www.meilisearch.com/products/hybrid-search)
- Typesense server's repository is GPL-3.0 licensed. Its vector-search documentation supports combining keyword and vector searches and using `k`, `page` and `per_page` to paginate within a bounded vector candidate set. [Typesense repository](https://github.com/typesense/typesense); [Typesense vector search](https://typesense.org/docs/30.1/api/vector-search.html)
- OpenSearch is Apache 2.0 licensed. Its hybrid search uses an index, a query plus search pipeline, and either score normalization or reciprocal rank fusion. It supports `search_after` and point-in-time pagination for a stable snapshot. [OpenSearch about](https://opensearch.org/About/); [OpenSearch hybrid search](https://docs.opensearch.org/latest/vector-search/ai-search/hybrid-search/index/); [OpenSearch hybrid pagination](https://docs.opensearch.org/latest/vector-search/ai-search/hybrid-search/search-after/); [OpenSearch point in time](https://docs.opensearch.org/latest/search-plugins/searching-data/point-in-time/)

### Inferences
- Project only public, active, fresh catalog fields into any search engine: `id`, source metadata, approved title/brand/category/attributes, source URL, `lastCheckedAt`, status and optional vectors. On each committed catalog change, upsert or delete by stable product ID. A periodic reconciliation should compare source IDs/status/content hashes with the index, because asynchronous indexing can lag or fail.
- Keep the read-only Dressed API in front of the engine. The backend should enforce status/freshness filters and return the existing public DTO plus an explicit match explanation; the iOS client should not hold an engine admin key. Search engines are derived indexes, so source provenance and exact-product claims must be validated against canonical records before response.
- Meilisearch or Typesense is plausible if typo tolerance and facets materially improve the judged queries; OpenSearch likely carries a higher setup and tuning burden for a 30–50-item evaluation corpus. Validate this with an actual deployment estimate, rather than treating self-hosted as free.
- For pagination, keep the present `offset` contract for the small fixed fixture and deterministic tie-break. For mutable larger indexes, a cursor/snapshot strategy can prevent duplicates or omissions as data changes; OpenSearch supplies PIT plus `search_after`, while Typesense documents bounded vector candidate pagination.
- Legal review should confirm GPL implications before embedding or distributing a modified Typesense server. Merely choosing an open-source engine does not license retailer images, descriptions or feeds.

### Gaps
- There is no Dressed traffic, corpus-growth or hosting target, so no honest monthly operational cost or latency comparison can be stated.
- Exact Meilisearch pagination limits and current self-hosting resource requirements were not verified for this note; check the pinned release docs when evaluating a deployment.
- No engine was exercised against the Dressed fixture, so quality and p95 latency are unknown.

## When would an image/text embedding index be justified?

### Takeaway
CLIP or SigLIP-style embeddings are a plausible later visual retrieval layer, but should be compared against category/text results on licensed product images and held-out judged queries. Similarity scores do not establish product identity.

### Cited Findings
- OpenAI's CLIP project provides image and text encoders for comparing text snippets with images. [OpenAI CLIP repository](https://github.com/openai/CLIP)
- Google's `big_vision` project includes SigLIP code/models under Apache 2.0 unless noted otherwise; the `google/siglip-base-patch16-224` model page identifies an Apache 2.0 license. [Google big_vision](https://github.com/google-research/big_vision); [SigLIP model page](https://huggingface.co/google/siglip-base-patch16-224/tree/main)
- pgvector stores vectors in Postgres, supports exact search by default and approximate HNSW/IVFFlat indexes. Its documentation explicitly notes the speed/recall tradeoff and that approximate filtering happens after index scan unless mitigated. It also documents combining vector and Postgres full-text results through rank fusion or reranking. [pgvector README](https://github.com/pgvector/pgvector)
- Dressed's catalog proposal says to start with category/text filters, test visual embeddings only after a quality baseline, and reserve “exact product” for a verified retailer identifier or source URL; an image similarity score supports “similar.” [Dressed catalog spec](/Users/nealkotval/Documents/GitHub/dressed/docs/catalog-and-recognition-spec.md#L54)

### Inferences
- For a visual experiment, version a single embedding model and preprocessing pipeline; compute product-image vectors only for images Dressed may use, and query with a reviewed garment crop. First constrain candidates by category and active/fresh status, then blend lexical and visual rankings on a fixed judged set. Record model version and image hash so changed images are re-embedded and stale vectors can be purged.
- For a small corpus, exact vector scoring in application code or pgvector avoids approximate-index recall surprises. Add HNSW only when measured scale and latency require it. Evaluate visual recall@5 separately from exact-identity precision, source-link validity, stale leakage and p95 query time.
- CLIP and SigLIP model weights/license terms must be checked per chosen checkpoint. Model availability does not grant permission to copy retailer images or upload user photos to a hosted service.

### Gaps
- No Dressed-specific comparison exists for CLIP versus SigLIP or lexical-only ranking.
- The repository has not settled retailer image reuse terms, deployment hardware, expected upload volume or a privacy decision for user images; those determine whether local or hosted embedding is viable.
