#!/usr/bin/env bash
set -euo pipefail

: "${R_SCRIPT:=Rscript}"
: "${RAJIVE_GATE_DIR:=docs/_codexdocs/execution/2026-09-19/gates}"
mkdir -p "${RAJIVE_GATE_DIR}"

"${R_SCRIPT}" --vanilla -e \
  'devtools::load_all(".", quiet = TRUE); testthat::test_local(stop_on_failure = TRUE)' \
  2>&1 | tee "${RAJIVE_GATE_DIR}/fast-tests.log"
