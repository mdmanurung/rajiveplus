# Stage-2 rank-selection calibration (defect R1)

Date: 2026-10-22. Scope: joint-rank selection rule for the default
(`RJP-BASE` v2) estimator after the ADR 0005 geometry change.

## Changes under test

1. Statistic-matched permutation null: `get_perm_bound_robustH()` now
   orthonormalizes each block basis before row-permutation (ADR 0006 §
   Decision 1). Commit `cdf5967`.
2. Noise-floor identifiability threshold: `get_sv_threshold()` returns
   `d[rank + 1]` instead of the signal/noise midpoint (ADR 0006 § Decision
   2). Commit `cdf5967`.

## Development pilot (B=25 per cell, dev seeds 9001-9025 / 9201-9225 / 9301-9325)

Rule comparison with the matched null (pilot script `pilot_rank_rule.R`):

| Rule | NULL Type-I | rank-1 exact | rank-2 exact | over |
|---|---|---|---|---|
| shipped rule + matched null (adopted) | 0.04 | 1.00 | 0.72 | 0.00 |
| per-rank perm q95 count | 0.16 | 0.72 | 0.68 | 0.28 |
| per-rank perm q95 consecutive | 0.04 | 0.80 | 0.64 | 0.28 |
| rand-dir guard + per-rank consecutive | 0.04 | 0.80 | 0.64 | 0.28 |

Pre-fix baseline (register R1, old instrument): rank-1 exact 0.96, rank-2
exact 0.36.

Instrumented decomposition on ten rank-2 dev seeds: before the threshold
fix, the identifiability filter dropped at least one true joint component in
3/10 fits (knife-edge: projections 0.06-2.5 above the largest observed noise
singular value but below the midpoint); after the fix, 1/10. The remaining
under-selection is rule-level (second stack amplitude below the perm q95).

## Confirmation run (untouched seeds, offset 42000)

Full `Rajive()` pipeline, configuration identical to
`tests/testthat/test-calibration-joint-rank.R`:
`n_wedin_samples=200, n_rand_dir_samples=200, n_perm_samples=1000,
num_cores=1`, `simulate_blocks(n=60, pks=c(50,40,30),
individual_ranks=c(5,4,3))`.

Status at snapshot time (2026-10-23 02:00 UTC): **IN PROGRESS**. Completed
cells:

- Null (B=200): **Type-I = 1/200 = 0.005** (target <= 0.10) — PASS.
- Rank-1 (B=100) and rank-2 (B=100): running; checkpoints land in
  `/mnt/shared-workspace/rajive_stage2/calibration/` (`checkpoint_rank1.rds`,
  `checkpoint_rank2.rds`) and the final verdict in
  `confirmation_results.json` (`gate_pass` field).

## Verdict

PENDING the rank-1/rank-2 confirmation cells. The version remains 0.1.0 and
the release-checklist slow-manifest row remains un-promoted until the
confirmation completes; per the stage gate rule, 0.2.0 requires all
mandatory local gates to pass. Development-pilot evidence (B=25/cell) and
the confirmed null cell support the fix; the confirmation is the authority.
