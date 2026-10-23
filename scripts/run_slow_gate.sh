#!/usr/bin/env bash
set -euo pipefail

: "${R_SCRIPT:=Rscript}"
: "${RAJIVE_GATE_DIR:=docs/_codexdocs/execution/2026-09-19/gates/$(date -u +%Y%m%dT%H%M%SZ)}"
: "${RAJIVE_CALIBRATION_CORES:=1}"
: "${RAJIVE_SLOW_MANIFEST:=validation/slow_tests.json}"
export RAJIVE_GATE_DIR
export RAJIVE_CALIBRATION_CORES
export RAJIVE_SLOW_MANIFEST
mkdir -p "${RAJIVE_GATE_DIR}"
RAJIVE_GATE_DIR="$(cd "${RAJIVE_GATE_DIR}" && pwd -P)"
export RAJIVE_GATE_DIR

for artifact in slow-tests.log native-recovery.tsv \
  native-coverage.tsv jackstraw-pip.tsv; do
  if [[ -e "${RAJIVE_GATE_DIR}/${artifact}" ]]; then
    echo "refusing to reuse calibration artifact: ${RAJIVE_GATE_DIR}/${artifact}" >&2
    exit 64
  fi
done
if compgen -G "${RAJIVE_GATE_DIR}/*.xml" > /dev/null; then
  echo "refusing to reuse JUnit artifacts in ${RAJIVE_GATE_DIR}" >&2
  exit 64
fi

while IFS= read -r test_file; do
  test_name="$(basename "${test_file}" .R)"
  export RAJIVE_TEST_FILE="${test_file}"
  export RAJIVE_JUNIT_FILE="${RAJIVE_GATE_DIR}/${test_name}.xml"
  RAJIVE_RUN_SLOW=1 "${R_SCRIPT}" --vanilla -e \
    'devtools::load_all(".", quiet = TRUE); testthat::test_file(Sys.getenv("RAJIVE_TEST_FILE"), reporter = testthat::JunitReporter$new(file = Sys.getenv("RAJIVE_JUNIT_FILE")), stop_on_failure = TRUE, stop_on_warning = TRUE)' \
    2>&1 | tee -a "${RAJIVE_GATE_DIR}/slow-tests.log"
done < <(python3 -c 'import json,os; d=json.load(open(os.environ["RAJIVE_SLOW_MANIFEST"])); print("\n".join(dict.fromkeys(x["file"] for x in d["required_tests"])))')
python3 scripts/check_slow_manifest.py \
  "${RAJIVE_SLOW_MANIFEST}" "${RAJIVE_GATE_DIR}"
