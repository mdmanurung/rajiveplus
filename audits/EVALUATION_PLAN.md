# Evaluation Plan — scientific correctness, publication readiness, API usability

Active: 2026-09-26. This file is the strategy owner for the evaluation
workstream. [DEFECT_REGISTER.md](DEFECT_REGISTER.md) holds the tracked findings.
[PROGRESS.md](PROGRESS.md) holds current state and next commands.

Sequencing decision: correctness first with a hard gate. Usability and
packaging work does not open until the correctness gate is decided. Evaluation
first, then fix what is confirmed. Breaking API changes are permitted at
version `0.1.0`.

## Central finding that shapes this plan

The repository already names the right scientific questions, but the
instruments used to answer them were themselves broken. Calibration numbers,
including the red joint-rank gate, were not interpretable. Phase 0 was therefore
load-bearing rather than administrative.

Phase 0 is complete. Summary of what it established:

- The Wedin joint threshold was computed by summing a whole vector of resampling
  draws and subtracting it from the number of Data Blocks, producing a large
  negative value where a squared singular-value threshold belongs. The term was
  therefore never binding, and the documented `max(wedin, rand_dir, perm)` rule
  did not describe the code.
- Fixing that arithmetic made the Wedin term reachable and revealed it to be far
  too conservative: its threshold is nearly constant at about 2.8, while the
  observed squared stacked amplitudes lie between 1.6 and 2.9. Correcting the
  arithmetic alone cost 87% of recoverable signal at true rank 1.
- The benchmark generator's ground truth was not identifiable, and the joint-rank
  recovery metric counted overestimation as power.
- With the instruments repaired, the joint-rank rule recovers rank 1 essentially
  always and rank 2 poorly, and the error is entirely one-sided toward
  under-selection.

The re-gated verdict is therefore: **the joint-rank power failure is a genuine
method defect, not a measurement artifact.** The rule under-selects. The
random-direction bound is the only calibrated component, and it is
data-independent.

## Phase status

| Phase | Scope | Status |
|---|---|---|
| 0 | Repair measurement instruments, re-measure | `DONE` |
| 1 | Mathematical correctness of the estimator | `PARTIAL` — I1 fixed; G1, G2, S1, W3, W4 open |
| 2 | Statistical calibration of the shipped estimator | `NOT STARTED` |
| 3 | Reference benchmark against pinned RaJIVE | `NOT STARTED` — reference library absent |
| 4 | Usability and API redesign | `NOT STARTED` — gated on Phase 1 |
| 5 | CRAN packaging | `PARTIAL` — mechanical blockers fixed; gate not run |
| 6 | Methods-paper evidence | `NOT STARTED` — gated on Phase 5 |

## Phase 1 — Mathematical correctness (hard gate)

The blocker is that `RJP-BASE` ships raw robust factors with no orthonormal
canonicalisation (`basis_extraction_tolerance = "none_raw_robust_factors"`),
while projectors, principal angles, the variance identity and the joint-rank
threshold all assume an orthonormal basis.

| ID | Task | State |
|---|---|---|
| 1.1 | State the estimator contract: what is orthonormal, what is a subspace, what is a statistic, what is a null. | open |
| 1.2 | Factor the geometric correction. `RJP-GEOM-CANDIDATE` bundled representation, statistic and estimator together, so its 3-replicate rejection could not be attributed. Re-run as a factorial ablation: representation only, statistic only, both. | open |
| 1.3 | Re-factorize the Individual Component exactly after joint-complement reprojection. Measured leakage 0.0158 against a `1e-8` target. | open, gated |
| 1.4 | Fix the identifiability filter to reject every unsupported direction. | `DONE` |
| 1.5 | Resolve the statistic/null mismatch. The robust elementwise stacked statistic is not invariant to within-block basis rotation; the nulls are classical. | open |
| 1.6 | Enforce or record centring and Frobenius normalisation. | open |
| 1.7 | Re-derive the Wedin bound and its across-block combination against the pinned reference. | `BLOCKED` on the reference |
| 1.8 | Rank-selection rule. The rule under-selects at rank 2. Test candidate rules as a paired ablation with predeclared margins. | open |

Gate 1 exit: all five Tier-B invariants hold on real fits across all scenarios,
plus a recorded accept/reject decision per ablation arm.

**Threshold re-specification rule.** Fixing the metric made the gate harder, not
easier, because overestimation previously counted as power. If the corrected
rule cannot reach 0.80, that is a finding about the method. The three acceptable
responses are: fix the rule; re-derive the threshold from what the estimator can
achieve with a recorded rationale; or report it as a method limitation in the
documentation and the paper, and re-specify the gate against the corrected
instrument. Quietly editing the 0.80 to whatever the corrected number happens to
be is not an acceptable response and must be recorded as a maintainer decision
if it happens.

