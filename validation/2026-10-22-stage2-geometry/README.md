# Stage-2 geometry receipt: defects G1 and G2 fixed in the default estimator

Date: 2026-10-22. Branch: `publication/stage1-truth-wedin-design-20261022`.
Design record: [ADR 0005](../../docs/adr/0005-default-orthonormal-geometry.md).

## Change

`RJP-BASE` v1 -> v2 (`frozen_local_baseline` -> `default_orthonormal_constrained`):

1. Per-block retained robust score bases are orthonormalized by a
   rank-revealing SVD pass (`basis_extraction_tolerance` =
   `dimension_scaled_machine_epsilon`); rank-deficient bases are truncated
   with a warning and the stack capacity follows the achieved ranks.
2. The selected joint factors are canonicalized by the same pass before the
   identifiability filter; the pre-filter drop is recorded as
   `canonical_rank_drop` in `joint_rank_sel`.
3. The Individual Component freezes the selected robust rank, projects the
   selected reconstruction onto the joint complement, and refactorizes with an
   exact algebraic SVD (`individual_constraint` =
   `exact_joint_complement_reprojection`, `individual_refactorization` =
   `algebraic_svd_only`). `get_individual_decomposition_robustH()` gains a
   `constraint` argument (`"none"` preserves the legacy unconstrained refit
   for the experimental ablation adapter).

The algebra is the stage-1 validated `RJP-GEOM-CANDIDATE` arm, moved from
`R/experimental_ablation.R` into the default path via the shared
`.rank_revealing_basis()` helper. The Wedin bound, permutation bound, robust
block factorization and native missingness machinery are unchanged; the Wedin
term remains diagnostic-only.

## Red-first evidence (before)

Gated tests `tests/testthat/test-robust-basis-orthonormality.R` at
`RAJIVE_RUN_GEOMETRY_GATE=1`, stage-1 source (commit `d1cd445`):

- G1 worst `max|U'U - I|` = 0.0727897047 (target < 1e-10) -- FAIL
- G2 worst relative `||Q_J' I||F / ||I||F` = 0.01579166 (target < 1e-8) -- FAIL
- joint-basis Gram (G3 pin) -- PASS

## Green evidence (after)

Same fixture (`simulate_blocks(n=60, pks=c(50,40,30), joint_rank=2,
individual_ranks=c(5,4,3), seed=6161)`, `Rajive(..., joint_rank=2,
num_cores=1, seed=6161)`), tests promoted to the default suite (no gate):

- worst block Gram error: 1.110223025e-15 (target < 1e-10) -- PASS
- worst Individual fitted-span leakage: 8.135974709e-17 (target < 1e-8) -- PASS
- joint-basis Gram error: 2.220446049e-16 -- PASS
- fit records `canonical_rank_drop = 0`, `identif_dropped = 1`, final
  `joint_rank = 1` (the filter drops one of the two requested components, as
  designed).

Test receipts (this working tree, 2026-10-22):

- `robust-basis-orthonormality`: FAIL 0 | WARN 0 | SKIP 0 | PASS 3 (18.1 s)
- `experimental-ablation|rajive-boundaries|method-profiles`:
  FAIL 0 | WARN 0 | SKIP 0 | PASS 131 after the adapter/default-equivalence
  test was re-pointed to the orthonormal+robust+constrained arm
- full reduced suite (`vignette-native-missing-union`, invert):
  FAIL 0 | WARN 0 | SKIP 15 | PASS 1463

## Consumer adjustments required by the estimator change

- `.summarize_missing_refit_scores()` (native uncertainty): a refit may now
  legitimately retain fewer joint components than the reference fit; it
  contributes NA for the dropped component instead of crashing.
- PERF-003 fixture seed 1408 -> 1409: the fixture's joint component was
  borderline under the identifiability filter (block-1 score 21.87 vs
  threshold 21.91, a 0.2% margin) and the geometry fix moved the robust
  factor across the knife edge, so the reference fit now correctly estimates
  `joint_rank = 0` and has no joint score payload to bootstrap. The test's
  purpose (fixed-rank bootstrap determinism) is preserved on a stable seed.
- `test-experimental-ablation.R` first test: the adapter/default-equivalence
  claim transfers from the raw/unconstrained arm (legacy contrast) to the
  orthonormal/robust/constrained arm, which now reproduces the default path
  bit-for-bit (tolerance 1e-12).
