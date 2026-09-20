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
| Slow jackstraw/rank/Wedin calibration | Scheduler/manual workflow prepared; no authorized heavy run. | `NOT RUN` | `validation/slow_tests.json`; `.github/workflows/calibration.yaml` |

All relative paths above are under
`docs/_codexdocs/execution/2026-09-19/` unless another path is shown.