## Phase 2 — Calibration of whatever Phase 1 ships

Runs on SLURM. Replicate budgets must be fixed per cell before running: at a 0.05
event rate, 200 datasets give a Monte Carlo standard error near 0.015, and
roughly 1,825 independent datasets are needed for a 0.01 half-width.

- Type-I rate under the global null, with the data-independent bound characterised (W5).
- Rank recovery on valid truth, exact/under/over, with Monte Carlo standard error.
- Robustness across contamination types and heavy-tailed noise.
- Wedin and random-direction calibration against a structurally different reference.
- Jackstraw null uniformity, empirical FDR, power, approximate versus full refit.
- Native missing data across MCAR, MAR-like and blockwise patterns.
- Variance accounting reconciled to a single contract (V1).

## Phase 3 — Reference benchmark

Pinned CRAN `r.jive` and original RaJIVE are absent from this machine; the
upstream repository is `ericaponzi/rajive` at commit
`7d494d11029e538587ee9b27688adacf7f1f9841`, which matches the commit already
recorded in the repository's own provenance notes. Restore the reference, then
re-derive W3 and W4 against it before the Wedin term is allowed back into the
default threshold.

## Phase 4 — Usability and API redesign

Gated on Phase 1. Target surface is roughly 27 exports, down from 59, with
breaking changes permitted. Priority order within the phase:

1. Make the fit object self-contained by storing `blocks` and `initial_signal_ranks`, which removes re-supply at 13 required and 6 conditional call sites.
2. Export a signal-rank selection helper, so `initial_signal_ranks` stops being a required positional the user must guess.
3. Honour user Data Block names; three accessors currently hard-code `block1` to `blockK`.
4. Unify the error and warning vocabulary; four coexist, and one warning names an argument `Rajive()` does not have.
5. Finish the `noise` to `residual` vocabulary migration and remove remaining glossary violations.
6. Provide one canonical fully evaluated end-to-end vignette; all four inferential README chunks are currently `eval=FALSE`.
7. One name per concept: `k` versus `block`, four `type` domains, five `method` meanings, three names for "top N".
8. Full collapse of the export surface, with a migration table in `NEWS.md`.

`Rajive()` keeps its name. Renaming it to `rajive()` would collide with the result
class and break the recognisable lineage to JIVE, aJIVE and RaJIVE.

## Phase 5 — CRAN packaging

Fixed in this pass: the R version floor, undeclared `jsonlite`, `Title` case, the
missing method citation, `inst/CITATION` version and reference errors, `cph`
attribution, and the `.Rbuildignore` gaps that shipped test debris and purl
intermediates.

Still blocking, in order:

1. One real `R CMD check --as-cran` reaching `Status: OK` on the exact tarball. Both prior attempts died with `Execution halted`, and the only `0/0/0` predates the commit that rewrote `DESCRIPTION`, `NAMESPACE` and 14 `R/` files.
2. Rebuild and re-attest the tarball. The root tarball hash does not match the attested hash, it contains no `inst/doc`, and it contains a stray `--help` file.
3. Make all seven vignettes build from a clean clone. Four read untracked `.rds` caches unconditionally.
4. Run the CI matrix; it has never run. Add `--as-cran` to the pinned-R job and fix the invalid `needs:` input in the calibration workflow.
5. Gate the unconditional `library()` calls on Suggests packages in three vignettes.
6. Stop publishing internal maintainer documents on the pkgdown site.
7. Add `CODE_OF_CONDUCT.md` and `CONTRIBUTING.md`; fix the 404 self-link.

## Phase 6 — Methods-paper evidence

Gated on Phase 5. Reuses the Phase 0 to 3 receipts. Requires a formal estimator
definition, a simulation study on valid truth, a reference comparison, a
regenerated real-data application from the active 120-sample inputs, and a
limitations section covering the rank threshold's lack of formal error control,
the approximate jackstraw, unsupported MNAR, approximate joint/individual splits
under partial missingness, and compute scaling.

## Explicitly not done

The following are recorded as `CONFIRMED` in the register but were not fixed,
because each needs a decision or a reference that is not available:

- V1, the two disagreeing variance APIs.
- S1, unenforced centring and normalisation.
- M2, the jackstraw calibration's dataset-level denominators.
- G1, G2, W3, W4, and the Phase 1 factorial ablation.

The 59-export API collapse, the self-contained fit object, and the rank-selection
helper were scoped but not started, because they are gated on Phase 1.
