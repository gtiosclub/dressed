# Hybrid retailer import implementation

The accepted direction is **shared links for broad capture, on-demand shopping search for discovery, and approved feeds for persistent inventory**. This work supports [#177](https://github.com/gtiosclub/dressed/issues/177), [#178](https://github.com/gtiosclub/dressed/issues/178), and [#212](https://github.com/gtiosclub/dressed/issues/212); it does not complete their UI or live-source acceptance criteria.

## Sequence and acceptance

1. **Backend experiment (this slice).** Implement a bounded SerpApi client and offer resolver, saved-response replay, per-query evaluation output, and offline JSON-LD/Open Graph extraction for supplied product HTML. Verify errors, request budgets, missing fields, unsafe URLs, and ambiguous products using synthetic fixtures. No provider key exists in the current shell, so live quality remains unmeasured.
2. **Coverage trial.** Run 20 queries from the checked-in manifest and collect 30 real, permitted shared links: ten Pacsun, ten eBay, ten Depop, including unavailable and variant-ambiguous examples. Record blocked/unsupported pages honestly. Do not replace them with synthetic successes. An operator configures the provider key and chooses a request cap before running. Evaluate retailer URL correctness, relevant top-five results, image availability, price correctness, variant ambiguity, latency and requests per useful offer. Human judgments stay separate from automated presence metrics.
3. **Reviewed app integration.** After the trial, add an authenticated backend adapter behind the existing catalog/search and product-link review services. Preserve edit/cancel/manual fallback, explicit Wishlist confirmation, stable identities and account isolation. Exercise real sign-in and the entire flow on an iOS simulator. No UI integration is implemented in slice 1.
4. **Durable sources.** Request Pacsun catalog access through Impact and eBay Browse production access. Review each source's image display/storage/indexing and freshness rules. Alternatively pilot a consenting merchant's CSV. Feed configuration belongs to the backend, not untrusted feed content. Partial search results must never age unrelated products out.
5. **Contributions and passive discovery.** Add opt-in public link/tag contributions separate from private saves. Merchant-owned images require explicit contribution rights. Scheduled agents run bounded saved searches, deduplicate and suggest tags; actual source evidence supplies price, availability and URLs. No autonomous retailer crawler is part of this plan.

## Decisions

- Initial experiment: US shopping queries, English, SerpApi as a replaceable provider. Geography is an experiment setting, not a worldwide coverage claim.
- Search candidates persist in a local discovery staging database with per-run observations; they are not automatically imported `CatalogProduct` rows. Sanitized provider responses and normalized reports are archived for offline replay. This avoids treating Google comparison links as retailer listings or mixing uncertain display rights into the public catalog. Shared-link extraction also records candidates and field evidence. Repeated discoveries keep one provider-scoped candidate and retain observation history.
- A resolved merchant URL is **unverified** until a person checks its destination and variant. Search price is an observed quote, not a promise of current stock. Missing currency remains missing.
- One product may resolve to several merchant offers. Each offer keeps its own URL, title, seller, price and evidence. Never attach one merchant's price to another merchant's URL.
- Shared-link extraction uses supplied HTML only in this slice. Network acquisition needs source approval and an SSRF-safe fetcher (DNS/address validation at connection time, redirect revalidation, size/time limits). Depop defaults to manual link capture; no scraper bypass.
- Keep `ClothingItem` unchanged. Wishlist saves remain private and explicit. Public contributions, catalog offers and private closet records are separate types.
- Provider secrets remain backend environment variables. Request counts are hard per invocation; they are not a monthly billing cap. No automatic retries or pagination.

## Source gates

| Source | Next action | Current evidence |
| --- | --- | --- |
| Pacsun | Ask Impact program for catalog, image and native-app use access | [Official affiliate link](https://www.pacsun.com/content/site-map.html); feed availability unconfirmed |
| eBay | Apply for production Browse access; implement compliant display/cache | [Production requirements](https://developer.ebay.com/api-docs/buy/buy-requirements.html), [license](https://developer.ebay.com/develop/api-license-agreement) includes display separation and freshness constraints |
| Depop | Private shared links or participating seller integration | [API](https://partnerapi.depop.com/api-docs/) is private and seller-oriented |
| Shopping search | Measure coverage and review downstream use before public release | [Shopping response](https://serpapi.com/shopping-results), [offer resolution](https://serpapi.com/google-immersive-product-api) |

## Release gates still open

Live coverage and cost measurement; source-specific reuse approval; human quality thresholds after baseline; authenticated hosted service and durable quota; native review integration and simulator checks; freshness/removal handling; public-contribution moderation. Ownership of these follow-up integrations is TBD. Existing GitHub assignments are unchanged.

## Verification of slice 1

On November 16, 2026, all 26 catalog and experiment tests passed locally. Synthetic
CLI replay evaluated two queries, including one empty result, and resolved one
merchant offer with zero network requests. The supplied-HTML CLI returned title,
category, image URL, price, currency and availability with field evidence and
mandatory review. An initially malformed example fixture was caught by output
inspection, covered with a regression test, corrected and rerun successfully.
The live command without a key exited before making a request. CI now includes
the offline Python suite; its remote run has not been observed. No SwiftUI code
changed in this slice, and no native UI verification or live-provider coverage is
claimed.

See [experiment commands](../backend/catalog/README.md#hybrid-import-experiment) and [research](../reports/Dressed%20real%20product%20imports.md).

## November 17 accumulation update

Neal requested that gathered data accumulate into a reusable database. Search and
supplied-HTML extraction now automatically save local discovery candidates and
per-run evidence; output paths are optional additional copies. Synthetic runs use
a separate database. The first live Pacsun search returned ten candidate products,
each with an image URL and quoted search price, but no resolved merchant offers.
Those ten records and their original observation timestamp have been preserved.
The earlier run did not save raw responses; the new archive path does. Merchant
resolution was subsequently diagnosed from a saved response: Google's comparison
URL contained unescaped query spaces and store links were relative `/goto`
redirects. The parser now encodes Google query spaces and retains redirect offers
as `pendingOffers`, with merchant name and quoted price but no claimed direct
product URL. Offline replay recovered three offers for the first product (PacSun,
Nordstrom, TikTok Shop) and updated live staging using the original observation
time. No additional API requests were made during that replay.

A bounded Google-only redirect resolver now reads HTTP Location headers without
fetching retailer destinations. It resolved all three captured store offers to
merchant URLs. Future live shopping runs perform at most three such requests by
default (`--max-redirects`), independently of the SerpApi request cap. The saved
response and redirect evidence can both be replayed without network access.
URL resolution does not verify product identity, variant, current price or stock.

The shared `RetailProduct` Codable contract now represents multiple photo
references, brand/description/category, identifiers and attributes, explicit
variants, variant-option groups, merchant offers including price ranges, and field
evidence. Search and supplied-HTML extraction serialize this object into local
discovery records. The live Pacsun example retains four detail photos, brand,
variant-option groups and three resolved store offers. Missing descriptions and
unknown variant choices stay empty. This is backend/schema work; the native link
review screen still needs an authenticated enrichment service and rich review UI.

Development moved to local `main` at Neal's request. Existing uncommitted work was
backed up in stash `f69081e33dbca2558fe44392a8e748e7b1bd3e71` before switching.
Conflicts were reconciled with main's newer Discovery/OOTD and Avatar navigation,
retaining CameraCaptureView, post-publish feed refresh, and profile editing access.
The full app build stalled before compilation; merged UI behavior is unverified.
The backup stash and original feature branch remain recoverable. No commits or
pushes were made; local main has not been advanced to the newer origin/main.

The intended acquisition flow is `search / user link / approved extraction / feed /
contribution → evidence archive → deduplicated discovery candidate → validation →
public catalog projection`. The current automatic collectors are the bounded
search CLI and supplied-HTML parser. A source-approved URL fetcher, scheduled
agentic searches, contribution endpoint and cloud database synchronization are
follow-up work. No uploader's private Wishlist is silently published.

## Live Discovery catalog (November 17, 2026)

`main` now includes the merged Data/Social/design-system work and the retailer
import tools recovered from the preserved local-work stash. The old stash remains
available; unrelated camera/cloud experiments were not blindly replayed over newer
shared implementations.

Discovery's existing For You/Friends outfit routing is preserved. For You adds a
Shop retailers shelf with one product per category and retailer variety. See all
opens the searchable product grid. Details show the source description, remote
photo gallery, variant options, observed available-variant price/range with its
actual currency, and a retailer button. No catalog item is silently added to a
closet or wishlist. This additive shelf has no supplied Figma frame; it reuses the
existing design-system typography, color, spacing, and controls.

Normal launches use `FirebaseCatalogService` against `out-fitted/catalogProducts`.
Demo products require explicit `-demoCatalog` or fixture-authentication flags.
An explicitly configured catalog HTTP endpoint still overrides Firebase. Reads
are bounded to 200 documents (the seed has 80); growing beyond that needs server
pagination/search. Existing Firestore rules were backed up, compared to the local
baseline, then updated only with authenticated catalog get/list (maximum 200) and
no client writes. Raw responses and deployment receipts remain in ignored local-data.

### Existing outfit image repair

The three `demo_front_*` published records referenced absent Storage objects, and
`PostArtwork` was a placeholder that never fetched media. Their original matching
`DemoFront*` sample assets were recovered and are now used only for those exact
IDs with author `dressed_demo`. Other posts use an injected, cached Storage loader
restricted to `posts/{authorId}/{postId}/composite.jpg`; missing/denied media has a
clear fallback. This does not publish private closet media or change Storage rules.
Real post publication still requires deployed Storage and a publication workflow.

### Verification

- 49 Python catalog tests and all 16 Firebase emulator access tests pass.
- All 80 saved records decode through the exact Swift catalog models; all eight
  categories have ten records and retain rich metadata through Codable roundtrip.
- Signed simulator launch restored a real Firebase session (no mock auth flags).
  For You displayed live retailer photographs/prices and the three restored outfit
  images. See all, product detail/gallery/options, and Allbirds search (five shoe
  results) were exercised. The store button handed off to lucyandyak.com in Safari.
- Search initially opened without keyboard focus; the reproduced issue was fixed
  by focusing on appearance, and the search/return flow then produced results.
- SwiftLint is unavailable locally. Existing ProfileView actor-isolation warnings
  remain; the Debug build succeeds in the project's current Swift language mode.
