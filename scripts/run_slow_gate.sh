#!/usr/bin/env bash
set -euo pipefail

: "${R_SCRIPT:=Rscript}"
: "${RAJIVE_GATE_DIR:=docs/_codexdocs/execution/2026-09-19/gates}"
export RAJIVE_GATE_DIR
mkdir -p "${RAJIVE_GATE_DIR}"

RAJIVE_RUN_SLOW=1 "${R_SCRIPT}" --vanilla -e \
  'devtools::load_all(".", quiet = TRUE); testthat::test_local(reporter = testthat::JunitReporter$new(file = file.path(Sys.getenv("RAJIVE_GATE_DIR"), "slow-tests.xml")), stop_on_failure = TRUE)' \
  2>&1 | tee "${RAJIVE_GATE_DIR}/slow-tests.log"
python3 scripts/check_slow_manifest.py \
  validation/slow_tests.json "${RAJIVE_GATE_DIR}/slow-tests.xml"
