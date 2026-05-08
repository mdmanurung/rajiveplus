#!/bin/bash
#SBATCH --job-name=rajive_verify
#SBATCH --partition=all
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=6:00:00
#SBATCH --output=logs/slurm_verify_%j.log
#SBATCH --error=logs/slurm_verify_%j.log

set -euo pipefail

# Under sbatch, scripts run from a spool copy; use submit directory.
cd "${SLURM_SUBMIT_DIR:-$(pwd)}"

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export BLIS_NUM_THREADS=1

R_BIN="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/R"
R_SCRIPT="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/Rscript"

# Install package (with lock retry — other regen jobs may have just finished).
for i in 1 2 3; do
  rm -rf /exports/para-lipg-hpc/mdmanurung/R/4.5/00LOCK-RaJIVEutils 2>/dev/null || true
  "${R_BIN}" CMD INSTALL --no-multiarch --with-keep.source . && break
  echo "Install attempt $i failed, retrying in 60s..."
  sleep 60
done

# Ensure light mode for all vignettes before verification builds.
perl -0pi -e 's/run_heavy <- TRUE\s+# set to TRUE once to regenerate \.rds cache files/run_heavy <- FALSE         # set to TRUE once to regenerate .rds cache files/g' vignettes/benchmarking.Rmd || true
perl -0pi -e 's/run_heavy <- TRUE\s+# set to TRUE once to regenerate \.rds cache files/run_heavy <- FALSE  # set to TRUE once to regenerate .rds cache files/g' vignettes/jackstraw_scaling.Rmd || true
perl -0pi -e 's/run_heavy <- TRUE\s+# set to FALSE after \.rds files are generated/run_heavy <- FALSE  # set to FALSE after .rds files are generated/g' vignettes/cll_application.Rmd || true

# Validate expected cache files exist before build.
required=(
  bench_results.rds bench_results_bench.rds peakram_single.rds scaling_results.rds parallel_results.rds
  jackstraw_time_vs_n.rds jackstraw_time_vs_p.rds jackstraw_time_vs_nnull.rds jackstraw_ram_vs_n.rds jackstraw_ram_vs_p.rds
  cll_preprocessed.rds cll_svd_list.rds cll_rajive_results.rds cll_jackstraw_results.rds
  gallery_precomp.rds
)
for f in "${required[@]}"; do
  if [[ ! -f "vignettes/data/$f" ]]; then
    echo "Missing required cache file: vignettes/data/$f"
    exit 2
  fi
done

echo "All 15 cache files found; starting build_vignettes"
"${R_SCRIPT}" -e "devtools::build_vignettes()"

echo "build_vignettes done; starting pkgdown"
"${R_SCRIPT}" -e "pkgdown::build_site()"

# Strict blocker: pkgdown must include all vignette article pages.
expected_articles=(
  docs/articles/benchmarking.html
  docs/articles/jackstraw_scaling.html
  docs/articles/cll_application.html
  docs/articles/function_gallery.html
)

for page in "${expected_articles[@]}"; do
  if [[ ! -f "$page" ]]; then
    echo "Missing expected pkgdown article page: $page"
    exit 3
  fi
done

echo "Verification job completed successfully"
echo "Blockers satisfied: build_vignettes passed and 4 pkgdown article pages exist"
