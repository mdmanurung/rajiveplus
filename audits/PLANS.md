# rajiveplus - Active Strategy

This file owns current strategy, gates, and durable blockers. Historical audit
crosswalks and discovery notes are evidence, not the active plan; their status
is indexed in [archive/README.md](archive/README.md).

## Operating Rules

- Use test-driven changes for package source: no production change under `R/`
  or `src/` lands without a failing test in the same step or earlier.
- Keep generated files generated. Do not hand-edit `NAMESPACE`, generated
  roxygen output, `R/RcppExports.R`, `src/RcppExports.cpp`, or pkgdown HTML.
- Treat generated site files under `docs/*.html`, `docs/reference/`,
  `docs/articles/`, and `docs/deps/` as validation artifacts, not project truth.
- Keep heavy benchmark and release validation on SLURM unless the user directs
  otherwise.
- Make focused changes. Do not use this plan as permission for unrelated
  refactors.

## Active Workstream: Scientific Evaluation, Release Readiness, And Usability

Adopted 2026-09-26. This stream supersedes the ordering in the frozen `0.2.0`
completion packet for Phases 4 to 6. The packet remains the reference for the
baseline, object readers, and input contracts already delivered, and its
authorisation boundary is unchanged.

Plan: [EVALUATION_PLAN.md](EVALUATION_PLAN.md). Findings:
[DEFECT_REGISTER.md](DEFECT_REGISTER.md). Current state:
[PROGRESS.md](PROGRESS.md).

Decisions governing this stream:

- Correctness first, with a hard gate. Usability and packaging do not open until
  the correctness gate is decided.
- Evaluate, then fix what is confirmed. Findings are recorded with reproduction
  evidence before any source change.
- Breaking API changes are permitted at version `0.1.0`. Silent breakage is not;
  every merge gets a row in the `NEWS.md` migration table.
- The measurement instruments are validated before the estimator is. A
  calibration number from an unvalidated generator or a metric that rewards
  overestimation is not evidence.

Current order:

1. Repair the measurement instruments and re-measure. `DONE`.
2. Restore the pinned upstream reference, which is the only route to re-deriving
   the Wedin bound and its across-block combination.
3. Resolve the estimator geometry: orthonormal score basis, exact Individual
   re-factorization, rank-selection rule.
4. Enforce the preprocessing contract and reconcile the variance contract.
5. Gate on the above before any usability or packaging work.

The joint-rank power gate is re-gated as a method gate, not a documentation
item. Its 0.80 threshold may not be quietly edited to match a corrected result;
re-specifying it is a recorded maintainer decision taken against the repaired
instrument, with both numbers in the receipt.

## Superseded: 0.2.0 Release-Candidate Completion

The frozen completion plan at
[../docs/_codexdocs/execution/2026-09-19/FROZEN_PLAN.md](../docs/_codexdocs/execution/2026-09-19/FROZEN_PLAN.md)
owned the execution order for the local `0.2.0-rc1` candidate through 2026-09-26.
Its checkbox tracker is
[../docs/_codexdocs/execution/2026-09-19/TASKS.md](../docs/_codexdocs/execution/2026-09-19/TASKS.md).
Stage A through Stage C remain the reference for the baseline, object readers,
and input contracts. Its Phase 4 to Phase 6 ordering is superseded by the
evaluation workstream above.

Its order was:

1. Persist governance and CI and capture an immutable baseline.
2. Complete S1-01/S1-02 readers and S2-01 constructors before method changes.
3. Establish input, method-profile, simulation, and reproducibility contracts.
4. Evaluate complete-data method corrections through the frozen ablation
   rules without changing defaults from invariant tests alone.
5. Validate native missingness and inference under separate supported and
   experimental contracts, then close locally feasible release gates against
   one candidate hash.

Scheduler submissions, network access, remote writes, tags, publication, and
release promotion remain blocked pending explicit authorization. Later module
splitting is paused until method contracts stabilize.

## Foundation: Maintainability Refactor

The full discovery plan is archived at
[archive/rajiveplus-refactoring-maintainability-plan-2026-05-18.md](archive/rajiveplus-refactoring-maintainability-plan-2026-05-18.md).
Implement from the compact stages below.

### Stage 1 - Component Vocabulary And Accessors

| ID | Goal | Key contract | Primary tests |
|---|---|---|---|
| S1-00 | Replace decomposition `noise` vocabulary with `residual` and full public labels `Joint`, `Individual`, `Residual` | `type = "noise"` gets a targeted migration error; `noise` remains only for stochastic error/perturbation language | `test-extractors.R`, `test-varexplained.R`, native diagnostics/core tests, documentation scans |
| S1-01 | Add non-exported `block_decomps` readers | `.block_decomp_index(block, component, n_blocks)` returns the flat index; `.get_block_decomp()` returns the stored record exactly; invalid helper arguments use ordinary internal errors | `test-extractors.R` with tiny real fits plus hand-built malformed fixtures |
| S1-02 | Consolidate component-matrix reconstruction | `.get_component_matrix()` is fit-owned, prefers `$full`, reconstructs from `u/d/v`, preserves dimnames, treats zero-rank Joint/Individual as available zero matrices | `test-extractors.R`, `test-missing-native-reconstruction.R`, `test-variance-partition.R` |
| S1-03 | Replace low-risk positional SVD list reads | Use named fields such as `[['d']]` where the code means singular values | `test-rajive-boundaries.R`, `test-robustsvd-rcpp.R` |
| S1-04 | Name small native-missing constants | Preserve defaults and error behavior while making constants discoverable | `test-missing-native-validation.R`, native core tests |
| S1-05 | Remove dead code only with proof | Reference scan across source, tests, vignettes, docs, metadata, and a targeted regression test per candidate | Affected area plus full targeted suite |

