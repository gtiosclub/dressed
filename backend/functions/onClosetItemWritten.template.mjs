/**
 * TEMPLATE — not deployed. Firebase Functions v2 sketch for bounded outfit composite refresh.
 *
 * TODO(lead):
 * - Initialize admin SDK and OpenAI (or chosen provider) from environment secrets only.
 * - Subscribe to Firestore writes on users/{uid}/closetItems/{itemId} OR Storage finalize on item photos.
 * - Load current closet + avatar version; select up to MAX_OUTFITS (e.g. 20) combinations containing itemId.
 * - For each combination: if users/{uid}/outfitComposites/{hash} is stale, call images API
 *   (same prompt contract as TryOnPrompts.alignedOutfit) and write PNG to Storage.
 * - Do NOT generate factorial combinations on every upload from the iOS client.
 */

// import { onDocumentWritten } from "firebase-functions/v2/firestore";
// import { defineSecret } from "firebase-functions/params";

// const MAX_OUTFITS = 20;
// const openAIKey = defineSecret("OPENAI_API_KEY");

// export const onClosetItemWritten = onDocumentWritten(
//   {
//     document: "users/{uid}/closetItems/{itemId}",
//     secrets: [openAIKey],
//   },
//   async (event) => {
//     const uid = event.params.uid;
//     const itemId = event.params.itemId;
//     // 1. Fetch closet items for uid
//     // 2. Build candidate outfit hashes containing itemId (cap MAX_OUTFITS)
//     // 3. Skip hashes with fresh outfitComposites docs
//     // 4. Queue image generation jobs (Cloud Tasks or inline with concurrency limit)
//     // 5. Write users/{uid}/outfitComposites/{hash} + Storage PNG
//     void uid;
//     void itemId;
//   }
// );

export const onClosetItemWritten = null;