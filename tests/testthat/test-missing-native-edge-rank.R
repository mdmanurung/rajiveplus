# Edge-case tests for native automatic rank selection, hold-out diagnostics,
# and RNG hygiene. See audits/2026-05-15-missing-data-audit.md.
#
# Tests tagged `# Regression for audit F#` pin a behaviour that was a
# confirmed audit gap and turned green once the corresponding fix landed.
#
# make_union_blocks() is defined in helper-missing-union.R.

test_that("empty hold-out folds fall back to the training objective", {
  # Each feature is observed in exactly one row, so neither
  # .rank_block_row_holdout_units() nor .rank_cell_holdout_units() yields an
  # eligible unit; diagnose_missing_ranks() must still return finite errors.
  set.seed(9201)
  diag_mask <- diag(TRUE, 6L)
  blocks <- list(
    block1 = matrix(stats::rnorm(36), 6L, 6L),
    block2 = matrix(stats::rnorm(36), 6L, 6L)
  )
  mask <- list(block1 = diag_mask, block2 = diag_mask)

  expect_no_error(
    diag <- diagnose_missing_ranks(blocks, candidates = 0:1,
                                   initial_signal_ranks = c(1L, 1L),
                                   mask = mask)
  )
  expect_true(all(is.finite(diag$prediction_error)))
  expect_equal(nrow(diag), 2L)
})

test_that("joint_rank = 0 collapses estimability to not_identifiable", {
  # Pins audit F10: .compute_estimability gates cross_block_joint_estimable on
  # `fit$joint_rank > 0L`, so a rank-0 fit labels every whole-row-missing cell
  # not_identifiable even where cross-block support exists.
  ub <- make_union_blocks(n = 18L, n_features = c(8L, 8L, 8L))
  expect_false(ub$mask$blk2["sample_01", 1])   # whole-row missing in blk2
  expect_true(any(ub$mask$blk1["sample_01", ])) # but observed elsewhere

  fit <- Rajive(ub$blocks, initial_signal_ranks = c(3L, 3L, 3L),
                missing = "native", mask = ub$mask, joint_rank = 0L)
  expect_equal(get_joint_rank(fit), 0L)

  est <- get_estimability(fit, block = "blk2")
  expect_true(all(est$label[est$row == 1L] == "not_identifiable"))
})

test_that("joint_rank truncation warns when the request exceeds recoverable dim", {
  ub <- make_union_blocks(n = 18L, n_features = c(8L, 8L, 8L))
  # initial_signal_ranks = 1 per block -> concatenated signal matrix has 3
  # columns, so joint_rank = 5 is not recoverable.
  expect_warning(
    fit <- Rajive(ub$blocks, initial_signal_ranks = c(1L, 1L, 1L),
                  missing = "native", mask = ub$mask, joint_rank = 5L),
    class = "rajiveplus_joint_rank_truncated"
  )
  expect_lt(get_joint_rank(fit), 5L)
})

test_that("auto-rank selection is reproducible with a fixed seed", {
  # Green anchor: passing `seed=` makes native auto-rank reproducible even when
  # the ambient RNG stream is churned between calls.
  ub <- make_union_blocks(n = 18L, n_features = c(8L, 8L, 8L))
  ctrl <- rajive_missing_control(rank_repeats = 1L)
  args <- list(ub$blocks, initial_signal_ranks = c(3L, 3L, 3L),
               missing = "native", mask = ub$mask, joint_rank = NA,
               seed = 4202, missing_control = ctrl)

  fit1 <- do.call(Rajive, args)
  invisible(stats::rnorm(50))
  fit2 <- do.call(Rajive, args)

  expect_identical(get_joint_rank(fit1), get_joint_rank(fit2))
  expect_equal(fit1$missing$rank_diagnostics, fit2$missing$rank_diagnostics)
})

test_that("diagnose_missing_ranks does not mutate the global RNG state", {
  # Regression for audit F7: passing `seed=` is scoped to the call and the
  # caller's RNG stream survives.
  ub <- make_union_blocks(n = 18L, n_features = c(8L, 8L, 8L))
  set.seed(321)
  before <- .Random.seed
  diagnose_missing_ranks(ub$blocks, candidates = 0:2,
                         initial_signal_ranks = c(3L, 3L, 3L),
                         mask = ub$mask, seed = 8800,
                         missing_control = rajive_missing_control(
                           rank_repeats = 1L))
  expect_true(identical(.Random.seed, before))
})

test_that("auto-rank recovers the true joint rank on well-separated signal", {
  skip_if_not_slow()
  # Low-noise union blocks with a true joint rank of 2; native auto-rank
  # should select 2 from candidates 0:3.
  ub <- make_union_blocks(n = 24L, rankJ = 2L,
                          n_features = c(10L, 10L, 10L), noise = 0.1,
                          seed = 9210L)
  fit <- Rajive(ub$blocks, initial_signal_ranks = c(3L, 3L, 3L),
                missing = "native", mask = ub$mask, joint_rank = NA,
                seed = 9210,
                missing_control = rajive_missing_control(
                  center = TRUE, scale = TRUE, normalize = TRUE,
                  rank_candidates = 0:3, rank_repeats = 1L))
  expect_equal(get_joint_rank(fit), 2L)
})
