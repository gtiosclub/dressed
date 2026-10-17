# Product image matching for Dressed

## What counts as an exact product match?

### Takeaway
An image can retrieve visually similar products from a known catalog, but its nearest-neighbor score alone does not establish that the item is the same SKU. Treat a product as verified only when the result is backed by a source product ID, retailer URL, barcode/GTIN, or another corroborating identifier; otherwise label it a lookalike or possible match.

### Cited Findings
- Google's Vision Product Search compares a user's image with **the retailer's product set** and returns ranked visually and semantically similar results, not a web-wide guaranteed identity lookup. Its product entries require reference images and product-set indexing. — [Google Cloud Product Search documentation](https://docs.cloud.google.com/vision/product-search/docs?hl=en)
- Google states Product Search scores are **not calibrated across queries**, so one fixed score threshold cannot certify exact identity; it suggests experimenting with thresholds per item label. — [Google Cloud general tips](https://docs.cloud.google.com/vision/product-search/docs/general-tips)
- Product structured data can carry `sku`, `mpn`, `brand`, offer URL, price, and availability, while GS1 identifies a GTIN as a trade-item identifier. These identifiers provide a different kind of evidence than visual similarity. — [Google product structured-data example](https://developers.google.com/search/docs/appearance/structured-data/product-snippet?hl=en); [GS1 General Specifications](https://ref.gs1.org/standards/genspecs/24.0.0/)
- Google recommends 3–8 varied reference images per product and notes that images where the product fills most of the frame give better results. — [Google Cloud Product Search general tips](https://docs.cloud.google.com/vision/product-search/docs/general-tips)

### Inferences
- For a Dressed share containing a retailer product page URL, parse permitted page/product metadata first and use that retailer's stable product ID as the strongest identity clue. For a free-form social image, return ranked **similar** catalog items, with brand/shape/print checks and user review before any exact-match label.
- Product coverage and image rights are the core constraint: no vector index or vendor can return a reliable retailer SKU absent a searchable catalog or source metadata. A catalog also needs live URL, stock, price, variant, and image updates.

### Gaps
- No official source establishes a universal visual score that reliably proves exact SKU identity across brands, photos, and retailers.
- The availability, licensing, and freshness of retailer catalogs for Dressed are business/partnership questions; no source shows that Dressed currently has such feeds.

## Which open-source stack is practical?

### Takeaway
For a small benchmark, crop the garment, embed it with FashionCLIP and a general baseline such as OpenCLIP/SigLIP 2, then search a catalog image index. FAISS is simple for an offline benchmark; Qdrant adds managed or self-hosted filtered search when a live catalog is needed.

### Cited Findings
- FashionCLIP's released model card describes a CLIP architecture fine-tuned on roughly 800,000 Farfetch fashion products; the catalog training images are clean product images on white backgrounds. The card is MIT-licensed and explicitly warns the model was not developed for deployment without studying its capabilities in context. — [FashionCLIP model card](https://huggingface.co/patrickjohncyh/fashion-clip)
- OpenCLIP exposes image and text encoders, normalized embeddings, and a list of pretrained checkpoints; its code is MIT-licensed. Individual model-weight/data terms need separate review. — [OpenCLIP repository](https://github.com/mlfoundations/open_clip); [OpenCLIP license](https://github.com/mlfoundations/open_clip/blob/main/LICENSE)
- The official SigLIP 2 code/model documentation reports gains over SigLIP across image-text retrieval and other tasks; Google's Big Vision repository says its code and models are Apache 2.0 unless noted. — [SigLIP 2 documentation](https://github.com/google-research/big_vision/blob/main/big_vision/configs/proj/image_text/README_siglip2.md); [Big Vision repository](https://github.com/google-research/big_vision)
- FAISS provides dense-vector nearest-neighbor indexes, including exhaustive and approximate alternatives, and is MIT-licensed. — [FAISS repository](https://github.com/facebookresearch/faiss)
- Qdrant supports vector similarity plus payload filters such as category and price; its open-source edition and cloud edition use the same core API. Qdrant Cloud billing is based on CPU, memory, and disk use, with model-inference charges separately where applicable. — [Qdrant filtered search](https://qdrant.tech/documentation/search-patterns/vector-search-filtering/); [Qdrant Cloud](https://qdrant.tech/cloud/); [Qdrant billing](https://qdrant.tech/documentation/cloud-pricing-payments/)

### Inferences
- Minimal prototype: curate a permissioned catalog of perhaps hundreds to a few thousand products with stable product ID, brand, category, variant, image URLs, and source URL; embed each reference image; use FAISS for local ranking; score a held-out set of user photos against known exact products **and** lookalikes; log top-k recall, incorrect exact-match claims, and user correction rate. The catalog size here is a proposed test size, not a vendor requirement.
- A garment crop matters because FashionCLIP's training images are isolated products; an entire outfit photo adds background and other garments. Compare models on actual Dressed photos instead of assuming fashion-specific fine-tuning wins.
- Keep embedding/search behind a backend service if catalog data, credentials, or private user photos are involved; offer a manual no-match path and delete temporary query images under an explicit policy.

### Gaps
- No model-specific evidence here establishes FashionCLIP, OpenCLIP, or SigLIP 2 accuracy on Dressed's exact product and street-photo distribution. Benchmarking is required.
- Model weights and source-image licensing must be checked for each chosen checkpoint and catalog feed; the code license alone does not cover them.

## Which paid products can reduce integration work?

### Takeaway
Google Cloud Vision Product Search has documented self-service product-set matching and transparent per-query/catalog-image pricing. ViSenze and Syte offer fashion-oriented visual discovery, including multi-object shopping, but need a sales and catalog/contract evaluation. Managed embeddings plus vector search are another paid infrastructure route, not a turnkey global product catalog.

### Cited Findings
- Google Vision Product Search supports apparel, matches against uploaded product sets, and can return multiple detected products from one query image. Its published US list price is first 1,000 prediction images and first 1,000 stored images/month free, then $4.50 per 1,000 predictions and $0.10 per 1,000 stored images for the next tier, with other Google Cloud charges possible. — [Google product search overview](https://docs.cloud.google.com/vision/product-search/docs?hl=en); [multi-detection response](https://docs.cloud.google.com/vision/product-search/docs/searching-response); [pricing](https://cloud.google.com/vision/product-search/pricing?hl=en)
- ViSenze markets visual search integrated with catalog search, and its own product-search SDK describes querying a catalog for visually similar products using an image. Its terms say prices are set in an order form; its FAQ routes prospects to sales for a demo or trial. — [ViSenze Discovery Suite](https://www.visenze.com/discovery-suite/); [ViSenze SDK docs](https://github.com/visenze/visearch-sdk-java/blob/master/docs/product-search-api.md); [terms](https://www.visenze.com/terms-of-service/); [sales FAQ](https://www.visenze.com/faq/how-can-i-get-started-with-visenze/)
- Syte advertises multi-object detection, smart cropping, fashion attributes, and visual search; its onboarding page says customers feed their catalog into its platform and requests a demo. — [Syte Visual Discovery](https://www.syte.ai/visual-discovery-suite/); [Syte onboarding](https://www.syte.ai/grow-your-business/)
- Google describes a separate build-it-yourself path: generate image embeddings and search a product catalog with Vertex AI Vector Search. Its Vector Search pricing includes hosting and index build/update costs. — [Google Cloud multimodal search architecture](https://cloud.google.com/blog/products/ai-machine-learning/combine-text-image-power-with-vertex-ai?hl=en); [Vertex Vector Search overview](https://cloud.google.com/vertex-ai/docs/vector-search/overview)
- Qdrant Cloud also offers hosted CLIP image and text embeddings plus a managed vector index, with separate billing for paid inference models. — [Qdrant Cloud inference](https://qdrant.tech/documentation/cloud/inference/)

### Inferences
- Paid shortlist for Dressed: first test Google Product Search if Dressed has a small authorized catalog and needs quick baseline results; ask ViSenze/Syte to run the **same held-out photos and same catalog** and quote minimum spend, mobile/backend API access, data retention/training terms, geography, and feed update cadence. Compare against the open-source stack on top-k retrieval, false exact labels, latency, and cost.
- ViSenze/Syte's retail positioning likely makes them more suitable when Dressed or a partner controls a catalog than for open-web identification of anything seen in a social post. This is an inference from their catalog-based descriptions, not a verified limitation of a negotiated offering.

### Gaps
- Public Syte and ViSenze material found here does not publish a reliable self-service price or Dressed-specific data-retention terms; obtain current quotes and contracts.
- None of these sources verifies access to a universal, current, licensable retailer catalog or an official Google Lens API for arbitrary exact product matching.
