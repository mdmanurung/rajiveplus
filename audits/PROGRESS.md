# rajiveplus - Operational Dashboard

This file owns current state, next commands, open blockers, and the latest
validation snapshot. Long-form history is archived in
[archive/progress-pre-maintainer-consolidation-2026-05-18.md](archive/progress-pre-maintainer-consolidation-2026-05-18.md)
and [archive/progress-pre-consolidation-2026-05-13.md](archive/progress-pre-consolidation-2026-05-13.md).

## Status

Status line: A new evaluation workstream is active and owns the strategy. Its
plan is [EVALUATION_PLAN.md](EVALUATION_PLAN.md) and its findings are tracked in
[DEFECT_REGISTER.md](DEFECT_REGISTER.md). Phase 0, repairing the measurement
instruments, is complete. Phase 1, mathematical correctness, is partially
complete: the identifiability filter is fixed, while the geometry, the Wedin
combination rule, preprocessing enforcement and the variance contract remain
open. Phase 4 usability work and the Phase 5 CRAN gate have not opened.

The single most important result: the joint-rank power failure is a genuine
method defect, not a measurement artifact. The measurement instruments were
broken and have been repaired; the re-measured rule recovers rank 1 almost always
and rank 2 poorly, with error entirely toward under-selection.

The package version remains `0.1.0`. Nothing has been committed, tagged,
published or submitted.

## Rapid Next Action

1. Re-run the full local test suite and record the totals. The last full run was
   interrupted before its summary was written, so the current pass/fail totals
   for the working tree are unknown. Individual files all pass as of the last
   completed per-file run.
2. Restore the pinned reference, then re-derive the Wedin bound and its
   across-block combination against it. This unblocks W3, W4 and Phase 1.8, and
   is the only route to putting the Wedin term back into the default threshold.
3. Run the Phase 1 factorial ablation: representation only, statistic only,
   both, with predeclared replicate counts and margins.
4. Fix the remaining register rows that need no reference: V1 variance contract,
   S1 preprocessing enforcement, M2 jackstraw denominators.
5. Only after the Phase 1 gate is decided, open Phase 4 usability work and the
   Phase 5 CRAN gate.

## Open Blockers

| Area | Current state | Next action |
|---|---|---|
| Local test suite | **UNKNOWN for the working tree.** The final full-suite run was interrupted before writing its summary. All files passed individually. | Re-run and record totals. |
| Wedin combination rule | **UNVERIFIED and excluded from the default threshold.** `K - sum(per-block bounds)` is nearly constant at about 2.8 and rejects true joint ranks 1 and 2. | Re-derive against the pinned reference. |
| Pinned reference | **ABSENT.** `/tmp/rajive-benchmark-lib` does not exist on this machine. Upstream is `ericaponzi/rajive` at `7d494d11029e538587ee9b27688adacf7f1f9841`. | Restore the reference clone and library. |
| Robust basis geometry | **OPEN.** `RJP-BASE` ships no orthonormal canonicalisation; worst `max\|U'U - I\| = 0.0728` against a `1e-10` target. | Phase 1 factorial ablation. |
| Individual leakage | **OPEN.** Relative `\|\|QJ'I\|\|F/\|\|I\|\|F = 0.0158` against a `1e-8` target. | Exact re-factorization after reprojection. |
| Joint-rank power | **RE-GATED, FAILS at rank 2.** 0.96 exact at rank 1, 0.36 at rank 2, B=25, over-selection 0.00 in both cells. | Phase 1.8 rank-selection ablation. |
| Random-direction bound | **CHARACTERISATION PENDING.** Data-independent: returned exactly 1.7884 in 24 of 24 fits. Pilot Type-I was 0.00 and 0.20 under two seed offsets at B=15. | Proper Monte Carlo Type-I with a declared budget. |
| Variance contract | **OPEN.** Two exported APIs disagree; the singular-value-identity one reports a plug-in Residual. | Reconcile to a single contract. |
| Preprocessing | **OPEN.** `Rajive()` neither centres nor scales, and nothing enforces the documented requirement. | Apply and record, or hard error. |
| API usability | **NOT STARTED, gated on Phase 1.** 59 exports, 315 formals, 115 distinct argument names. | Self-contained fit object first. |
| CRAN packaging | **PARTIAL.** Mechanical blockers fixed; no `--as-cran` run has ever completed. | See Gate 3 in EVALUATION_PLAN.md. |
| Vignette reproducibility | **OPEN.** Four of seven vignettes read untracked `.rds` caches unconditionally, so a clean clone cannot build the package. | Fix before any tarball. |
| CI matrix | **NEVER RUN.** | Run after local validation. |
| BMV application evidence | **STALE.** Downstream evidence is from an older 78-sample run. | Regenerate from the active 120-sample inputs. |

## Latest Validation Snapshot

- **2026-09-26 working tree, per-file runs, all passing:**
  - `test-wedin-threshold-arithmetic.R` 18 assertions.
  - `test-identifiability-all-rejections.R` 7 assertions.
  - `test-validation-generator.R` 42 assertions.
  - `test-report-sections.R` 9 assertions.
  - `test-calibration-joint-rank.R` 8 assertions plus 3 slow skips.
  - `test-rajive-perm.R` 24 assertions, after fixing a regression I introduced.
  - `test-robust-basis-orthonormality.R` gated behind
    `RAJIVE_RUN_GEOMETRY_GATE=1`; when run, G1 and G2 fail as designed and the
    joint-score orthonormality check passes.
