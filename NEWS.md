# rajiveplus 0.1.0

## Scientific corrections

### Stage-1 simulator truth certification (estimator unchanged)

`simulate_blocks()` now rejects insufficient combined feature-rank capacity
and dimensionally forced all-block Individual intersections before using RNG.
Feasible construction and RNG behavior are unchanged. A new deterministic
internal SVD-based certificate checks realized component/signal ranks, metadata
spaces, Joint/Individual orthogonality, all-block intersections and closure.
The compact certificate is added to `truth`; uncertifiable draws fail rather
than being silently replaced. This is numerical truth validation, not recovery
or statistical calibration.

The stage-1 pinned-source Wedin audit supersedes the historical interpretation
below: original RaJIVE normally aggregates draws across blocks before taking
a quantile; the present per-block-quantile reduction is not equivalent.
`K - sum(error^2)` is conditionally justified for orthogonal projector sums,
but no end-to-end guarantee for robust factors/amplitudes has been established.
No threshold formula, activation option or estimator default changes here.

### Variance reporting uses reconstructed component energies

`showVarExplained_robust()` retains its arguments and named-list return shape,
but now calculates each component's observed-entry matrix energy divided by
observed data energy. It no longer substitutes squared robust singular values
or defines Residual as `1 - Joint - Individual`. Nonorthogonal components have
cross terms, so the three reported energies need not sum to one. `NA` entries
are excluded consistently; Inf/NaN are rejected; zero data energy returns zero.
`full = FALSE` components are reconstructed from the fitted records.

The feature-level `joint_variance_partition()` fields and denominators are
unchanged: its `*_prop` columns normalize by component-total energy, while its
`*_ss` fields agree with the block-level reporting after data-energy
normalization. This reporting repair does not alter the fitted estimator,
ranks, component matrices, or rank-selection defaults. The geometry and
calibration release blockers remain open.

### The Wedin joint-rank threshold is no longer a negative "squared magnitude"

`get_wedin_bound_samples()` returns `n_wedin_samples` independent draws per Data
Block, each in `[0, 1]`. The joint threshold reduced them with
`K - colSums(block_wedin_samples)`, which summed the whole draw vector and
subtracted it from the number of Data Blocks. The result was always large and
negative — for example `-197` with `K = 3` and 200 draws — and a squared
singular-value threshold cannot be negative. Because the combined rule takes
`max(wedin, rand_dir, perm)`, the Wedin term was never the binding constraint,
so the documented rule did not describe what the code did.

The draws are now reduced to one bound per Data Block at the same 5% quantile
the threshold is taken at, and the threshold is rejected with a classed error if
it is ever not finite or negative.

### The Wedin bound is now reported but excluded from the default threshold

Fixing the arithmetic made the Wedin term reachable, and it turned out to be far
too conservative: on the standard three-block fixture its threshold is nearly
constant at roughly 2.8, while the observed squared stacked amplitudes sit
around 1.6 to 2.9, so it rejected true joint ranks 1 and 2 outright. The
random-direction bound separates the same cases correctly, at 0 false positives
in 6 null replicates.

The across-block combination rule `K - sum(per-block bounds)` has never been
verified against a pinned upstream RaJIVE reference, and that reference is not
currently available. Rather than ship an unverified rule, the Wedin bound is now
computed and stored in `fit$joint_rank_sel$wedin` with a
`participates_in_threshold` field, and excluded from the default decision rule.
Setting `options(rajiveplus.wedin_in_default_threshold = TRUE)` restores the old
behaviour. Re-deriving the combination rule against the pinned reference is
tracked as an open item.

### The identifiability filter no longer stops at the first rejection

The post-selection filter dropped a candidate joint direction when any Data Block
barely supported it, but it stopped examining candidates as soon as one failed in
a given block. A block that left two candidate directions unsupported therefore
contributed only one rejection, and an unsupported direction could survive into
the decomposition. Every block now tests every candidate. The filter was
extracted into an internal `.identifiability_filter()` and is covered directly.

## New functionality

