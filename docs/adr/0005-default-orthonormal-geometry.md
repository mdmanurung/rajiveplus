# ADR 0005: Default orthonormal geometry and constrained Individual refit

## Status

Accepted 2026-10-22. Promotes the stage-1 `RJP-GEOM-CANDIDATE` semantics to the
default estimator (`RJP-BASE` v2) and closes defects G1 and G2.

## Context

AJIVE-style geometry assumes that score matrices are orthonormal bases of
estimated subspaces: the stacked joint aggregation, the common l2
identifiability filter, the projector `I - Q Q'`, and the Joint/Individual
partition all consume `Q'Q = I`. The shipped default (`RJP-BASE` v1) violated
this twice:

- **G1** — per-block robust score bases and the selected joint factors were
  used raw (`basis_extraction_tolerance = "none_raw_robust_factors"`). On the
  standard three-block fixture the worst block Gram error was 7.3e-2.
- **G2** — the Individual Component was obtained by projecting the input into
  the joint complement and then performing an unconstrained robust refit,
  which reintroduced joint variation: worst relative fitted-span leakage
  1.6e-2 against a 1e-8 contract.

The stage-1 paired ablation (`RJP-GEOM-CANDIDATE` arm) validated the corrected
semantics on the smoke fixture: orthonormal arms reached Gram error <= 2.2e-16
and constrained leakage <= 7.0e-17, with reconstruction preserved.

## Decision

The default estimator adopts three changes, reusing the ablation-validated
algebra (`.rank_revealing_basis()` in `R/Rajive_helpfunctions.R`):

1. **Block bases.** Each retained per-block robust score matrix is
   orthonormalized by a rank-revealing SVD pass with tolerance
   `max(dim) * .Machine$double.eps * max(singular values)`. Rank-deficient
   bases are truncated with a warning; the stack capacity becomes
   `min(achieved block ranks)`. A fully rank-deficient stack aborts with
   class `rajiveplus_degenerate_basis`.
2. **Joint canonicalization.** The selected joint factors are orthonormalized
   by the same rank-revealing pass *before* the identifiability filter, so the
   filter's projection norms and the downstream projector act on an
   orthonormal `Q`. The pre-filter drop is recorded as
   `canonical_rank_drop` in `joint_rank_sel`. For orthonormal block bases the
   squared singular values of the stack equal the eigenvalues of the summed
   block projectors, so the rank-selection statistic keeps its meaning.
3. **Individual refactorization.** The Individual Component freezes the
   selected robust rank, projects the selected reconstruction onto the joint
   complement, and refactorizes with an exact algebraic SVD — no second
   robust fit. The constrained rank is
   `min(selected, directions above dimension-scaled machine epsilon)`.
   `get_individual_decomposition_robustH()` gains a `constraint` argument
   (`"joint_complement"` default, `"none"` legacy) so the experimental
   ablation adapter keeps its unconstrained contrast arm.

`RJP-BASE` moves to version 2 with status `default_orthonormal_constrained`
(`basis_extraction_tolerance = "dimension_scaled_machine_epsilon"`,
`individual_constraint = "exact_joint_complement_reprojection"`,
`individual_refactorization = "algebraic_svd_only"`). The three geometry tests
in `tests/testthat/test-robust-basis-orthonormality.R` are promoted to the
default suite in the same change.

## Consequences

- Fits are bit-different from `RJP-BASE` v1: scores, ranks and downstream
  statistics can shift. Value-pinning fixtures are updated with the change,
  preserving each test's purpose (determinism, schema, contract).
- The Wedin bound, permutation bound, robust block factorization and native
  missingness machinery are unchanged; the Wedin term remains diagnostic-only.
- The experimental ablation adapter keeps all eight arms; its
  raw/unconstrained arms are now legacy contrasts rather than the default.
- Rank-selection calibration against the statistic-matched permutation null
  must be (re)run for the new default before any recovery claims.
