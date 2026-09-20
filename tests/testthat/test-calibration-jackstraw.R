# Slow calibration tests for jackstraw_rajive().
#
# Design note: Rajive() applies an L2 identifiability filter by default,
# dropping joint components whose projection onto a block falls below that
# block's sv_threshold. Use identifiability_norm = "l1" for original RaJIVE
# norm(score) parity.
# On pure-noise data, this filter correctly drops even a forced joint_rank=1
# component.  Tests therefore use ajive.data.sim() to generate blocks with
# genuine dense joint signal (which passes the filter), then augment each
# block with p_null appended pure-noise columns.  Only those null columns'
# jackstraw p-values are used for the null-uniformity assertion.
#
# Run with:
#   RAJIVE_RUN_SLOW=1 conda run -n R4_51 Rscript -e \
#     "devtools::test_file('tests/testthat/test-calibration-jackstraw.R')"
#
# Reference: Yang X et al. (2021) arXiv:2109.12272 (YHHM 2021).
# Reference: Phipson B, Smyth GK (2010) Stat. Appl. Genet. Mol. Biol. 9(1).

# ---------------------------------------------------------------------------
# W-M4: Null uniformity — null columns appended to signal blocks
# ---------------------------------------------------------------------------

test_that("jackstraw controls dataset-level null feature discovery", {
  skip_if_not_slow()

  # Construction:
  #   - ajive.data.sim K=2, rankJ=1, rankA=c(3,2), n=60, pks=c(10,8)
  #     -> dense joint signal in first 10/8 features, passes identifiability filter.
  #   - Append p_null=40 pure-noise columns to each block.
  #   - initial_signal_ranks = c(4,3) = rankJ + rankA (full signal space).
  #   - Collect p-values for null columns (cols 11:50 / 9:48) only.
  # The replicate, rather than the pooled feature, is the inference unit.
  # Rank-zero fits remain in the denominator with zero discoveries.
  with_lecuyer_seed(2026, {
    B      <- 100L
    p_null <- 40L
    n      <- 60L
    replicate_fpr <- replicate(B, {
      Y <- ajive.data.sim(K = 2, rankJ = 1L, rankA = c(3L, 2L),
                          n = n, pks = c(10L, 8L), dist.type = 1)
      # augment each block with null columns
      blk_aug <- lapply(Y$sim_data, function(x)
        cbind(x, matrix(stats::rnorm(n * p_null), n, p_null)))

      fit <- Rajive(blk_aug,
                    initial_signal_ranks = c(4L, 3L),
                    num_cores = 1L)
      if (fit$joint_rank == 0L) return(0)

      js <- jackstraw_rajive(fit, blk_aug, n_null = 20L, correction = "none")
      n_sig <- c(10L, 8L)   # original sim feature counts
      null_p <- unlist(lapply(seq_len(attr(js, "n_blocks")), function(k) {
        lapply(seq_len(attr(js, "joint_rank")), function(j) {
          js[[k]][[j]]$p_values[(n_sig[k] + 1L):(n_sig[k] + p_null)]
        })
      }), use.names = FALSE)
      mean(null_p <= 0.05, na.rm = TRUE)
    })

    mean_fpr <- mean(replicate_fpr)
    cat(sprintf("\n  [W-M4 null] datasets=%d, mean dataset FPR=%.4f\n",
                B, mean_fpr))
    expect_lte(mean_fpr, 0.10,
               label = paste0("Mean dataset FPR = ", signif(mean_fpr, 3)))
  })
})

# ---------------------------------------------------------------------------
# W-M4: Power property — signal features detected above null rate
# ---------------------------------------------------------------------------

test_that("jackstraw signal features have elevated detection rate", {
  skip_if_not_slow()

  # ajive.data.sim creates DENSE joint loadings across all features.
  # Under strong signal, most features are associated with the joint score,
  # so the fraction with p <= 0.05 should far exceed the 5% null rate.
  # We assert mean(p <= 0.05) >= 0.30 across B=50 reps.
  # (Conservative; true loading is dense so detection typically > 60%.)
  with_lecuyer_seed(9999, {
    B    <- 50L
    frac <- replicate(B, {
      Y <- ajive.data.sim(K = 2, rankJ = 2L, rankA = c(4L, 3L),
                          n = 60, pks = c(80L, 60L), dist.type = 1)
      # initial_signal_ranks = rankJ + rankA = c(6, 5)
      fit <- Rajive(Y$sim_data, initial_signal_ranks = c(6L, 5L),
                    num_cores = 1L)
      if (fit$joint_rank == 0L) return(0)
      js <- jackstraw_rajive(fit, Y$sim_data,
                             n_null = 20L, correction = "none")
      # all features; dense loadings -> high p < 0.05 rate
      all_p <- unlist(lapply(js, function(b) lapply(b, `[[`, "p_values")),
                      use.names = FALSE)
      mean(all_p <= 0.05, na.rm = TRUE)
    })

    mean_frac <- mean(frac)
    cat(sprintf("  [W-M4 power] mean detection frac = %.4f (B=%d)\n",
                mean_frac, B))

    expect_gte(mean_frac, 0.30,
               label = paste0("Mean detection fraction = ", signif(mean_frac, 3),
                              "; should be >> 0.05 under dense joint signal"))
  })
})
