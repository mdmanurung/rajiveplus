#!/bin/bash
#SBATCH --job-name=rajive_jack2
#SBATCH --partition=all
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/slurm_jack2_%j.log
#SBATCH --error=logs/slurm_jack2_%j.log

set -euo pipefail

# Under sbatch, scripts run from a spool copy; use submit directory.
cd "${SLURM_SUBMIT_DIR:-$(pwd)}"

# Pin BLAS/OpenMP threads to avoid nested over-subscription.
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export BLIS_NUM_THREADS=1

R_BIN="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/R"
R_SCRIPT="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/Rscript"

# Install package (retry up to 3 times to handle concurrent lock from bench job).
for i in 1 2 3; do
  rm -rf /exports/para-lipg-hpc/mdmanurung/R/4.5/00LOCK-RaJIVEutils 2>/dev/null || true
  "${R_BIN}" CMD INSTALL --no-multiarch --with-keep.source . && break
  echo "Install attempt $i failed, retrying in 60s..."
  sleep 60
done

RAJIVEPLUS_VIGNETTE_HEAVY=1 "${R_SCRIPT}" -e "rmarkdown::render('vignettes/jackstraw_scaling.Rmd')"

echo "EXIT CODE: $?"
