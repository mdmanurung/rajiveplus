setwd('/exports/para-lipg-hpc/mdmanurung/RaJIVEutils')
library(rajiveplus)

set.seed(2)
n <- 80L; pks <- c(60L, 50L, 40L)
sim <- ajive.data.sim(K = 3, rankJ = 2, rankA = c(5L, 4L, 4L), n = n, pks = pks, dist.type = 1)
blocks <- sim[['sim_data']]
names(blocks) <- c('mRNA', 'Methylation', 'Proteomics')
for (k in seq_along(blocks)) rownames(blocks[[k]]) <- paste0('sample', seq_len(n))

meta_df <- data.frame(
  group      = rep(c('A', 'B'), each = n / 2L),
  score_cont = rnorm(n),
  time_event = abs(rnorm(n, 5, 2)),
  event_flag = rbinom(n, 1L, 0.6),
  row.names  = paste0('sample', seq_len(n)),
  stringsAsFactors = FALSE
)

cat('Running Rajive...\n')
fit <- Rajive(blocks, initial_signal_ranks = c(5L, 4L, 4L),
              n_wedin_samples = 200L, n_rand_dir_samples = 200L)
cat('Joint rank:', get_joint_rank(fit), '\n')

set.seed(2)
cat('Running jackstraw...\n')
js <- jackstraw_rajive(fit, blocks, n_null = 10L, correction = 'BH')

cat('Running associations...\n')
assoc_cat  <- suppressMessages(associate_components(fit, meta_df, variable = 'group',      mode = 'categorical'))
assoc_cont <- suppressMessages(associate_components(fit, meta_df, variable = 'score_cont', mode = 'continuous'))

cat('Running stability joint_rank...\n')
stab_rank <- assess_stability(fit, blocks, c(5L, 4L, 4L), target = 'joint_rank',  B = 5L)
cat('Running stability loadings...\n')
stab_load <- assess_stability(fit, blocks, c(5L, 4L, 4L), target = 'loadings',    B = 5L)
cat('Running stability components...\n')
stab_comp <- assess_stability(fit, blocks, c(5L, 4L, 4L), target = 'components',  B = 5L)

out <- 'vignettes/data/gallery_precomp.rds'
saveRDS(
  list(blocks = blocks, meta = meta_df, fit = fit, js = js,
       assoc_cat = assoc_cat, assoc_cont = assoc_cont,
       stab_rank = stab_rank, stab_load = stab_load, stab_comp = stab_comp),
  out
)
cat('SAVED:', out, ' joint_rank:', get_joint_rank(fit),
    ' exists:', file.exists(out), '\n')