- **2026-09-26 re-measured joint-rank recovery**, `simulate_blocks()`,
  `n = 60`, `pks = c(50, 40, 30)`, `initial_signal_ranks = c(5, 4, 3)`, B=25:
  - true rank 1: exact 0.96, under 0.04, over 0.00, mean estimate 0.96.
  - true rank 2: exact 0.36, under 0.64, over 0.00, mean estimate 1.32.
  - B=25 is a pilot, not a gate result. The gate runs at B=100.
- **2026-09-26 measured bound values** across true ranks 0 to 3, 24 fits:
  - random-direction threshold 1.7884 in 24 of 24 fits.
  - Wedin threshold 2.70 to 2.87 after the arithmetic fix, previously
    `-197` at 200 draws and `K = 3`.
- **2026-09-26 Wedin arithmetic before and after**, 15 replicates:
  - before: true=1 exact 1.00, true=2 exact 0.33.
  - after the fix alone: true=1 exact 0.13, true=2 exact 0.00. This regression
    is why the Wedin term is now excluded rather than active.
  - after excluding the Wedin term: true=1 exact 1.00, true=2 exact 0.33, so
    effective behaviour is restored to the pre-fix baseline.
- **2026-09-20 prior candidate** remains the last fully checked state: full
  suite `1,160` assertions with zero failures, `R CMD check --no-manual`
  `Status: OK` at 0/0/0, source SHA-256
  `a5165dc4adc8f334d47992e914ccc5da66d85fef6bb3c2436ec3a86f6a93d2a5`, package
  version `0.1.0`. That check predates the commit that rewrote `DESCRIPTION`,
  `NAMESPACE` and 14 `R/` files, so it does not cover the current tree.

## Environment

`R` and `conda` are not on the default `PATH`. The R4_51 environment is reached
directly:

```bash
export PATH="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin:$PATH"
Rscript <script.R>
```

R 4.5.1. `Rcpp` 1.1.2, `RcppArmadillo` 15.6.0.1, `ggplot2` 4.0.3, `cli` 3.6.6,
`testthat` 3.3.2, `devtools` 2.5.2, `roxygen2` 8.1.0, `qvalue` 2.42.0,
`jsonlite` 2.0.0. There is no `conda` binary, so `conda run -n R4_51 ...` from
the older notes does not work; call `Rscript` directly.

## Useful Commands

Full suite, recording totals:

```bash
export PATH="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin:$PATH"
Rscript -e 'options(rajiveplus.wedin_diagnostic_informed = TRUE); devtools::test(reporter = "silent")'
```

Targeted files:

```bash
Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-wedin-threshold-arithmetic.R")'
Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-identifiability-all-rejections.R")'
Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-validation-generator.R")'
```

Gated suites:

```bash
RAJIVE_RUN_GEOMETRY_GATE=1 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-robust-basis-orthonormality.R")'
RAJIVE_RUN_SLOW=1 Rscript -e 'devtools::load_all("."); testthat::test_file("tests/testthat/test-calibration-joint-rank.R")'
```

Regenerate documentation after any roxygen change:

```bash
Rscript -e 'devtools::document()'
```

## Last Session Note

**2026-09-26 - Evaluation workstream opened; Phase 0 complete.** A new
evaluation workstream was opened to assess scientific correctness, CRAN
readiness and API usability, sequenced correctness-first with a hard gate before
usability and packaging, with breaking API changes permitted at 0.1.0.

Phase 0 found that the measurement instruments were themselves broken, which
invalidated every prior calibration number including the red joint-rank gate.
Four instrument defects were confirmed and repaired. The Wedin joint threshold
was computed by summing a whole vector of resampling draws and subtracting it
from the number of Data Blocks, producing a large negative value where a squared
singular-value threshold belongs; because the combined rule takes a maximum, the
Wedin term was never binding and the documented rule did not describe the code.
Fixing the arithmetic made the term reachable and revealed it to be far too
conservative, costing 87% of recoverable signal at true rank 1, so the Wedin
term is now computed and stored but excluded from the default threshold, with
the exclusion recorded, reversible by option, and stated to the user once. The
identifiability filter stopped at the first rejection in a block and could let
an unsupported joint direction survive; it was extracted into a testable helper
and now rejects every unsupported direction. The benchmark generator's truth was
not identifiable and the joint-rank recovery metric counted overestimation as
power; `simulate_blocks()` was added with an orthogonal ground truth, and
recovery is now reported as exact, under and over with a Monte Carlo standard
error.

Re-measured on the repaired instruments, the joint-rank rule recovers rank 1 at
0.96 and rank 2 at 0.36 with error entirely toward under-selection. The failure
is therefore a real method defect and was re-gated accordingly, with an explicit
rule that the 0.80 threshold may not be quietly edited to match a corrected
result.

Four documentation defects were fixed: the `autoplot` default, the
`extract_components(blocks=)` contradiction, the dead `rajive_report`
`jackstraw_result` argument and its stub stability section, and the
`ajive.data.sim()` return value together with a vignette that read two
nonexistent fields. Seven CRAN mechanical blockers were fixed, including the R
version floor, an undeclared dependency, and a citation that had been invented
incorrectly and has been replaced with the verified Ponzi, Thoresen and Ghosh
reference. `NEWS.md` and the defect register were created, and `.gitignore` was
corrected so the new planning documents survive a fresh clone.

One regression was introduced and caught during this session: the threshold
metadata was written unconditionally, creating a `wedin` element even when the
Wedin path was skipped, which broke `test-rajive-perm.R`. It is fixed and that
file passes.

Not done, and recorded in the register: the geometry gate, the variance
contract, preprocessing enforcement, the jackstraw denominators, the full API
collapse, the self-contained fit object, the rank-selection helper, and the CRAN
gate. The final full-suite totals for the working tree are unknown because that
run was interrupted; this is the first thing to do when resuming.
