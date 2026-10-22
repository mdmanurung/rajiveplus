# Defect I1: the post-selection identifiability filter stops at the first
# rejected direction in each block.
#
# The condition is "drop a candidate joint direction if any Data Block has a
# trivial projection of it". The loop `break`s out of the inner loop as soon as
# one direction fails in a block, so a block with two unsupported directions
# records only one. The intended condition requires rejecting all of them.

# A rank-only fit reaches the identifiability filter with a known joint score
# basis, so the filter can be exercised directly on a controlled fixture.
two_unsupported_directions <- function(n = 40L) {
  set.seed(8080L)
  # Two orthonormal candidate joint directions in score space.
  basis <- qr.Q(qr(matrix(stats::rnorm(n * 2L), n, 2L)))
  u1 <- basis[, 1L]
  u2 <- basis[, 2L]

  # `score = t(X_k) %*% u_j` is large only when some column of X_k is aligned
  # with u_j. Block 1 aligns with neither candidate, so the filter must reject
  # both; block 2 aligns with both, so it rejects neither. This is the case the
  # old `break` got wrong: it stopped at the first rejection inside block 1 and
  # never examined the second candidate there.
  block_supporting_neither <- cbind(stats::rnorm(n, sd = 0.01),
                                    stats::rnorm(n, sd = 0.01))
  block_supporting_both <- cbind(u1, u2)

  blocks <- list(block_supporting_neither, block_supporting_both)
  names(blocks) <- c("block1", "block2")

  list(blocks = blocks, joint_scores = cbind(u1, u2))
}

test_that("the identifiability filter rejects every unsupported direction", {
  fixture <- two_unsupported_directions()

  dropped <- rajiveplus:::.identifiability_filter(
    blocks = fixture$blocks,
    joint_scores = fixture$joint_scores,
    sv_thresholds = rep(0.5, 2L),
    identifiability_norm = "l2",
    quiet = TRUE
  )

  expect_setequal(dropped, c(1L, 2L))
  expect_length(dropped, 2L)
})

test_that("a direction supported in every block is retained", {
  n <- 40L
  set.seed(8081L)
  u1 <- matrix(stats::rnorm(n), n, 1L)
  blocks <- list(cbind(u1, stats::rnorm(n, sd = 0.01)),
                 cbind(u1, stats::rnorm(n, sd = 0.01)))

  dropped <- rajiveplus:::.identifiability_filter(
    blocks = blocks,
    joint_scores = u1,
    sv_thresholds = rep(0.5, 2L),
    identifiability_norm = "l2",
    quiet = TRUE
  )

  expect_length(dropped, 0L)
})

test_that("the filter reports each rejection once", {
  # The rejection list is surfaced to users through
  # `fit$joint_rank_sel$identif_dropped`; duplicates there would misreport how
  # many candidate directions were actually discarded.
  fixture <- two_unsupported_directions()

  dropped <- rajiveplus:::.identifiability_filter(
    blocks = fixture$blocks,
    joint_scores = fixture$joint_scores,
    sv_thresholds = rep(0.5, 2L),
    identifiability_norm = "l2",
    quiet = TRUE
  )

  expect_identical(dropped, unique(dropped))
  expect_false(anyNA(dropped))
  expect_identical(dropped, as.integer(dropped))
})

test_that("a fully unsupported basis is removed rather than retained", {
  n <- 40L
  joint_scores <- cbind(matrix(stats::rnorm(n), n, 1L),
                        matrix(stats::rnorm(n), n, 1L))
  blocks <- list(matrix(stats::rnorm(n), n, 1L),
                 matrix(stats::rnorm(n), n, 1L))

  dropped <- rajiveplus:::.identifiability_filter(
    blocks = blocks,
    joint_scores = joint_scores,
    sv_thresholds = rep(1e6, 2L),
    identifiability_norm = "l2",
    quiet = TRUE
  )

  expect_setequal(dropped, c(1L, 2L))
})
