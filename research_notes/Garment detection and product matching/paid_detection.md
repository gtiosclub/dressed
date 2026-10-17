# Paid garment detection and visual-search services (2026-10-14)

## Which general-purpose paid APIs can locate garments in an outfit photo?

### Takeaway
Google Cloud Vision and Amazon Rekognition can return multiple labeled object boxes, but neither documented general-purpose API promises garment-level segmentation or reliable category detail for layered outfits. A garment-specific evaluation set is needed before treating their output as closet candidates.

### Cited Findings
- Google Vision Object Localization returns multiple object names, scores, and rectangular bounds, not pixel masks. [Google object localization](https://docs.cloud.google.com/vision/docs/object-localizer)
- Google charges by feature and image. Object Localization is free for the first 1,000 units/month, $2.25 per 1,000 for 1,001–5 million, then $1.50 per 1,000. A separate Web Detection call is $3.50 per 1,000 in the middle tier. [Google pricing](https://cloud.google.com/vision/pricing)
- Google Vision online request images are processed in memory rather than persisted to disk, are not used to train Vision, and are not made public; async batch images are briefly stored. [Google data usage](https://docs.cloud.google.com/vision/docs/data-usage)
- Rekognition DetectLabels returns objects and concepts and gives bounding boxes for common object labels; it can accept image bytes or S3 input. [AWS DetectLabels](https://docs.aws.amazon.com/rekognition/latest/dg/labels-detect-labels-image.html); [AWS image input](https://docs.aws.amazon.com/rekognition/latest/dg/images-s3.html)
- AWS pricing example charges DetectLabels $0.001/image for the first million images/month and $0.0008/image for the next tier. [AWS pricing](https://aws.amazon.com/rekognition/pricing/)
- Rekognition DetectLabels is a non-storage operation, but AWS says images passed to Rekognition operations may be stored and used to improve the service unless the account opts out under the AI services opt-out policy. [AWS non-storage operations](https://docs.aws.amazon.com/rekognition/latest/dg/how-it-works-storage-non-storage.html); [AWS data encryption and usage](https://docs.aws.amazon.com/rekognition/latest/dg/security-data-encryption.html)
- Rekognition Custom Labels trains a business-specific model and may return bounding boxes when the dataset is labeled for object localization. The API response may contain polygons, but this does not establish a garment instance-mask service. [AWS Custom Labels overview](https://docs.aws.amazon.com/rekognition/latest/customlabels-dg/understanding-custom-labels.html); [AWS DetectCustomLabels API](https://docs.aws.amazon.com/rekognition/latest/APIReference/API_DetectCustomLabels.html)
- Custom Labels charges for training hours and for inference-unit running hours, including idle time; one minimum inference unit is required when a model runs. AWS's own example prices one inference unit at $4/hour. [AWS Custom Labels pricing](https://aws.amazon.com/rekognition/pricing/); [AWS running models](https://docs.aws.amazon.com/rekognition/latest/customlabels-dg/running-model.html); [AWS autoscaling announcement](https://aws.amazon.com/about-aws/whats-new/2022/08/amazon-rekognition-custom-labels-supports-autoscaling-inference-units/)

### Inferences
- Generic APIs are cheap baselines for candidate labels and boxes, especially a low-volume trial, but a detector trained on outfit photos is more plausible for separating overlapping shirt, coat, trousers, shoes, and accessories.
- AWS Custom Labels' hourly minimum is ill-suited to sporadic consumer uploads unless jobs can be batched into limited running windows.

### Gaps
- Official docs do not publish garment-specific precision or recall for these APIs on real outfit photos. Their outputs must be benchmarked against Dressed images.

## Which platform can host a custom clothing detector or segmenter?

### Takeaway
Roboflow is a practical managed experiment and deployment platform for a labeled custom detector or instance-segmentation model. It supplies the model plumbing, not a verified ready-made fashion matcher.

### Cited Findings
- Roboflow documents classification, object detection, instance segmentation, and semantic segmentation, with serverless, dedicated, and self-hosted deployments. [Roboflow Inference](https://inference.roboflow.com/quickstart/roboflow_ecosystem/)
- Since September 18, 2026, Roboflow's serverless API bills per image according to model; local self-hosted inference no longer consumes Roboflow credits. [Roboflow change announcement](https://roboflow.com/blog/making-it-easier-cheaper-to-deploy-with-roboflow)
- Its current pricing lists a $0 tier with 10 credits monthly, Core from $39/month with 20 total credits, prepaid credits starting at $4, and on-demand credits at $6; specific model rates vary. It advertises enough free credits for about 80,000 RF-DETR Nano inferences, not a universal rate. [Roboflow pricing](https://roboflow.com/pricing)
- Roboflow says workspaces/models are private by default, but Core content may be used to improve products or included in licensed datasets unless opted out; Enterprise content is excluded. Data-sovereignty selection and custom DPA are Enterprise features. [Roboflow pricing and governance](https://roboflow.com/pricing)
- Some self-hosted model weights need separate commercial licenses; Roboflow-hosted models receive a commercial license under its plans. [Roboflow pricing and model licenses](https://roboflow.com/pricing); [Roboflow licensing](https://roboflow.com/licensing)

### Inferences
- Roboflow is attractive for a pilot because Dressed can change between hosted and self-hosted endpoints while iterating on labeled data; commercial model/weight rights and data opt-out should be settled before private user images are used.
- Segmentation is useful for clean item cutouts; bounding boxes may suffice for selecting review candidates and generating initial crops.

### Gaps
- Current public pricing page does not render exact per-image rates for every selected model in static text; quote the chosen model's live rate before budgeting.
- No independent, Dressed-specific garment accuracy benchmark is provided.

## Which fashion-specific vendor combines item detection with product matching?

### Takeaway
Syte is the clearest documented all-in-one fashion visual-search service found: it detects multiple objects and returns similar offers from a merchant's catalog. This is catalog similarity, not proof of an exact product identity across the entire web.

### Cited Findings
- Syte's Camera API documents `bounds` for objects with categories and coordinates and `offers` for similar catalog items sorted by similarity; developer credentials require contact. [Syte API documentation](https://developers.syte.ai/)
- Syte advertises multi-object detection and fashion attribute recognition, offered through API, JavaScript, and ecommerce plugins. [Syte Visual Discovery Suite](https://www.syte.ai/visual-discovery-suite/)
- ViSenze's first-party SDK documents fashion search app types and an automatic object-detection option that detects and searches the main object in an image. [ViSenze product-search SDK documentation](https://github.com/visenze/visearch-sdk-java/blob/master/docs/product-search-api.md)

### Inferences
- Syte is worth a vendor demo if Dressed intends to show shoppable matches from participating retail catalogs soon. Its integration appears tailored to retailers with catalog feeds, so Dressed should clarify catalog access, outbound-link rights, and whether a multi-retailer mobile app is supported.
- ViSenze is another vendor to evaluate, but the cited SDK establishes main-object search rather than multi-garment segmentation.

### Gaps
- Public first-party sources reviewed did not provide self-serve pricing for Syte or ViSenze, guaranteed exact-SKU match accuracy, catalog coverage for Dressed, or private-photo retention terms. These require vendor quotes and contracts.

## Can a paid API identify the exact retail product from an arbitrary photo?

### Takeaway
The documented APIs mainly return visual similarity against either web image references or an indexed product catalog. Exact SKU identification requires matching evidence, product-feed coverage, and explicit uncertainty handling.

### Cited Findings
- Google Vision Web Detection returns full/partial image matches, pages containing them, and visually similar image URLs; these are web-image references, not a verified SKU database. [Google Web Detection](https://docs.cloud.google.com/vision/docs/detecting-web)
- Google Vision Product Search searches similar products from a configured product set, so the developer needs an indexed catalog. [Google Product Search](https://docs.cloud.google.com/vision/product-search/docs/searching)
- Syte `offers` are similar items from *your catalog*, sorted by similarity. [Syte API documentation](https://developers.syte.ai/)

### Inferences
- Dressed should show candidate labels such as “similar products” unless a merchant feed, exact image match, or other provenance confirms a specific SKU; the object crop and product search are separate pipeline stages.
- A fair pilot compares detection recall, review corrections, top-k relevant matches, exact verified SKU hit rate, latency, per-image cost, and privacy on the same outfit-photo set.

### Gaps
- No source reviewed established an API that guarantees exact product identity from an arbitrary social image with universal retailer coverage.
