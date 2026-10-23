# Defect Register

Created: 2026-09-26. This file owns the tracked scientific and usability defect
list for the evaluation workstream defined in
[EVALUATION_PLAN.md](EVALUATION_PLAN.md).

Status vocabulary: `CONFIRMED`, `REFUTED`, `UNVERIFIED`, `NOT-TESTABLE`,
`FIXED`, `DEFERRED`.

Every row records a claim, how to reproduce it, the observed value, the target,
and the disposition. A row may only become `FIXED` with a passing red-first test
and a receipt under [validation/](validation/).

## 2026-10-22 current-source qualification

Stage-0 starts from PR #9 head
`8ceabeedea6501a15b10158e40ad8cebd904ec11`, not the historical working tree
described below. Historical pilot/calibration values remain historical and
are not new measurements at this source. See
[the stage-0 receipt index](validation/2026-10-22-stage0/README.md).
Current evidence confirms V1/V2 red-first and repairs reporting only; G1/G2
were fixed on 2026-10-22 by promoting the stage-1 validated ablation semantics
to the default estimator (RJP-BASE v2, ADR 0005; see
[the stage-2 geometry receipt](../validation/2026-10-22-stage2-geometry/README.md)).
Public-generator capacity/intersection defects B2/B3 mean its
truth must be independently certified before calibration. No v1.0.0 or
manuscript readiness is established.

### Stage-1 qualification (2026-10-22)

B2/B3 are now repaired locally by pre-RNG feasibility rejection plus realized
SVD-based truth certification; see
[stage-1 evidence](validation/2026-10-22-stage1/README.md).
The raw/robust/original eight-arm smoke matches public baseline matrices.
Experimental invariants are not promotion evidence. Default G1/G2 failures
were fixed on 2026-10-22 (RJP-BASE v2, ADR 0005). A separate two-column smoke
also disproves the broad X2
refutation: final robust Joint scores are not guaranteed orthonormal.

The pinned-source Wedin derivation is complete at the classical/conditional
level; the robust transfer is unresolved. Historical W1/W2 wording below
must not be read as a description of pinned original RaJIVE: its ordinary
`t(mapply(...))`/`colSums` reduces across blocks per draw correctly. The current
per-block-quantile reduction is not equivalent. See
[the derivation](../docs/stage1-wedin-derivation.md). No threshold change is made.

## Confirmed defects

