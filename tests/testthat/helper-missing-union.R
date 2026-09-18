# Shared fixture for native missing-data edge-case tests.
#
# make_union_blocks(): a compact port of vignettes/native_missing_union.Rmd.
# Three partially overlapping blocks aligned to the sample union, with a
# shared joint structure, per-block individual structure, and noise. Returns
# the union-aligned blocks, the is.finite() mask, and the noise-free truth.
#
# By default the sample subsets are derived from `n` so the fixture scales:
# blk1 omits the tail, blk2 omits sample 1, blk3 has a middle gap -- every
# block therefore has whole-row-missing samples on the union, and sample_01 is
# observed in blk1/blk3 but missing in blk2.
#
# Sourced automatically by testthat (file name begins with "helper-"); shared
# by test-missing-native-edge*.R and test-missing-native-shrinkage.R.
make_union_blocks <- function(n = 30L, rankJ = 2L,
                              subsets = NULL,
                              n_features = c(20L, 18L, 16L),
                              noise = 0.4, seed = 4201L) {
  if (is.null(subsets)) {
    subsets <- list(
      seq_len(ceiling(0.80 * n)),
      seq.int(floor(0.25 * n) + 1L, n),
      c(seq_len(ceiling(0.45 * n)), seq.int(floor(0.65 * n) + 1L, n))
    )
  }
  set.seed(seed)
  all_samples <- sprintf("sample_%02d", seq_len(n))
  joint_scores <- matrix(stats::rnorm(n * rankJ), n, rankJ)
  one_block <- function(idx, p, prefix) {
    joint_loadings <- matrix(stats::rnorm(p * rankJ, sd = 0.8), p, rankJ)
    individual_score <- as.numeric(scale(stats::rnorm(length(idx))))
    individual_loadings <- stats::rnorm(p, sd = 0.4)
    signal <- joint_scores[idx, , drop = FALSE] %*% t(joint_loadings) +
      outer(individual_score, individual_loadings)
    x <- signal +
      matrix(stats::rnorm(length(idx) * p, sd = noise), nrow = length(idx))
    dimnames(x) <- dimnames(signal) <-
      list(all_samples[idx], paste0(prefix, "_", seq_len(p)))
    list(x = x, truth = signal)
  }
  prefixes <- paste0("blk", seq_along(subsets))
  raw <- Map(one_block, subsets, n_features, prefixes)
  to_union <- function(component) {
    out <- lapply(raw, function(b) {
      m <- matrix(NA_real_, n, ncol(b[[component]]),
                  dimnames = list(all_samples, colnames(b[[component]])))
      m[rownames(b[[component]]), ] <- b[[component]]
      m
    })
    names(out) <- prefixes
    out
  }
  blocks <- to_union("x")
  list(blocks = blocks, mask = lapply(blocks, is.finite),
       truth = to_union("truth"), samples = all_samples)
}
