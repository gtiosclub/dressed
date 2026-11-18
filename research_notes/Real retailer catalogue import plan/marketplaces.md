# Depop and Vinted marketplace access

## What official access exists for Depop listings?

### Takeaway
Depop offers a private Selling API for approved partners and seller-authorized integrations. Its documented read access is to a seller's own products, so it is a possible opt-in seller catalogue route, not a general Depop search feed.

### Cited Findings
- Depop says its Selling API is private, unavailable to the general public, and requires contacting Depop for integration access. — [Depop first listing guide](https://partnerapi.depop.com/api-docs/getting-started/your-first-listing/)
- API keys are for direct partners managing their own shops; OAuth lets a seller authorize a third-party app with `products_read` scope. Credentials require Depop setup. — [Depop authentication](https://partnerapi.depop.com/api-docs/concepts/authentication/)
- `GET /api/v1/products/` returns products the authorized seller has listed. The API reference describes a Selling API for enterprise partners, not a cross-seller public discovery endpoint. — [Depop API reference](https://partnerapi.depop.com/api-docs/reference/)
- Depop product create/update webhooks are best effort, and its guidance calls for periodic product endpoint reconciliation. Stable `product_id` is recommended over mutable SKU. — [Depop API reference](https://partnerapi.depop.com/api-docs/reference/); [Depop webhooks](https://partnerapi.depop.com/api-docs/concepts/webhooks/)
- Depop's general terms prohibit mining, scraping, crawling, and automated access without prior express permission; they also restrict use or sharing of another user's content without consent. — [Depop Terms of Service](https://depophelp.zendesk.com/hc/en-gb/articles/360001773148-Terms-of-Service)
- Its API terms separately prohibit automated scraping without express written authorization and API use for analytics, machine-learning, or AI training without express written authorization. — [Depop API Access Service Terms](https://partnerapi.depop.com/api-docs/terms/)

### Inferences
- A Dressed integration could approach Depop for partner approval and have consenting sellers connect shops, then import only those shops' listings. Product display/image reuse and similarity indexing should be explicit in that permission; `products_read` alone does not settle downstream usage.
- Building an agentic crawler against Depop now would conflict with the documented access rules. An agent can help monitor or validate a partner-approved connector instead.

### Gaps
- No official public API for searching every Depop seller's listings was found in the official documentation reviewed. This is an absence of verified access, not proof that no private agreement exists.
- The public API docs do not establish rights to cache seller photos, republish listing details in Dressed, or create image embeddings for product recommendations. Those need written approval and seller consent as applicable.

## What official access exists for Vinted listings?

### Takeaway
Vinted's current US terms explicitly disallow scraping, crawling, data mining, and copying or commercializing site content without consent. No public listing API or product feed was verified in the official sources reviewed.

### Cited Findings
- Vinted US terms, version applicable October 8, 2026, prohibit external bots/scrapers/crawlers unless authorized, and separately prohibit data mining, screen scraping, and crawling any part of the site. They also require prior written consent to adapt, copy, distribute, or commercialize site content. — [Vinted US Terms and Conditions](https://www.vinted.com/terms-and-conditions)
- The terms permit sharing site information with third parties only if allowed by Vinted's Share button. — [Vinted US Terms and Conditions](https://www.vinted.com/terms-and-conditions)
- Vinted says sellers can hide, edit, delete, or mark listings sold; hidden items disappear from its catalogue and feed, and sold listings can later be deleted. — [Vinted listing management help](https://www.vinted.com/help/4/60-hiding-editing-or-deleting-listings?access_channel=hc_topics)

### Inferences
- A user-initiated share-link workflow with editable, user-supplied details is a lower-dependency Dressed feature than a Vinted-wide catalogue; it should not silently scrape metadata or imply live price/availability.
- If Vinted were to grant a feed/license, frequent delisting and one-off resale inventory would require short freshness windows and reconciliation.

### Gaps
- No official Vinted developer product-discovery API, affiliate feed, or partner listing export was verified in the official materials found. Contact Vinted for a direct agreement before planning an automated listing connector.
- The terms do not specify whether Dressed's particular user-initiated sharing flow or preview rendering is authorized; confirm before using Vinted listing photos or text outside Vinted.
