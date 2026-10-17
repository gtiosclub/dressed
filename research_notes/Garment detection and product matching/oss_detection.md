# Open-source garment detection and segmentation

## Which practical approaches can separate garments in an outfit photo?

### Takeaway
For a quick zero-shot server evaluation, compare SAM 3 text-prompted masks against Grounding DINO plus SAM 2; for a smaller deployable garment detector, train a closed-vocabulary model on licensed garment boxes or masks. Apple's Vision classifier alone does not separate garments.

### Cited Findings
- Apple's built-in `VNClassifyImageRequest` classifies an image; Vision can return per-object `VNRecognizedObjectObservation` boxes when supplied a custom Core ML object detector. Create ML object-detector training requires per-image labeled bounding boxes. — [Apple classification](https://developer.apple.com/documentation/CoreML/classifying-images-with-vision-and-core-ml); [Apple detection](https://developer.apple.com/documentation/vision/recognizing-objects-in-live-capture); [Create ML data](https://developer.apple.com/documentation/createml/building-an-object-detector-data-source)
- Grounding DINO is an Apache-2.0, text-conditioned open-set **box detector** with published PyTorch checkpoints; the original repository reports 48.4 COCO zero-shot box AP for its Swin-T checkpoint and 56.7 for Swin-B trained on additional data. These are general-object benchmarks, not Dressed garment-photo results. — [Official Grounding DINO repository](https://github.com/IDEA-Research/GroundingDINO)
- Meta's SAM 2.1 offers point/box-prompted image masks and automatic mask generation, with Apache-2.0 checkpoints and code. It does not itself attach garment category names to its masks; Grounded SAM 2 demonstrates Grounding DINO boxes fed into SAM 2 for grounded segmentation. — [SAM 2 repository](https://github.com/facebookresearch/sam2); [SAM 2 mask generator](https://github.com/facebookresearch/sam2/blob/main/sam2/automatic_mask_generator.py); [Grounded SAM 2](https://github.com/IDEA-Research/Grounded-SAM-2)
- SAM 3 can return masks, boxes and scores from a text prompt such as a garment noun. It has 848M parameters and its official installation requires Python 3.12, PyTorch 2.7 and CUDA 12.6; checkpoints require access approval. It uses Meta's custom SAM License rather than Apache-2.0. — [Official SAM 3 repository](https://github.com/facebookresearch/sam3); [SAM License](https://github.com/facebookresearch/sam3/blob/main/LICENSE)
- Ultralytics YOLO supports object detection and instance segmentation, custom-data training and Core ML export; current YOLO models are AGPL-3.0 or Enterprise licensed. The documented Core ML segmentation export may leave non-maximum suppression to the client. — [Ultralytics model and licensing documentation](https://docs.ultralytics.com/models/yolo11/); [Segmentation training/export](https://github.com/ultralytics/ultralytics/blob/main/docs/en/tasks/segment.md)
- RF-DETR offers Apache-2.0 code and Nano-through-Large weights for object detection and instance segmentation; XL/2XL detection models have a distinct PML license. It accepts COCO or YOLO data for fine-tuning and has a native Core ML export, which its docs label **experimental**. — [Official RF-DETR documentation](https://github.com/roboflow/rf-detr/blob/develop/docs/index.md); [Core ML export](https://github.com/roboflow/rf-detr/blob/develop/docs/exports/coreml.md)

### Inferences
- The fastest proof of concept is likely server-side SAM 3 or Grounding DINO + SAM 2 on a held-out Dressed set, followed by a smaller trained detector if latency, privacy, or per-image cost warrants on-device inference. This is an engineering inference from the official deployment requirements above, not a garment-specific benchmark.
- SAM 3 should be evaluated separately from SAM 2 because text-prompted detection and masking are integrated in SAM 3; SAM 2 requires a box/point prompt or another detector to provide garment semantics.

### Gaps
- No cited primary source establishes garment-specific accuracy, latency, or battery use for these models on Dressed's target iPhones or share-source photos. Benchmark them on Dressed's own consented examples.
- The official sources do not establish that an unmodified general-object checkpoint reliably separates overlapping outerwear, garments obscured by arms, bags, shoes, or tiny accessories.

## What training data and licensing issues govern a garment-specific model?

### Takeaway
Fashion benchmarks can guide evaluation and annotation, but DeepFashion2 is unsuitable for commercial training without new rights; Fashionpedia's annotation license does not grant one uniform license for all source photos.

### Cited Findings
- DeepFashion2 has 491,895 images, 13 clothing categories, 800,732 annotated garments with boxes and masks, and 873,234 consumer/shop pairs. Its categories are apparel-only, with no shoes or handbags among the 13 categories. — [Official DeepFashion2 repository](https://github.com/switchablenorms/DeepFashion2)
- A DeepFashion2 collaborator stated the dataset is for non-commercial research and that no commercial license was available when asked. — [DeepFashion2 maintainer issue](https://github.com/switchablenorms/DeepFashion2/issues/3)
- Fashionpedia defines 27 main apparel categories, 19 parts and 294 attributes with segmentation masks. Its ontology/annotations are CC BY 4.0, while images must follow the original hosts' terms, including Flickr, Unsplash and other sources. — [Fashionpedia paper](https://arxiv.org/abs/2004.12276); [Fashionpedia data license](https://fashionpedia.github.io/home/data_license.html)
- Create ML needs labeled object bounding boxes; Ultralytics segmentation training needs polygons; RF-DETR accepts COCO JSON or YOLO-format annotations. — [Apple data guide](https://developer.apple.com/documentation/createml/building-an-object-detector-data-source); [Ultralytics guide](https://github.com/ultralytics/ultralytics/blob/main/docs/en/tasks/segment.md); [RF-DETR docs](https://github.com/roboflow/rf-detr/blob/develop/docs/index.md)

### Inferences
- A Dressed-specific benchmark should include full outfits, flat lays, screenshots, ecommerce photos, occlusions, and the taxonomy actually used in the app. License-cleared user-consented or directly licensed examples would avoid the DeepFashion2 commercial restriction.
- Begin with boxes if the product only needs candidates for review; collect masks if cutouts or region-specific matching materially improve the experience. The annotation burden and model choice differ.

### Gaps
- No source above quantifies how many labeled Dressed photos are needed to meet a useful garment recall threshold; this depends on categories, image distribution and target model.
- Fashionpedia's per-photo licensing must be audited before using images for commercial training; its CC BY annotation grant is not a blanket image grant.

## How does object detection relate to exact product matching?

### Takeaway
Detection yields garment regions and broad labels. Exact SKU matching is a separate retrieval problem that requires a current, licensed product catalog with searchable images and identity evidence.

### Cited Findings
- DeepFashion2 explicitly treats consumer-to-shop retrieval as a separate task after detection and counts a missed detection as a missed query. Its baseline's validation top-1 retrieval with class plus keypoints was 0.192 and top-20 was 0.524; these figures are for its closed benchmark and model, not a current retail catalog. — [Official DeepFashion2 repository, retrieval benchmark](https://github.com/switchablenorms/DeepFashion2)
- DeepFashion2 annotates positive consumer/shop pairs by shared `pair_id` and style number; these labels are identity supervision beyond category detection. — [Official DeepFashion2 annotation description](https://github.com/switchablenorms/DeepFashion2)

### Inferences
- Treat detector output as candidates for user review. A visual nearest-neighbor result should be described as a similar item unless product metadata, catalog coverage, and identity evidence justify an exact-match claim.
- A catalog missing the photographed SKU cannot return a genuine exact match even if detection and embeddings are perfect; catalog rights, freshness, variants and availability become core product dependencies.

### Gaps
- The sources here do not identify a live product catalog available to Dressed or prove exact-match performance on real share/camera images. That requires separate catalog and retrieval research.