| ID | Area | Claim | Reproduce | Observed | Target | Status |
|---|---|---|---|---|---|---|
| W1 | Rank selection | The Wedin joint threshold is dimensionally invalid: `K - colSums()` sums `num_samples` independent draws per block, so the result is always large and negative. A squared singular-value threshold cannot be negative. | `tests/testthat/test-wedin-threshold-arithmetic.R` | before: `-21.65` at 50 draws, `K=3`; after: `1.71` to `1.78`, independent of draw count | finite, `>= 0` | `FIXED` |
| W2 | Rank selection | Because W1 drove the Wedin threshold to large negative values, the documented combined rule `max(wedin, rand_dir, perm)` never selected the Wedin term, so the Wedin contribution was inert. | `tests/testthat/test-wedin-threshold-arithmetic.R` | before: Wedin never binding; after the W1 fix it became binding at `2.75` and destroyed rank recovery (true=1 exact recovery fell 1.00 to 0.13) | Wedin term participates as documented, or documentation states it does not | `FIXED` by making the exclusion explicit and recorded; see the new row W4 |
| W4 | Rank selection | The across-block Wedin combination rule `K - sum(per-block bounds)` is nearly a constant: with `K = 3` and per-block bounds around 0.08 the threshold sits at roughly 2.8 regardless of the data, while the observed squared stacked amplitudes lie between about 1.6 and 2.9. It therefore rejects true joint ranks 1 and 2 outright. Correcting W1 made this reachable and cost 87% of recoverable signal at true rank 1, so the arithmetic fix and the combination rule had to be separated. | `RAJIVE_RUN_SLOW=1 tests/testthat/test-calibration-joint-rank.R`; bounds probe over true ranks 0-3 | before the W1 fix: `overall = rand_dir = 1.7884`, Wedin inert; after: `overall = wedin = 2.75`, true=1 exact recovery 1.00 to 0.13 | a combination rule that separates true rank 0, 1 and 2 | `DEFERRED`; Wedin excluded from the default threshold and the exclusion recorded, pending the pinned reference |
| W5 | Rank selection | The random-direction bound is data-independent: with fixed `n_obs`, `initial_signal_ranks` and `num_samples` it returned exactly `1.7884` in every scenario examined, including true ranks 0 to 3. That is correct for a null threshold, but it means the effective rule has no data-adaptive component, and its Type-I rate is not yet characterised with a proper replicate budget. | bounds probe, 24 fits across true ranks 0-3 | `1.7884` in 24 of 24 fits; pilot Type-I 0.00 at B=15 with one seed offset and 0.20 with another | characterised Type-I with a declared Monte Carlo budget | `CONFIRMED` (characterisation pending) |
| W3 | Wedin bound | Max is valid for the common two-sided classical Wedin bound; min is invalid in general. Raw robust factors, amplitudes and resampling do not establish its premises. | `scripts/check_stage1_wedin.R`; pinned source derivation | C1-C10 pass; conditional projector/min-max proof; per-block quantiles differ from draw-level aggregation | justified robust statistic and resampling coverage | `UNVERIFIED` for robust transfer; classical max/min and conditional aggregation resolved |
| G1 | Geometry | The shipped default `RJP-BASE` sets `basis_extraction_tolerance = "none_raw_robust_factors"`, so per-block robust score bases are not orthonormal. | `tests/testthat/test-robust-basis-orthonormality.R` (default suite) | before: worst `max\|U'U - I\|` = 0.0728; after: 1.11e-15 | `< 1e-10` | `FIXED` (RJP-BASE v2; [receipt](../validation/2026-10-22-stage2-geometry/README.md); ADR 0005) |
| G2 | Geometry | The Individual Component is fit by projecting into the joint complement and then performing an unconstrained robust refit, which reintroduces joint variation. | `tests/testthat/test-robust-basis-orthonormality.R` (default suite) | before: worst relative `\|\|QJ'I\|\|F/\|\|I\|\|F` = 0.0158; after: 8.14e-17 | `< 1e-8` | `FIXED` (RJP-BASE v2; [receipt](../validation/2026-10-22-stage2-geometry/README.md); ADR 0005) |
| I1 | Identifiability | The post-selection identifiability loop `break`s after the first rejected direction in each block, so a block with two unsupported directions retains one. | `tests/testthat/test-identifiability-all-rejections.R` | old logic on the same fixture: dropped `{1}`, expected `{1, 2}`; new logic drops `{1, 2}` | all unsupported directions rejected | `FIXED` |
| R1 | Rank selection | The joint-rank rule under-selects. Re-measured on the corrected instrument (`simulate_blocks()`, exact/under/over, B=25): true rank 1 gives 0.96 exact with 0.04 under; true rank 2 gives 0.36 exact with 0.64 under. The error is entirely one-sided toward under-selection; over-selection was 0.00 in both cells. Root-caused 2026-10-22 to two mechanisms: (a) the permutation null stacked raw permuted bases while the observed statistic used orthonormalized bases (statistic mismatch inflating the null); (b) the identifiability threshold midpoint `0.5*(d[r]+d[r+1])` rejected joint directions whose projections exceeded every observed noise singular value. Fixed by the statistic-matched null (`get_perm_bound_robustH` orthonormalizes block bases before permutation) and the noise-floor threshold (`get_sv_threshold` returns `d[r+1]`); see ADR 0006. | `RAJIVE_RUN_SLOW=1 tests/testthat/test-calibration-joint-rank.R` | 0.96 at rank 1, 0.36 at rank 2 (pre-fix instrument); dev-seed pilot post-fix: 1.00 at rank 1, 0.72 at rank 2 (B=25, matched null, pre-filter-fix) | `>= 0.80` exact | `FIXED` pending confirmation run (see `validation/2026-10-22-stage2-rankrule/`) |
| V1 | Variance | Squared robust factor values need not equal matrix energy; a plug-in `1 - Joint - Individual` is not the reconstructed Residual energy. | `tests/testthat/test-variance-single-contract.R`; stage-0 red/green receipts | Same certified actual-fit block 1: old J 0.766270123356 vs matrix 0.764127002172; old E 0.086288611819 vs matrix 0.080988684993. Repaired API agrees with feature `*_ss` / data-energy block sums; cross-term closure passes. | matrix energies on one observed-entry mask; retain distinct documented proportion denominators | `FIXED` locally, red 27 failures then green 33 actual-fit assertions; release gate remains incomplete |
| V2 | Variance | Mock-only sum-to-one tests could not detect the reporting defect. | `tests/testthat/test-variance-single-contract.R`, `test-varexplained.R` | Actual-fit tests cover nonadditivity, full=FALSE, zero joint rank, NA masks, Inf/NaN rejection, fit/RNG nonmutation; supplemental zero-energy/orthogonal records retained. Focused combined run: 38 assertions pass. | real-fit energy and cross-term tests | `FIXED` locally; exact red and green evidence retained |
| S1 | Input handling | `Rajive()` neither centres nor scales. Documentation states the user must Frobenius-normalise or the joint rank is silently wrong, but nothing enforces or records this. | `tests/testthat/test-preprocessing-contract.R` | policy recorded in every method profile (`preprocessing_centering`/`preprocessing_scaling`); clearly uncentred blocks (column-mean offset > 50% of block variance) warn with class `rajiveplus_uncentered_blocks` naming the block | preprocessing applied and recorded in the method profile, or a hard error | `FIXED` (recorded policy + documented tripwire warning; [receipt](../validation/2026-10-22-stage2-preprocessing/README.md)) |
| B1 | Benchmark truth | `ajive.data.sim()` samples each block's Individual scores independently of the joint scores and never projects them into the joint complement, so its stored truth violates the model the estimator targets. | `tests/testthat/test-validation-generator.R` | legacy generator overlap non-zero (asserted); `simulate_blocks()` overlap `< 1e-10` | orthogonal truth, `< 1e-10` | `FIXED` by adding `simulate_blocks()`; the legacy generator is retained and documented as a misspecification stress case |
| B2 | Benchmark truth | Joint plus Individual rank must fit both sample and feature capacity. | `test-simulation-truth-certificate.R`; stage-1 red/green receipts | impossible feature ranks rejected before RNG; realized J/I/J+I ranks certified | reject infeasible requests; certify realized truth | `FIXED` locally, not a recovery/calibration claim |
| B3 | Benchmark truth | Joint orthogonality alone does not rule out additional all-block Individual sharing. | `test-simulation-truth-certificate.R`; stage-1 red/green receipts | forced-intersection requests rejected; actual all-block I intersection zero and signal intersection rJ certified; pairwise sharing allowed | no additional all-block shared Individual directions | `FIXED` locally by feasibility plus realized numerical certification |
| M1 | Calibration metric | The joint-rank recovery test scores `estimated_rank >= true_rank`, so overestimation counts as power. | `tests/testthat/test-calibration-joint-rank.R` (`rank_recovery_summary()`) | before: over-selection scored as power; after: over reported separately and gated `<= 0.10` | exact / under / over reported separately | `FIXED` |
| M2 | Calibration metric | The jackstraw calibration treats correlated per-feature p-values as an independent binomial sample and drops zero-rank datasets from the denominator. | `tests/testthat/test-calibration-jackstraw.R` | dataset-level denominators exclude rank-zero fits | dataset-level denominators include every fit | `CONFIRMED` |

