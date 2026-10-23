test_that("candidate basis extraction records numerical rank loss", {
  x <- diag(c(3, 1, 0))
  decomp <- svd(x)
  basis <- rajiveplus:::.extract_block_basis(
    decomp, requested_rank = 3L, tolerance = 1e-12
  )
  expect_identical(basis$requested_rank, 3L)
  expect_identical(basis$effective_rank, 2L)
  expect_identical(basis$dropped_directions, 3L)
  expect_equal(crossprod(basis$basis), diag(2), tolerance = 1e-12)

  zero <- rajiveplus:::.extract_block_basis(decomp, 0L, 1e-12)
  expect_equal(dim(zero$basis), c(3L, 0L))
})

test_that("geometric aggregation is invariant to signs permutations and rotations", {
  set.seed(9801L)
  q1 <- qr.Q(qr(matrix(rnorm(30), 10, 3)))
  q2 <- qr.Q(qr(matrix(rnorm(20), 10, 2)))
  base <- rajiveplus:::.aggregate_geometric_bases(list(q1, q2))

  rotated <- list(q1 %*% diag(c(-1, 1, -1)), q2[, 2:1, drop = FALSE])
  transformed <- rajiveplus:::.aggregate_geometric_bases(rotated)
  expect_equal(base$eigenvalues, transformed$eigenvalues, tolerance = 1e-12)
  expect_equal(rajiveplus:::.projector(base$basis),
               rajiveplus:::.projector(transformed$basis), tolerance = 1e-10)

  rotation <- qr.Q(qr(matrix(rnorm(9), 3, 3)))
  rotated_all <- rajiveplus:::.aggregate_geometric_bases(
    list(q1 %*% rotation, q2)
  )
  expect_equal(base$eigenvalues, rotated_all$eigenvalues, tolerance = 1e-12)
})

test_that("tied eigenspaces are compared as full subspaces", {
  q <- diag(4)[, 1:2, drop = FALSE]
  rotation <- matrix(c(0, -1, 1, 0), 2, 2)
  a <- rajiveplus:::.aggregate_geometric_bases(list(q, q))
  b <- rajiveplus:::.aggregate_geometric_bases(list(q %*% rotation, q))
  expect_equal(a$eigenvalues[1:2], c(2, 2), tolerance = 1e-12)
  expect_equal(rajiveplus:::.projector(a$basis[, 1:2, drop = FALSE]),
               rajiveplus:::.projector(b$basis[, 1:2, drop = FALSE]),
               tolerance = 1e-12)
})

test_that("identifiability counterexample returns every rejected direction", {
  joint_scores <- diag(4)[, 1:3, drop = FALSE]
  blocks <- list(
    cbind(c(1, 0, 0, 0), c(0, 0, 0, 1)),
    cbind(c(0, 1, 0, 0), c(0, 0, 0, 1))
  )
  dropped <- rajiveplus:::.identifiability_rejections(
    blocks, joint_scores, thresholds = c(0.5, 0.5), norm = "l2"
  )
  expect_identical(dropped, c(1L, 2L, 3L))
})

test_that("Wedin resampling handles rank-zero and saturated boundaries", {
  x <- matrix(seq_len(12), 4, 3)
  zero <- rajiveplus:::wedin_bound_resampling(
    x, matrix(numeric(), 4, 0), FALSE, num_samples = 3L, num_cores = 1L
  )
  expect_identical(zero, rep(0, 3L))

  saturated_left <- rajiveplus:::.wedin_bound_resampling_candidate(
    x, diag(4), FALSE, num_samples = 3L
  )
  saturated_right <- rajiveplus:::.wedin_bound_resampling_candidate(
    x, diag(3), TRUE, num_samples = 3L
  )
  expect_equal(as.numeric(saturated_left), rep(0, 3L), tolerance = 1e-10)
  expect_equal(as.numeric(saturated_right), rep(0, 3L), tolerance = 1e-10)
})

test_that("simulation reconstruction is sign-invariant", {
  sim <- rajiveplus:::.simulate_identifiable_data(
    2L, 15L, c(6L, 6L), 1L, c(1L, 1L), seed = 9802L
  )
  scores <- -sim$truth$joint_scores
  loadings <- -sim$truth$joint_loadings[[1L]]
  reconstructed <- scores %*% diag(2, 1L, 1L) %*% t(loadings)
  expect_equal(unname(reconstructed), unname(sim$truth$joint[[1L]]),
               tolerance = 1e-12)
})
