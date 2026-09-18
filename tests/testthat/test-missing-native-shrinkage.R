# Tests for the missMDA-inspired regularised SVD path used by native
# missing-data fitting (R/RobustSVD.R + rajive_missing_control()).
# See audits/2026-05-15-missing-data-audit.md.
#
# Tests tagged `# Regression for audit F#` pin a behaviour that was a
# confirmed audit gap and turned green once the corresponding fix landed.

test_that(".shrink_singular_values matches the missMDA regularisation formula", {
  sv <- c(10, 6, 3, 1, 0.5)
  rank <- 2L
  n_rows <- 20L
  n_cols <- 8L

  d <- sv[seq_len(rank)]
  tail <- sv[-seq_len(rank)]
  denom <- (n_rows - 1) * n_cols - (n_rows - 1) * rank -
    n_cols * rank + rank^2
  sigma2 <- n_rows * n_cols / min(n_cols, n_rows - 1) * sum(tail^2 / denom)
  sigma2 <- min(sigma2, sv[[rank + 1L]]^2)
  expected <- pmax((d^2 - sigma2) / d, 0)

  got <- rajiveplus:::.shrink_singular_values(
    sv, rank = rank, shrinkage = "missmda", shrinkage_coeff = 1,
    n_rows = n_rows, n_cols = n_cols
  )
  expect_equal(got, expected)
  # regularisation must shrink, never inflate, the retained singular values
  expect_true(all(got < d))
})

test_that("svd_shrinkage = \"missmda\" changes the native fit", {
  ub <- make_union_blocks(n = 24L, n_features = c(10L, 10L, 10L))
  fit0 <- Rajive(ub$blocks, c(3L, 3L, 3L), missing = "native", mask = ub$mask,
                 joint_rank = 2L, seed = 9302,
                 missing_control = rajive_missing_control(center = TRUE,
                                                          scale = TRUE))
  fit1 <- Rajive(ub$blocks, c(3L, 3L, 3L), missing = "native", mask = ub$mask,
                 joint_rank = 2L, seed = 9302,
                 missing_control = rajive_missing_control(
                   center = TRUE, scale = TRUE, svd_shrinkage = "missmda"))

  r0 <- get_reconstructed_blocks(fit0, type = "joint_individual",
                                 scale = "standardized")
  r1 <- get_reconstructed_blocks(fit1, type = "joint_individual",
                                 scale = "standardized")
  expect_false(isTRUE(all.equal(r0$blk1, r1$blk1)))
})

test_that(".RobRSVD_all_weighted_R recovers a low-rank matrix from a mask", {
  set.seed(9303)
  n <- 40L
  p <- 15L
  r <- 2L
  truth <- matrix(stats::rnorm(n * r), n, r) %*%
    matrix(stats::rnorm(r * p), r, p)
  mask <- matrix(TRUE, n, p)
  mask[sample.int(n * p, round(0.25 * n * p))] <- FALSE
  stopifnot(all(rowSums(mask) > 2L), all(colSums(mask) > 2L))

  fit <- rajiveplus:::.RobRSVD_all_weighted_R(truth, mask, nrank = r)
  recon <- fit$u %*% (diag(fit$d, r, r) %*% t(fit$v))

  # The weighted path now uses the robust SVD update rather than classical SVD;
  # it should still recover the held-out low-rank cells to a small absolute
  # error, but it is no longer an exact classical low-rank completion.
  expect_lt(max(abs(recon[!mask] - truth[!mask])), 0.2)
  expect_equal(fit$method, "weighted_robust_em")
  expect_equal(dim(fit$u), c(n, r))
  expect_equal(dim(fit$v), c(p, r))
})

test_that(".RobRSVD_all_weighted_R zeroes fully-masked rows and columns", {
  set.seed(9304)
  n <- 20L
  p <- 10L
  data <- matrix(stats::rnorm(n * p), n, p)
  mask <- matrix(TRUE, n, p)
  mask[3, ] <- FALSE
  mask[, 7] <- FALSE

  fit <- rajiveplus:::.RobRSVD_all_weighted_R(data, mask, nrank = 2L)
  expect_true(all(fit$u[3, ] == 0))
  expect_true(all(fit$v[7, ] == 0))
})

test_that("missmda shrinkage warns when the spectrum has no noise tail", {
  # Regression for audit F9: .shrink_singular_values now warns
  # (rajiveplus_shrinkage_inert) when length(singular_values) <= rank instead
  # of silently returning the unshrunk spectrum.
  sv <- c(8, 4, 2)
  expect_warning(
    rajiveplus:::.shrink_singular_values(
      sv, rank = 3L, shrinkage = "missmda", shrinkage_coeff = 1,
      n_rows = 20L, n_cols = 6L
    ),
    class = "rajiveplus_shrinkage_inert"
  )
})

test_that(".RobRSVD_all_weighted_R reports its convergence status", {
  # Regression for audit F4: the weighted EM loop now returns `n_iter` and
  # `converged` alongside d/u/v so callers can tell whether the iteration cap
  # was hit before the objective stabilised.
  set.seed(9305)
  data <- matrix(stats::rnorm(60), 12L, 5L)
  mask <- matrix(TRUE, 12L, 5L)
  mask[sample.int(60, 18)] <- FALSE
  res <- rajiveplus:::.RobRSVD_all_weighted_R(data, mask, nrank = 2L)
  expect_true(any(c("converged", "iterations", "n_iter") %in% names(res)))
})