### `simulate_blocks()` generates an identifiable ground truth

`ajive.data.sim()` draws each block's Individual scores independently of the
joint scores, so its stored truth is not an identifiable decomposition: the
joint and individual score spaces overlap. A method that is correct can be
penalised for failing to reproduce that overlap.

`simulate_blocks()` constructs an orthonormal joint score basis and places each
block's orthonormal individual basis in its orthogonal complement, so the
decomposition is identifiable by construction. It also returns the latent scores
and the per-block joint loadings, and its signal magnitude is comparable to
`ajive.data.sim()` at matched settings. `ajive.data.sim()` remains available and
documented as a misspecification stress case.

## Validation changes

### Joint-rank recovery no longer rewards overestimation

The calibration power metric scored `estimated_rank >= true_rank`, so selecting
too many components counted as a success. Recovery is now reported as exact,
under, and over separately, with the Monte Carlo standard error of the exact
rate, and every fit stays in the denominator. On the corrected instrument the
measured rates are 0.96 exact at true rank 1 and 0.36 exact at true rank 2 over
25 replicates, with the error entirely one-sided toward under-selection.

### The open geometry gate is executable

`tests/testthat/test-robust-basis-orthonormality.R` states and measures the
Tier-B geometric invariants. Two of them do not currently hold on the shipped
default: per-block robust score bases reach `max|U'U - I| = 0.073` against a
target of `1e-10`, and the Individual Component leaks into the joint space at a
relative `0.016` against a target of `1e-8`. The tests are gated behind
`RAJIVE_RUN_GEOMETRY_GATE=1` so an open scientific question does not mask
unrelated regressions, and they must be promoted into the default suite in the
same change that fixes the geometry.

## Documentation corrections

- `autoplot.rajive` documented `"variance"` as its default `plot_type`; the
  default is `"pairs"`.
- `extract_components(blocks=)` was documented as reserved and unused in one
  place and required for variance extraction in another. It is required for
  variance extraction and ignored otherwise.
- `rajive_report()` documented a `jackstraw_result` argument that added a
  significance section; the body never referenced it. The section is now
  implemented, `"significance"` was added to the documented and default section
  lists, and the `"stability"` section no longer emits a fixed instruction
  string in place of content.
- `ajive.data.sim()` documented its return value as neither `sim_data` nor
  `truth`, and a vignette read `sim$rankJ_true` and `sim$rankA_true`, which do
  not exist and rendered as empty. The return value is now documented and the
  vignette reads `sim$truth$rankJ` and `sim$truth$rankA`.

## Packaging

- `Depends` raised to `R (>= 4.1.0)`: the native pipe `|>` is used in a vignette
  and a shipped benchmark, which are parsed at build time.
- `jsonlite` added to `Suggests`; it is used by the validation runner tests.
- `Title` set to title case with the external algorithm name in single quotes.
- `Description` now cites the originating method. The original RaJIVE method is
  Ponzi, Thoresen and Ghosh (2021), arXiv:2101.09110, not the repository URL
  that was previously given.
- `inst/CITATION` records the RaJIVE, aJIVE and JIVE references with DOIs, and no
  longer claims a version that disagrees with `DESCRIPTION`.
- `cph` added to `Authors@R`; the original RaJIVE co-authors are credited.
- `.Rbuildignore` extended to exclude `.Rhistory`, `..Rcheck`,
  `rajiveplus.Rcheck`, `fits`, purl intermediates, `vignettes/data`, the
  microbiome vignette generator, and `testthat-problems.rds`, which was shipping
  inside the tarball.

## API migration

No existing exported function changed signature. `simulate_blocks()` is new.
Behaviours that changed:

- `fit$joint_rank_sel$wedin` now carries `block_wedin_bounds` and
  `participates_in_threshold`.
- The Wedin bound no longer contributes to `overall_sv_sq_threshold` unless
  `options(rajiveplus.wedin_in_default_threshold = TRUE)` is set.
- `Rajive()` emits a one-time message on first use explaining the above.
