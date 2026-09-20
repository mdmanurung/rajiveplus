#!/usr/bin/env bash
set -euo pipefail

: "${R_SCRIPT:=Rscript}"
: "${RAJIVE_GATE_DIR:=docs/_codexdocs/execution/2026-09-19/gates}"
mkdir -p "${RAJIVE_GATE_DIR}"

"${R_SCRIPT}" --vanilla -e \
  'devtools::check(document = FALSE, error_on = "never", args = c("--no-manual", "--as-cran"))' \
  2>&1 | tee "${RAJIVE_GATE_DIR}/r-cmd-check.log"
python3 scripts/check_rcmd_fingerprint.py \
  validation/check_fingerprint.json "${RAJIVE_GATE_DIR}/r-cmd-check.log"
