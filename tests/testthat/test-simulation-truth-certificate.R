certificate_fixture <- function() {
  n <- 6L
  axes <- diag(n)
  J <- lapply(1:3, function(k) 2 * outer(axes[, 1], c(1, 0, 0)))
  I <- lapply(c(2, 2, 3), function(j) 3 * outer(axes[, j], c(0, 1, 0)))
  E <- lapply(J, function(x) x * 0)
  names(J) <- names(I) <- names(E) <- c("a", "b", "c")
  list(
    blocks = Map(`+`, J, I),
    truth = list(
      joint = J, individual = I, residual = E,
      joint_rank = 1L, individual_ranks = c(1L, 1L, 1L),
      joint_basis = axes[, 1, drop = FALSE],
      individual_bases = lapply(c(2, 2, 3), function(j) axes[, j, drop = FALSE]),
      joint_scores = axes[, 1, drop = FALSE] * sqrt(n),
      individual_scores = lapply(c(2, 2, 3), function(j) {
        axes[, j, drop = FALSE] * sqrt(n)
      })
    )
  )
}

test_that("infeasible feature and common-Individual ranks are rejected before RNG", {
  invalid <- list(
    list(n = 12L, pks = c(2L, 2L), joint_rank = 3L,
         individual_ranks = c(1L, 1L)),
    list(n = 12L, pks = c(3L, 3L), joint_rank = 2L,
         individual_ranks = c(2L, 1L)),
    list(n = 8L, pks = c(10L, 10L), joint_rank = 2L,
         individual_ranks = c(4L, 4L)),
    list(n = 10L, pks = 5L, joint_rank = 1L, individual_ranks = 1L)
  )
  for (args in invalid) {
    set.seed(7161L)
    before <- .Random.seed
    expect_error(do.call(simulate_blocks, c(args, list(seed = 99L))),
                 class = "rajiveplus_invalid_input")
    expect_true(identical(.Random.seed, before),
                info = "infeasible input must fail before consuming RNG")
  }
})

test_that("every valid draw carries a recomputable matrix-based certificate", {
  sim <- simulate_blocks(12L, c(6L, 5L, 4L), 1L, c(2L, 2L, 1L),
                         block_names = c("rna", "protein", "metabolite"),
                         seed = 7161L)
  expect_identical(sim$truth$certificate$status, "PASS")
  before <- .Random.seed
  repeated <- rajiveplus:::.certify_simulated_truth(sim)
  expect_identical(.Random.seed, before)
  expect_equal(sim$truth$certificate, repeated)
  expect_identical(repeated$individual_intersection_rank, 0L)
  expect_identical(repeated$signal_intersection_rank, 1L)
  expect_identical(repeated$blocks$signal_rank, c(3L, 3L, 2L))
  expect_identical(repeated$blocks$block, names(sim$blocks))
})

test_that("independent controls allow pairwise but reject all-block sharing", {
  sim <- certificate_fixture()
  certificate <- rajiveplus:::.certify_simulated_truth(sim)
  expect_identical(certificate$status, "PASS")
  expect_identical(certificate$individual_intersection_rank, 0L)
  # Blocks 1 and 2 share an Individual direction; block 3 does not.
  sim$truth$individual[[3]] <- sim$truth$individual[[1]]
  sim$truth$individual_bases[[3]] <- sim$truth$individual_bases[[1]]
  sim$truth$individual_scores[[3]] <- sim$truth$individual_scores[[1]]
  sim$blocks[[3]] <- sim$truth$joint[[3]] + sim$truth$individual[[3]]
  expect_error(rajiveplus:::.certify_simulated_truth(sim),
               class = "rajiveplus_invalid_simulation")
})

test_that("certification checks actual matrices and metadata, not cached status", {
  sim <- certificate_fixture()
  sim$truth$certificate <- list(status = "PASS")
  variants <- list()
  variants[[1]] <- sim
  variants[[1]]$truth$joint[[1]][] <- 0
  variants[[2]] <- sim
  variants[[2]]$truth$joint_basis <- diag(6)[, 4, drop = FALSE]
  variants[[3]] <- sim
  variants[[3]]$truth$individual_scores[[1]] <- diag(6)[, 4, drop = FALSE]
  variants[[4]] <- sim
  variants[[4]]$blocks[[1]][1, 1] <- Inf
  variants[[5]] <- sim
  variants[[5]]$blocks[[1]][1, 1] <- variants[[5]]$blocks[[1]][1, 1] + 1
  variants[[6]] <- sim
  variants[[6]]$truth$individual[[1]] <- sim$truth$joint[[1]]
  variants[[6]]$blocks[[1]] <- variants[[6]]$truth$joint[[1]] * 2
  for (bad in variants) {
    expect_error(rajiveplus:::.certify_simulated_truth(bad),
                 class = "rajiveplus_invalid_simulation")
  }
})

test_that("zero, saturated, single-block and feasible boundary ranks certify", {
  scenarios <- list(
    list(n = 6L, pks = c(4L, 4L), joint_rank = 0L,
         individual_ranks = c(0L, 0L), noise_sd = 0),
    list(n = 6L, pks = c(6L, 6L), joint_rank = 6L,
         individual_ranks = c(0L, 0L), noise_sd = 0),
    list(n = 6L, pks = c(4L, 4L), joint_rank = 2L,
         individual_ranks = c(2L, 2L)),
    list(n = 5L, pks = 2L, joint_rank = 2L, individual_ranks = 0L),
    list(n = 5L, pks = c(4L, 4L, 4L), joint_rank = 1L,
         individual_ranks = c(3L, 3L, 2L))
  )
  for (args in scenarios) for (seed in 1:4) {
    a <- do.call(simulate_blocks, c(args, list(seed = seed)))
    b <- do.call(simulate_blocks, c(args, list(seed = seed)))
    expect_identical(a, b)
    expect_identical(a$truth$certificate$status, "PASS")
    expect_identical(a$truth$certificate$signal_intersection_rank,
                     args$joint_rank)
  }
})

test_that("invalid real-matrix and oversized-rank truth contracts fail structurally", {
  sim <- simulate_blocks(n = 12, pks = c(6, 6), joint_rank = 1,
                         individual_ranks = c(1, 1), seed = 42)
  bad <- sim
  bad$blocks[[1]] <- bad$blocks[[1]] + 0i
  expect_error(.certify_simulated_truth(bad), class = "rajiveplus_invalid_simulation")
  bad <- sim
  bad$truth$joint_rank <- 2^40
  expect_error(.certify_simulated_truth(bad), class = "rajiveplus_invalid_simulation")
  expect_error(.certify_simulated_truth(sim, geometry_tolerance = 1i),
               class = "rajiveplus_invalid_simulation")
})
