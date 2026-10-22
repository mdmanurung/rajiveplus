# Stage-2 hygiene receipt: license/attribution and metadata fixes

Date: 2026-10-22. Branch: `publication/stage1-truth-wedin-design-20261022`.

## Changes

1. **`inst/CITATION` Lock et al. DOI corrected.** The flagged
   `10.1214/12-AOAS708` does not resolve (Crossref HTTP 404) and belongs to a
   different paper. The correct DOI for Lock, Hoadley, Marron and Nobel
   (2013), "Joint and individual variation explained (JIVE) for integrated
   analysis of multiple data types", Ann. Appl. Stat. 7(1):523-542, is
   `10.1214/12-AOAS597` (verified against Crossref; full title also
   corrected). The Feng et al. (2018) DOI `10.1016/j.jmva.2018.03.008` and
   the RaJIVE arXiv DOI `10.48550/arXiv.2101.09110` were verified and kept.
2. **Description DOI form.** `<https://doi.org/...>` rewritten to the
   `<doi:10.48550/arXiv.2101.09110>` form required by R CMD check.
3. **`withr` single-listing.** Removed from Suggests; retained in Imports.
4. **RaJIVE MIT attribution.** The pinned upstream
   (`ericaponzi/RaJIVE@7d494d1`, `License: MIT + file LICENSE`, file LICENSE
   "YEAR: 2021, COPYRIGHT HOLDER: Erica Ponzi") was re-fetched and verified.
   This package's `file LICENSE` now carries both copyright blocks (2026
   Manurung; 2021 Ponzi for the retained/adapted robust-SVD and core JIVE
   routines) plus the provenance note naming the pinned commit, satisfying
   the MIT notice-preservation obligation. DESCRIPTION already lists Ponzi,
   Ghosh and Thoresen as contributors of the original implementation.

## Verification

- `readCitationFile("inst/CITATION")` parses 4 entries with the DOIs above.
- `read.dcf("DESCRIPTION")` parses; `withr` present in Imports only.
- Upstream LICENSE/DESCRIPTION re-fetched at the pinned commit this session.