S1-00 should run before accessor migration so the internal names are canonical.
S1-01 should introduce helpers and tests before call-site migration. S1-02
should keep compatibility behavior at exported API boundaries only.

Typed unavailable-matrix conditions are reserved for valid requests that cannot
produce a matrix. Use class `rajiveplus_component_matrix_unavailable` with
structured fields `block`, `component`, and controlled `reason` values:
`residual_not_stored`, `invalid_component_record`, or
`unsupported_component_matrix`. Tests should assert class and fields, not exact
message prose, except targeted public migration errors.

### Stage 2 - Result Schema And Module Boundaries

| ID | Goal | Key contract | Primary tests |
|---|---|---|---|
| S2-01 | Add strict non-exported constructors | `.new_rajive()`, `.new_rajive_incomplete()`, and `.new_rajive_rank_only()` validate schema/shape without exporting new API | `test-result-object-schema.R`, extractor/native/bootstrap tests |
| S2-02 | Route complete and native result construction through constructors | Public slots, class order, names, dimensions, and accessor-visible behavior stay structurally equivalent | Native dispatch/core/reconstruction tests plus extractor tests |
| S2-03 | Split `R/visualization.R` only after accessors/constructors are stable | Move one topical group per PR without changing exported names or roxygen aliases | Visualization, association, stability, build-metadata tests |
| S2-04 | Split `R/missing_data.R` only after schema helpers are stable | Separate observed masks/preprocess, fit, diagnostics/accessors, and uncertainty; deeper metadata validators belong here | Full native missing targeted suite |
| S2-05 | Replace bootstrap/inference direct reads with accessors | Preserve payloads and rank-only object behavior | `test-bootstrap-engine.R`, `test-inference-ci.R` |

### Stage 3 - Native Missing-Data Research, Not Cleanup

Do not replace the current native missing-data algorithm as part of the
maintainability refactor. Any redesign must be a separate research/validation
stream with:

- a formal observed-entry JIVE objective,
- a robust weighted native low-rank kernel,
- benchmarks against current native mode,
- benchmarks against missMDA multiple imputation plus aligned RaJIVE pooling of
  interpretive outputs rather than raw averaged decomposition matrices.

## Architecture Sources

- [../CONTEXT.md](../CONTEXT.md): glossary only.
- [../docs/architecture.md](../docs/architecture.md): result-object and module map.
- [../docs/adr/0001-preserve-rajive-block-decomps-layout.md](../docs/adr/0001-preserve-rajive-block-decomps-layout.md): preserve public `block_decomps` shape.
- [../docs/adr/0002-use-residual-instead-of-noise.md](../docs/adr/0002-use-residual-instead-of-noise.md): use full component vocabulary.
- [../docs/adr/0003-strict-constructors-scoped-reader-validation.md](../docs/adr/0003-strict-constructors-scoped-reader-validation.md): strict constructors and scoped reader validation.

## Validation Gates

For each implementation slice:

1. Add or update the smallest red-first test that demonstrates the intended
   contract.
2. Make the focused source change.
3. Run the targeted `testthat::test_file()` or filter for the changed area.
4. Run broader validation when the slice touches shared contracts:
   `devtools::test()`, then `devtools::check(args = '--no-manual')`.
5. Run `devtools::document()` when roxygen or exports change.
6. Run `git diff --check` before handoff.

Known carried check findings are acceptable only if unchanged from the current
baseline: missing `qpdf`, top-level `scratch`, visible-binding notes for
ggplot/foreach NSE symbols, non-portable `-march=nocona`, and optional vignette
dependency notes for `RaJIVE`, `tibble`, and `tidyr`.

## Durable Blockers And Deferred Work

| Item | Status | Next action |
|---|---|---|
| Full source/install/check validation after latest native missing-data patch | Open | Rerun full source/install/check validation before release claims. |
| Package vignette HTML after latest native edits | Stale | Refresh package-vignette HTML artifacts before release. |
| Heavy benchmark validation | Native/jackstraw/PIP and Wedin scoped calibration pass locally; complete manifest fails joint-rank power; pinned standard-JIVE/original-RaJIVE comparison is prepared but not run | Smoke-test and run the paired reference comparison, then diagnose joint-rank strong-signal recovery before broad calibration claims. |
| Release Gate 2-4 | Partially closed | Preserve the passing scoped receipts; repair joint-rank power and rerun the complete slow manifest. |
| BMV downstream caches | Stale | Rerun fit and downstream stages from the 120-sample union preprocess cache. |
| PERF-001 and PERF-004 | Deferred | Revisit only with exact-result tests and profiling evidence. |

## Evidence Policy

Archived and evidence-only documents are indexed in
[archive/README.md](archive/README.md). They can explain why a decision was made,
but they do not override this file, [PROGRESS.md](PROGRESS.md),
[AGENTS.md](AGENTS.md), [../CONTEXT.md](../CONTEXT.md), or active ADRs.
