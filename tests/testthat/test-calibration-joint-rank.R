# Slow calibration test for the Rajive() joint-rank selection rule.
#
# Two properties are measured separately:
#   * Type-I rate under the global null, as P(joint_rank > 0).
#   * Rank recovery under signal, reported as exact / under / over.
#
# Recovery is measured against `simulate_blocks()`, whose ground truth is an
# identifiable decomposition. The previous metric scored
# `estimated_rank >= true_rank`, which counted overestimation as power, and the
# previous generator produced a truth whose joint and individual score spaces
# overlap, so a correct estimator could not have matched it.
#
# The Wedin bound is excluded from the default threshold because its across-block
# combination is unverified; see audits/DEFECT_REGISTER.md rows W1-W3.
#
# Run with:
#   RAJIVE_RUN_SLOW=1 Rscript -e \
#     "devtools::test_file('tests/testthat/test-calibration-joint-rank.R')"
#
# Reference: Lock EF et al. (2013) Ann. Appl. Statist. 7(1):523-542.
# See also: R/Rajive.R @section "Joint-rank threshold (heuristic, no formal FWER/FDR)".

# ---------------------------------------------------------------------------
# Type-I rate for joint_rank > 0 under the global null
# ---------------------------------------------------------------------------

test_that("joint_rank Type-I rate under H0 is bounded at <= 0.10", {
  skip_if_not_slow()

  # B=200 replications, K=3 blocks.
  # Binomial sd at p=0.05, B=200: sqrt(0.05*0.95/200) ≈ 0.0154.
  # Upper 3-sigma bound ≈ 0.096; we assert <= 0.10 for a safety margin.
  with_lecuyer_seed(2026, {
    B <- 200L
    ranks <- replicate(B, {
      blk <- lapply(c(50L, 40L, 30L), function(p)
        matrix(stats::rnorm(60 * p), 60, p))
      Rajive(blk, c(6L, 5L, 4L),
             n_wedin_samples     = 200L,
             n_rand_dir_samples  = 200L,
             num_cores           = 1L)$joint_rank
    })

    type1_rate <- mean(ranks > 0)
    cat(sprintf("\n  [joint-rank Type-I] P(joint_rank > 0) = %.4f (B=%d)\n",
                type1_rate, B))

    # Every fit stays in the denominator, including any that selected nothing.
    expect_identical(length(ranks), B)
    expect_lte(type1_rate, 0.10,
               label = paste0("Type-I rate = ", signif(type1_rate, 3),
                              "; must be <= 0.10"))
  })
})

# ---------------------------------------------------------------------------
# Rank recovery under signal
# ---------------------------------------------------------------------------

test_that("joint rank is recovered exactly under strong signal", {
  skip_if_not_slow()

  # B=100 independent datasets. At an exact rate near 0.80 the binomial sd is
  # about 0.040, so the lower 3-sigma bound is near 0.68. The gate is set at
  # 0.80 and a shortfall is a method defect, not a documentation defect.
  with_lecuyer_seed(4242, {
    B <- 100L
    estimates <- replicate(B, {
      sim <- simulate_blocks(n = 60L, pks = c(50L, 40L, 30L),
                             joint_rank = 2L, individual_ranks = c(5L, 4L, 3L),
                             noise_sd = 1, signal_sd = 1)
      Rajive(sim$blocks, c(5L, 4L, 3L),
             n_wedin_samples    = 200L,
             n_rand_dir_samples = 200L,
             num_cores          = 1L)$joint_rank
    })

    summary <- rank_recovery_summary(estimates, true_rank = 2L)
    cat(sprintf("  [joint-rank recovery] %s\n", format_rank_recovery(summary)))

    expect_gte(summary$exact, 0.80,
               label = paste0("exact recovery = ", signif(summary$exact, 3),
                              "; must be >= 0.80"))
    # Over-selection is a distinct failure mode and is not folded into power.
    expect_lte(summary$over, 0.10,
               label = paste0("over-selection rate = ", signif(summary$over, 3),
                              "; must be <= 0.10"))
  })
})

test_that("joint rank is recovered exactly at rank one", {
  skip_if_not_slow()

  with_lecuyer_seed(4343, {
    B <- 100L
    estimates <- replicate(B, {
      sim <- simulate_blocks(n = 60L, pks = c(50L, 40L, 30L),
                             joint_rank = 1L, individual_ranks = c(5L, 4L, 3L),
                             noise_sd = 1, signal_sd = 1)
      Rajive(sim$blocks, c(5L, 4L, 3L),
             n_wedin_samples    = 200L,
             n_rand_dir_samples = 200L,
             num_cores          = 1L)$joint_rank
    })

    summary <- rank_recovery_summary(estimates, true_rank = 1L)
    cat(sprintf("  [joint-rank recovery] %s\n", format_rank_recovery(summary)))

    expect_gte(summary$exact, 0.80,
               label = paste0("exact recovery = ", signif(summary$exact, 3),
                              "; must be >= 0.80"))
  })
})

# ---------------------------------------------------------------------------
# Recovery metric itself
# ---------------------------------------------------------------------------

test_that("the recovery metric does not reward overestimation", {
  # A metric that scores `estimated >= true` would report power 1.0 here.
  over_every_time <- c(2L, 2L, 2L, 3L, 5L)
  summary <- rank_recovery_summary(over_every_time, true_rank = 2L)
  expect_equal(summary$exact, 0.6)
  expect_equal(summary$under, 0)
  expect_equal(summary$over, 0.4)
  expect_equal(summary$n, 5L)
  expect_true(summary$mc_se > 0)

  under_every_time <- c(2L, 2L, 1L, 1L)
  summary_under <- rank_recovery_summary(under_every_time, true_rank = 2L)
  expect_equal(summary_under$exact, 0.5)
  expect_equal(summary_under$under, 0.5)
  expect_equal(summary_under$over, 0)

  all_wrong <- c(0L, 3L)
  summary_wrong <- rank_recovery_summary(all_wrong, true_rank = 2L)
  expect_equal(summary_wrong$exact, 0)
  expect_equal(summary_wrong$under, 0.5)
  expect_equal(summary_wrong$over, 0.5)
})
