# Bounded validation and benchmark record

Snapshot: 2026-09-20. These results are local engineering evidence, not broad
scientific acceptance.

| Study | Result | Classification | Receipt |
|---|---|---|---|
| Geometric paired pilot | Clean degradation was -0.0175 to -0.0379. Contamination degradation was +0.2302 to +0.3890, beyond the frozen +0.02 margin. | `REJECT` | `stage_c_local_pilot.tsv`; `stage_c_candidate_decision.json` |
| Native missing pilot | 8/8 fits completed; native projector error was lower than simple imputation in 7/8 bounded replicates; 1/8 outer loops converged. Left-censoring recovery was weak. | `EXPERIMENTAL`, `PASS_WITH_LIMITATIONS` | `stage_d_native_pilot.tsv`; `stage_d_status.json` |
| Runtime pilot | Complete: 0.091 s at 50x40 and 0.579 s at 200x80. Weighted: 0.416 s and 2.067 s. Input matrices were 0.015 and 0.122 MiB. | `BOUNDED_LOCAL_PILOT` | `stage_d_performance_pilot.tsv` |
| missMDA comparison | Dependency unavailable locally. | `BLOCKED` | `stage_d_status.json` |
| Final 800-dataset paired ablation | Unnecessary for the rejected candidate and not authorized for scheduler execution. | `NOT RUN` | `paired_ablation_manifest.json` |
| Slow jackstraw/rank/Wedin calibration | Local fail-closed execution completed Wedin and joint-rank files before stopping at the joint-rank power failure. | `PARTIAL`; see component rows below | `validation/slow_tests.json`; `gates/calibration-20260920-v4/` |
| Native recovery | Promoted 30-iteration outer cap converged in 60/60 datasets versus 45/60 for the legacy five-iteration cap. Mean projector-error change was -0.0134 versus legacy and -0.1477 versus mean imputation. | `PASS`, scoped to MCAR, MAR-like, and structured-row missingness with fixed joint rank | `gates/native-jackstraw-pip-20260920-v2/native-recovery.tsv` |
| Native bootstrap coverage | Thirty MCAR datasets produced 0.884 mean pointwise joint-score coverage with 20 aligned bootstrap refits per dataset; 30/30 primary fits converged. | `PASS`, scoped simulation evidence | `gates/native-jackstraw-pip-20260920-v2/native-coverage.tsv` |
| Jackstraw and pooled PIP | Across 100 datasets: mean null FPR 0.0673, mean FDP 0.0622, BH power 0.5545, high-null-PIP rate 0.0131, PIP power 0.7018, median PIP AUC 0.8423. Conservative pi0 fallback was used in 9/100 datasets; no non-finite PIPs remained. | `PASS`, conditional on fixed true rank and the declared signal/null design | `gates/native-jackstraw-pip-20260920-v2/jackstraw-pip.tsv` |
| Wedin Haar calibration | Correcting the reference from the thin-SVD complement (35 dimensions) to the full ambient complement (55 dimensions) changed the deterministic U-side KS p-value from 8.35e-19 to 0.544; all 3/3 Wedin tests pass. | `PASS` | `gates/calibration-20260920-v4/test-calibration-wedin.xml` |
| Complete slow manifest | Joint-rank Type-I rate passed at 0.00, but strong-signal recovery was 0.53 versus the required 0.80. | `FAIL`; Wedin is no longer the blocker | `gates/calibration-20260920-v4/test-calibration-joint-rank.xml` |

All relative paths above are under
`docs/_codexdocs/execution/2026-09-19/` unless another path is shown.
