# Stage-1 evidence index

Scope: simulator truth repair, source-grounded Wedin derivation, fixed-rank
paired-ablation correctness only. Package remains 0.1.0 and NOT_READY.

The stage-1 deliverable evidence archive contains bounded command receipts,
logs and maximum-child RSS records, including failed development attempts.
This directory stores the final compact validation summary. Final source
commits and patch-replay verification are in the deliverable status manifest.

- `simulator_red_verified`: unmodified production, 57 failures / 20 passes,
  no warnings; absent certification accounts for many assertions, not 57
  independent scientific defects.
- `simulator_final_targeted`: initial repair 146 assertions pass.
- `simulator_seed_compatibility_v3`: nine original feasible draws, all prior
  fields and final RNG states identical after removing the new certificate.
- `stage1_reduced_regression_v1`: 1,440 assertions pass, 18 expected skips,
  no warnings; excludes native-union vignette test only. Later boundary tests
  are validated again in the final receipt.
- `eight_arm_smoke_v2`: one certified synthetic centered dataset, all eight
  arms executable; raw/robust/original reproduces public baseline numerical
  components and public dimension names are checked separately.
- `stage1_open_geometry_gate`: two failures / one pass, unchanged default
  G1/G2 defects retained, not hidden by reduced-suite skips.
- `wedin_independent_arithmetic`: C1-C10 pass. The portable copy in
  `scripts/check_stage1_wedin.R` parses the unchanged current helper instead of
  a private frozen snapshot; final validation confirms both.

No automatic-rank calibration, scientific superiority, application results,
full release build/check or default promotion is established.
