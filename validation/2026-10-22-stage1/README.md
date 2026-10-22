# Stage-1 evidence index (2026-10-22)

Stage-1 (simulator truth certification, pinned-source Wedin derivation, paired
2x2x2 ablation design) was executed on this branch through commit `d1cd445`
(tree `9eafa97871031a0cb7e7255b7211cb87865bac28`, base `3fecb81`). The bulky
evidence payloads are delivered outside the repository; this index records the
verified facts and where they live.

## Verified results

- Reduced suite (`vignette-native-missing-union`, invert): 1448 pass /
  18 expected skips / 0 fail / 0 warn (342.65 s, 554,200 KiB max child RSS).
  The three geometry-gate tests were deliberately left gated and red
  (G1 Gram 0.0727897047, G2 leakage 0.01579166); see
  [the stage-2 geometry receipt](../2026-10-22-stage2-geometry/README.md)
  for their fix.
- Paper foundation: 45 pytest pass; 15 unittest manifest tests pass.
- Eight-arm paired ablation smoke passed (`RJP-GEOM-CANDIDATE` arm: block
  Gram <= 2.2e-16, constrained leakage <= 7.0e-17; smoke seeds data=1729,
  block_fit=8101, aggregation=8102, individual=8103; n=36, p=(12,10,8)).
- Wedin pinned-source derivation: arithmetic checks C1-C10 pass
  (`docs/stage1-wedin-derivation.md`); Wedin stays diagnostic-only.
- Pinned upstream: `ericaponzi/RaJIVE@7d494d11029e538587ee9b27688adacf7f1f9841`
  (MIT, file LICENSE, Erica Ponzi, 2021).

## Delivered artifacts (outside the repository)

- Hash-verified deliverables: `rajiveplus_stage1/` in the session results
  store (20 files + SHA256SUMS + artifact_manifest.json; package patch
  sha256 `e5c0c66fcb8e411be17051f8836c3a0dbd22f135c64684318418d251834e0409`,
  paper patch sha256 `e9392e1e54cd9654ffa2474115d8d6aecc4bee64ae83dccc967e17de13e1c6c9`;
  both replay to the exact final trees).
- Git bundles (verified with `git bundle verify`): package 39,252,772 B,
  paper 43,478 B, in the session shared-workspace checkpoint store.
- Per-run evidence logs (`.log/.resources/.json`) were captured by the
  session evidence runner and are included in the delivered archive.
