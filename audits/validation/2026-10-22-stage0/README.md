# Stage-0 correctness receipt index — 2026-10-22

Scope: local-only reporting repair from PR #9 head
`8ceabeedea6501a15b10158e40ad8cebd904ec11`, R 4.4.2.
This is not a release gate, confirmatory simulation or clinical analysis.
The final stage report/evidence archive carries full logs, build/suite terminal
statuses, environment inventory and final source identity.

## Red-first repair

The actual-fit regression was committed alone at
`4817b7657dfe78430ce51ea42c877b1dcff478c8` before production edits:

- `variance_red_verified.json`: 27 failures, 6 passes, no warning or skip.
- `variance_green_v1.json`: 38 focused assertions pass after the implementation
  and supplemental mock-test correction (33 actual-fit assertions + 5
  supplemental assertions).
- `affected_regressions.json`: 132 assertions pass, including variance,
  extractors, fit schema and RNG regressions.
- `matrix_and_generator_probes.json`, `variance_before_after.csv`: same saved
  synthetic fit before/after, no refit; serialized fit and RNG unchanged.
  Matrix and cross-term energy closure satisfy relative 1e-10.

The fixture uses the independently checked internal identifiable simulator,
not an application dataset or the uncertified public-generator edge cases.
The missing-entry test masks a previously complete fit for **reporting only**;
it is not evidence of native-missing estimator validity. The wholly zero-energy
record is supplemental because the estimator cannot fit a wholly degenerate
block. It does not establish all-zero-data fitting support.

`showVarExplained_robust()` now sums reconstructed J/I/E matrix energies on the
same observed domain and divides by observed data energy. It reuses the
existing partition routine; the latter's `*_prop` denominator remains component
energy, and legacy `reconstruction_error` is unchanged. Fitted results,
rank selection, preprocessing and object layout are not modified.

## Independent scientific gates

- `independent_instrument_tests.json`: 76 assertions pass across generator,
  all-rejection identifiability, Wedin-reference and arithmetic files. This is
  neither a Wedin derivation nor calibration.
- `open_geometry_gate.json`: 2 failures, 1 pass. Worst robust Gram error
  0.0727897047 exceeds 1e-10; Individual leakage 0.01579166 exceeds 1e-8.
  The joint-score orthonormality assertion passes.
- `generator_feature_capacity_probe.csv`: accepted requested Joint rank 3,
  p=(2,2), actual Joint matrix ranks (2,2).
- `generator_forced_intersection_probe.csv`: n=8, Joint rank 2, Individual
  ranks (4,4), complement dimension 6, measured all-block Individual
  intersection 2. A shared Individual subspace is forced by dimension.

Those new generator defects are not repaired here. Existing calibration
pilots and historical check totals are not rerun evidence for current source.
The original threshold numbers, comparison margins and replicate budgets
remain unchanged.

## Full-suite and packaging qualification

`baseline_fast_gate_v2.json` records a 900-second timeout at the pinned
unmodified source, with no final suite totals. The last logged context was
the native-missing union vignette. A restricted test/build may be useful as
diagnosis but cannot turn this into a release pass.

Receipts record maximum-child RSS for successfully terminated commands, not
the concurrent process-tree peak. RSS from timed-out descendants can be
incomplete and must not be used as a peak-memory estimate.
The runner records source HEAD and tracked diff at completion; concurrent
audit-only documentation edits do not imply a new numerical implementation.
Final exact-commit confirmation receipts in the stage evidence avoid this
ambiguity. An empty first-launch baseline log and an exploratory red run
with corrected test attributes are retained as non-authoritative history;
only `variance_red_verified` is the definitive red evidence.
