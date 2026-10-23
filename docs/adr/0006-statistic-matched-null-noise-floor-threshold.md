# ADR 0006: Statistic-matched permutation null and noise-floor identifiability threshold

## Status

Accepted 2026-10-22. Closes register defect R1 (joint-rank under-selection).
Companion to ADR 0005, whose consequences section required re-running
rank-selection calibration for the orthonormal default before any recovery
claims.

## Context

The stage-2 geometry change (ADR 0005) made the observed joint statistic the
squared singular values of the stack of per-block **orthonormalized** bases.
Two threshold mechanisms were inherited unchanged from `RJP-BASE` v1 and were
calibrated against the old raw-stack statistic:

1. **Permutation null statistic mismatch.** `get_perm_bound_robustH()` stacked
   *raw* permuted block scores, while the observed side stacked
   orthonormalized bases. For a raw basis `U`, row-permuting and then
   orthonormalizing is equivalent to orthonormalizing and then row-permuting
   (left singular vectors of `P %*% U` are `P %*% U_d`), so the null can be
   computed on orthonormalized bases directly — but the shipped code never
   orthonormalized, so the null distribution was drawn from a different
   statistic than the observed one. The mismatch inflated the null threshold:
   on the corrected instrument the rank-2 exact-recovery rate was 0.36
   (register R1), entirely one-sided toward under-selection.
2. **Identifiability threshold midpoint.** `get_sv_threshold()` returned
   `0.5 * (d[rank] + d[rank + 1])` — the midpoint between the last retained
   signal singular value and the first noise singular value. The filter's
   documented semantics reject *trivial projections*: directions
   indistinguishable from noise. The midpoint implements a strictly stronger
   requirement — a joint direction must be as strong as the weakest retained
   *individual* direction. Instrumented fits on the rank-2 fixture showed
   true joint directions rejected with projections 0.06–2.5 above the largest
   observed noise singular value but below the midpoint (knife-edge drops,
   including one dataset where both true joint components were dropped).

## Decision

1. **Statistic-matched null.** `get_perm_bound_robustH()` orthonormalizes each
   block basis once (`.rank_revealing_basis()`), then row-permutes per draw.
   Row-permuting an orthonormal basis preserves orthonormality, so the null
   statistic is now identical to the observed statistic. The robust SVD
   (`get_svd_robustH`) is retained for the null draws.
2. **Noise-floor identifiability threshold.** `get_sv_threshold()` returns
   `d[rank + 1]` — the first singular value past the retained signal rank,
   i.e. the largest observed noise direction. A joint direction is rejected
   only when its projection norm falls below *every* observed noise direction
   in a block. The `rank == length(d)` boundary fallback (half the last
   singular value, midpoint to the implicit floor at 0) is unchanged.

`RJP-BASE` records the matched null as
`random_permutation_statistic = "leading_orthonormal_stacked_factor_squared_amplitude"`.

## Evidence

Development-seed pilot (B=25 per cell, `simulate_blocks(n=60,
pks=c(50,40,30), individual_ranks=c(5,4,3))`, B_perm=200, robust null):

| Rule | NULL Type-I | rank-1 exact | rank-2 exact | over |
|---|---|---|---|---|
| shipped rule + matched null (adopted) | 0.04 | 1.00 | 0.72 | 0.00 |
| per-rank perm q95 count | 0.16 | 0.72 | 0.68 | 0.28 |
| per-rank perm q95 consecutive | 0.04 | 0.80 | 0.64 | 0.28 |
| rand-dir guard + per-rank consecutive | 0.04 | 0.80 | 0.64 | 0.28 |

The per-rank variants inflate Type-I beyond the 0.10 gate or trade rank-1
power for rank-2 power; the shipped rule form with the matched null
dominates. Instrumented decomposition of the remaining rank-2
under-selection: rule-level misses (second stack amplitude below the perm
q95) and filter-level knife-edge drops in comparable proportion before the
threshold fix; after the noise-floor fix the filter drops only one true
component in one of ten dev seeds.

Confirmation on untouched seeds (offset 42000, B=200 null / B=100 rank-1 /
B=100 rank-2, full `Rajive()` pipeline with `n_perm_samples=1000`,
`n_rand_dir_samples=200`, `n_wedin_samples=200`): recorded in
`validation/2026-10-22-stage2-rankrule/README.md`.

## Consequences

- Rank-2 exact recovery improves from 0.36 (pre-fix instrument) to the
  confirmation value; Type-I remains bounded at the 0.10 gate.
- Fits are bit-different from the pre-fix default whenever
  `joint_rank = NA` or the identifiability filter engages: the permutation
  threshold and the filter can both select differently. Value-pinning
  fixtures are updated with the change, preserving each test's purpose.
- The identifiability filter's semantics are unchanged ("trivial
  projection"); only the noise-floor calibration of "trivial" is corrected.
- The Wedin bound remains diagnostic-only; the random-direction bound is
  unchanged and continues to participate in the default threshold.
