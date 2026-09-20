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
| Native missing recovery/coverage | Experimental | `NOT RUN` | `stage_d_status.json` | Bounded pilot is insufficient for acceptance. |
| Jackstraw/PIP calibration | Experimental | `NOT RUN` | `validation/slow_tests.json` | Heavy run requires separate scheduler/remote authority. |
| Remote CI and platform matrix | Mandatory for release | `NOT RUN` | `.github/workflows/R-CMD-check.yaml` | Local execution cannot establish remote platforms. |
| Scheduler validation | Optional continuation | `NOT RUN` | `jobs/rajiveplus_validation.slurm` | Submission requires separate authority. |
| BMV regeneration | Application evidence | `NOT RUN` | `stage_d_status.json` | Active 120-sample regeneration is outside local package completion. |
| Version bump, publication, tag | Release operation | `BLOCKED` | Frozen plan authorization boundary | Requires remaining mandatory gates plus explicit maintainer authorization. |
