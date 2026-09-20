# Local release checklist

Snapshot: 2026-09-20. The package version remains `0.1.0`; the requested target
is the `0.2.0-rc1` completion stream. Version promotion, publication, and tags
still require the remaining mandatory gates and explicit maintainer authority.

Every local receipt resolves its source hash through
`docs/_codexdocs/execution/2026-09-19/candidate_identity.json`; profile hashes
are in `method_profiles.json` and the frozen paired manifest.

| Gate | Class | State | Command or artifact | Acceptance / staleness |
|---|---|---|---|---|
| Focused methodology/native/inference tests | Mandatory | `PASS` | `focused_post_revert.log` | Zero failures/warnings; stale after relevant source changes. |
| Repository full test suite | Mandatory | `PASS` | `full_tests_final.log` | Exit 0; both vignette tests enabled; 10 declared slow/performance skips. |
| Source build | Mandatory | `PASS` | `source_build.log`; final tarball | R4_51, `R CMD build --no-manual`; all vignettes built. |
| Job-local install | Mandatory | `PASS` | `source_install.log` | Exact tarball installed into `/tmp/rajiveplus-r4_51-lib`; no shared-library mutation. |
| Strict substantive check fingerprint | Mandatory | `PASS` | `source_check.log`; `validation/check_fingerprint.json` | Full `R CMD check --no-manual`: `Status: OK`; fingerprint 0/0/0. |
| CRAN incoming feasibility | External release gate | `BLOCKED` | `source_check_as_cran_remote_attempt.log`; `source_check_as_cran_incoming_note.log` | Incoming NOTE preserved separately; not accepted as a 0/0/0 PASS. |
| Roxygen/Rd/NAMESPACE | Mandatory | `PASS` | `devtools::document()` and generated files | Stale after roxygen source change. |
| README, vignettes, pkgdown site | Mandatory | `PASS` | `README_render.log`; `source_build.log`; `pkgdown_build.log` | Pandoc 3.4; canonical generators; source build regenerated all seven vignettes; final lazy site refresh passed. |
| Upstream compatibility pin | Mandatory for compatibility claim | `BLOCKED` | `baseline_receipt.json` | Local clone absent; no commit guessed. |
| Geometric candidate | Scientific default gate | `REJECT` | `stage_c_candidate_decision.json` | Frozen +0.02 degradation rule. Default retained. |
| Native missing recovery/coverage | Experimental, scoped | `PASS` | `gates/native-jackstraw-pip-20260920-v2/native-recovery.tsv`; `native-coverage.tsv` | 60 recovery datasets across MCAR, MAR-like, and structured-row missingness plus 30 MCAR bootstrap datasets; stale after native method/control changes. MNAR and broad application claims remain unsupported. |
| Jackstraw/PIP calibration | Experimental, scoped | `PASS` | `gates/native-jackstraw-pip-20260920-v2/jackstraw-pip.tsv`; JUnit receipts | 100 fixed-rank datasets with dense signal and appended independent nulls; pooled PIP only. Stale after jackstraw, PIP, simulation, or threshold changes. |
| Remote CI and platform matrix | Mandatory for release | `NOT RUN` | `.github/workflows/R-CMD-check.yaml` | Local execution cannot establish remote platforms. |
| Wedin Haar calibration | Mandatory for broad calibration claims | `PASS` | `gates/calibration-20260920-v4/test-calibration-wedin.xml` | 3/3 tests pass after the U-side reference was corrected to use the full ambient complement. |
| Complete slow manifest | Mandatory for broad calibration claims | `FAIL` | `gates/calibration-20260920-v4/test-calibration-joint-rank.xml` | Joint-rank null Type-I rate passes at 0.00, but strong-signal recovery is 0.53 versus the required 0.80. |
| Scheduler validation | Optional continuation | `NOT RUN` | `jobs/rajiveplus_validation.slurm` | Local deterministic execution completed the requested calibration scope; scheduler execution remains optional. |
| BMV regeneration | Application evidence | `NOT RUN` | `stage_d_status.json` | Active 120-sample regeneration is outside local package completion. |
| Version bump, publication, tag | Release operation | `BLOCKED` | Frozen plan authorization boundary | Requires remaining mandatory gates plus explicit maintainer authorization. |
