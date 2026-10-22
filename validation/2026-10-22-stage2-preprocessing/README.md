# Stage-2 preprocessing receipt: defect S1 closed (recorded policy + tripwire)

Date: 2026-10-22. Branch: `publication/stage1-truth-wedin-design-20261022`.

## Change

- The method profile now records the preprocessing policy for every profile:
  `preprocessing_centering` / `preprocessing_scaling` =
  `none_user_responsibility` (RJP-BASE, RJP-COMPAT, RJP-GEOM-CANDIDATE) and
  `optional_missing_control_default_off` (RJP-NATIVE-BASE, whose
  `rajive_missing_control(center, scale)` applies its own policy).
- `Rajive()` (complete path) detects clearly uncentred blocks and emits a
  documented warning (class `rajiveplus_uncentered_blocks`) naming each
  offending block. Criterion (scale-free): the share of a block's total
  variance carried by the column-mean offset exceeds 0.5. Centred data sits
  near 1/n (sampling noise); a forgotten centreing on all-positive data
  approaches 1, so the cutoff separates the regimes by orders of magnitude.
  No data is modified; the estimator's no-centering behavior is unchanged.
- Roxygen "Block normalization" section documents the policy and the warning.

## Red-first evidence

`tests/testthat/test-preprocessing-contract.R` before implementation:
FAIL 7 | WARN 3 | SKIP 0 | PASS 3 (profile fields missing; no warning
emitted; block naming absent). The 3 fixture warnings were a test bug
(recycling `rnorm(50)` into 20 rows), fixed in the same commit.

## Green evidence

- `preprocessing-contract`: FAIL 0 | WARN 0 | SKIP 0 | PASS 11.
- Full reduced suite (`vignette-native-missing-union`, invert):
  FAIL 0 | WARN 0 | SKIP 15 | PASS 1474.
- One shared fixture (`make_small_rajive_fixture`) fed legacy-generator
  uncentred output into association/profile tests; it now column-centres the
  generated blocks, matching the documented contract the tests otherwise do
  not exercise.
