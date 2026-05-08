#!/bin/bash
#SBATCH --job-name=rajive_gallery_cache
#SBATCH --partition=all
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=2:00:00
#SBATCH --output=logs/slurm_gallery_cache_%j.log
#SBATCH --error=logs/slurm_gallery_cache_%j.log

cd "${SLURM_SUBMIT_DIR:-$(pwd)}"

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export BLIS_NUM_THREADS=1

R_BIN="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/R"
R_SCRIPT="/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/Rscript"

echo "=== Reinstalling rajiveplus from source ==="
for i in 1 2 3; do
  rm -rf /exports/para-lipg-hpc/mdmanurung/R/4.5/00LOCK-RaJIVEutils 2>/dev/null || true
  "${R_BIN}" CMD INSTALL --no-multiarch --with-keep.source . && break
  echo "Install attempt $i failed, retrying in 60s..."
  sleep 60
done
echo "=== Install exit code: $? ==="

echo "=== Generating gallery_precomp.rds cache ==="
"${R_SCRIPT}" - <<'RSCRIPT'

library(rajiveplus)

set.seed(42)
n   <- 80L
pks <- c(60L, 50L, 40L)

sim    <- ajive.data.sim(K = 3, rankJ = 2, rankA = c(5L, 4L, 4L),
                         n = n, pks = pks, dist.type = 1)
blocks <- sim$sim_data
names(blocks) <- c("mRNA", "Methylation", "Proteomics")
for (k in seq_along(blocks))
  rownames(blocks[[k]]) <- paste0("sample", seq_len(n))

meta_df <- data.frame(
  group      = rep(c("A", "B"), each = n / 2L),
  score_cont = rnorm(n),
  time_event = abs(rnorm(n, mean = 5, sd = 2)),
  event_flag = rbinom(n, 1L, 0.6),
  row.names  = paste0("sample", seq_len(n)),
  stringsAsFactors = FALSE
)

cat("Running Rajive()...\n")
fit <- Rajive(
  blocks               = blocks,
  initial_signal_ranks = c(5L, 4L, 4L),
  n_wedin_samples      = 200L,
  n_rand_dir_samples   = 200L
)
cat("Joint rank estimated:", get_joint_rank(fit), "\n")

cat("Running jackstraw_rajive()...\n")
set.seed(42)
js <- jackstraw_rajive(fit, blocks, n_null = 5L, correction = "BH")

cat("Running associate_components()...\n")
assoc_cat  <- associate_components(fit, meta_df, variable = "group",
                                   mode = "categorical")
assoc_cont <- associate_components(fit, meta_df, variable = "score_cont",
                                   mode = "continuous")

# Stability: B=5 per target keeps total Rajive calls to 15 (manageable on HPC)
cat("Running assess_stability(joint_rank)...\n")
stab_rank <- assess_stability(fit, blocks, c(5L, 4L, 4L),
                              target = "joint_rank", B = 5L)

cat("Running assess_stability(loadings)...\n")
stab_load <- assess_stability(fit, blocks, c(5L, 4L, 4L),
                              target = "loadings", B = 5L)

cat("Running assess_stability(components)...\n")
stab_comp <- assess_stability(fit, blocks, c(5L, 4L, 4L),
                              target = "components", B = 5L)

dir.create("vignettes/data", showWarnings = FALSE, recursive = TRUE)
saveRDS(
  list(blocks    = blocks, meta      = meta_df,
       fit       = fit,    js        = js,
       assoc_cat = assoc_cat, assoc_cont = assoc_cont,
       stab_rank = stab_rank, stab_load  = stab_load,
       stab_comp = stab_comp),
  file = "vignettes/data/gallery_precomp.rds"
)
cat("gallery_precomp.rds saved OK\n")

RSCRIPT

echo "=== Cache generation exit code: $? ==="

# Render vignette with cached data
echo "=== Rendering function_gallery.Rmd ==="
"${R_SCRIPT}" \
  -e "rmarkdown::render('vignettes/function_gallery.Rmd', output_dir = 'vignettes')"

echo "=== Render exit code: $? ==="
