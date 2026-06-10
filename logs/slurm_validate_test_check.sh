#!/bin/bash
#SBATCH --job-name=rajive_validate
#SBATCH --partition=all
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=8:00:00
#SBATCH --output=logs/slurm_validate_%j.log
#SBATCH --error=logs/slurm_validate_%j.log

# Validation-only gates for rajiveplus (no pkgdown build, no install).
#   1. testthat::test_local(stop_on_failure = TRUE)  -> full suite, slow tests skipped
#   2. devtools::check(args = c('--no-manual'))      -> source check
#
# Submit from repo root:
#   sbatch logs/slurm_validate_test_check.sh
# Results in: logs/slurm_validate_<jobid>.log

cd /exports/para-lipg-hpc/mdmanurung/RaJIVEutils

if ! command -v conda >/dev/null 2>&1; then
  echo "conda command not found on compute node"
  exit 127
fi

echo "====== VALIDATION GATES START ======"
echo "Timestamp: $(date)"

echo ""
echo "GATE 1/2: testthat::test_local(stop_on_failure = TRUE)"
echo "==========================================="
conda run -n R4_51 R --no-save -q -e "testthat::test_local(stop_on_failure = TRUE)" 2>&1
TEST_EXIT=$?
echo "Test exit code: $TEST_EXIT"
if [ $TEST_EXIT -ne 0 ]; then
  echo "Gate 1 failed; aborting remaining gates."
  exit $TEST_EXIT
fi

echo ""
echo "GATE 2/2: devtools::check(args = c('--no-manual'))"
echo "==========================================="
conda run -n R4_51 R --no-save -q -e "devtools::check(args = c('--no-manual'), error_on = 'never')" 2>&1
CHECK_EXIT=$?
echo "Check exit code: $CHECK_EXIT"

echo ""
echo "====== VALIDATION SUMMARY ======"
echo "Gate 1 (tests): $TEST_EXIT"
echo "Gate 2 (check): $CHECK_EXIT"
echo "Timestamp: $(date)"
exit $CHECK_EXIT
