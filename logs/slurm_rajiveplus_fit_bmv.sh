#!/bin/bash
#SBATCH --job-name=rajive_bmv
#SBATCH --partition=all
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=128G
#SBATCH --time=72:00:00

set -euo pipefail

STAGE="${1:-all}"
CACHE_ROOT="${2:-}"
REPO_ROOT="/exports/para-lipg-hpc/mdmanurung/RaJIVEutils"

cd "${REPO_ROOT}"

echo "====== BMV SLURM WRAPPER START ======"
echo "Timestamp: $(date)"
echo "Stage: ${STAGE}"
echo "Cache root: ${CACHE_ROOT:-<default>}"
echo "CPUs: ${SLURM_CPUS_PER_TASK:-unknown}"
echo "Job: ${SLURM_JOB_ID:-manual}"

if [[ -n "${CACHE_ROOT}" ]]; then
  conda run --no-capture-output -n R4_51 Rscript scratch/bmv_workflow/run_bmv_stage.R "${STAGE}" "${CACHE_ROOT}"
else
  conda run --no-capture-output -n R4_51 Rscript scratch/bmv_workflow/run_bmv_stage.R "${STAGE}"
fi

echo "====== BMV SLURM WRAPPER DONE ======"
echo "Timestamp: $(date)"