## Refuted claims

Recorded so they are not re-litigated without new evidence.

| ID | Claim | Result |
|---|---|---|
| X1 | Joint Component reconstruction is inexact. | `REFUTED`. Relative `\|\|X - J - I - E\|\|F / \|\|X\|\|F` = 0 exactly on the tested fixtures. |
| X2 | The joint score basis itself is non-orthonormal. | The historical single-column/fixture refutation was too broad. Stage-1 two-column public-baseline smoke has Gram error 0.003818097. Robust sequential deflation does not guarantee cross-column orthogonality; no blanket refutation is supported. The earlier geometry fixture still passes its final-Joint check. |
| X3 | `showVarExplained_robust()` Residual falls outside `[0, 1]`. | `REFUTED` on the tested fixtures (0.2395 to 0.3240, all in range). The defect is V1: the reported value disagrees with the true Residual energy. |

## Blocked

| ID | Blocker | Needed to clear |
|---|---|---|
| W3, and the across-block Wedin combination rule | Classical/conditional derivation and pinned-source comparison complete; current robust theorem/statistic/resampling/quantile link remains unresolved. Inherited-source redistribution not authorized. | Establish valid robust residual/gap certificates and coverage, then independent calibration; keep default exclusion unchanged. |
| Phase 1.2 geometric-candidate ablation | Historical three-replicate bundled comparison changes block factorization and cannot support acceptance/rejection. New paired R/S/I protocol and executable eight-arm smoke exist, but no performance benchmark ran. | Execute separately approved statistic-matched calibration and paired development/untouched confirmation runs. |
