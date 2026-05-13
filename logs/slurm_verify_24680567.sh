#!/bin/bash
#SBATCH --job-name=rajive_verify
#SBATCH --partition=all
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=6:00:00
#SBATCH --dependency=afterok:24680567
#SBATCH --output=logs/slurm_verify_%j.log
#SBATCH --error=logs/slurm_verify_%j.log

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$(pwd)}"
export RAJIVEPLUS_VIGNETTE_HEAVY=0

# Validate expected cache files exist before build.
required=(
  bench_results.rds bench_results_bench.rds peakram_single.rds scaling_results.rds parallel_results.rds
  jackstraw_time_vs_n.rds jackstraw_time_vs_p.rds jackstraw_time_vs_nnull.rds jackstraw_ram_vs_n.rds jackstraw_ram_vs_p.rds
  cll_preprocessed.rds cll_svd_list.rds cll_rajive_results.rds cll_jackstraw_results.rds
)
for f in "${required[@]}"; do
  if [[ ! -f "vignettes/data/$f" ]]; then
    echo "Missing required cache file: vignettes/data/$f"
    exit 2
  fi
done

echo "All cache files found; starting build_vignettes"
/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/Rscript -e "devtools::build_vignettes()"

echo "build_vignettes done; starting pkgdown"
/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/Rscript -e "pkgdown::build_site()"

# Strict blocker: pkgdown must include all 3 vignette article pages.
expected_articles=(
  docs/articles/benchmarking.html
  docs/articles/jackstraw_scaling.html
  docs/articles/cll_application.html
)

for page in "${expected_articles[@]}"; do
  if [[ ! -f "$page" ]]; then
    echo "Missing expected pkgdown article page: $page"
    exit 3
  fi
done

echo "All verification gates passed"
