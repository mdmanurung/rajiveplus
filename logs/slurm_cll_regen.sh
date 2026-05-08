#!/bin/bash
#SBATCH --job-name=rajive_cll2
#SBATCH --partition=all
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=logs/slurm_cll2_%j.log
#SBATCH --error=logs/slurm_cll2_%j.log

set -euo pipefail

# Under sbatch, scripts run from a spool copy; use submit directory.
cd "${SLURM_SUBMIT_DIR:-$(pwd)}"

# Put conda env bin on PATH so C/C++ compilers are available for source builds.
CONDA_ENV_BIN="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin"
export PATH="${CONDA_ENV_BIN}:${PATH}"

R_BIN="${CONDA_ENV_BIN}/R"
R_SCRIPT="${CONDA_ENV_BIN}/Rscript"

# Pin BLAS/OpenMP threads to avoid nested over-subscription.
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export BLIS_NUM_THREADS=1

cleanup() {
  perl -0pi -e 's/run_heavy <- TRUE\s+# set to FALSE after \.rds files are generated/run_heavy <- FALSE  # set to FALSE after .rds files are generated/g' vignettes/cll_application.Rmd || true
}
trap cleanup EXIT

# Install package (retry up to 3 times to handle concurrent lock from bench job).
for i in 1 2 3; do
  rm -rf /exports/para-lipg-hpc/mdmanurung/R/4.5/00LOCK-RaJIVEutils 2>/dev/null || true
  "${R_BIN}" CMD INSTALL --no-multiarch --with-keep.source . && break
  echo "Install attempt $i failed, retrying in 60s..."
  sleep 60
done

# Install CLL-specific dependencies.
# Use version = '3.22' to match R 4.5; do NOT call BiocManager::install(version=...)
# without checking first (it tries to upgrade 100+ pkgs if version mismatch).
"${R_SCRIPT}" -e "
if (!requireNamespace('BiocManager', quietly = TRUE))
  install.packages('BiocManager', repos = 'https://cloud.r-project.org')
if (!requireNamespace('BloodCancerMultiOmics2017', quietly = TRUE)) {
  BiocManager::install('BloodCancerMultiOmics2017', version = '3.22',
                       ask = FALSE, update = FALSE, force = FALSE)
}
pkgs <- c('survminer', 'maxstat', 'pheatmap', 'ggrepel', 'patchwork')
miss <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
if (length(miss) > 0) install.packages(miss, repos = 'https://cloud.r-project.org')
cat('Dependency check done\n')
"

perl -0pi -e 's/run_heavy <- FALSE\s+# set to FALSE after \.rds files are generated/run_heavy <- TRUE   # set to FALSE after .rds files are generated/g' vignettes/cll_application.Rmd

"${R_SCRIPT}" -e "rmarkdown::render('vignettes/cll_application.Rmd')"

echo "EXIT CODE: $?"
