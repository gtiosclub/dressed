# Issue #209 — review and import flow

Changes on Riva’s existing 209 branch: sequential Approve/Skip review, combined selection, outfit versus individual-piece confirmation, and persisted review progress/name/mode. Reuses the existing share extension, recognition service, crop/lasso editor, local closet/outfit stores and stable IDs. No shared recognition-pipeline, background-processing, or performance changes are included. Recognition retry is offered for an empty review; use Find more for missed pieces. Generic full-photo fallback is presented as no detection, with manual entry available.

Related work: #208 / PR #228 owns recognition recovery and performance; #211 / PR #229 owns missing-piece analysis; #132 / PR #160 owns alternate choices; #181 owns outfit arrangement. Shared review/model files will still need integration with those branches. This change does not claim those teammates’ components as original work.

Verification: portable state regression checks and Swift type-checking are run separately. A full signed build, real share-sheet walkthrough, lasso acceptance, persistence checks, and screenshots against the design remain pending. Updated fixture UI tests are not proof of real authentication or recognition quality.

Run `sh tests/run-shared-import-state-tests.sh` from the repository root. For native tests, follow docs/IOS_DEVELOPMENT.md and run the ShareImportUITests import cases.

Design gaps for Neal: exact native layout, combined outfit preview/arrangement handoff, and ranked alternate matches. The extension queues an image; it cannot force the app open. Local storage does not imply Firebase sync.

Observed after transfer: draft-state checks passed; the review view and supporting Swift sources passed type-checking. An Xcode IDE build was attempted and stopped at missing Apple developer account/provisioning profiles for the app and Share Extension. No native walkthrough or screenshot acceptance is claimed.
