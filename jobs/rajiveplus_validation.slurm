#!/usr/bin/env bash
#SBATCH --job-name=rajiveplus-validation
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=logs/%x-%j.out

set -euo pipefail
: "${SOURCE_SNAPSHOT:?set SOURCE_SNAPSHOT to an immutable candidate snapshot}"
: "${EXPECTED_SOURCE_SHA256:?set EXPECTED_SOURCE_SHA256 from candidate_identity.json}"
: "${SLURM_TMPDIR:?SLURM_TMPDIR is required}"

job_root="${SLURM_TMPDIR}/rajiveplus-${SLURM_JOB_ID}"
mkdir -p "${job_root}/source" "${job_root}/library" "${job_root}/tmp" "logs"
cp -a "${SOURCE_SNAPSHOT}/." "${job_root}/source/"
cd "${job_root}/source"

observed_source_sha256="$(python3 scripts/candidate_identity.py "${job_root}/identity.json")"
if [[ "${observed_source_sha256}" != "${EXPECTED_SOURCE_SHA256}" ]]; then
  echo "candidate identity mismatch" >&2
  exit 64
fi

export R_LIBS_USER="${job_root}/library"
export TMPDIR="${job_root}/tmp"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 BLIS_NUM_THREADS=1
export RAJIVE_GATE_DIR="${job_root}/receipts"
bash scripts/run_slow_gate.sh
cp -a "${job_root}/receipts" "${SLURM_SUBMIT_DIR}/logs/${SLURM_JOB_ID}-receipts"
