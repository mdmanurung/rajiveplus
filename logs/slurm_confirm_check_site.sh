#!/bin/bash
#SBATCH --job-name=rajive_confirm
#SBATCH --partition=all
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=8:00:00
#SBATCH --output=logs/slurm_confirm_%j.log
#SBATCH --error=logs/slurm_confirm_%j.log

# Post-doc-fix confirmation for rajiveplus.
#   1. devtools::check(args = c('--no-manual'))   -> expect 1 warning (qpdf) baseline
#   2. pkgdown::build_site(lazy = TRUE)           -> refresh docs/articles/ site copies
# No package install/deploy.

cd /exports/para-lipg-hpc/mdmanurung/RaJIVEutils

if ! command -v conda >/dev/null 2>&1; then
  echo "conda command not found on compute node"
  exit 127
fi

echo "====== CONFIRM CHECK + SITE START ======"
echo "Timestamp: $(date)"

echo ""
echo "STEP 1/2: devtools::check(args = c('--no-manual'))"
echo "==========================================="
conda run -n R4_51 R --no-save -q -e "devtools::check(args = c('--no-manual'), error_on = 'never')" 2>&1
CHECK_EXIT=$?
echo "Check exit code: $CHECK_EXIT"

echo ""
echo "STEP 2/2: pkgdown::build_site(lazy = TRUE, preview = FALSE)"
echo "==========================================="
conda run -n R4_51 R --no-save -q -e "pkgdown::build_site(lazy = TRUE, preview = FALSE)" 2>&1
SITE_EXIT=$?
echo "Site exit code: $SITE_EXIT"

echo ""
echo "====== CONFIRM SUMMARY ======"
echo "Step 1 (check): $CHECK_EXIT"
echo "Step 2 (site):  $SITE_EXIT"
echo "Timestamp: $(date)"
exit $SITE_EXIT
