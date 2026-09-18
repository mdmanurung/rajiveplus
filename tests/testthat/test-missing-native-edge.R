# Edge-case / robustness tests for native missing-data fitting.
#
# Audit 2026-05-15 (audits/2026-05-15-missing-data-audit.md). Tests tagged
# `# Regression for audit F#` pin behaviour that was a confirmed gap in the
# original audit; each turned green once the corresponding fix landed.
#
# make_union_blocks() is defined in helper-missing-union.R.

# ---------------------------------------------------------------------------
# Green tests: pin current, correct behaviour.
# ---------------------------------------------------------------------------

test_that("underdetermined features warn and zero the joint contribution", {
  ub <- make_union_blocks()
  # Leave feature 1 of blk1 with a single observed entry while joint_rank = 2.
  ub$mask$blk1[, 1] <- FALSE
  ub$mask$blk1[1, 1] <- TRUE

  expect_warning(
    fit <- Rajive(ub$blocks, initial_signal_ranks = c(3L, 3L, 3L),
                  missing = "native", mask = ub$mask, joint_rank = 2L),
    class = "rajiveplus_underdetermined_joint"
  )
  joint <- get_reconstructed_blocks(fit, type = "joint", scale = "standardized")
  expect_true(all(joint$blk1[, 1] == 0))
})

test_that("zero-variance feature stays finite through preprocessing", {
  ub <- make_union_blocks()
  obs1 <- ub$mask$blk1[, 1]
  ub$blocks$blk1[obs1, 1] <- 5            # constant observed feature
  ub$mask$blk1[2, 3] <- FALSE             # keep some scattered missingness

  fit <- Rajive(ub$blocks, initial_signal_ranks = c(3L, 3L, 3L),
                missing = "native", mask = ub$mask, joint_rank = 1L,
                missing_control = rajive_missing_control(
                  center = TRUE, scale = TRUE, normalize = TRUE))

  recon <- get_reconstructed_blocks(fit, type = "joint_individual",
                                    scale = "original")
  expect_true(all(is.finite(recon$blk1)))
  # a constant feature must back-transform to its constant
  expect_equal(unname(recon$blk1[obs1, 1]), rep(5, sum(obs1)),
               tolerance = 1e-6)
})

test_that("single-observation-per-feature block does not crash", {
  ub <- make_union_blocks()
  ub$mask$blk1[, 1:2] <- FALSE
  ub$mask$blk1[1, 1] <- TRUE
  ub$mask$blk1[2, 2] <- TRUE

  expect_no_error(
    fit <- Rajive(ub$blocks, initial_signal_ranks = c(3L, 3L, 3L),
                  missing = "native", mask = ub$mask, joint_rank = 1L)
  )
  expect_s3_class(fit, "rajive_incomplete")

  est <- get_estimability(fit, block = "blk1")
  one_obs <- est[est$col == 1L, ]
  # exactly one observed cell for that feature, per component
  expect_equal(sum(one_obs$observed), 3L)
  # missing cells of a 1-observation feature are never labelled "observed"
  expect_false(any(est$label[est$col == 1L & !est$observed] == "observed"))
})

test_that("whole-row-missing sample gets a joint-only reconstruction", {
  ub <- make_union_blocks()
  # sample_01 is present in blk1 and blk3 but absent from blk2 (subset 7:30).
  expect_false(ub$mask$blk2["sample_01", 1])
  expect_true(any(ub$mask$blk1["sample_01", ]))

  fit <- Rajive(ub$blocks, initial_signal_ranks = c(3L, 3L, 3L),
                missing = "native", mask = ub$mask, joint_rank = 1L)

  est <- get_estimability(fit, block = "blk2")
  row1 <- est[est$row == 1L, ]
  expect_equal(unique(row1$label[row1$component == "individual"]),
               "not_identifiable")
  expect_equal(unique(row1$label[row1$component == "joint"]),
               "cross_block_joint_estimable")

  joint <- get_reconstructed_blocks(fit, type = "joint",
                                    scale = "standardized")
  both <- get_reconstructed_blocks(fit, type = "joint_individual",
                                   scale = "standardized")
  expect_equal(both$blk2[1, ], joint$blk2[1, ], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# Regression tests: documented audit gaps that now stay green.
# ---------------------------------------------------------------------------

test_that(".solve_masked_joint_matrix stays finite on a rank-deficient design", {
  # Green anchor for audit F6: the fixed sqrt(.Machine$double.eps) ridge keeps
  # the masked least-squares solve finite even when a feature is observed only
  # on exactly `r` collinear rows (an exactly rank-deficient design).
  set.seed(9101)
  n <- 16L
  r <- 2L
  p <- 3L
  joint_scores <- matrix(stats::rnorm(n * r), n, r)
  joint_scores[2, ] <- joint_scores[1, ]      # exactly collinear rows
  x <- matrix(stats::rnorm(n * p), n, p)
  mask <- matrix(TRUE, n, p)
  mask[3:n, 1] <- FALSE                       # feature 1: only the 2 collinear rows

  jhat <- rajiveplus:::.solve_masked_joint_matrix(x, mask, joint_scores)
  expect_true(all(is.finite(jhat)))
  expect_equal(dim(jhat), c(n, p))
})

test_that("a native fit does not mutate the global RNG state", {
  # Regression for audit F7: passing `seed=` is scoped to the call and the
  # caller's RNG stream survives.
  ub <- make_union_blocks()
  set.seed(123)
  before <- .Random.seed
  fit <- Rajive(ub$blocks, initial_signal_ranks = c(3L, 3L, 3L),
                missing = "native", mask = ub$mask, joint_rank = 1L,
                seed = 4202)
  expect_true(identical(.Random.seed, before))
})

test_that(".masked_variance_explained never reports negative residual variance", {
  # Regression for audit F8: residual_prop is clamped at zero, so even when
  # joint + individual jointly carry more energy than the observed
  # sum-of-squares the reported `Residual` is non-negative.
  x <- matrix(c(1, 1, 1, 1), 2, 2)
  joint <- matrix(c(1, 1, 1, 1), 2, 2)        # sum(joint^2)      = sum(x^2)
  individual <- matrix(c(1, 1, 1, 1), 2, 2)   # sum(individual^2) = sum(x^2)
  mask <- matrix(TRUE, 2, 2)

  ve <- rajiveplus:::.masked_variance_explained(x, joint, individual, mask)
  expect_gte(ve[["Residual"]], -1e-8)
})

test_that("a sample missing from every block is dropped with a warning", {
  # Regression for audit F11: .validate_native_missing_inputs() drops samples
  # observed in no block (warning class rajiveplus_sample_all_missing) instead
  # of aborting, so the union-alignment workflow needs no manual pre-filtering.
  set.seed(9111)
  blocks <- list(
    block1 = matrix(stats::rnorm(60), nrow = 10),
    block2 = matrix(stats::rnorm(50), nrow = 10)
  )
  mask <- lapply(blocks, function(x) matrix(TRUE, nrow(x), ncol(x)))
  mask$block1[5, ] <- FALSE
  mask$block2[5, ] <- FALSE                 # sample 5 observed in no block

  expect_warning(
    fit <- Rajive(blocks, c(2L, 2L), missing = "native", mask = mask,
                  joint_rank = 1L),
    class = "rajiveplus_sample_all_missing"
  )
  expect_s3_class(fit, "rajive_incomplete")
  expect_equal(nrow(fit$missing$mask$block1), 9L)
})
